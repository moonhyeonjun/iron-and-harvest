extends SceneTree
## IH-102 acceptance runner. Uses the real InteractionTest map, Area2D overlaps, physics
## queries and UI. Key events go through Input.parse_input_event + flush_buffered_events, which
## updates Input state and dispatches to the viewport like a window, so _unhandled_input and
## Control consumption are real (verified: a focused LineEdit receives each key exactly once).
## Exit code 0 only when every automated check passes. Real window focus switches, resize
## and readability are GUI checks and are never reported as passed here.
##
## Timing: `await physics_frame` resumes at the start of a tick, before the player (priority 0)
## and the controller (priority 10) run. An E press pushed there is resolved in that same tick.

const MAP_SCENE: String = "res://scenes/tests/interaction_test.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const TARGET_SCENE: String = "res://scenes/interaction/interaction_target.tscn"
const UI_SCENE: String = "res://ui/interaction/interaction_ui.tscn"
const PROBE: Script = preload("res://tests/support/probe_target.gd")
const MAIN_SCENE: String = "res://scenes/foundation.tscn"
## Free floor away from the authored sign/crate and the movement fixture walls.
const BASE: Vector2 = Vector2(400, 560)
const EPS: float = 0.001
const FACING_KEYS: Dictionary = {"down": [KEY_S], "up": [KEY_W], "left": [KEY_A], "right": [KEY_D]}
const C := preload("res://scripts/interaction/interaction_controller.gd")

var _ac_checks: Dictionary = {}
var _failures: Array[String] = []
var _held: Array[Key] = []
var _map: Node2D
var _controller: InteractionController
var _ui: InteractionUI
var _player: PlayerController
var _targets_root: Node2D
var _temp: Array[Node] = []
var _rec: Array[Dictionary] = []
var _pass_metrics: Array[Dictionary] = []
var _metrics: Dictionary = {}
var _engine_errors: EngineErrorLog = EngineErrorLog.new()


## Script runtime errors only abort the failing call; collect them so they fail the run.
class EngineErrorLog extends Logger:
	var _mutex: Mutex = Mutex.new()
	var _entries: PackedStringArray = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text: String = rationale if not rationale.is_empty() else code
		if text.begins_with("FAIL "):
			return
		_mutex.lock()
		_entries.append("%s:%d %s" % [file, line, text])
		_mutex.unlock()

	func entries() -> PackedStringArray:
		_mutex.lock()
		var copy: PackedStringArray = _entries.duplicate()
		_mutex.unlock()
		return copy


func _initialize() -> void:
	OS.add_logger(_engine_errors)
	_run()


func _run() -> void:
	print("IH-102 runner: engine=%s physics_hz=%d" % [Engine.get_version_info().string, Engine.physics_ticks_per_second])
	_check_static_contract()
	for pass_index: int in 2:
		_metrics = {}
		await _load_map()
		await _run_suite()
		await _unload_map()
		_check("AC-I12", _all_released(), "pass %d left a key pressed" % pass_index)
		_pass_metrics.append(_metrics)
	_compare_passes()
	await process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("AC-I12", orphans == 0, "orphan nodes after both passes: %d" % orphans)
	_log("AC-I12", "orphan nodes after both passes: %d" % orphans)
	if "--inject-failure" in OS.get_cmdline_user_args():
		_check("AC-I12", false, "deliberate failure requested by --inject-failure")
	var errors: PackedStringArray = _engine_errors.entries()
	OS.remove_logger(_engine_errors)
	_check("AC-I12", errors.is_empty(), "engine/script errors during the run: %s" % "; ".join(errors))
	_log("AC-I12", "engine/script errors logged during the run: %d" % errors.size())
	_finish()


func _run_suite() -> void:
	var steps: Array = [
		["AC-I01", _i01_runtime], ["AC-I02", _i02_range], ["AC-I03", _i03_facing],
		["AC-I04", _i04_order_and_ids], ["AC-I05", _i05_walls], ["AC-I06", _i06_revalidation],
		["AC-I07", _i07_presses], ["AC-I08", _i08_consumed_and_blocked], ["AC-I09", _i09_session_and_movement],
		["AC-I11", _i11_ui], ["AC-I10", _i10_lifecycle],
	]
	for step: Array in steps:
		# A script error aborts the coroutine and yields null instead of true.
		var completed: Variant = await (step[1] as Callable).call()
		_check(step[0], completed == true, "%s case list aborted before completion" % step[0])


# --- AC-I01 ----------------------------------------------------------------------

