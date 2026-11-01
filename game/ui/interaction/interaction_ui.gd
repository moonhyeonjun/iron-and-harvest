class_name InteractionUI
extends CanvasLayer
## Shows the interaction prompt and the read-only inspect panel (IH-102). It only displays
## values and reports close/cancel intents with the request ID it was opened for; it never
## changes the player, targets or any game state.

signal close_requested(request_id: int)
signal cancel_requested(request_id: int)

const KEY_HINT: String = "E"

var _open_request_id: int = 0

@onready var _prompt: Label = $Prompt
@onready var _panel: Control = $InspectPanel
@onready var _title: Label = $InspectPanel/Layout/Title
@onready var _description: Label = $InspectPanel/Layout/Description
@onready var _close_button: Button = $InspectPanel/Layout/CloseButton


func _ready() -> void:
	_prompt.visible = false
	_panel.visible = false
	_close_button.pressed.connect(_on_close_pressed)


func show_target(target_id: StringName, action_label: String, display_name: String) -> void:
	_prompt.visible = not target_id.is_empty()
	_prompt.text = "%s %s — %s" % [KEY_HINT, action_label, display_name] if _prompt.visible else ""


func open_session(request_id: int, title: String, description: String) -> void:
	_open_request_id = request_id
	_title.text = title
	_description.text = description
	_prompt.visible = false
	_panel.visible = true
	_close_button.grab_focus()


func close_session(request_id: int, _reason: StringName) -> void:
	if request_id != _open_request_id:
		return
	_open_request_id = 0
	_panel.visible = false
	# The session can close while the map is leaving the tree; focus only exists inside it.
	if _close_button.has_focus():
		_close_button.release_focus()


func get_open_request_id() -> int:
	return _open_request_id


## Escape closes the visible panel before gameplay sees the key.
func _shortcut_input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed(&"interaction_cancel", false):
		get_viewport().set_input_as_handled()
		cancel_requested.emit(_open_request_id)


func _on_close_pressed() -> void:
	if _panel.visible:
		close_requested.emit(_open_request_id)
