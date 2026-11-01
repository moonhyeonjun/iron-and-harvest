class_name GatherTarget
extends InteractionTarget
## Scene adapter for one resource point (IH-111). It owns no quantity: availability and the
## remaining count are read from GatherService, and try_begin only prepares a single-use
## command for the controller to commit after its last re-check. Nothing is granted here.
## target_id is the point_id. Visual shows available/depleted; it never changes stock.

const DEPLETED_COLOR: Color = Color(0.42, 0.42, 0.4, 1)

@export var available_color: Color = Color(0.6, 0.45, 0.25, 1)

var _service: GatherService
var _bag_id: StringName = &""
var _prepared: RefCounted = null
var _prepared_request_id: int = 0
var _shown_remaining: int = -1

@onready var _visual: Polygon2D = $Visual
@onready var _count: Label = $Count


func _ready() -> void:
	_refresh_view()


## Connects this view to the session's point. Labels come from the validated definition.
func bind_service(service: GatherService, bag_id: StringName) -> void:
	_service = service
	_bag_id = bag_id
	var info: GatherService.Result = service.query(target_id)
	if info.ok:
		display_name = info.value.display_name
		action_label = info.value.action_label
	_shown_remaining = -1
	_refresh_view()


## Leaves the session without touching stock: only the prepared command is dropped.
func unbind() -> void:
	_drop_prepared()
	_service = null
	_shown_remaining = -1
	_refresh_view()


func get_remaining() -> int:
	var info: GatherService.Result = _query()
	return int(info.value.remaining) if info != null and info.ok else 0


func can_interact() -> bool:
	return available and get_remaining() > 0


func get_execution_kind() -> InteractionTarget.ExecutionKind:
	return InteractionTarget.ExecutionKind.INSTANT


## Prepares (never grants) one gather for request_id.
func try_begin(request_id: int) -> bool:
	if not can_interact():
		return false
	var prepared: GatherService.Result = _service.prepare(target_id, _bag_id, request_id)
	if not prepared.ok:
		return false
	_prepared = prepared.value
	_prepared_request_id = request_id
	return true


func get_prepared_command(request_id: int) -> RefCounted:
	return _prepared if request_id == _prepared_request_id else null


func end_interaction(request_id: int, cancelled: bool) -> void:
	if request_id != _prepared_request_id:
		return
	if cancelled:
		_drop_prepared()
	_prepared = null
	_prepared_request_id = 0


func _exit_tree() -> void:
	_drop_prepared()


func _process(_delta: float) -> void:
	_refresh_view()


func _drop_prepared() -> void:
	if _prepared != null and _prepared.has_method("cancel"):
		_prepared.cancel()
	_prepared = null
	_prepared_request_id = 0


func _query() -> GatherService.Result:
	if _service == null or _service.is_closed():
		return null
	return _service.query(target_id)


func _refresh_view() -> void:
	if not is_node_ready():
		return
	var remaining: int = get_remaining()
	if remaining == _shown_remaining:
		return
	_shown_remaining = remaining
	_visual.color = available_color if remaining > 0 else DEPLETED_COLOR
	_count.text = str(remaining) if remaining > 0 else "-"
