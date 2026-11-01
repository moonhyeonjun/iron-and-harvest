class_name InteractionController
extends Node2D
## Selects the interaction target the player faces and runs one request at a time (IH-102).
## Input callbacks only queue intents; every check and action happens in the next
## physics tick, after the player has moved (process_physics_priority 10 > player 0).
## Range/facing/keys are provisional verification values (INTERACTION.md, ADR-014).

signal target_changed(target_id: StringName, action_label: String, display_name: String)
signal session_opened(request_id: int, title: String, description: String)
signal session_closed(request_id: int, reason: StringName)
signal request_rejected(request_id: int, reason: StringName)
## An INSTANT target's command committed (IH-111). `result` is the command's own result.
signal instant_completed(request_id: int, target_id: StringName, result: RefCounted)

enum State { IDLE, RESOLVING, ACTIVE, EXECUTING }

const NO_TARGET: StringName = &"NO_TARGET"
const INVALID_TARGET: StringName = &"INVALID_TARGET"
const DISABLED: StringName = &"DISABLED"
const CONTROL_BLOCKED: StringName = &"CONTROL_BLOCKED"
const OUT_OF_RANGE: StringName = &"OUT_OF_RANGE"
const NOT_FACING: StringName = &"NOT_FACING"
const OCCLUDED: StringName = &"OCCLUDED"
const BUSY: StringName = &"BUSY"
const TARGET_REJECTED: StringName = &"TARGET_REJECTED"
const CANCELLED: StringName = &"CANCELLED"
const COMPLETED: StringName = &"COMPLETED"
const FOCUS_LOST: StringName = &"FOCUS_LOST"
const REMOVED: StringName = &"REMOVED"
const OK: StringName = &""

const WORLD_SOLID_MASK: int = 1
const ACTION_INTERACT: StringName = &"interact"
const ACTION_CANCEL: StringName = &"interaction_cancel"

## Feet-to-anchor distance in world units. Final value is TBD.
@export var interaction_range: float = 32.0
## Minimum dot between facing and the direction to the anchor (0.5 = +-60 degrees).
@export var min_facing_dot: float = 0.5

var _player: PlayerController
## instance_id -> WeakRef(InteractionTarget), maintained by Detector enter/exit only.
var _candidates: Dictionary = {}
var _selected: WeakRef = null
var _selected_id: StringName = &""
var _queued_request_id: int = 0
var _queued_target: WeakRef = null
var _queued_target_id: StringName = &""
var _cancel_queued: bool = false
var _next_request_id: int = 1
var _state: State = State.IDLE
var _active_request_id: int = 0
var _active_target: WeakRef = null
var _active_target_id: StringName = &""
## First reason the controller became unable to start while try_begin was running.
var _resolve_cancel: StringName = &""
var _owns_movement_gate: bool = false
## True while an INSTANT result is being cleaned up and reported; with EXECUTING it marks
## the window in which a re-entrant E press is dropped instead of queued for the next tick.
var _reporting: bool = false
var _enabled: bool = true
var _window_focused: bool = true

@onready var _detector: Area2D = $Detector


func _ready() -> void:
	_player = get_parent() as PlayerController
	_detector.area_entered.connect(_on_area_entered)
	_detector.area_exited.connect(_on_area_exited)
	for area: Area2D in _detector.get_overlapping_areas():
		_on_area_entered(area)


func _exit_tree() -> void:
	_cancel_resolving(REMOVED)
	_candidates.clear()
	_cancel_queued = false
	_discard_queue(REMOVED)
	if _state == State.ACTIVE:
		_close_active(REMOVED)
	_set_selected(null)


func set_interaction_enabled(enabled: bool) -> void:
	if enabled == _enabled:
		return
	_enabled = enabled
	if not enabled:
		_cancel_resolving(DISABLED)
		_discard_queue(DISABLED)
		if _state == State.ACTIVE:
			_close_active(DISABLED)
		_set_selected(null)


