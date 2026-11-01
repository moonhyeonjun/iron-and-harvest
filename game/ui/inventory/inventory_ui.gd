class_name InventoryUI
extends CanvasLayer
## Read-only bag/store panel (IH-110). It shows copies the controller hands it, keeps the
## local slot selection and emits intents tagged with the session ID and the item and
## revisions it displayed. It never calls the inventory service, never edits state and
## never touches the movement gate; I/Escape are routed by InventoryController.

signal transfer_requested(session_id: int, source_id: StringName, source_slot: int, item_id: StringName,
	quantity: int, source_revision: int, destination_revision: int)
signal close_requested(session_id: int)
signal view_requested(session_id: int, view: int)

const COLUMNS: int = 4
const MESSAGES: Dictionary = {
	&"OK": "옮겼습니다.",
	&"NO_SPACE": "받는 쪽에 공간이 부족합니다. 수량은 그대로입니다.",
	&"STALE_REVISION": "내용이 바뀌었습니다. 최신 상태를 보고 다시 선택하세요.",
	&"SELECTION_CHANGED": "선택한 칸이 바뀌었습니다. 다시 선택하세요.",
	&"STALE_SESSION": "이미 닫힌 화면의 요청입니다.",
	&"EMPTY_SLOT": "빈 칸입니다.",
	&"INSUFFICIENT_QUANTITY": "선택한 칸의 수량이 부족합니다.",
	&"BUSY": "처리 중입니다. 다시 시도하세요.",
	&"INTERACTION_BUSY": "살펴보기를 먼저 닫으세요.",
	&"CONTROL_BLOCKED": "지금은 가방을 열 수 없습니다. 이동 키를 놓고 다시 시도하세요.",
	&"INTERACTION_DISABLED": "지금은 가방을 열 수 없습니다.",
	&"FOCUS_LOST": "창이 비활성 상태입니다.",
	&"SERVICE_UNAVAILABLE": "인벤토리를 사용할 수 없습니다.",
}

var _session_id: int = 0
var _view: int = 0
var _model: Dictionary = {}
var _selected_side: String = ""
var _selected_slot: int = -1
var _slot_buttons: Dictionary = {"bag": [], "store": []}

@onready var _panel: Control = $Panel
@onready var _title: Label = $Panel/Layout/Title
@onready var _store_column: Control = $Panel/Layout/Columns/Store
@onready var _bag_label: Label = $Panel/Layout/Columns/Bag/Label
@onready var _store_label: Label = $Panel/Layout/Columns/Store/Label
@onready var _selection_label: Label = $Panel/Layout/Selection
@onready var _message_label: Label = $Panel/Layout/Message
@onready var _move_one: Button = $Panel/Layout/Actions/MoveOne
@onready var _move_stack: Button = $Panel/Layout/Actions/MoveStack
@onready var _view_toggle: Button = $Panel/Layout/Actions/ViewToggle
@onready var _close_button: Button = $Panel/Layout/Actions/Close
@onready var _notice: Label = $Notice
@onready var _notice_timer: Timer = $NoticeTimer


func _ready() -> void:
	_panel.visible = false
	_notice.visible = false
	for side: String in ["bag", "store"]:
		var grid: GridContainer = get_node("Panel/Layout/Columns/%s/Grid" % side.capitalize()) as GridContainer
		grid.columns = COLUMNS
	_move_one.pressed.connect(func() -> void: _request_transfer(false))
	_move_stack.pressed.connect(func() -> void: _request_transfer(true))
	_view_toggle.pressed.connect(func() -> void: view_requested.emit(_session_id, 0 if _view == 1 else 1))
	_close_button.pressed.connect(func() -> void: close_requested.emit(_session_id))
	_notice_timer.timeout.connect(func() -> void: _notice.visible = false)


func open_view(session_id: int, view: int, model: Dictionary) -> void:
	_session_id = session_id
	_view = view
	_selected_side = ""
	_selected_slot = -1
	_message_label.text = ""
	_notice.visible = false
	_apply_model(model)
	_panel.visible = true
	var first: Array = _slot_buttons.bag
	if not first.is_empty():
		(first[0] as Button).grab_focus()


func update_view(session_id: int, model: Dictionary) -> void:
	if session_id == _session_id and _panel.visible:
		_apply_model(model)