func _check_static_contract() -> void:
	_check("AC-I01", ProjectSettings.get_setting("application/run/main_scene") == MAIN_SCENE, "Foundation stays main scene")
	_check("AC-I01", ProjectSettings.get_setting("layer_names/2d_physics/layer_3") == "interaction_target", "layer 3 name")
	var interact: Array[InputEvent] = InputMap.action_get_events(&"interact") if InputMap.has_action(&"interact") else []
	var cancel: Array[InputEvent] = InputMap.action_get_events(&"interaction_cancel") if InputMap.has_action(&"interaction_cancel") else []
	_check("AC-I01", interact.size() == 1 and (interact[0] as InputEventKey).physical_keycode == KEY_E
		and (interact[0] as InputEventKey).keycode == KEY_NONE, "interact = physical E only")
	_check("AC-I01", cancel.size() == 1 and (cancel[0] as InputEventKey).keycode == KEY_ESCAPE
		and (cancel[0] as InputEventKey).physical_keycode == KEY_NONE, "interaction_cancel = Escape keycode only")
	var player: Node = (load(PLAYER_SCENE) as PackedScene).instantiate()
	var last: Node = player.get_child(player.get_child_count() - 1)
	_check("AC-I01", last is InteractionController and last.name == &"InteractionController", "controller is the last player child")
	_check("AC-I01", player.get_node("Camera2D").get_index() == 2, "Camera2D keeps index 2 for the movement map override")
	_check("AC-I01", (last as Node).process_physics_priority == 10 and player.process_physics_priority == 0, "controller runs after player")
	var detector: Area2D = last.get_node("Detector") as Area2D
	var detector_shape: CollisionShape2D = detector.get_node("CollisionShape2D") as CollisionShape2D
	_check("AC-I01", detector.collision_layer == 0 and detector.collision_mask == 4 and detector.monitoring
		and not detector.monitorable and detector.gravity_space_override == Area2D.SPACE_OVERRIDE_DISABLED,
		"detector layer0/mask4/monitoring/not monitorable/no override")
	_check("AC-I01", detector_shape.shape is CircleShape2D and is_equal_approx((detector_shape.shape as CircleShape2D).radius, 32.0)
		and detector_shape.position == Vector2.ZERO, "detector circle r32 at feet")
	player.free()
	var target: Node = (load(TARGET_SCENE) as PackedScene).instantiate()
	var target_area: Area2D = target as Area2D
	var target_shape: CollisionShape2D = target.get_node("CollisionShape2D") as CollisionShape2D
	_check("AC-I01", target is InteractionTarget and target_area.collision_layer == 4 and target_area.collision_mask == 0
		and not target_area.monitoring and target_area.monitorable
		and target_area.gravity_space_override == Area2D.SPACE_OVERRIDE_DISABLED, "target layer4(value4)/mask0/monitorable only")
	_check("AC-I01", target_shape.shape is CircleShape2D and is_equal_approx((target_shape.shape as CircleShape2D).radius, 4.0)
		and target_shape.position == Vector2.ZERO and (target.get_node("Anchor") as Node2D).position == Vector2.ZERO,
		"target circle r4 and Anchor at origin")
	target.free()
	var ui: Node = (load(UI_SCENE) as PackedScene).instantiate()
	_check("AC-I01", (ui.get_node("Prompt") as Control).focus_mode == Control.FOCUS_NONE
		and (ui.get_node("Prompt") as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "prompt never takes focus or mouse")
	ui.free()


func _i01_runtime() -> bool:
	_check("AC-I01", (_map.get("audit_rejections") as Dictionary).is_empty(), "authored targets pass the ID audit")
	_check("AC-I01", _map.get_node("World/Player") == _player and _player.get_node("Camera2D").get_index() == 2,
		"movement map instance and camera override preserved")
	# Start position (128,360) facing down selects the sign; facing right selects the crate.
	_check("AC-I01", _controller.get_selected_target_id() == &"sign_entrance", "initial selection %s" % _controller.get_selected_target_id())
	_check("AC-I01", _prompt_text() == "E 살펴보기 — 마을 안내판", "initial prompt '%s'" % _prompt_text())
	await _place(Vector2(128, 360), "right")
	_check("AC-I01", _controller.get_selected_target_id() == &"crate_supplies", "facing right selects crate (%s)" % _controller.get_selected_target_id())
	_metrics["AC-I01 right"] = String(_controller.get_selected_target_id())
	_log("AC-I01", "initial=sign_entrance prompt='E 살펴보기 — 마을 안내판' facing_right=%s candidates=%d" % [
		_controller.get_selected_target_id(), _controller.get_candidate_count()])
	await _place(Vector2(128, 360), "down")
	await _end_case("AC-I01")
	return true


# --- AC-I02 ----------------------------------------------------------------------

func _i02_range() -> bool:
	for case: Array in [[31.9, true], [32.0, true], [32.1, false], [35.9, false]]:
		await _place(BASE, "down")
		_target("range", BASE + Vector2(0, case[0]))
		await _ticks(3)
		var selected: bool = _controller.get_selected_target_id() == &"range"
		var candidate: bool = _controller.get_candidate_count() >= 1
		_check("AC-I02", selected == case[1], "distance %.1f selected=%s" % [case[0], selected])
		_metrics["AC-I02 d%.1f" % case[0]] = selected
		_log("AC-I02", "distance=%.1f selected=%s detector_candidate=%s" % [case[0], selected, candidate])
		await _end_case("AC-I02")
	# Overlap reaches 36 (r32 + r4), but only the 32-unit anchor distance may select.
	await _place(BASE, "down")
	_target("far", BASE + Vector2(0, 36.5))
	await _ticks(3)
	_check("AC-I02", _controller.get_candidate_count() == 0, "36.5 is not even a candidate")
	await _end_case("AC-I02")
	# Distance zero ignores facing, but a wall at that point still blocks.
	await _place(BASE, "up")
	_target("zero", BASE)
	await _ticks(3)
	var zero_selected: bool = _controller.get_selected_target_id() == &"zero"
	var wall: StaticBody2D = _wall(Rect2(BASE - Vector2(3, 3), Vector2(6, 6)), true)
	await _ticks(2)
	var inside_wall: bool = _controller.get_selected_target_id() == &"zero"
	var mark: int = _rec.size()
	await _press_interact()
	var rejected: Array = _since(mark, "rejected")
	wall.free()
	await _ticks(2)
	var after_wall: bool = _controller.get_selected_target_id() == &"zero"
	_check("AC-I02", zero_selected and not inside_wall and after_wall, "distance 0: facing exempt %s, wall %s, after %s" % [zero_selected, inside_wall, after_wall])
	_check("AC-I02", rejected.size() == 1 and rejected[0].reason == C.NO_TARGET and _since(mark, "opened").is_empty(),
		"E at a walled zero-distance target opens nothing")
	_log("AC-I02", "distance0 facing_up selected=%s inside_wall_selected=%s E=%s wall_removed_selected=%s" % [
		zero_selected, inside_wall, rejected[0].reason if rejected.size() > 0 else "-", after_wall])
	await _end_case("AC-I02")
	# Entry and exit by teleport: the prompt follows within two physics ticks.
	await _place(BASE + Vector2(0, -40), "down")
	_target("entry", BASE + Vector2(0, 28))
	await _ticks(3)
	_player.global_position = BASE
	var enter_ticks: int = await _ticks_until(func() -> bool: return _controller.get_selected_target_id() == &"entry", 5)
	_player.global_position = BASE + Vector2(0, -40)
	var exit_ticks: int = await _ticks_until(func() -> bool: return _controller.get_selected_target_id().is_empty(), 5)
	_check("AC-I02", enter_ticks >= 1 and enter_ticks <= 2 and exit_ticks >= 1 and exit_ticks <= 2,
		"prompt latency enter %d exit %d ticks" % [enter_ticks, exit_ticks])
	_metrics["AC-I02 enter"] = enter_ticks
	_metrics["AC-I02 exit"] = exit_ticks
	await _end_case("AC-I02")
	# Walking in: the selection appears on the tick the feet come within 32.
	await _place(BASE + Vector2(0, -30), "down")
	var walker: InteractionTarget = _target("walk", BASE + Vector2(0, 28))
	await _ticks(3)
	var crossing: Array[int] = [-1, -1]
	var tick: Array[int] = [0]
	_press([KEY_S])
	await _ticks_until(func() -> bool:
		tick[0] += 1
		if crossing[0] < 0 and _player.global_position.distance_to(walker.get_anchor_position()) <= 32.0:
			crossing[0] = tick[0]
		if crossing[1] < 0 and _controller.get_selected_target_id() == &"walk":
			crossing[1] = tick[0]
		return crossing[1] >= 0, 40)
	_release_all()
	_check("AC-I02", crossing[0] >= 0 and crossing[1] - crossing[0] <= 2, "walking: within range tick %d, prompt tick %d" % [crossing[0], crossing[1]])
	_log("AC-I02", "teleport enter=%d ticks exit=%d ticks; walking in-range tick=%d prompt tick=%d" % [enter_ticks, exit_ticks, crossing[0], crossing[1]])
	await _end_case("AC-I02")
	return true


# --- AC-I03 ----------------------------------------------------------------------

func _i03_facing() -> bool:
	var front: Vector2 = Vector2(0, 20)
	for case: Array in [["down", true], ["up", false], ["left", false], ["right", false]]:
		await _place(BASE, case[0])
		_target("front", BASE + front)
		await _ticks(3)
		var selected: bool = _controller.get_selected_target_id() == &"front"
		_check("AC-I03", selected == case[1], "facing %s selected=%s" % [case[0], selected])
		_metrics["AC-I03 %s" % case[0]] = selected
		await _end_case("AC-I03")
	# dot boundary around 60 degrees from the facing direction (down).
	for degrees: float in [59.0, 60.0, 61.0]:
		await _place(BASE, "down")
		var radians: float = deg_to_rad(degrees)
		var probe: InteractionTarget = _target("angle", BASE + Vector2(sin(radians), cos(radians)) * 20.0)
		await _ticks(3)
		var offset: Vector2 = probe.get_anchor_position() - _player.global_position
		var dot: float = Vector2.DOWN.dot(offset.normalized())
		var selected: bool = _controller.get_selected_target_id() == &"angle"
		_check("AC-I03", selected == (dot >= 0.5), "angle %.0f dot %.9f selected %s" % [degrees, dot, selected])
		if degrees != 60.0:
			_check("AC-I03", selected == (degrees < 60.0), "angle %.0f must %s" % [degrees, "select" if degrees < 60.0 else "not select"])
		_metrics["AC-I03 angle %.0f" % degrees] = selected
		_log("AC-I03", "angle=%.0f actual_dot=%.9f selected=%s" % [degrees, dot, selected])
		await _end_case("AC-I03")
	# Diagonal movement keeps the horizontal facing priority from IH-101.
	for case: Array in [[[KEY_W, KEY_D], Vector2(20, 0), Vector2(0, -20)], [[KEY_S, KEY_A], Vector2(-20, 0), Vector2(0, 20)]]:
		await _place(BASE, "down")
		_press(case[0])
		await physics_frame
		_release_all()
		_player.global_position = BASE
		_target("horizontal", BASE + case[1])
		_target("vertical", BASE + case[2])
		await _ticks(3)
		var picked: StringName = _controller.get_selected_target_id()
		_check("AC-I03", picked == &"horizontal", "diagonal %s facing selects %s" % [_names(case[0]), picked])
		_log("AC-I03", "diagonal keys=%s facing=%s selected=%s" % [_names(case[0]),
			PlayerController.Facing.find_key(_player.get_facing()), picked])
		await _end_case("AC-I03")
	return true


# --- AC-I04 ----------------------------------------------------------------------

func _i04_order_and_ids() -> bool:
	# Exact distance/dot tie resolved by ID, regardless of creation order or side.
	for layout: Array in [[["tie_b", 10.0], ["tie_a", -10.0]], [["tie_a", -10.0], ["tie_b", 10.0]], [["tie_b", -10.0], ["tie_a", 10.0]]]:
		await _place(BASE, "down")
		for entry: Array in layout:
			_target(entry[0], BASE + Vector2(entry[1], 20))
		await _ticks(3)
		_check("AC-I04", _controller.get_selected_target_id() == &"tie_a", "tie layout %s -> %s" % [layout, _controller.get_selected_target_id()])
		_log("AC-I04", "tie layout=%s selected=%s" % [layout, _controller.get_selected_target_id()])
		await _end_case("AC-I04")
	# Same rounded distance: the more frontal target wins over the smaller ID.
	await _place(BASE, "down")
	_target("a_side", BASE + Vector2(10, 20))
	_target("z_front", BASE + Vector2(0, 22.36068))
	await _ticks(3)
	_check("AC-I04", _controller.get_selected_target_id() == &"z_front", "dot breaks a distance tie (%s)" % _controller.get_selected_target_id())
	await _end_case("AC-I04")
	# Empty and duplicated IDs among candidates are never selectable.
	await _place(BASE, "down")
	_target("", BASE + Vector2(0, 8))
	_target("dup", BASE + Vector2(0, 10))
	_target("dup", BASE + Vector2(4, 12))
	_target("unique", BASE + Vector2(0, 26))
	await _ticks(3)
	var picked: StringName = _controller.get_selected_target_id()
	var mark: int = _rec.size()
	await _press_interact()
	var opened: Array = _since(mark, "opened")
	_check("AC-I04", picked == &"unique" and opened.size() == 1 and opened[0].title == "Probe unique",
		"empty/duplicate IDs skipped: selected %s opened %s" % [picked, opened])
	_log("AC-I04", "empty+duplicate candidates closer, selected=%s opened=%s" % [picked, opened[0].title if opened.size() > 0 else "-"])
	await _close_active_with_escape()
	await _end_case("AC-I04")
	# Map audit: an empty ID and a duplicate of the authored sign are rejected at load.
	var audited: Node2D = (load(MAP_SCENE) as PackedScene).instantiate() as Node2D
	var extra_targets: Node = audited.get_node("Targets")
	for entry: Array in [["EmptyId", &""], ["SecondSign", &"sign_entrance"]]:
		var extra: InteractionTarget = (load(TARGET_SCENE) as PackedScene).instantiate() as InteractionTarget
		extra.name = entry[0]
		extra.target_id = entry[1]
		extra.position = Vector2(900, 600)
		extra_targets.add_child(extra)
	# Both maps would share one physics space; the main map steps out meanwhile.
	root.remove_child(_map)
	root.add_child(audited)
	await process_frame
	var rejections: Dictionary = audited.get("audit_rejections")
	var audited_controller: InteractionController = audited.get_node("World/Player/InteractionController") as InteractionController
	(audited.get_node("World/Player/Camera2D") as Camera2D).enabled = false
	await _ticks(3)
	_check("AC-I04", rejections == {"EmptyId": &"EMPTY_ID", "SecondSign": &"DUPLICATE_ID", "SignEntrance": &"DUPLICATE_ID"},
		"audit result %s" % rejections)
	_check("AC-I04", audited_controller.get_selected_target_id().is_empty(), "duplicated sign is not selectable at spawn")
	_log("AC-I04", "map audit rejections=%s selection_at_spawn='%s'" % [rejections, audited_controller.get_selected_target_id()])
	audited.queue_free()
	await _ticks(2)
	root.add_child(_map)
	await _ticks(3)
	# No world-wide search: a target far outside the detector never becomes a candidate.
	await _place(BASE, "down")
	_target("distant", BASE + Vector2(0, -400))
	await _ticks(3)
	_check("AC-I04", _controller.get_candidate_count() == 0, "distant target not a candidate")
	await _end_case("AC-I04")
	return true


# --- AC-I05 ----------------------------------------------------------------------

func _i05_walls() -> bool:
	await _place(BASE, "down")
	var probe: InteractionTarget = _target("behind", BASE + Vector2(0, 24))
	var wall: StaticBody2D = _wall(Rect2(BASE + Vector2(-20, 10), Vector2(40, 4)))
	await _ticks(3)
	var hidden: bool = _controller.get_selected_target_id().is_empty()
	var mark: int = _rec.size()
	await _press_interact()
	var rejected: Array = _since(mark, "rejected")
	_check("AC-I05", hidden and rejected.size() == 1 and rejected[0].reason == C.NO_TARGET
		and probe.get("begin_calls") == 0, "wall hides prompt and E runs nothing")
	wall.free()
	await _ticks(2)
	var visible_after: bool = _controller.get_selected_target_id() == &"behind"
	mark = _rec.size()
	await _press_interact()
	_check("AC-I05", visible_after and _since(mark, "opened").size() == 1, "wall removed: selected and opens")
	_log("AC-I05", "wall: prompt_hidden=%s E=%s begin_calls=0; removed: selected=%s opened=1" % [
		hidden, rejected[0].reason if rejected.size() > 0 else "-", visible_after])
	await _close_active_with_escape()
	await _end_case("AC-I05")
	# Another target's Area between the feet and the anchor does not occlude.
	await _place(BASE, "down")
	_target("blocker", BASE + Vector2(0, 12), {"available": false})
	_target("past_area", BASE + Vector2(0, 24))
	await _ticks(3)
	_check("AC-I05", _controller.get_selected_target_id() == &"past_area", "target Area does not block LOS")
	await _end_case("AC-I05")
	# Fixture Block: an anchor inside a world_solid body is behind the wall surface.
	await _place(Vector2(588, 360), "right")
	_target("in_block", Vector2(612, 360))
	await _ticks(3)
	_check("AC-I05", _controller.get_selected_target_id().is_empty(), "anchor inside Block is occluded")
	_log("AC-I05", "area_between_selected=past_area block_anchor_selected='%s'" % _controller.get_selected_target_id())
	await _end_case("AC-I05")
	return true


# --- AC-I06 ----------------------------------------------------------------------

func _i06_revalidation() -> bool:
	var mutations: Array = [
		["out_of_range", func(t: InteractionTarget) -> void: t.global_position = BASE + Vector2(0, 200), C.OUT_OF_RANGE],
		["queue_free", func(t: InteractionTarget) -> void: t.queue_free(), C.INVALID_TARGET],
		["free", func(t: InteractionTarget) -> void: t.free(), C.INVALID_TARGET],
		["unavailable", func(t: InteractionTarget) -> void: t.available = false, C.INVALID_TARGET],
		["hidden", func(t: InteractionTarget) -> void: t.visible = false, C.INVALID_TARGET],
	]
	for case: Array in mutations:
		await _place(BASE, "down")
		var probe: InteractionTarget = _target("captured", BASE + Vector2(0, 20))
		var other: InteractionTarget = _target("other", BASE + Vector2(0, 28))
		await _ticks(3)
		var before: StringName = _controller.get_selected_target_id()
		var mark: int = _rec.size()
		_interact_event()
		(case[1] as Callable).call(probe)
		await physics_frame
		var rejected: Array = _since(mark, "rejected")
		var ok: bool = before == &"captured" and rejected.size() == 1 and rejected[0].reason == case[2] \
			and _since(mark, "opened").is_empty() and other.get("begin_calls") == 0 and _player.is_control_effective()
		_check("AC-I06", ok, "%s: before %s rejected %s" % [case[0], before, rejected])
		_metrics["AC-I06 %s" % case[0]] = String(rejected[0].reason) if rejected.size() > 0 else "-"
		_log("AC-I06", "%s: captured=%s result=%s substitute_begin_calls=%d opened=0" % [
			case[0], before, rejected[0].reason if rejected.size() > 0 else "-", other.get("begin_calls")])
		await _end_case("AC-I06")
	# Selection changes after the press: the captured target still opens, not the new one.
	await _place(BASE, "down")
	var first: InteractionTarget = _target("first", BASE + Vector2(0, 20))
	var second: InteractionTarget = _target("second", BASE + Vector2(0, 28))
	await _ticks(3)
	var mark2: int = _rec.size()
	_interact_event()
	second.global_position = BASE + Vector2(0, 10)
	await physics_frame
	var opened: Array = _since(mark2, "opened")
	_check("AC-I06", opened.size() == 1 and opened[0].title == "Probe first" and second.get("begin_calls") == 0
		and first.get("begin_calls") == 1, "captured target opens despite a closer newcomer: %s" % [opened])
	await _close_active_with_escape()
	await _end_case("AC-I06")
	# try_begin refusing, or the target freeing itself inside try_begin.
	for case: Array in [["refuse", {"begin_result": false}, C.TARGET_REJECTED, 0], ["self_free", {"queue_free_on_begin": true}, C.INVALID_TARGET, 1]]:
		await _place(BASE, "down")
		var journal: Array = []
		var properties: Dictionary = (case[1] as Dictionary).duplicate()
		properties["journal"] = journal
		_target("begin", BASE + Vector2(0, 20), properties)
		await _ticks(3)
		var mark3: int = _rec.size()
		_interact_event()
		await physics_frame
		var calls: int = journal.count("begin")
		var ends: int = journal.count("end")
		var rejected3: Array = _since(mark3, "rejected")
		_check("AC-I06", calls == 1 and ends == case[3] and rejected3.size() == 1 and rejected3[0].reason == case[2]
			and _since(mark3, "opened").is_empty() and _player.is_control_effective() and not _panel_visible(),
			"%s: begin %d end %d result %s" % [case[0], calls, ends, rejected3])
		_log("AC-I06", "%s: begin_calls=%d end_calls=%d result=%s gate_unchanged=%s panel=%s" % [
			case[0], calls, ends, rejected3[0].reason if rejected3.size() > 0 else "-", _player.is_control_effective(), _panel_visible()])
		await _end_case("AC-I06")
	# BUG-003: a same-ID candidate becomes usable after E captured the shown target.
	for change: Array in [["available", {"available": false}, "available", true], ["visible", {"visible": false}, "visible", true]]:
		await _place(BASE, "down")
		var shown_journal: Array = []
		var twin_journal: Array = []
		_target("twin", BASE + Vector2(0, 20), {"journal": shown_journal})
		var twin: InteractionTarget = _target("twin", BASE + Vector2(2, 22), (change[1] as Dictionary).merged({"journal": twin_journal}))
		await _ticks(3)
		var shown: StringName = _controller.get_selected_target_id()
		var mark4: int = _rec.size()
		_interact_event()
		twin.set(change[2], change[3])
		await physics_frame
		var rejected4: Array = _since(mark4, "rejected")
		await _ticks(2)
		var ok4: bool = shown == &"twin" and rejected4.size() == 1 and rejected4[0].reason == C.INVALID_TARGET \
			and _since(mark4, "opened").is_empty() and shown_journal.is_empty() and twin_journal.is_empty() \
			and _player.is_control_effective() and not _panel_visible() and _controller.get_selected_target_id().is_empty()
		_check("AC-I04", ok4, "duplicate made %s after E: shown %s rejected %s begin %d/%d" % [
			change[0], shown, rejected4, shown_journal.size(), twin_journal.size()])
		_metrics["AC-I04 late duplicate %s" % change[0]] = String(rejected4[0].reason) if rejected4.size() > 0 else "-"
		_log("AC-I04", "duplicate made %s after E: shown=%s result=%s begin_calls=%d/%d opened=0 selection_after='%s'" % [
			change[0], shown, rejected4[0].reason if rejected4.size() > 0 else "-", shown_journal.count("begin"),
			twin_journal.count("begin"), _controller.get_selected_target_id()])
		await _end_case("AC-I04")
	return true


# --- AC-I07 ----------------------------------------------------------------------

func _i07_presses() -> bool:
	var ids: Array[int] = []
	# One press.
	await _place(BASE, "down")
	var probe: InteractionTarget = _target("press", BASE + Vector2(0, 20))
	await _ticks(3)
	var mark: int = _rec.size()
	await _press_interact()
	var opened: Array = _since(mark, "opened")
	_check("AC-I07", probe.get("begin_calls") == 1 and opened.size() == 1, "single press: begin 1 opened 1")
	ids.append(opened[0].id if opened.size() > 0 else -1)
	# E while ACTIVE: BUSY, no second begin.
	mark = _rec.size()
	await _press_interact()
	var busy: Array = _since(mark, "rejected")
	_check("AC-I07", busy.size() == 1 and busy[0].reason == C.BUSY and probe.get("begin_calls") == 1
		and _controller.get_active_request_id() == ids[0], "E while active is BUSY")
	ids.append(busy[0].id if busy.size() > 0 else -1)
	await _close_active_with_escape()
	await _end_case("AC-I07")
	# Held key with echo events over many ticks: one request only.
	await _place(BASE, "down")
	probe = _target("held", BASE + Vector2(0, 20))
	await _ticks(3)
	mark = _rec.size()
	_key(KEY_E, true)
	for i: int in 8:
		await physics_frame
		_key(KEY_E, true, true)
	_release_all()
	await physics_frame
	var held_requests: int = _since(mark, "opened").size() + _since(mark, "rejected").size()
	_check("AC-I07", probe.get("begin_calls") == 1 and held_requests == 1, "held E with 8 echoes: begin %d requests %d" % [probe.get("begin_calls"), held_requests])
	ids.append(_since(mark, "opened")[0].id if _since(mark, "opened").size() > 0 else -1)
	await _close_active_with_escape()
	await _end_case("AC-I07")
	# Two separate presses inside one tick share a single request.
	await _place(BASE, "down")
	probe = _target("double", BASE + Vector2(0, 20))
	await _ticks(3)
	mark = _rec.size()
	_interact_event()
	_interact_event()
	await physics_frame
	await physics_frame
	var double_requests: int = _since(mark, "opened").size() + _since(mark, "rejected").size()
	_check("AC-I07", probe.get("begin_calls") == 1 and double_requests == 1, "same-tick double press: begin %d requests %d" % [probe.get("begin_calls"), double_requests])
	ids.append(_since(mark, "opened")[0].id if _since(mark, "opened").size() > 0 else -1)
	await _close_active_with_escape()
	await _end_case("AC-I07")
	# E queued in the same tick the button closes the session: rejected BUSY, not dropped.
	await _place(BASE, "down")
	probe = _target("close_and_press", BASE + Vector2(0, 20))
	await _ticks(3)
	await _press_interact()
	mark = _rec.size()
	_interact_event()
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	await physics_frame
	var same_tick: Array = _since(mark, "rejected")
	var same_tick_closed: Array = _since(mark, "closed")
	_check("AC-I07", same_tick_closed.size() == 1 and same_tick.size() == 1 and same_tick[0].reason == C.BUSY
		and probe.get("begin_calls") == 1, "E queued while closing: closed %s rejected %s" % [same_tick_closed, same_tick])
	ids.append(same_tick[0].id if same_tick.size() > 0 else -1)
	_log("AC-I07", "E queued while the button closes the session: closed=%s request=%s" % [
		same_tick_closed[0].reason if same_tick_closed.size() > 0 else "-", same_tick[0].reason if same_tick.size() > 0 else "-"])
	await _end_case("AC-I07")
	var increasing: bool = true
	for i: int in range(1, ids.size()):
		increasing = increasing and ids[i] > ids[i - 1]
	_check("AC-I07", increasing, "request IDs increase monotonically %s" % [ids])
	_log("AC-I07", "single begin=1 opened=1; active E=BUSY; held+8 echo requests=1; same-tick double requests=1; ids=%s" % [ids])
	return true


# --- AC-I08 ----------------------------------------------------------------------

func _i08_consumed_and_blocked() -> bool:
	# A focused text field consumes E before _unhandled_input.
	await _place(BASE, "down")
	var probe: InteractionTarget = _target("consumed", BASE + Vector2(0, 20))
	await _ticks(3)
	var layer: CanvasLayer = CanvasLayer.new()
	var field: LineEdit = LineEdit.new()
	layer.add_child(field)
	_map.add_child(layer)
	field.grab_focus()
	await physics_frame
	var mark: int = _rec.size()
	_key(KEY_E, true, false, true)
	_key(KEY_E, false)
	await physics_frame
	await physics_frame
	var typed: String = field.text
	layer.queue_free()
	await physics_frame
	var requests: int = _since(mark, "opened").size() + _since(mark, "rejected").size()
	_check("AC-I08", typed == "e" and requests == 0 and probe.get("begin_calls") == 0, "UI consumed E: text '%s' requests %d" % [typed, requests])
	await _end_case("AC-I08")
	# Movement blocked by someone else: no prompt, no panel, and the lock stays theirs.
	await _place(BASE, "down")
	probe = _target("blocked", BASE + Vector2(0, 20))
	await _ticks(3)
	_player.set_control_enabled(false)
	await physics_frame
	var prompt_hidden: bool = _controller.get_selected_target_id().is_empty() and not _prompt_visible()
	mark = _rec.size()
	_interact_event()
	await physics_frame
	var blocked: Array = _since(mark, "rejected")
	var still_locked: bool = not _player.is_control_effective()
	_player.set_control_enabled(true)
	await physics_frame
	_check("AC-I08", prompt_hidden and blocked.size() == 1 and blocked[0].reason == C.CONTROL_BLOCKED
		and probe.get("begin_calls") == 0 and not _panel_visible() and still_locked, "external lock respected")
	await _end_case("AC-I08")
	# Interaction disabled: no prompt, requests refused, an active session is cancelled.
	await _place(BASE, "down")
	probe = _target("disabled", BASE + Vector2(0, 20))
	await _ticks(3)
	_controller.set_interaction_enabled(false)
	await physics_frame
	var disabled_hidden: bool = _controller.get_selected_target_id().is_empty()
	mark = _rec.size()
	_interact_event()
	await physics_frame
	var refused: Array = _since(mark, "rejected")
	_controller.set_interaction_enabled(true)
	await physics_frame
	mark = _rec.size()
	_interact_event()
	await physics_frame
	var opened_before_disable: bool = _since(mark, "opened").size() == 1
	_controller.set_interaction_enabled(false)
	var closed: Array = _since(mark, "closed")
	_controller.set_interaction_enabled(true)
	await physics_frame
	_check("AC-I08", disabled_hidden and refused.size() == 1 and refused[0].reason == C.DISABLED and opened_before_disable
		and closed.size() == 1 and closed[0].reason == C.DISABLED and probe.get("end_calls") == 1, "disable hides, refuses and cancels")
	_log("AC-I08", "ui_consumed_text='%s' requests=%d; external_lock: prompt_hidden=%s E=%s lock_kept=%s; disabled: hidden=%s E=%s active_closed=%s" % [
		typed, requests, prompt_hidden, blocked[0].reason if blocked.size() > 0 else "-", still_locked, disabled_hidden,
		refused[0].reason if refused.size() > 0 else "-", closed[0].reason if closed.size() > 0 else "-"])
	await _end_case("AC-I08")
	# BUG-004: interaction disabled from inside try_begin (and re-enabled before it returns).
	var disable: Callable = func() -> void: _controller.set_interaction_enabled(false)
	var toggle: Callable = func() -> void:
		_controller.set_interaction_enabled(false)
		_controller.set_interaction_enabled(true)
	var restore: Callable = func() -> void: _controller.set_interaction_enabled(true)
	await _resolving_cancel("AC-I08", "disable_in_begin", disable, C.DISABLED, restore)
	await _resolving_cancel("AC-I08", "disable_enable_in_begin", toggle, C.DISABLED, restore)
	return true


## Runs one E whose target changes the controller from inside try_begin. The request must
## end rejected once with `expected`, the target told end(cancelled) once, nothing opened,
## no gate taken and no other target started; after `restore` a new E works normally.
func _resolving_cancel(ac: String, label: String, action: Callable, expected: StringName, restore: Callable) -> void:
	await _place(BASE, "down")
	var journal: Array = []
	var bystander: Array = []
	var probe: InteractionTarget = _target("resolving", BASE + Vector2(0, 20), {"journal": journal, "on_begin": action})
	_target("bystander", BASE + Vector2(0, 28), {"journal": bystander})
	await _ticks(3)
	var mark: int = _rec.size()
	_interact_event()
	await physics_frame
	var rejected: Array = _since(mark, "rejected")
	var state_idle: bool = _controller.get_state() == InteractionController.State.IDLE
	var panel_hidden: bool = not _panel_visible()
	await _ticks(3)
	var nothing_opened: bool = _since(mark, "opened").is_empty()
	restore.call()
	probe.set("on_begin", Callable())
	await _ticks(3)
	var gate_free: bool = _player.is_control_effective()
	var mark2: int = _rec.size()
	await _press_interact()
	var reopened: Array = _since(mark2, "opened")
	var fresh_id: bool = reopened.size() == 1 and rejected.size() == 1 and reopened[0].id > rejected[0].id
	_check(ac, rejected.size() == 1 and rejected[0].reason == expected and journal.slice(0, 2) == ["begin", "end"]
		and str(probe.get("end_cancelled").slice(0, 1)) == str([true]) and state_idle and panel_hidden and nothing_opened
		and bystander.is_empty() and gate_free and fresh_id,
		"%s: rejected %s journal %s idle %s panel_hidden %s opened0 %s bystander %s gate_free %s fresh %s" % [
			label, rejected, journal, state_idle, panel_hidden, nothing_opened, bystander, gate_free, fresh_id])
	_metrics["%s %s" % [ac, label]] = String(rejected[0].reason) if rejected.size() > 0 else "-"
	_log(ac, "%s: result=%s end_calls_before_retry=%d opened=0 panel_hidden=%s bystander_begin=%d gate_free=%s retry_opened_new_id=%s" % [
		label, rejected[0].reason if rejected.size() > 0 else "-", journal.slice(0, 2).count("end"), panel_hidden,
		bystander.count("begin"), gate_free, fresh_id])
	await _close_active_with_escape()
	await _end_case(ac)


# --- AC-I09 ----------------------------------------------------------------------

func _i09_session_and_movement() -> bool:
	# Walk toward a target, press E while still holding S.
	await _place(BASE + Vector2(0, -20), "down")
	var probe: InteractionTarget = _target("walk_open", BASE + Vector2(0, 30))
	await _ticks(3)
	_press([KEY_S])
	await _ticks_until(func() -> bool: return _controller.get_selected_target_id() == &"walk_open", 30)
	var mark: int = _rec.size()
	_interact_event()
	await physics_frame
	var opened_id: int = _since(mark, "opened")[0].id if _since(mark, "opened").size() > 0 else -1
	var stopped: bool = _player.velocity == Vector2.ZERO
	var frozen_at: Vector2 = _player.global_position
	await _ticks(20)
	var drift: float = _player.global_position.distance_to(frozen_at)
	_check("AC-I09", opened_id > 0 and stopped and drift == 0.0, "open while walking: velocity zero, drift %.4f" % drift)
	# Close with the focused button (Enter) while S is still held.
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)
	await physics_frame
	var closed: Array = _since(mark, "closed")
	var held_still: Vector2 = _player.global_position
	await _ticks(10)
	var moved_while_held: float = _player.global_position.distance_to(held_still)
	_release_all()
	await physics_frame
	_press([KEY_S])
	await _ticks(10)
	var resumed: float = _player.global_position.distance_to(held_still)
	_release_all()
	_check("AC-I09", closed.size() == 1 and closed[0].reason == C.COMPLETED and probe.get("end_calls") == 1
		and str(probe.get("end_cancelled")) == str([false]), "button close: COMPLETED once")
	_check("AC-I09", moved_while_held == 0.0 and resumed > 10.0, "held S after close: moved %.4f, after neutral %.4f" % [moved_while_held, resumed])
	_log("AC-I09", "walking open: velocity0=%s drift_20=%.4f; Enter close=%s end_calls=%d; held_move=%.4f resumed_10=%.4f" % [
		stopped, drift, closed[0].reason if closed.size() > 0 else "-", probe.get("end_calls"), moved_while_held, resumed])
	await _end_case("AC-I09")
	# Escape closes as CANCELLED; an old request ID cannot close the next session.
	await _place(BASE, "down")
	probe = _target("stale", BASE + Vector2(0, 20))
	await _ticks(3)
	mark = _rec.size()
	await _press_interact()
	var first_id: int = _controller.get_active_request_id()
	await _close_active_with_escape()
	var first_close: Array = _since(mark, "closed")
	await _press_interact()
	var second_id: int = _controller.get_active_request_id()
	_ui.close_requested.emit(first_id)
	_ui.cancel_requested.emit(first_id)
	_controller.finish_active(first_id, C.COMPLETED)
	_ui.close_session(first_id, C.COMPLETED)
	await physics_frame
	var still_active: bool = _controller.get_active_request_id() == second_id and _panel_visible() and _ui.get_open_request_id() == second_id
	await _close_active_with_escape()
	_check("AC-I09", first_close.size() == 1 and first_close[0].reason == C.CANCELLED and still_active
		and second_id > first_id and probe.get("end_calls") == 2 and str(probe.get("end_cancelled")) == str([true, true]),
		"Escape cancels; stale ID %d ignored while %d active" % [first_id, second_id])
	_log("AC-I09", "Escape=%s; stale id %d ignored by controller and UI while %d active=%s; end_calls=%d" % [
		first_close[0].reason if first_close.size() > 0 else "-", first_id, second_id, still_active, probe.get("end_calls")])
	await _end_case("AC-I09")
	return true


