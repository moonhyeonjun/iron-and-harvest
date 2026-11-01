class_name InventoryController
extends Node
## Scene adapter for the bag/store panel (IH-110). It is the only owner of that panel and,
## while it is open, of one movement gate and of the interaction enable flag it turned off.
## It routes keys, gives each opened panel a session ID and forwards UI intents to the
## InventoryService; it never edits inventory state or lets the UI touch the gate.
## Bag and inspect panel are mutually exclusive; no general lock system is introduced.

signal opened(session_id: int, view: View)
signal closed(session_id: int, reason: StringName)
signal open_rejected(reason: StringName)
signal command_finished(session_id: int, code: StringName)

enum State { CLOSED, OPENING, OPEN }
enum View { BAG, STORE }

const OK: StringName = &""
const BUSY: StringName = &"BUSY"
const NOT_READY: StringName = &"NOT_READY"
const REMOVED: StringName = &"REMOVED"
const FOCUS_LOST: StringName = &"FOCUS_LOST"
const SERVICE_UNAVAILABLE: StringName = &"SERVICE_UNAVAILABLE"
const INTERACTION_BUSY: StringName = &"INTERACTION_BUSY"
const INTERACTION_DISABLED: StringName = &"INTERACTION_DISABLED"
const CONTROL_BLOCKED: StringName = &"CONTROL_BLOCKED"
const CLOSED_BY_USER: StringName = &"CLOSED_BY_USER"
const STALE_SESSION: StringName = &"STALE_SESSION"
const WRONG_VIEW: StringName = &"WRONG_VIEW"
const SELECTION_CHANGED: StringName = &"SELECTION_CHANGED"

const ACTION_TOGGLE: StringName = &"inventory_toggle"
const ACTION_CANCEL: StringName = &"inventory_cancel"
## Keys swallowed while the panel is open so the world never sees them.
const WORLD_ACTIONS: Array[StringName] = [&"interact", &"interaction_cancel"]

var _service: InventoryService
var _player: PlayerController
var _interaction: InteractionController
var _ui: InventoryUI
var _bag_id: StringName = &""
var _store_id: StringName = &""
var _state: State = State.CLOSED
var _view: View = View.BAG
var _session_id: int = 0
var _owns_gate: bool = false
var _disabled_interaction: bool = false
## First reason a close/focus-out/removal arrived while opening; the open then aborts.
var _open_cancel: StringName = &""
var _window_focused: bool = true


func setup(service: InventoryService, player: PlayerController, interaction: InteractionController,
		ui: InventoryUI, bag_id: StringName, store_id: StringName) -> void:
	_service = service
	_player = player
	_interaction = interaction
	_ui = ui
	_bag_id = bag_id
	_store_id = store_id
	_ui.transfer_requested.connect(_on_transfer_requested)
	_ui.close_requested.connect(_on_close_requested)
	_ui.view_requested.connect(_on_view_requested)
	_service.inventories_changed.connect(_on_inventories_changed)


func get_state() -> State:
	return _state


func get_session_id() -> int:
	return _session_id if _state == State.OPEN else 0


func get_view() -> View:
	return _view


func owns_movement_gate() -> bool:
	return _owns_gate


## Opens the panel in `view`, or switches the open panel to it (new session ID).
func request_open(view: View) -> StringName:
	if _state == State.OPENING:
		return _reject(BUSY)
	if _state == State.OPEN:
		if view != _view:
			_show(view)
		return OK
	var reason: StringName = _open_blocker()
	if reason != OK:
		return _reject(reason)
	_state = State.OPENING
	_open_cancel = &""
	# Turning interaction off discards a queued E and may run callbacks that close us,
	# take focus or free nodes; every precondition is checked again afterwards.
	_interaction.set_interaction_enabled(false)
	_disabled_interaction = true
	reason = _open_cancel if not _open_cancel.is_empty() else _still_openable()
	_open_cancel = &""
	if reason != OK:
		_state = State.CLOSED
		_restore_interaction()
		return _reject(reason)
	_player.set_control_enabled(false)
	_owns_gate = true
	_state = State.OPEN
	_show(view)
	return OK


## Closes once: clears the view, releases our gate, restores what we disabled, reports.
func request_close(reason: StringName) -> void:
	if _state == State.OPENING:
		if _open_cancel.is_empty():
			_open_cancel = reason
		return
	if _state != State.OPEN:
		return
	var session_id: int = _session_id
	_state = State.CLOSED
	if is_instance_valid(_ui):
		_ui.close_view(session_id)
	if _owns_gate:
		_owns_gate = false
		if is_instance_valid(_player):
			_player.set_control_enabled(true)
	_restore_interaction()
	closed.emit(session_id, reason)


func _notification(what: int) -> void:
	# May arrive before _ready (BUG-001 rule): only the flag changes then.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
		if is_node_ready():
			request_close(FOCUS_LOST)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_focused = true


func _exit_tree() -> void:
	request_close(REMOVED)


func _physics_process(_delta: float) -> void:
	if _state == State.OPEN and not _player_usable():
		request_close(REMOVED)


