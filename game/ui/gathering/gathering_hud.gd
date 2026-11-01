class_name GatheringHUD
extends CanvasLayer
## Read-only gathering display (IH-111): point and total lines, a short toast and a setup
## error. Never focusable and ignores the mouse, so it cannot consume E, I or movement.


@onready var _points: Label = $Points
@onready var _totals: Label = $Totals
@onready var _toast: Label = $Toast
@onready var _error: Label = $Error
@onready var _timer: Timer = $ToastTimer


func _ready() -> void:
	_toast.visible = false
	_error.visible = false
	_timer.timeout.connect(func() -> void: _toast.visible = false)


func show_lines(points: String, totals: String) -> void:
	_points.text = points
	_totals.text = totals


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_timer.start()


func show_error(text: String) -> void:
	_error.text = text
	_error.visible = true


func get_toast() -> String:
	return _toast.text if _toast.visible else ""