# --- AC-I10 ----------------------------------------------------------------------

func _i10_lifecycle() -> bool:
	var breakers: Array = [
		["queue_free", func(t: InteractionTarget) -> void: t.queue_free(), C.INVALID_TARGET],
		["hidden", func(t: InteractionTarget) -> void: t.visible = false, C.INVALID_TARGET],
		["unavailable", func(t: InteractionTarget) -> void: t.available = false, C.INVALID_TARGET],
		["pushed_away", func(_t: InteractionTarget) -> void: _player.global_position = BASE + Vector2(0, -60), C.OUT_OF_RANGE],
		["walled_off", func(_t: InteractionTarget) -> void: _wall(Rect2(BASE + Vector2(-20, 10), Vector2(40, 4))), C.OCCLUDED],
	]
	for case: Array in breakers:
		await _place(BASE, "down")
		var probe: InteractionTarget = _target("active", BASE + Vector2(0, 20))
		await _ticks(3)
		await _press_interact()
		var mark: int = _rec.size()
		(case[1] as Callable).call(probe)
		await physics_frame
		var closed: Array = _since(mark, "closed")
		await physics_frame
		var ok: bool = closed.size() == 1 and closed[0].reason == case[2] and not _panel_visible() \
			and _controller.get_state() == InteractionController.State.IDLE and _player.is_control_effective()
		_check("AC-I10", ok, "%s during session: %s" % [case[0], closed])
		_metrics["AC-I10 %s" % case[0]] = String(closed[0].reason) if closed.size() > 0 else "-"
		_log("AC-I10", "%s: closed=%s panel_hidden=%s gate_released=%s" % [case[0],
			closed[0].reason if closed.size() > 0 else "-", not _panel_visible(), _player.is_control_effective()])
		await _end_case("AC-I10")
	# Application focus out cancels and hides; focus in does not reopen anything.
	await _place(BASE, "down")
	var focus_probe: InteractionTarget = _target("focus", BASE + Vector2(0, 20))
	await _ticks(3)
	await _press_interact()
	var mark2: int = _rec.size()
	_interact_event()
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await physics_frame
	var focus_closed: Array = _since(mark2, "closed")
	var hidden: bool = not _prompt_visible() and not _panel_visible()
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _ticks(3)
	var reopened: int = _since(mark2, "opened").size()
	_check("AC-I10", focus_closed.size() == 1 and focus_closed[0].reason == C.FOCUS_LOST and hidden and reopened == 0
		and focus_probe.get("end_calls") == 1 and _since(mark2, "rejected").size() == 1, "focus out/in: %s" % [focus_closed])
	_check("AC-I10", _controller.get_selected_target_id() == &"focus", "selection returns after focus in")
	_log("AC-I10", "focus_out closed=%s queued_request_rejected=%s hidden=%s focus_in_reopened=%d" % [
		focus_closed[0].reason if focus_closed.size() > 0 else "-", _since(mark2, "rejected")[0].reason if _since(mark2, "rejected").size() > 0 else "-", hidden, reopened])
	await _end_case("AC-I10")
	# Focus notifications before ready (BUG-001 order) on a fresh player with its controller.
	var early: PlayerController = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerController
	early.position = Vector2(900, 650)
	early.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	early.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_map.add_child(early)
	await _ticks(2)
	var early_controller: InteractionController = early.get_node("InteractionController") as InteractionController
	var early_ok: bool = early_controller.get_state() == InteractionController.State.IDLE and early_controller.get_selected_target_id().is_empty()
	early.queue_free()
	await physics_frame
	_check("AC-I10", early_ok, "pre-ready focus notifications leave a clean idle controller")
	# Map leaves and re-enters the tree: selection works again with no errors.
	await _place(Vector2(128, 360), "down")
	root.remove_child(_map)
	await _ticks(2)
	root.add_child(_map)
	await _ticks(3)
	var reentered: StringName = _controller.get_selected_target_id()
	_check("AC-I10", reentered == &"sign_entrance", "selection after map re-entry %s" % reentered)
	await _end_case("AC-I10")
	# BUG-003 during a session: the active target's ID becomes duplicated or changes.
	for change: String in ["duplicate", "renamed"]:
		await _place(BASE, "down")
		var active: InteractionTarget = _target("held_id", BASE + Vector2(0, 20))
		var twin: InteractionTarget = _target("held_id", BASE + Vector2(2, 22), {"available": false})
		await _ticks(3)
		await _press_interact()
		var mark5: int = _rec.size()
		if change == "duplicate":
			twin.available = true
		else:
			active.target_id = &"renamed_id"
		await physics_frame
		var closed5: Array = _since(mark5, "closed")
		await physics_frame
		_check("AC-I10", closed5.size() == 1 and closed5[0].reason == C.INVALID_TARGET and active.get("end_calls") == 1
			and twin.get("begin_calls") == 0 and not _panel_visible() and _player.is_control_effective(),
			"active ID %s: closed %s end %d" % [change, closed5, active.get("end_calls")])
		_metrics["AC-I10 active id %s" % change] = String(closed5[0].reason) if closed5.size() > 0 else "-"
		_log("AC-I10", "active ID %s: closed=%s end_calls=%d twin_begin=%d gate_released=%s" % [change,
			closed5[0].reason if closed5.size() > 0 else "-", active.get("end_calls"), twin.get("begin_calls"), _player.is_control_effective()])
		await _end_case("AC-I10")
	# BUG-004 variants: focus lost or the controller leaving the tree inside try_begin.
	var lose_focus: Callable = func() -> void: root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var regain_focus: Callable = func() -> void: root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _resolving_cancel("AC-I10", "focus_out_in_begin", lose_focus, C.FOCUS_LOST, regain_focus)
	var detach: Callable = func() -> void: _player.remove_child(_controller)
	var reattach: Callable = func() -> void: _player.add_child(_controller)
	await _resolving_cancel("AC-I10", "tree_exit_in_begin", detach, C.REMOVED, reattach)
	# queue_free of the controller inside try_begin: no session, target told once.
	await _place(BASE, "down")
	var free_journal: Array = []
	var doomed: InteractionController = _controller
	_target("doomed", BASE + Vector2(0, 20), {"journal": free_journal, "on_begin": func() -> void: doomed.queue_free()})
	await _ticks(3)
	var mark6: int = _rec.size()
	_interact_event()
	await physics_frame
	var rejected6: Array = _since(mark6, "rejected")
	var opened6: int = _since(mark6, "opened").size()
	await _ticks(2)
	_check("AC-I10", rejected6.size() == 1 and rejected6[0].reason == C.REMOVED and opened6 == 0
		and free_journal == ["begin", "end"] and not _panel_visible() and _player.is_control_effective(),
		"controller queue_free inside try_begin: %s journal %s" % [rejected6, free_journal])
	_metrics["AC-I10 queue_free_in_begin"] = String(rejected6[0].reason) if rejected6.size() > 0 else "-"
	_log("AC-I10", "queue_free_in_begin: result=%s journal=%s opened=%d gate_free=%s" % [
		rejected6[0].reason if rejected6.size() > 0 else "-", free_journal, opened6, _player.is_control_effective()])
	await _unload_map()
	await _load_map()
	# The controller is removed during a session: target notified, own gate released.
	await _place(BASE, "down")
	var removal_probe: InteractionTarget = _target("removal", BASE + Vector2(0, 20))
	await _ticks(3)
	await _press_interact()
	var mark3: int = _rec.size()
	var removed: InteractionController = _controller
	_player.remove_child(removed)
	var removed_closed: Array = _since(mark3, "closed")
	removed.free()
	await physics_frame
	_check("AC-I10", removed_closed.size() == 1 and removed_closed[0].reason == C.REMOVED and removal_probe.get("end_calls") == 1
		and _player.is_control_effective(), "controller removal releases its gate: %s" % [removed_closed])
	_log("AC-I10", "pre_ready_focus_clean=%s reentry_selected=%s controller_removed=%s end_calls=%d gate_released=%s" % [
		early_ok, reentered, removed_closed[0].reason if removed_closed.size() > 0 else "-", removal_probe.get("end_calls"), _player.is_control_effective()])
	# The whole map is freed during a session (the suite reloads it afterwards).
	await _unload_map()
	await _load_map()
	await _place(Vector2(128, 360), "down")
	await _press_interact()
	var open_before_free: bool = _controller.get_state() == InteractionController.State.ACTIVE
	await _unload_map()
	await _load_map()
	_check("AC-I10", open_before_free, "map freed while a session was open")
	return true