## Closed: I opens the bag. Open: handled here, after the focused GUI control, so a
## focused Button cannot hide I/Escape and the same event is never routed twice.
func _unhandled_input(event: InputEvent) -> void:
	if _state == State.CLOSED and event.is_action_pressed(ACTION_TOGGLE, false):
		get_viewport().set_input_as_handled()
		request_open(View.BAG)


func _shortcut_input(event: InputEvent) -> void:
	if _state != State.OPEN:
		return
	if event.is_action(ACTION_TOGGLE) or event.is_action(ACTION_CANCEL):
		get_viewport().set_input_as_handled()
		if event.is_pressed() and not event.is_echo():
			request_close(CLOSED_BY_USER)
		return
	for action: StringName in WORLD_ACTIONS:
		if event.is_action(action):
			get_viewport().set_input_as_handled()
			return


func _open_blocker() -> StringName:
	if _service == null or not is_instance_valid(_ui) or not is_instance_valid(_interaction):
		return NOT_READY
	if not is_inside_tree() or is_queued_for_deletion() or not _player_usable():
		return REMOVED
	if not _window_focused:
		return FOCUS_LOST
	if _service.is_closed() or not _service.is_catalog_valid():
		return SERVICE_UNAVAILABLE
	if _interaction.get_state() != InteractionController.State.IDLE:
		return INTERACTION_BUSY
	if not _interaction.is_interaction_enabled():
		return INTERACTION_DISABLED
	if not _player.is_control_effective():
		return CONTROL_BLOCKED
	return OK


func _still_openable() -> StringName:
	if not is_inside_tree() or is_queued_for_deletion() or not _player_usable() or not is_instance_valid(_interaction):
		return REMOVED
	if not _window_focused:
		return FOCUS_LOST
	if _interaction.get_state() != InteractionController.State.IDLE:
		return INTERACTION_BUSY
	if not _player.is_control_effective():
		return CONTROL_BLOCKED
	return OK


func _player_usable() -> bool:
	return is_instance_valid(_player) and _player.is_inside_tree() and not _player.is_queued_for_deletion()


func _reject(reason: StringName) -> StringName:
	if is_instance_valid(_ui):
		_ui.show_notice(reason)
	open_rejected.emit(reason)
	return reason


func _restore_interaction() -> void:
	if _disabled_interaction:
		_disabled_interaction = false
		if is_instance_valid(_interaction):
			_interaction.set_interaction_enabled(true)


func _show(view: View) -> void:
	_view = view
	_session_id += 1
	_ui.open_view(_session_id, view, _view_model())
	opened.emit(_session_id, view)


func _view_model() -> Dictionary:
	var names: Dictionary = {}
	for item_id: StringName in _service.get_item_ids():
		names[String(item_id)] = _service.get_item_info(item_id).fallback_name
	var bag: InventoryService.Result = _service.snapshot(_bag_id)
	var store: InventoryService.Result = _service.snapshot(_store_id)
	return {
		"names": names,
		"bag": bag.value if bag.ok else null,
		"store": store.value if store.ok and _view == View.STORE else null,
	}


func _on_inventories_changed(_changed: Array[StringName], _revisions: Dictionary) -> void:
	# Display only; never issues another command from here.
	if _state == State.OPEN:
		_ui.update_view(_session_id, _view_model())


## One UI action -> at most one service command, using the revisions and item captured
## when the UI showed the slot. Failures show a message and the latest state, no retry.
func _on_transfer_requested(session_id: int, source_id: StringName, source_slot: int, item_id: StringName,
		quantity: int, source_revision: int, destination_revision: int) -> void:
	var code: StringName = _transfer_blocker(session_id, source_id, source_slot, item_id)
	if code == OK:
		var destination_id: StringName = _store_id if source_id == _bag_id else _bag_id
		code = _service.transfer(source_id, source_slot, destination_id, quantity, source_revision, destination_revision).code
	if _state == State.OPEN and session_id == _session_id:
		_ui.show_result(session_id, code)
		_ui.update_view(session_id, _view_model())
	command_finished.emit(session_id, code)


func _transfer_blocker(session_id: int, source_id: StringName, source_slot: int, item_id: StringName) -> StringName:
	if _state != State.OPEN or session_id != _session_id:
		return STALE_SESSION
	if _view != View.STORE or (source_id != _bag_id and source_id != _store_id):
		return WRONG_VIEW
	var current: InventoryService.Result = _service.snapshot(source_id)
	if not current.ok:
		return current.code
	var slots: Array = current.value.slots
	if source_slot < 0 or source_slot >= slots.size() or slots[source_slot] == null \
			or StringName(slots[source_slot].item_id) != item_id:
		return SELECTION_CHANGED
	return OK


func _on_close_requested(session_id: int) -> void:
	if _state == State.OPEN and session_id == _session_id:
		request_close(CLOSED_BY_USER)


func _on_view_requested(session_id: int, view: int) -> void:
	if _state == State.OPEN and session_id == _session_id:
		request_open(view as View)
