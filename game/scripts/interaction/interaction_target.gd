class_name InteractionTarget
extends Area2D
## A non-physical thing the player can face and inspect (IH-102). It owns its identity,
## description and availability only; selection and validation belong to the controller.
## IH-102 targets only open a read-only panel: no items, rewards or inventory changes.

const GROUP: StringName = &"interaction_target"

## Authored map-unique ID. Never derived from display names or node paths.
@export var target_id: StringName = &""
@export var display_name: String = ""
@export var action_label: String = "살펴보기"
@export_multiline var description: String = ""
@export var available: bool = true

var _active_request_id: int = 0
var _registration_error: StringName = &""


func _enter_tree() -> void:
	add_to_group(GROUP)


## Side-effect free: whether this target may be used right now.
func can_interact() -> bool:
	return available


## Final synchronous permission for one request. Returning false changes nothing.
func try_begin(request_id: int) -> bool:
	if not can_interact():
		return false
	_active_request_id = request_id
	return true


## Notified once when the session the controller opened for request_id ends.
func end_interaction(request_id: int, _cancelled: bool) -> void:
	if request_id == _active_request_id:
		_active_request_id = 0


## World point used for range, facing and line of sight; placed on walkable floor.
func get_anchor_position() -> Vector2:
	var anchor: Node2D = get_node_or_null(^"Anchor") as Node2D
	return anchor.global_position if anchor != null else global_position


## Set by the owning map's one-time audit when the ID is empty or duplicated.
func reject_registration(reason: StringName) -> void:
	_registration_error = reason


func get_registration_error() -> StringName:
	return _registration_error


func is_registered() -> bool:
	return _registration_error.is_empty() and not target_id.is_empty()