# --- AC-I11 ----------------------------------------------------------------------

func _i11_ui() -> bool:
	var view: Rect2 = Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for case: Array in [["down", "sign_entrance", "마을 안내판"], ["right", "crate_supplies", "보급 상자"]]:
		await _place(Vector2(128, 360), case[0])
		var prompt: String = _prompt_text()
		var target: InteractionTarget = _targets_root.find_children("*", "InteractionTarget", true, false).filter(
			func(n: Node) -> bool: return (n as InteractionTarget).target_id == StringName(case[1]))[0]
		var position_before: Vector2 = _player.global_position
		await _press_interact()
		var title: Label = _ui.get_node("InspectPanel/Layout/Title") as Label
		var description: Label = _ui.get_node("InspectPanel/Layout/Description") as Label
		var panel: Control = _ui.get_node("InspectPanel") as Control
		var button: Button = _ui.get_node("InspectPanel/Layout/CloseButton") as Button
		var focused: bool = root.gui_get_focus_owner() == button
		var inside: bool = view.encloses(panel.get_global_rect()) and view.encloses((_ui.get_node("Prompt") as Control).get_global_rect())
		var lines_shown: bool = description.get_visible_line_count() >= description.get_line_count()
		_check("AC-I11", prompt == "E 살펴보기 — %s" % case[2], "prompt '%s'" % prompt)
		_check("AC-I11", title.text == target.display_name and description.text == target.description and focused,
			"panel shows %s with close focused (%s)" % [case[1], focused])
		_check("AC-I11", inside and lines_shown, "panel inside 640x360 %s, description lines %d/%d" % [
			panel.get_global_rect(), description.get_visible_line_count(), description.get_line_count()])
		var mark: int = _rec.size()
		_key(KEY_ENTER, true)
		_key(KEY_ENTER, false)
		await physics_frame
		await physics_frame
		var closed: Array = _since(mark, "closed")
		_check("AC-I11", closed.size() == 1 and closed[0].reason == C.COMPLETED and _player.global_position == position_before
			and _prompt_text() == prompt, "E -> read -> close completes and the prompt returns")
		_log("AC-I11", "%s: prompt='%s' title='%s' focus_close=%s panel_rect=%s lines=%d/%d closed=%s" % [
			case[1], prompt, title.text, focused, panel.get_global_rect(), description.get_visible_line_count(),
			description.get_line_count(), closed[0].reason if closed.size() > 0 else "-"])
		await _end_case("AC-I11")
	return true