func close_view(session_id: int) -> void:
	if session_id != _session_id:
		return
	_session_id = 0
	_panel.visible = false
	_model = {}
	var owner_focus: Control = _panel.get_viewport().gui_get_focus_owner() if _panel.is_inside_tree() else null
	if owner_focus != null and _panel.is_ancestor_of(owner_focus):
		owner_focus.release_focus()


func show_result(session_id: int, code: StringName) -> void:
	if session_id == _session_id:
		_message_label.text = MESSAGES.get(code, "실패: %s" % code)


## Short message outside the panel, e.g. why the bag could not open.
func show_notice(code: StringName) -> void:
	_notice.text = MESSAGES.get(code, String(code))
	_notice.visible = true
	_notice_timer.start()


func get_session_id() -> int:
	return _session_id


func is_open() -> bool:
	return _panel.visible


func _apply_model(model: Dictionary) -> void:
	_model = model.duplicate(true)
	var showing_store: bool = _view == 1 and model.get("store") != null
	_store_column.visible = showing_store
	_title.text = "검증용 보관함" if showing_store else "가방"
	_view_toggle.text = "가방만 보기" if showing_store else "보관함 보기"
	_move_one.visible = showing_store
	_move_stack.visible = showing_store
	_fill("bag", _model.get("bag"))
	if showing_store:
		_fill("store", _model.get("store"))
	if _selected_side == "store" and not showing_store:
		_selected_side = ""
		_selected_slot = -1
	_update_selection()


func _fill(side: String, snapshot: Variant) -> void:
	var label: Label = _bag_label if side == "bag" else _store_label
	var grid: GridContainer = get_node("Panel/Layout/Columns/%s/Grid" % side.capitalize()) as GridContainer
	var buttons: Array = _slot_buttons[side]
	if snapshot == null:
		label.text = "(사용할 수 없음)"
		return
	var slots: Array = snapshot.slots
	label.text = "%s · %d칸" % ["가방" if side == "bag" else "보관함", slots.size()]
	while buttons.size() < slots.size():
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(62, 30)
		button.add_theme_font_size_override("font_size", 9)
		button.toggle_mode = true
		var index: int = buttons.size()
		button.pressed.connect(func() -> void: _select(side, index))
		grid.add_child(button)
		buttons.append(button)
	for index: int in buttons.size():
		var button: Button = buttons[index]
		button.visible = index < slots.size()
		if not button.visible:
			continue
		var stack: Variant = slots[index]
		button.text = "·" if stack == null else "%s\n%d" % [_name(stack.item_id), stack.quantity]
		button.button_pressed = side == _selected_side and index == _selected_slot


func _select(side: String, index: int) -> void:
	_selected_side = side
	_selected_slot = index
	_message_label.text = ""
	for each: String in ["bag", "store"]:
		for i: int in (_slot_buttons[each] as Array).size():
			(_slot_buttons[each][i] as Button).button_pressed = each == side and i == index
	_update_selection()


func _update_selection() -> void:
	var stack: Variant = _selected_stack()
	if _selected_side.is_empty():
		_selection_label.text = "칸을 선택하세요."
	elif stack == null:
		_selection_label.text = "빈 칸"
	else:
		_selection_label.text = "선택: %s %d개" % [_name(stack.item_id), stack.quantity]
	var can_move: bool = _view == 1 and stack != null
	_move_one.disabled = not can_move
	_move_stack.disabled = not can_move


func _selected_stack() -> Variant:
	var snapshot: Variant = _model.get(_selected_side) if not _selected_side.is_empty() else null
	if snapshot == null or _selected_slot < 0 or _selected_slot >= (snapshot.slots as Array).size():
		return null
	return snapshot.slots[_selected_slot]


## Emits the intent with exactly what is on screen; the controller decides.
func _request_transfer(whole_stack: bool) -> void:
	var stack: Variant = _selected_stack()
	if stack == null or _view != 1:
		return
	var source: Dictionary = _model[_selected_side]
	var destination: Dictionary = _model["store" if _selected_side == "bag" else "bag"]
	transfer_requested.emit(_session_id, StringName(source.inventory_id), _selected_slot, StringName(stack.item_id),
		int(stack.quantity) if whole_stack else 1, int(source.revision), int(destination.revision))


func _name(item_id: Variant) -> String:
	return (_model.get("names", {}) as Dictionary).get(String(item_id), String(item_id))
