class_name PlayerController
extends CharacterBody2D
## Owns the player's world position, velocity, facing and locomotion (IH-101).
## Numbers are provisional verification values from PLAYER_MOVEMENT.md, not final balance.

enum Locomotion { IDLE, WALK }
enum Facing { UP, DOWN, LEFT, RIGHT }

const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
## Walk is decided from post-collision motion so pushing into a wall reads as idle.
const WALK_SPEED_THRESHOLD: float = 0.5

## World units per second (1 unit = 1 placeholder pixel). Final value is TBD.
@export var move_speed: float = 96.0

var _facing: Facing = Facing.DOWN
var _locomotion: Locomotion = Locomotion.IDLE
var _control_enabled: bool = true
var _window_focused: bool = true
## After the gate reopens, held keys must be released once before moving again,
## so a key held through a modal or a focus switch cannot cause a sudden move.
var _neutral_required: bool = false

@onready var _visual: PlayerVisual = $Visual


func _ready() -> void:
	_visual.set_presentation(_locomotion, _facing)


## Single gate for the current map/session owner (modal, pause, mode switch).
func set_control_enabled(enabled: bool) -> void:
	if enabled == _control_enabled:
		return
	_control_enabled = enabled
	if enabled:
		_neutral_required = true
	else:
		_halt()


func is_control_effective() -> bool:
	return _control_enabled and _window_focused and not _neutral_required


func get_facing() -> Facing:
	return _facing


func get_locomotion() -> Locomotion:
	return _locomotion


func _notification(what: int) -> void:
	# Input is polled, so UI event consumption cannot stop movement; focus is gated here.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
		_halt()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and not _window_focused:
		_window_focused = true
		_neutral_required = true


func _physics_process(_delta: float) -> void:
	var intent: Vector2 = _read_intent()
	if intent != Vector2.ZERO:
		_facing = _facing_for(intent)
	# move_and_slide applies delta itself; velocity stays in units per second.
	velocity = intent * move_speed
	move_and_slide()
	var moving: bool = get_real_velocity().length() > WALK_SPEED_THRESHOLD
	_set_locomotion(Locomotion.WALK if moving else Locomotion.IDLE)


func _read_intent() -> Vector2:
	if not (_control_enabled and _window_focused):
		return Vector2.ZERO
	if _neutral_required:
		# Opposite keys cancel to zero but are still held, so check each action.
		if _any_move_action_pressed():
			return Vector2.ZERO
		_neutral_required = false
	# get_vector cancels opposite keys and limits length to 1 without forcing
	# normalization, which keeps future analog magnitudes.
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func _any_move_action_pressed() -> bool:
	for action: StringName in MOVE_ACTIONS:
		if Input.is_action_pressed(action):
			return true
	return false


## The larger axis wins; an exact diagonal tie prefers the horizontal facing.
func _facing_for(intent: Vector2) -> Facing:
	if absf(intent.x) >= absf(intent.y):
		return Facing.RIGHT if intent.x > 0.0 else Facing.LEFT
	return Facing.DOWN if intent.y > 0.0 else Facing.UP


func _halt() -> void:
	velocity = Vector2.ZERO
	_set_locomotion(Locomotion.IDLE)


func _set_locomotion(value: Locomotion) -> void:
	_locomotion = value
	# On macOS the application focus notifications can arrive before the node enters
	# the tree; the state is kept and _ready presents it once Visual exists.
	if is_node_ready():
		_visual.set_presentation(_locomotion, _facing)