# --- harness ---------------------------------------------------------------------

func _load_map() -> void:
	_map = (load(MAP_SCENE) as PackedScene).instantiate() as Node2D
	root.add_child(_map)
	await process_frame
	_controller = _map.get("controller") as InteractionController
	_ui = _map.get("ui") as InteractionUI
	_player = _map.get_node("World/Player") as PlayerController
	_targets_root = _map.get_node("Targets") as Node2D
	_rec.clear()
	_controller.target_changed.connect(func(id: StringName, _a: String, _d: String) -> void:
		_rec.append({"kind": "target", "id": id}))
	_controller.session_opened.connect(func(id: int, title: String, _d: String) -> void:
		_rec.append({"kind": "opened", "id": id, "title": title}))
	_controller.session_closed.connect(func(id: int, reason: StringName) -> void:
		_rec.append({"kind": "closed", "id": id, "reason": reason}))
	_controller.request_rejected.connect(func(id: int, reason: StringName) -> void:
		_rec.append({"kind": "rejected", "id": id, "reason": reason}))
	await _ticks(3)


func _unload_map() -> void:
	_release_all()
	_temp.clear()
	_map.queue_free()
	_map = null
	await process_frame
	await physics_frame


## Puts the player on `position` facing `facing` with no keys held and the gate open.
func _place(position: Vector2, facing: String) -> void:
	_release_all()
	await physics_frame
	_press(FACING_KEYS[facing])
	await physics_frame
	_release_all()
	_player.global_position = position
	_player.velocity = Vector2.ZERO
	await _ticks(3)


