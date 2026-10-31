class_name PlayerVisual
extends Node2D
## Placeholder presentation for IH-101. It only reflects controller state and never
## reads input or moves BodyCollision. Final sprites and the idle_/walk_<facing>
## animation names are decided in IH-006.

const BODY_CENTER: Vector2 = Vector2(0.0, -10.0)
const IDLE_COLOR: Color = Color(0.32, 0.42, 0.68)
const WALK_COLOR: Color = Color(0.52, 0.66, 0.96)
## A small bob makes walk readable in the GUI without touching the physics shape.
const BOB_HEIGHT: float = 1.0
const BOB_RADIANS_PER_SECOND: float = 14.0
const MARKER_SIDE_OFFSET: float = 12.0
const MARKER_VERTICAL_OFFSET: float = 16.0

var _walking: bool = false
var _bob_phase: float = 0.0

@onready var _body: Polygon2D = $Body
@onready var _marker: Polygon2D = $FacingMarker


func set_presentation(locomotion: PlayerController.Locomotion, facing: PlayerController.Facing) -> void:
	_walking = locomotion == PlayerController.Locomotion.WALK
	_body.color = WALK_COLOR if _walking else IDLE_COLOR
	if not _walking:
		_bob_phase = 0.0
		_body.position = BODY_CENTER
	match facing:
		PlayerController.Facing.UP:
			_place_marker(Vector2(0.0, -MARKER_VERTICAL_OFFSET), -PI / 2.0)
		PlayerController.Facing.DOWN:
			_place_marker(Vector2(0.0, MARKER_VERTICAL_OFFSET), PI / 2.0)
		PlayerController.Facing.LEFT:
			_place_marker(Vector2(-MARKER_SIDE_OFFSET, 0.0), PI)
		PlayerController.Facing.RIGHT:
			_place_marker(Vector2(MARKER_SIDE_OFFSET, 0.0), 0.0)


func _process(delta: float) -> void:
	if not _walking:
		return
	_bob_phase = fmod(_bob_phase + delta * BOB_RADIANS_PER_SECOND, TAU)
	_body.position = BODY_CENTER + Vector2(0.0, -absf(sin(_bob_phase)) * BOB_HEIGHT)


func _place_marker(offset: Vector2, angle: float) -> void:
	_marker.position = BODY_CENTER + offset
	_marker.rotation = angle