## Ends the active session only when request_id matches it; stale IDs are ignored.
func finish_active(request_id: int, reason: StringName) -> void:
	if _state != State.ACTIVE or request_id != _active_request_id:
		return
	_close_active(reason)


func get_state() -> State:
	return _state


## Read-only view of the enable flag, for the inventory coordinator (IH-110).
func is_interaction_enabled() -> bool:
	return _enabled


func get_selected_target_id() -> StringName:
	return _selected_id


func get_active_request_id() -> int:
	return _active_request_id


func get_candidate_count() -> int:
	return _candidates.size()


func _notification(what: int) -> void:
	# Focus notifications may arrive before _ready (BUG-001); only flags change then.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
		if not is_node_ready():
			return
		_cancel_resolving(FOCUS_LOST)
		_discard_queue(FOCUS_LOST)
		if _state == State.ACTIVE:
			_close_active(FOCUS_LOST)
		_set_selected(null)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# No automatic restart; the player still needs a new press.
		_window_focused = true


func _unhandled_input(event: InputEvent) -> void:
	if (_state == State.EXECUTING or _reporting) and event.is_action(ACTION_INTERACT):
		# Pressed from inside a commit or its callbacks: consumed, never a next-tick job.
		get_viewport().set_input_as_handled()
		return
	if _state == State.RESOLVING and event.is_action_pressed(ACTION_CANCEL, false):
		# Escape while try_begin runs cancels this request before anything commits.
		_cancel_resolving(CANCELLED)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ACTION_INTERACT, false):
		# One intent per tick: repeated presses before it is processed get no new ID.
		if _queued_request_id == 0:
			_queued_request_id = _next_request_id
			_next_request_id += 1
			_queued_target = _selected
			_queued_target_id = _selected_id
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_CANCEL, false):
		# Only consume Escape when there is something of ours to cancel.
		if _state == State.ACTIVE or _queued_request_id != 0:
			_cancel_queued = true
			get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if _cancel_queued:
		_cancel_queued = false
		_discard_queue(CANCELLED)
		if _state == State.ACTIVE:
			_close_active(CANCELLED)
	if _state == State.ACTIVE:
		_revalidate_active()
	if _queued_request_id != 0:
		_resolve_queued()
	# A commit callback may have taken us out of the tree; no physics queries then.
	if not is_inside_tree() or not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	_update_selection()


func _resolve_queued() -> void:
	var request_id: int = _queued_request_id
	var target: InteractionTarget = _queued_target.get_ref() as InteractionTarget if _queued_target != null else null
	var captured_id: StringName = _queued_target_id
	_clear_queue()
	var reason: StringName = BUSY if _state != State.IDLE else _start_blocker()
	if reason == OK:
		if captured_id.is_empty() and target == null:
			reason = NO_TARGET
		else:
			# Only the target shown when E was pressed is checked; never a substitute.
			reason = _check_target(target, captured_id)
	if reason != OK:
		request_rejected.emit(request_id, reason)
		return
	_state = State.RESOLVING
	_resolve_cancel = &""
	var began: bool = target.try_begin(request_id)
	# INSTANT targets hand over their prepared command now, before the last re-check.
	var instant: bool = began and is_instance_valid(target) \
		and target.get_execution_kind() == InteractionTarget.ExecutionKind.INSTANT
	var command: RefCounted = target.get_prepared_command(request_id) if instant else null
	# try_begin may disable us, take focus, detach or free us, or change the target.
	# Re-check everything a start needs; the controller's own state comes first so no
	# physics query runs outside the tree.
	var cancel: StringName = _resolve_cancel
	_resolve_cancel = &""
	if cancel.is_empty():
		cancel = _start_blocker()
	if cancel.is_empty() and began:
		cancel = _check_target(target, captured_id)
	if cancel.is_empty() and instant and (command == null or not command.has_method("commit")):
		cancel = TARGET_REJECTED
	_state = State.IDLE
	if not began:
		request_rejected.emit(request_id, cancel if not cancel.is_empty() else TARGET_REJECTED)
		return
	if not cancel.is_empty():
		# Accepted by the target but no longer startable: undo once, report once.
		if command != null and command.has_method("cancel"):
			command.cancel()
		if is_instance_valid(target):
			target.end_interaction(request_id, true)
		request_rejected.emit(request_id, cancel)
		return
	if instant:
		_execute_instant(request_id, target, captured_id, command)
		return
	_state = State.ACTIVE
	_active_request_id = request_id
	_active_target = weakref(target)
	_active_target_id = captured_id
	_player.set_control_enabled(false)
	_owns_movement_gate = true
	_set_selected(null)
	session_opened.emit(request_id, target.display_name, target.description)