## Every case must leave no session, no lock, no panel and no held key behind.
func _end_case(ac: String) -> void:
	_release_all()
	await physics_frame
	var clean: bool = is_instance_valid(_controller) and _controller.get_state() == InteractionController.State.IDLE \
		and _player.is_control_effective() and not _panel_visible()
	_check(ac, clean, "case left state %s effective %s panel %s" % [
		_controller.get_state() if is_instance_valid(_controller) else -1, _player.is_control_effective(), _panel_visible()])
	for node: Node in _temp:
		if is_instance_valid(node):
			node.queue_free()
	_temp.clear()
	await physics_frame


func _target(id: String, position: Vector2, properties: Dictionary = {}) -> InteractionTarget:
	var node: Node = (load(TARGET_SCENE) as PackedScene).instantiate()
	node.set_script(PROBE)
	var target: InteractionTarget = node as InteractionTarget
	target.target_id = StringName(id)
	target.display_name = "Probe " + id
	target.description = "Probe target for the IH-102 runner."
	for key: String in properties:
		target.set(key, properties[key])
	target.global_position = position
	_targets_root.add_child(target)
	_temp.append(target)
	return target


## A world_solid wall; `pass_through` keeps it from pushing the player out of it.
func _wall(rect: Rect2, pass_through: bool = false) -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	body.position = rect.get_center()
	_map.add_child(body)
	if pass_through:
		_player.add_collision_exception_with(body)
	_temp.append(body)
	return body


