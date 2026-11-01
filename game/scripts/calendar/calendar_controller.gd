class_name CalendarController
extends Node
## Real-time adapter for the calendar (IH-120). It lives outside the replaceable world,
## next to the SaveCoordinator, and each physics step asks the coordinator for the CURRENT
## world and epoch, then advances that world's CalendarService by one tick when nothing
## stops time. One physics step is one tick; time not stepped (pause, focus, sleep, a slow
## frame) is never made up later.
##
## Stop reasons are combined here, each read from its own source, so releasing one never
## resumes time while another remains: user pause (P), focus and key-neutral wait, a modal
## or running interaction/commit (world.save_blocker), save/load (coordinator busy, also
## while it reports), a suspended or busy calendar, SceneTree.paused, a missing world or
## service, an unsupported physics rate and the calendar's last day. The movement gate is
## not touched and nothing is closed or cancelled to make time run.
##
## N (next dawn) is queued as one pending request and executed on the next physics step,
## after every check is repeated, through the same advance_ticks() as natural time; that
## step adds no natural tick. Results and day boundaries are reported once, while busy:
## a request made from a report is BUSY, and the save coordinator asks save_blocker().

signal state_changed(view: Dictionary)
signal command_finished(result: Dictionary)
signal day_boundary(event: Dictionary)

const OK: StringName = &"OK"
const QUEUED: StringName = &"QUEUED"
const BUSY: StringName = &"BUSY"
const STALE_SESSION: StringName = &"STALE_SESSION"
const STALE_REVISION: StringName = &"STALE_REVISION"
const CANCELLED: StringName = &"CANCELLED"
const FOCUS_LOST: StringName = &"FOCUS_LOST"
const REMOVED: StringName = &"REMOVED"
const NOT_READY: StringName = &"NOT_READY"
const ACTION_PAUSE: StringName = &"calendar_pause"
const ACTION_NEXT_DAY: StringName = &"calendar_next_day"

var _coordinator: SaveCoordinator
var _user_paused: bool = false
var _window_focused: bool = true
## A new process or a focus return waits until P and N are released.
var _neutral_required: bool = true
## {"epoch", "revision", "service": WeakRef} of the one queued N.
var _pending: Dictionary = {}
var _reporting: bool = false
## The service whose last day was reached; reported once, then time stays stopped for it.
var _limit_service: WeakRef = null
var _last_view_key: String = ""


func _ready() -> void:
	# Runs while the tree is paused so it can see the pause and refuse, never to tick.
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(coordinator: SaveCoordinator) -> void:
	_coordinator = coordinator


## For SaveCoordinator.set_external_blocker: a queued N or a report in progress is BUSY.
func save_blocker() -> StringName:
	return BUSY if is_busy() else &""


func is_busy() -> bool:
	return not _pending.is_empty() or _reporting


func has_pending() -> bool:
	return not _pending.is_empty()


func is_user_paused() -> bool:
	return _user_paused


## Current stop reasons (empty = time runs).
func get_stop_reasons() -> PackedStringArray:
	return _reasons(_current_service())


## Toggles the user time stop. Tied to the session epoch, not to the calendar revision;
## a modal or a user pause does not prevent toggling. Stopping cancels a queued N.
func request_toggle_pause(epoch: int) -> StringName:
	var refusal: StringName = _command_refusal(epoch)
	if refusal != OK:
		return _finish("pause", refusal)
	_user_paused = not _user_paused
	if _user_paused and not _pending.is_empty():
		_pending = {}
		_finish("next_day", CANCELLED, "time stopped")
	var code: StringName = _finish("pause", OK)
	_emit_state(true)
	return code