## Runs a prepared INSTANT command synchronously with no signal or callback of ours in
## between. Once the command reports success the transfer is installed: removal of the
## target, UI or this controller during its change signal never undoes or retries it, and
## it opens no panel and never touches the movement gate.
func _execute_instant(request_id: int, target: InteractionTarget, target_id: StringName, command: RefCounted) -> void:
	_state = State.EXECUTING
	var result: RefCounted = command.commit()
	_state = State.IDLE
	_reporting = true
	var ok: bool = result != null and result.get("ok") == true
	if is_instance_valid(target):
		target.end_interaction(request_id, not ok)
	if is_inside_tree() and not is_queued_for_deletion():
		if ok:
			instant_completed.emit(request_id, target_id, result)
		else:
			request_rejected.emit(request_id, StringName(result.get("code")) if result != null else TARGET_REJECTED)
	_reporting = false


func _revalidate_active() -> void:
	# Deleted, hidden, unavailable, renamed, duplicated, pushed away or walled off: cancel.
	var target: InteractionTarget = _active_target.get_ref() as InteractionTarget
	var reason: StringName = _check_target(target, _active_target_id, false)
	if reason != OK:
		_close_active(reason)


## Clears state, references and the queue first so re-entrant calls see IDLE, then
## notifies the target, releases only our own gate and reports once.
func _close_active(reason: StringName) -> void:
	var request_id: int = _active_request_id
	var target: InteractionTarget = _active_target.get_ref() as InteractionTarget if _active_target != null else null
	_state = State.IDLE
	_active_request_id = 0
	_active_target = null
	_active_target_id = &""
	# An E queued during the session still gets a result, never a silent drop.
	_discard_queue(BUSY)
	if is_instance_valid(target):
		target.end_interaction(request_id, reason != COMPLETED)
	if _owns_movement_gate:
		_owns_movement_gate = false
		if is_instance_valid(_player):
			_player.set_control_enabled(true)
	session_closed.emit(request_id, reason)


func _update_selection() -> void:
	if _state != State.IDLE or not _enabled or not _window_focused or not _player.is_control_effective():
		_set_selected(null)
		return
	var best: InteractionTarget = null
	var best_key: Array = []
	for key: int in _candidates.keys():
		var target: InteractionTarget = (_candidates[key] as WeakRef).get_ref() as InteractionTarget
		if target == null:
			_candidates.erase(key)
			continue
		# Same rule set as request execution, including the duplicate-ID check.
		if _check_target(target, target.target_id) != OK:
			continue
		var offset: Vector2 = target.get_anchor_position() - _player.global_position
		var dot: float = 1.0 if offset.is_zero_approx() else _facing_vector().dot(offset.normalized())
		# Integer tuple keeps the order total and independent of signal arrival order.
		var sort_key: Array = [roundi(offset.length() * 1000.0), -roundi(dot * 1000000.0), String(target.target_id)]
		if best == null or _key_less(sort_key, best_key):
			best = target
			best_key = sort_key
	_set_selected(best)