func _press_interact() -> void:
	_interact_event()
	await physics_frame


func _interact_event() -> void:
	_key(KEY_E, true)
	_key(KEY_E, false)


func _close_active_with_escape() -> void:
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await physics_frame


## Feeds the event like a window would; the flush dispatches it to the viewport synchronously.
func _key(code: Key, pressed: bool, echo: bool = false, typed: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	if typed:
		event.unicode = OS.get_keycode_string(code).to_lower().unicode_at(0)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed and code not in _held:
		_held.append(code)
	elif not pressed:
		_held.erase(code)


func _press(keys: Array) -> void:
	for code: Key in keys:
		_key(code, true)


func _release_all() -> void:
	for code: Key in _held.duplicate():
		_key(code, false)


func _ticks(count: int) -> void:
	for i: int in count:
		await physics_frame


## Number of ticks until `condition` holds (checked after each tick), or -1.
func _ticks_until(condition: Callable, limit: int) -> int:
	for i: int in limit:
		await physics_frame
		if condition.call():
			return i + 1
	return -1


func _since(mark: int, kind: String) -> Array:
	return _rec.slice(mark).filter(func(entry: Dictionary) -> bool: return entry.kind == kind)


func _prompt_text() -> String:
	var prompt: Label = _ui.get_node("Prompt") as Label
	return prompt.text if prompt.visible else ""


func _prompt_visible() -> bool:
	return (_ui.get_node("Prompt") as Label).visible


func _panel_visible() -> bool:
	return (_ui.get_node("InspectPanel") as Control).visible


func _all_released() -> bool:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"interact", &"interaction_cancel"]:
		if Input.is_action_pressed(action):
			return false
	return _held.is_empty()