## Queues one "next dawn" for the next physics step. A second request while one is queued
## is BUSY. Returns QUEUED or the refusal (reported once).
func request_next_day(epoch: int, revision: int) -> StringName:
	if not _pending.is_empty():
		return _finish("next_day", BUSY, "already queued")
	var refusal: StringName = _command_refusal(epoch)
	if refusal != OK:
		return _finish("next_day", refusal)
	var service: CalendarService = _current_service()
	var reasons: PackedStringArray = _reasons(service)
	if not reasons.is_empty():
		return _finish("next_day", _code_for(reasons), ", ".join(reasons))
	var snapshot: CalendarService.Result = service.get_snapshot()
	if not snapshot.ok or int(snapshot.value.revision) != revision:
		return _finish("next_day", STALE_REVISION)
	_pending = {"epoch": epoch, "revision": revision, "service": weakref(service)}
	return QUEUED


func _physics_process(_delta: float) -> void:
	if _neutral_required and not Input.is_action_pressed(ACTION_PAUSE) and not Input.is_action_pressed(ACTION_NEXT_DAY):
		_neutral_required = false
	var service: CalendarService = _current_service()
	if not _pending.is_empty():
		_consume_pending(service)
		return
	var reasons: PackedStringArray = _reasons(service)
	if not reasons.is_empty():
		_emit_state(false)
		return
	var snapshot: Dictionary = service.get_snapshot().value
	var result: Dictionary = service.advance_ticks(1, int(snapshot.revision))
	_after_advance(service, result)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
		if is_node_ready() and not _pending.is_empty():
			_pending = {}
			_finish("next_day", FOCUS_LOST)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and not _window_focused:
		_window_focused = true
		_neutral_required = true


func _exit_tree() -> void:
	if not _pending.is_empty():
		_pending = {}
		_finish("next_day", REMOVED)


## P and N: a new press only (echo and held keys ignored), never while waiting for neutral.
func _unhandled_input(event: InputEvent) -> void:
	var pause: bool = event.is_action_pressed(ACTION_PAUSE, false)
	var next_day: bool = event.is_action_pressed(ACTION_NEXT_DAY, false)
	if not pause and not next_day:
		return
	get_viewport().set_input_as_handled()
	if _neutral_required or not _coordinator_alive():
		return
	var epoch: int = _coordinator.get_epoch()
	if pause:
		request_toggle_pause(epoch)
		return
	var service: CalendarService = _current_service()
	var snapshot: CalendarService.Result = service.get_snapshot() if service != null else null
	request_next_day(epoch, int(snapshot.value.revision) if snapshot != null and snapshot.ok else -1)


## The queued N: every check again, then the same advance API for exactly the ticks to the
## next dawn. This step adds no natural tick, whatever the outcome.
func _consume_pending(service: CalendarService) -> void:
	var pending: Dictionary = _pending
	_pending = {}
	var code: StringName = _command_refusal(int(pending.epoch))
	var queued: CalendarService = (pending.service as WeakRef).get_ref() as CalendarService
	if code == OK and (service == null or queued != service):
		code = STALE_SESSION
	if code == OK:
		var reasons: PackedStringArray = _reasons(service)
		if not reasons.is_empty():
			code = _code_for(reasons)
	if code != OK:
		_finish("next_day", code)
		_emit_state(false)
		return
	var result: Dictionary = service.advance_ticks(service.ticks_to_next_dawn(), int(pending.revision))
	_finish("next_day", result.code, "", result)
	_after_advance(service, result)


func _after_advance(service: CalendarService, result: Dictionary) -> void:
	if result.code == CalendarService.NUMBER_OUT_OF_RANGE and not _is_limit(service):
		_limit_service = weakref(service)
		_emit_state(true)
		return
	if result.get("boundary") != null:
		var outer: bool = _reporting
		_reporting = true
		day_boundary.emit(result.boundary)
		_reporting = outer
	_emit_state(result.get("boundary") != null)