## OK or the reason the target cannot be used from the player's current feet position.
func _check_target(target: InteractionTarget, expected_id: StringName, check_facing: bool = true) -> StringName:
	if not _is_usable(target, expected_id) or _has_usable_twin(target):
		return INVALID_TARGET
	var offset: Vector2 = target.get_anchor_position() - _player.global_position
	var distance: float = offset.length()
	if distance > interaction_range:
		return OUT_OF_RANGE
	# Distance zero exempts only the facing rule; a wall at that point still blocks.
	if check_facing and distance > 0.0 and _facing_vector().dot(offset / distance) < min_facing_dot:
		return NOT_FACING
	if _is_occluded(target.get_anchor_position(), distance):
		return OCCLUDED
	return OK


## A repeated ID among usable candidates makes every holder of it invalid, both when
## selecting and when executing or keeping a session. Only the bounded candidate set is
## scanned, never the whole map.
func _has_usable_twin(target: InteractionTarget) -> bool:
	for key: int in _candidates:
		var other: InteractionTarget = (_candidates[key] as WeakRef).get_ref() as InteractionTarget
		if other != target and _is_usable(other, target.target_id):
			return true
	return false


## Controller-side reason a request cannot start now (or OK).
func _start_blocker() -> StringName:
	if not is_inside_tree() or is_queued_for_deletion():
		return REMOVED
	if not _enabled:
		return DISABLED
	if not _window_focused:
		return FOCUS_LOST
	if not is_instance_valid(_player) or _player.is_queued_for_deletion() or not _player.is_control_effective():
		# Someone else holds the movement gate; never open over or unlock it.
		return CONTROL_BLOCKED
	return OK


func _cancel_resolving(reason: StringName) -> void:
	if _state == State.RESOLVING and _resolve_cancel.is_empty():
		_resolve_cancel = reason


func _is_usable(target: InteractionTarget, expected_id: StringName) -> bool:
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion():
		return false
	if not target.is_visible_in_tree() or not target.can_interact() or not target.is_registered():
		return false
	return expected_id.is_empty() or target.target_id == expected_id


func _is_occluded(anchor: Vector2, distance: float) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if distance == 0.0:
		var point: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		point.position = anchor
		point.collision_mask = WORLD_SOLID_MASK
		point.collide_with_bodies = true
		point.collide_with_areas = false
		return not space.intersect_point(point, 1).is_empty()
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		_player.global_position, anchor, WORLD_SOLID_MASK, [_player.get_rid()])
	ray.collide_with_bodies = true
	ray.collide_with_areas = false
	ray.hit_from_inside = true
	return not space.intersect_ray(ray).is_empty()


func _facing_vector() -> Vector2:
	match _player.get_facing():
		PlayerController.Facing.UP:
			return Vector2.UP
		PlayerController.Facing.LEFT:
			return Vector2.LEFT
		PlayerController.Facing.RIGHT:
			return Vector2.RIGHT
	return Vector2.DOWN


func _key_less(a: Array, b: Array) -> bool:
	if a[0] != b[0]:
		return a[0] < b[0]
	if a[1] != b[1]:
		return a[1] < b[1]
	return (a[2] as String) < (b[2] as String)


func _set_selected(target: InteractionTarget) -> void:
	var target_id: StringName = target.target_id if target != null else &""
	_selected = weakref(target) if target != null else null
	if target_id == _selected_id:
		return
	_selected_id = target_id
	if target == null:
		target_changed.emit(&"", "", "")
	else:
		target_changed.emit(target_id, target.action_label, target.display_name)


func _clear_queue() -> void:
	_queued_request_id = 0
	_queued_target = null
	_queued_target_id = &""


func _discard_queue(reason: StringName) -> void:
	if _queued_request_id != 0:
		var request_id: int = _queued_request_id
		_clear_queue()
		request_rejected.emit(request_id, reason)


func _on_area_entered(area: Area2D) -> void:
	if area is InteractionTarget:
		_candidates[area.get_instance_id()] = weakref(area)


func _on_area_exited(area: Area2D) -> void:
	_candidates.erase(area.get_instance_id())