func _names(keys: Array) -> String:
	var names: PackedStringArray = []
	for code: Key in keys:
		names.append(OS.get_keycode_string(code))
	return "+".join(names)


func _compare_passes() -> void:
	var first: Dictionary = _pass_metrics[0]
	var second: Dictionary = _pass_metrics[1]
	var differences: PackedStringArray = []
	for key: String in first:
		if not second.has(key) or str(first[key]) != str(second[key]):
			differences.append("%s: %s vs %s" % [key, first[key], second.get(key)])
	_check("AC-I12", first.keys() == second.keys() and differences.is_empty(), "pass differences %s" % differences)
	_log("AC-I12", "passes=2 measurements=%d differences=%d" % [first.size(), differences.size()])


func _check(ac: String, ok: bool, message: String) -> void:
	var counts: Array = _ac_checks.get(ac, [0, 0])
	counts[0] += 1
	if not ok:
		counts[1] += 1
		_failures.append("%s: %s" % [ac, message])
		push_error("FAIL %s: %s" % [ac, message])
	_ac_checks[ac] = counts


func _log(ac: String, message: String) -> void:
	print("  [%s] %s" % [ac, message])


func _finish() -> void:
	print("IH-102 automated summary:")
	var keys: Array = _ac_checks.keys()
	keys.sort()
	for ac: String in keys:
		var counts: Array = _ac_checks[ac]
		print("  %s %s (%d checks, %d failed)" % [ac, "PASS" if counts[1] == 0 else "FAIL", counts[0], counts[1]])
	print("  Not covered here: real app switch (AC-I10), keyboard/readability/resize (AC-I07..I11 GUI), code/doc review (AC-I12).")
	if _failures.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		for failure: String in _failures:
			print("  FAILED " + failure)
		print("RESULT: FAIL (%d)" % _failures.size())
		quit(1)