func _reasons(service: CalendarService) -> PackedStringArray:
	var reasons: PackedStringArray = []
	if _user_paused:
		reasons.append("user_paused")
	if not _window_focused:
		reasons.append("focus")
	if _neutral_required:
		reasons.append("neutral")
	if is_inside_tree() and get_tree().paused:
		reasons.append("tree_paused")
	if not _coordinator_alive():
		reasons.append("removed")
		return reasons
	if _coordinator.is_busy():
		reasons.append("save_load")
	var world: Node = _coordinator.get_world()
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion():
		reasons.append("removed")
		return reasons
	if service == null or service.is_closed():
		reasons.append("no_service")
		return reasons
	if service.is_suspended():
		reasons.append("suspended")
	elif service.is_busy():
		reasons.append("busy")
	else:
		var world_blocker: StringName = world.call("save_blocker")
		if world_blocker == &"BUSY":
			reasons.append("modal")
		elif not world_blocker.is_empty():
			reasons.append("not_ready")
	if Engine.physics_ticks_per_second != int(service.get_profile().physics_hz):
		reasons.append("physics_hz")
	if _is_limit(service):
		reasons.append("limit")
	return reasons


## Refusal shared by P and N before anything else: reporting, lifetime, epoch, focus, keys,
## save/load.
func _command_refusal(epoch: int) -> StringName:
	if _reporting:
		return BUSY
	if not is_inside_tree() or is_queued_for_deletion() or not _coordinator_alive():
		return REMOVED
	if epoch != _coordinator.get_epoch():
		return STALE_SESSION
	if not _window_focused:
		return FOCUS_LOST
	if _neutral_required:
		return NOT_READY
	if _coordinator.is_busy():
		return BUSY
	return OK


func _code_for(reasons: PackedStringArray) -> StringName:
	if reasons.has("removed") or reasons.has("no_service"):
		return REMOVED
	if reasons.has("focus"):
		return FOCUS_LOST
	if reasons.has("neutral") or reasons.has("not_ready") or reasons.has("physics_hz"):
		return NOT_READY
	if reasons.has("user_paused"):
		return CANCELLED
	return BUSY


func _current_service() -> CalendarService:
	if not _coordinator_alive():
		return null
	var world: Node = _coordinator.get_world()
	if not is_instance_valid(world):
		return null
	return world.get("calendar") as CalendarService


func _coordinator_alive() -> bool:
	return is_instance_valid(_coordinator) and _coordinator.is_inside_tree() and not _coordinator.is_queued_for_deletion()


func _is_limit(service: CalendarService) -> bool:
	return service != null and _limit_service != null and _limit_service.get_ref() == service


## Reports a command result once, while busy, and returns its code. A refusal reported
## from inside another report keeps the outer report busy (no reset on the way out).
func _finish(command: String, code: StringName, detail: String = "", result: Dictionary = {}) -> StringName:
	var outer: bool = _reporting
	_reporting = true
	command_finished.emit({"command": command, "code": code, "ok": code == OK or code == QUEUED, "detail": detail,
		"boundary": result.get("boundary"), "snapshot": result.get("snapshot", {})})
	_reporting = outer
	return code


## View for the HUD: epoch/revision always current (so a button never sends an old one);
## `changed` tells it whether the visible text (minute, day, reasons) may have changed.
func _emit_state(force: bool) -> void:
	var service: CalendarService = _current_service()
	var snapshot: CalendarService.Result = service.get_snapshot() if service != null else null
	var date: CalendarService.Result = service.get_date() if service != null else null
	var reasons: PackedStringArray = _reasons(service)
	var view: Dictionary = {"epoch": _coordinator.get_epoch() if _coordinator_alive() else -1,
		"snapshot": snapshot.value if snapshot != null and snapshot.ok else {},
		"date": date.value if date != null and date.ok else {}, "reasons": reasons, "user_paused": _user_paused,
		"rule_id": String(service.get_profile().rule_id) if service != null else "", "limit": _is_limit(service)}
	var key: String = "%s|%s|%s" % [view.date.get("minute_of_day", -1), view.snapshot.get("day_index", -1), ",".join(reasons)]
	view["changed"] = force or key != _last_view_key
	_last_view_key = key
	state_changed.emit(view)
