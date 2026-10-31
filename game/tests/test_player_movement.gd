extends SceneTree
## IH-101 acceptance runner. Steps the real Player and MovementTest scenes through the
## engine's physics loop and feeds real InputEventKey events through the InputMap.
## Exit code 0 only when every automated check passes. GUI-only evidence (AC-09 real
## focus switch, AC-10 window resize/smoothness, keyboard feel) is never reported here.
##
## Timing contract: `await physics_frame` resumes at the start of a physics tick, before
## nodes run _physics_process. Pressing keys there and awaiting N more frames therefore
## measures exactly N controller updates; the physics frame counter is recorded to prove it.

const MAP_SCENE: String = "res://scenes/tests/movement_test.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const MAIN_SCENE: String = "res://scenes/foundation.tscn"
const SPEED: float = 96.0
const TICKS: int = 120
const TOL: float = 0.25
const RADIUS: float = 6.0
const WORLD: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
const OPEN_START: Vector2 = Vector2(320.0, 360.0)
## Fixture from PLAYER_MOVEMENT.md; the scene must match it exactly.
const FIXTURE: Dictionary = {
	"BoundaryTop": Rect2(0, 0, 1280, 16),
	"BoundaryBottom": Rect2(0, 704, 1280, 16),
	"BoundaryLeft": Rect2(0, 16, 16, 688),
	"BoundaryRight": Rect2(1264, 16, 16, 688),
	"Block": Rect2(600, 280, 64, 160),
	"CorridorTop": Rect2(900, 200, 160, 32),
	"CorridorBottom": Rect2(900, 252, 160, 32),
}
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]

var _ac_checks: Dictionary = {}
var _failures: Array[String] = []
var _held: Array[Key] = []
var _map: Node2D
var _player: PlayerController
var _solids: Array[Rect2] = []
var _pass_metrics: Array[Dictionary] = []
var _metrics: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	print("IH-101 runner: engine=%s cli_max_fps=%d physics_hz=%d" % [
		Engine.get_version_info().string, Engine.max_fps, Engine.physics_ticks_per_second])
	_check_static_contract()
	# AC-11: the full physical suite runs twice in one process on fresh map instances.
	for pass_index: int in 2:
		_metrics = {}
		await _load_map()
		await _run_suite()
		await _unload_map()
		_check("AC-11", _all_actions_released(), "pass %d left a move action pressed" % pass_index)
		_pass_metrics.append(_metrics)
	_compare_passes()
	await process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("AC-11", orphans == 0, "orphan nodes after both passes: %d" % orphans)
	if "--inject-failure" in OS.get_cmdline_user_args():
		_check("AC-11", false, "deliberate failure requested by --inject-failure")
	_finish()


func _run_suite() -> void:
	var steps: Array = [
		["AC-01", _ac01_runtime_contract], ["AC-02", _ac02_cardinal], ["AC-03", _ac03_diagonal_and_keys],
		["AC-04", _ac04_render_caps], ["AC-05", _ac05_boundaries], ["AC-06", _ac06_block_and_corridor],
		["AC-07", _ac07_states], ["AC-08", _ac08_control_gate], ["AC-09", _ac09_focus_notifications],
		["AC-10", _ac10_camera],
	]
	for step: Array in steps:
		# A script error aborts the coroutine and returns null instead of true.
		var completed: Variant = await (step[1] as Callable).call()
		_check(step[0], completed == true, "%s case list aborted before completion" % step[0])


# --- AC-01 -----------------------------------------------------------------------

func _check_static_contract() -> void:
	_check("AC-01", ProjectSettings.get_setting("application/run/main_scene") == MAIN_SCENE,
		"Foundation must stay the main scene")
	_check("AC-01", Engine.physics_ticks_per_second == 60, "physics must run at 60 Hz")
	_check("AC-01", not ProjectSettings.get_setting("physics/common/physics_interpolation"),
		"physics interpolation must stay off for this check")
	var expected: Dictionary = {
		&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
		&"move_up": [KEY_W, KEY_UP], &"move_down": [KEY_S, KEY_DOWN],
	}
	for action: StringName in ACTIONS:
		_check("AC-01", InputMap.has_action(action), "missing action %s" % action)
		if not InputMap.has_action(action):
			continue
		_check("AC-01", is_equal_approx(InputMap.action_get_deadzone(action), 0.2), "%s deadzone" % action)
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		_check("AC-01", events.size() == 2, "%s must have exactly two key events" % action)
		if events.size() != 2:
			continue
		var letter: InputEventKey = events[0] as InputEventKey
		var arrow: InputEventKey = events[1] as InputEventKey
		_check("AC-01", letter != null and letter.physical_keycode == expected[action][0] and letter.keycode == KEY_NONE,
			"%s letter key must be physical" % action)
		_check("AC-01", arrow != null and arrow.keycode == expected[action][1] and arrow.physical_keycode == KEY_NONE,
			"%s arrow key must use keycode" % action)
	var player_scene: PackedScene = load(PLAYER_SCENE) as PackedScene
	_check("AC-01", player_scene != null, "player scene must load")
	if player_scene == null:
		return
	var player: Node = player_scene.instantiate()
	_check("AC-01", player is CharacterBody2D and player is PlayerController, "Player root type")
	var body: CharacterBody2D = player as CharacterBody2D
	_check("AC-01", body.motion_mode == CharacterBody2D.MOTION_MODE_FLOATING, "floating motion mode")
	_check("AC-01", body.platform_floor_layers == 0 and body.collision_layer == 2 and body.collision_mask == 1,
		"player layers: layer 2 / mask 1 / no platform layers")
	_check("AC-01", body.process_mode == Node.PROCESS_MODE_PAUSABLE, "player must be pausable")
	var shape: CollisionShape2D = player.get_node_or_null("BodyCollision") as CollisionShape2D
	_check("AC-01", shape != null and shape.shape is CircleShape2D and is_equal_approx((shape.shape as CircleShape2D).radius, RADIUS)
		and shape.position == Vector2.ZERO, "feet circle radius 6 at origin")
	_check("AC-01", player.get_node_or_null("Visual") is PlayerVisual, "Visual adapter present")
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	_check("AC-01", camera != null and not camera.enabled, "player scene camera disabled by default")
	_check("AC-01", camera != null and camera.process_callback == Camera2D.CAMERA2D_PROCESS_PHYSICS
		and camera.zoom == Vector2.ONE and camera.offset == Vector2.ZERO and camera.ignore_rotation
		and not camera.position_smoothing_enabled and not camera.rotation_smoothing_enabled
		and not camera.drag_horizontal_enabled and not camera.drag_vertical_enabled, "camera start values")
	player.free()


func _ac01_runtime_contract() -> bool:
	var cameras: Array[Node] = _map.find_children("*", "Camera2D", true, false)
	var enabled: int = 0
	for node: Node in cameras:
		if (node as Camera2D).enabled:
			enabled += 1
	var camera: Camera2D = _player.get_node("Camera2D") as Camera2D
	_check("AC-01", enabled == 1 and camera.enabled and camera.is_current(), "exactly one active camera")
	_check("AC-01", camera.limit_left == 0 and camera.limit_top == 0 and camera.limit_right == 1280
		and camera.limit_bottom == 720, "camera limits match the world")
	_check("AC-01", _player.global_position == Vector2(128, 360), "spawn (128,360) got %s" % _player.global_position)
	var found: int = 0
	for body: Node in _map.get_node("WorldCollision").get_children():
		var static_body: StaticBody2D = body as StaticBody2D
		var rect: Rect2 = _static_rect(static_body)
		var expected: Rect2 = FIXTURE.get(String(static_body.name), Rect2())
		_check("AC-01", rect.is_equal_approx(expected), "%s rect %s != %s" % [static_body.name, rect, expected])
		_check("AC-01", static_body.collision_layer == 1 and static_body.collision_mask == 2, "%s layers" % static_body.name)
		var polygon: Polygon2D = static_body.get_node("Polygon2D") as Polygon2D
		var outline: Rect2 = Rect2(polygon.polygon[0], Vector2.ZERO)
		for point: Vector2 in polygon.polygon:
			outline = outline.expand(point)
		outline.position += static_body.global_position
		_check("AC-01", outline.is_equal_approx(rect), "%s visual outline must match its shape" % static_body.name)
		found += 1
	_check("AC-01", found == FIXTURE.size(), "fixture body count %d" % found)
	_log("AC-01", "spawn=%s active_cameras=%d fixture_bodies=%d" % [_player.global_position, enabled, found])
	return true


# --- AC-02 / AC-03 / AC-04 -------------------------------------------------------

func _ac02_cardinal() -> bool:
	var cases: Array = [[KEY_D, Vector2.RIGHT], [KEY_A, Vector2.LEFT], [KEY_W, Vector2.UP], [KEY_S, Vector2.DOWN]]
	for case: Array in cases:
		var run: Dictionary = await _drive(OPEN_START, [case[0]], TICKS)
		var along: float = run.delta.dot(case[1])
		var across: float = absf(run.delta.cross(case[1]))
		_check("AC-02", run.ticks == TICKS, "tick count %d" % run.ticks)
		_check("AC-02", absf(along - SPEED * TICKS / 60.0) <= TOL, "%s distance %.4f" % [case[1], along])
		_check("AC-02", across <= TOL, "%s off-axis %.4f" % [case[1], across])
		var stop: Dictionary = await _release_and_step()
		_check("AC-02", stop.velocity_zero and stop.moved <= 0.001, "%s must stop on the tick after release" % case[1])
		_metrics["AC-02 %s" % case[1]] = along
		_log("AC-02", "dir=%s ticks=%d distance=%.4f off_axis=%.4f after_release_move=%.4f" % [
			case[1], run.ticks, along, across, stop.moved])
	return true


func _ac03_diagonal_and_keys() -> bool:
	var expected_axis: float = SPEED * TICKS / 60.0 / sqrt(2.0)
	var diagonals: Array = [[KEY_W, KEY_D], [KEY_W, KEY_A], [KEY_S, KEY_D], [KEY_S, KEY_A]]
	for keys: Array in diagonals:
		var run: Dictionary = await _drive(OPEN_START, keys, TICKS)
		_check("AC-03", absf(run.delta.length() - SPEED * TICKS / 60.0) <= TOL, "diagonal length %.4f" % run.delta.length())
		_check("AC-03", absf(absf(run.delta.x) - expected_axis) <= TOL and absf(absf(run.delta.y) - expected_axis) <= TOL,
			"diagonal axes %s" % run.delta)
		_check("AC-03", run.max_speed <= 96.01, "diagonal speed %.4f" % run.max_speed)
		await _release_and_step()
		_metrics["AC-03 %s" % [keys]] = run.delta.length()
		_log("AC-03", "keys=%s delta=%s length=%.4f max_speed=%.4f" % [_names(keys), run.delta, run.delta.length(), run.max_speed])
	# Opposite keys cancel on their axis; pressing all four cancels everything.
	var opposite: Array = [[[KEY_A, KEY_D], Vector2.ZERO], [[KEY_W, KEY_S], Vector2.ZERO],
		[[KEY_A, KEY_D, KEY_W, KEY_S], Vector2.ZERO], [[KEY_A, KEY_D, KEY_W], Vector2.UP * 48.0],
		[[KEY_LEFT, KEY_RIGHT], Vector2.ZERO]]
	for case: Array in opposite:
		var run: Dictionary = await _drive(OPEN_START, case[0], 30)
		_check("AC-03", run.delta.distance_to(case[1]) <= TOL, "opposite %s delta %s" % [_names(case[0]), run.delta])
		await _release_and_step()
		_log("AC-03", "opposite keys=%s delta=%s" % [_names(case[0]), run.delta])
	# Two keys bound to the same action must not add speed (letter + arrow).
	var duplicates: Array = [[[KEY_W, KEY_UP], Vector2.UP], [[KEY_D, KEY_RIGHT], Vector2.RIGHT],
		[[KEY_W, KEY_UP, KEY_D, KEY_RIGHT], Vector2(1, -1).normalized()]]
	for case: Array in duplicates:
		var run: Dictionary = await _drive(OPEN_START, case[0], 60)
		_check("AC-03", run.delta.distance_to(case[1] * SPEED) <= TOL and run.max_speed <= 96.01,
			"duplicate %s delta %s speed %.4f" % [_names(case[0]), run.delta, run.max_speed])
		await _release_and_step()
		_log("AC-03", "duplicate keys=%s delta=%s max_speed=%.4f" % [_names(case[0]), run.delta, run.max_speed])
	return true


func _ac04_render_caps() -> bool:
	var original_cap: int = Engine.max_fps
	var distances: Array[float] = []
	for cap: int in [30, 60, 120]:
		Engine.max_fps = cap
		var process_before: int = Engine.get_process_frames()
		var run: Dictionary = await _drive(OPEN_START, [KEY_D], TICKS)
		var process_frames: int = Engine.get_process_frames() - process_before
		await _release_and_step()
		distances.append(run.delta.x)
		_check("AC-04", run.ticks == TICKS and absf(run.delta.x - 192.0) <= TOL, "cap %d distance %.4f" % [cap, run.delta.x])
		_log("AC-04", "requested_cap=%d physics_frames=%d process_frames=%d distance=%.4f" % [
			cap, run.ticks, process_frames, run.delta.x])
	Engine.max_fps = original_cap
	var spread: float = distances.max() - distances.min()
	_check("AC-04", spread <= TOL, "distance spread across caps %.4f" % spread)
	_metrics["AC-04 spread"] = spread
	return true


# --- AC-05 / AC-06 ---------------------------------------------------------------

func _ac05_boundaries() -> bool:
	var inner: Rect2 = Rect2(22, 22, 1236, 676)
	var cases: Array = [[Vector2(100, 360), KEY_A, "left"], [Vector2(1180, 360), KEY_D, "right"],
		[Vector2(320, 100), KEY_W, "top"], [Vector2(320, 620), KEY_S, "bottom"]]
	for case: Array in cases:
		# 80 ticks reach the wall from 78 units away; the next 120 ticks keep pushing.
		var approach: Dictionary = await _drive(case[0], [case[1]], 80, false)
		var contact: Vector2 = _player.global_position
		var push: Dictionary = await _continue(TICKS)
		var after: Vector2 = _player.global_position
		await _release_and_step()
		var drift: float = after.distance_to(contact)
		var inside: bool = inner.grow(TOL).has_point(after) and approach.max_penetration <= TOL and push.max_penetration <= TOL
		_check("AC-05", inside, "%s wall final %s penetration %.4f" % [case[2], after, maxf(approach.max_penetration, push.max_penetration)])
		_check("AC-05", drift <= TOL, "%s wall drift while pushing %.4f" % [case[2], drift])
		_check("AC-05", push.idle_ticks == TICKS, "%s wall pushing must read idle (%d/%d)" % [case[2], push.idle_ticks, TICKS])
		_metrics["AC-05 %s" % case[2]] = after
		_log("AC-05", "%s contact=%s after_120=%s drift=%.4f max_penetration=%.4f" % [
			case[2], contact, after, drift, maxf(approach.max_penetration, push.max_penetration)])
	return true


func _ac06_block_and_corridor() -> bool:
	# Head-on stop, then slide up along the block face, then round the top-left corner.
	var head_on: Dictionary = await _drive(Vector2(560, 360), [KEY_D], 60, false)
	var stop: Vector2 = _player.global_position
	_check("AC-06", stop.x <= 594.0 + TOL and stop.x >= 594.0 - 1.0 and absf(stop.y - 360.0) <= TOL, "head-on stop %s" % stop)
	_check("AC-06", _player.get_locomotion() == PlayerController.Locomotion.IDLE
		and _player.get_facing() == PlayerController.Facing.RIGHT, "blocked: idle facing right")
	_key(KEY_W, true)
	# Godot floating mode keeps the remaining motion length on the first slide, so the
	# slide is faster than the 67.88 projection; record it instead of assuming it.
	# Only y >= 280 is beside the flat face; between 274 and 280 the circle legitimately
	# rounds the corner (x up to ~600), which the penetration check covers.
	var beside_face: Array = [0, 0.0, 0]
	var face: Callable = func() -> void:
		var feet: Vector2 = _player.global_position
		if feet.y >= 280.0:
			beside_face[0] += 1
			beside_face[1] = maxf(beside_face[1], feet.x)
			if _player.get_locomotion() == PlayerController.Locomotion.WALK:
				beside_face[2] += 1
	var slide: Dictionary = await _continue(60, face)
	var slid: Vector2 = _player.global_position
	var slide_speed: float = (stop.y - 280.0) / float(beside_face[0]) * 60.0
	_check("AC-06", beside_face[1] <= 594.0 + TOL and stop.y - slid.y >= 60.0,
		"slide along wall: max x beside face %.4f, final %s" % [beside_face[1], slid])
	_check("AC-06", beside_face[2] == beside_face[0] and beside_face[0] > 0,
		"sliding along the wall must read walk (%d/%d)" % [beside_face[2], beside_face[0]])
	var corner: Dictionary = await _continue(60)
	var rounded: Vector2 = _player.global_position
	await _release_and_step()
	var penetration: float = maxf(maxf(head_on.max_penetration, slide.max_penetration), corner.max_penetration)
	_check("AC-06", rounded.y < 274.0 and rounded.x > 600.0, "rounded the corner %s" % rounded)
	_check("AC-06", penetration <= TOL, "block penetration %.4f" % penetration)
	_metrics["AC-06 slide"] = slid
	_metrics["AC-06 corner"] = rounded
	_log("AC-06", "head_on_stop=%s ticks_beside_face=%d max_x_beside_face=%.4f slide_speed~%.2f slide_60=%s after_corner_60=%s max_penetration=%.4f" % [
		stop, beside_face[0], beside_face[1], slide_speed, slid, rounded, penetration])
	# Diagonal approach straight at the block's top-left corner must not stick.
	var diagonal: Dictionary = await _drive(Vector2(560, 250), [KEY_S, KEY_D], TICKS)
	await _release_and_step()
	_check("AC-06", diagonal.delta.length() >= 100.0 and diagonal.max_penetration <= TOL,
		"corner approach moved %.4f penetration %.4f" % [diagonal.delta.length(), diagonal.max_penetration])
	_log("AC-06", "corner_diagonal start=(560,250) delta=%s penetration=%.4f" % [diagonal.delta, diagonal.max_penetration])
	# The 20-unit corridor fits a 12-unit body in both directions.
	for case: Array in [[Vector2(860, 242), KEY_D, 1100.0], [Vector2(1100, 242), KEY_A, 860.0]]:
		var run: Dictionary = await _drive(case[0], [case[1]], 150)
		var end: Vector2 = _player.global_position
		await _release_and_step()
		_check("AC-06", absf(end.x - case[2]) <= TOL and absf(end.y - 242.0) <= TOL and run.max_penetration <= TOL,
			"corridor %s -> %s" % [case[0], end])
		_metrics["AC-06 corridor %s" % case[0]] = end
		_log("AC-06", "corridor %s -> %s max_penetration=%.4f" % [case[0], end, run.max_penetration])
	return true


# --- AC-07 -----------------------------------------------------------------------

func _ac07_states() -> bool:
	# A fresh instance proves the initial state, independent of earlier cases.
	var player: PlayerController = (load(PLAYER_SCENE) as PackedScene).instantiate() as PlayerController
	player.position = Vector2(400, 600)
	_map.add_child(player)
	await physics_frame
	await physics_frame
	_check("AC-07", player.get_locomotion() == PlayerController.Locomotion.IDLE
		and player.get_facing() == PlayerController.Facing.DOWN, "initial idle/down")
	_check("AC-07", _marker_matches(player, PlayerController.Facing.DOWN), "initial marker points down")
	player.queue_free()
	await physics_frame

	var visual: PlayerVisual = _player.get_node("Visual") as PlayerVisual
	var body: Polygon2D = visual.get_node("Body") as Polygon2D
	var shape: CollisionShape2D = _player.get_node("BodyCollision") as CollisionShape2D
	var sequence: Array = [
		[[KEY_D], PlayerController.Facing.RIGHT], [[KEY_W], PlayerController.Facing.UP],
		[[KEY_A], PlayerController.Facing.LEFT], [[KEY_S], PlayerController.Facing.DOWN],
		[[KEY_W, KEY_A], PlayerController.Facing.LEFT], [[KEY_S, KEY_D], PlayerController.Facing.RIGHT],
		[[KEY_W, KEY_D], PlayerController.Facing.RIGHT], [[KEY_S, KEY_A], PlayerController.Facing.LEFT],
	]
	for case: Array in sequence:
		var body_y: Array[float] = []
		var shape_fixed: Array[bool] = [true]
		var sample: Callable = func() -> void:
			body_y.append(body.position.y)
			if shape.position != Vector2.ZERO or shape.global_position != _player.global_position:
				shape_fixed[0] = false
		var run: Dictionary = await _drive(OPEN_START, case[0], 30, true, sample)
		var walking: bool = _player.get_locomotion() == PlayerController.Locomotion.WALK
		await _release_and_step()
		var facing: PlayerController.Facing = _player.get_facing()
		_check("AC-07", walking and run.walk_ticks == 30, "%s must walk" % _names(case[0]))
		_check("AC-07", facing == case[1] and _player.get_locomotion() == PlayerController.Locomotion.IDLE,
			"%s stop keeps facing %s (got %s)" % [_names(case[0]), case[1], facing])
		_check("AC-07", _marker_matches(_player, case[1]), "%s marker direction" % _names(case[0]))
		_check("AC-07", shape_fixed[0], "visual changes must not move BodyCollision")
		_log("AC-07", "keys=%s facing=%s walk_ticks=%d body_bob_y=[%.2f..%.2f] shape_fixed=%s" % [
			_names(case[0]), PlayerController.Facing.find_key(facing), run.walk_ticks, body_y.min(), body_y.max(), shape_fixed[0]])
	_check("AC-07", is_equal_approx(body.position.y, PlayerVisual.BODY_CENTER.y), "idle resets bob")
	return true


func _marker_matches(player: PlayerController, facing: PlayerController.Facing) -> bool:
	var marker: Polygon2D = player.get_node("Visual/FacingMarker") as Polygon2D
	var offset: Vector2 = marker.position - PlayerVisual.BODY_CENTER
	var direction: Vector2 = {
		PlayerController.Facing.UP: Vector2.UP, PlayerController.Facing.DOWN: Vector2.DOWN,
		PlayerController.Facing.LEFT: Vector2.LEFT, PlayerController.Facing.RIGHT: Vector2.RIGHT,
	}[facing]
	return offset.normalized().is_equal_approx(direction) and Vector2.RIGHT.rotated(marker.rotation).is_equal_approx(direction)


# --- AC-08 / AC-09 ---------------------------------------------------------------

func _ac08_control_gate() -> bool:
	# Disable mid-move: velocity is zero immediately and the held key does nothing.
	await _drive(OPEN_START, [KEY_D], 20, false)
	_player.set_control_enabled(false)
	var immediate: bool = _player.velocity == Vector2.ZERO and _player.get_locomotion() == PlayerController.Locomotion.IDLE
	var blocked: Dictionary = await _continue(20)
	_check("AC-08", immediate and blocked.delta.length() <= 0.001, "disabled: immediate stop, moved %.4f" % blocked.delta.length())
	# Re-enable with the key still held: no movement until all actions are released once.
	_player.set_control_enabled(true)
	var held: Dictionary = await _continue(20)
	_check("AC-08", held.delta.length() <= 0.001 and not _player.is_control_effective(),
		"re-enabled with key held must not move (%.4f)" % held.delta.length())
	_release_all()
	await physics_frame
	_check("AC-08", _player.is_control_effective(), "one neutral tick reopens control")
	_press([KEY_D])
	var resumed: Dictionary = await _continue(20)
	_check("AC-08", absf(resumed.delta.x - 32.0) <= TOL, "new input moves after neutral (%.4f)" % resumed.delta.x)
	await _release_and_step()
	_log("AC-08", "disabled_move=%.4f held_after_enable_move=%.4f resumed_20_ticks=%.4f" % [
		blocked.delta.length(), held.delta.length(), resumed.delta.x])

	# Opposite keys cancel to a zero vector but are not "all released".
	await _place(OPEN_START)
	_player.set_control_enabled(false)
	_press([KEY_A, KEY_D])
	_player.set_control_enabled(true)
	var opposite: Dictionary = await _continue(10)
	_key(KEY_A, false)
	var one_left: Dictionary = await _continue(10)
	_check("AC-08", opposite.delta.length() <= 0.001 and one_left.delta.length() <= 0.001 and not _player.is_control_effective(),
		"opposite keys must keep neutral required (moved %.4f then %.4f)" % [opposite.delta.length(), one_left.delta.length()])
	_release_all()
	await physics_frame
	_press([KEY_D])
	var after_opposite: Dictionary = await _continue(10)
	await _release_and_step()
	_check("AC-08", absf(after_opposite.delta.x - 16.0) <= TOL, "moves after true neutral (%.4f)" % after_opposite.delta.x)
	_log("AC-08", "opposite_held_move=%.4f one_key_left_move=%.4f after_neutral_10_ticks=%.4f" % [
		opposite.delta.length(), one_left.delta.length(), after_opposite.delta.x])

	# A focused UI control consuming the key does not change polled Input state, so
	# only the gate stops movement. Headless DisplayServer does not dispatch parsed
	# events to the viewport, so the runner forwards the same event like a window would.
	await _place(OPEN_START)
	var field: LineEdit = LineEdit.new()
	_map.get_node("Instructions").add_child(field)
	field.grab_focus()
	await process_frame
	await physics_frame
	var event: InputEventKey = _key(KEY_D, true, true)
	root.push_input(event)
	var consumed: bool = root.is_input_handled() or field.text == "d"
	var polled: bool = Input.is_action_pressed(&"move_right")
	var ungated: Dictionary = await _continue(10)
	_player.set_control_enabled(false)
	var gated: Dictionary = await _continue(10)
	_release_all()
	_player.set_control_enabled(true)
	await physics_frame
	var typed: String = field.text
	field.queue_free()
	await process_frame
	_check("AC-08", consumed and polled, "UI consumed the key (text=%s) while Input still polls it pressed" % typed)
	_check("AC-08", absf(ungated.delta.x - 16.0) <= TOL and gated.delta.length() <= 0.001,
		"UI consumption alone does not stop polling (%.4f); the gate does (%.4f)" % [ungated.delta.x, gated.delta.length()])
	_log("AC-08", "ui_consumed=%s polled_pressed=%s move_without_gate=%.4f move_with_gate=%.4f" % [
		consumed, polled, ungated.delta.x, gated.delta.length()])
	return true


func _ac09_focus_notifications() -> bool:
	# Automated part only: the real app switch on a desktop is a manual GUI check.
	await _drive(OPEN_START, [KEY_D], 10, false)
	_player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var immediate: bool = _player.velocity == Vector2.ZERO
	var background: Dictionary = await _continue(20)
	_player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var returned_held: Dictionary = await _continue(20)
	_release_all()
	await physics_frame
	_press([KEY_D])
	var resumed: Dictionary = await _continue(10)
	await _release_and_step()
	_check("AC-09", immediate and background.delta.length() <= 0.001, "focus out stops (%.4f)" % background.delta.length())
	_check("AC-09", returned_held.delta.length() <= 0.001, "focus in with key held must not jump (%.4f)" % returned_held.delta.length())
	_check("AC-09", absf(resumed.delta.x - 16.0) <= TOL, "new input after focus return (%.4f)" % resumed.delta.x)
	_log("AC-09", "automated notification path: background_move=%.4f held_return_move=%.4f resumed=%.4f (GUI app switch: manual)" % [
		background.delta.length(), returned_held.delta.length(), resumed.delta.x])
	return true


# --- AC-10 -----------------------------------------------------------------------

func _ac10_camera() -> bool:
	var camera: Camera2D = _player.get_node("Camera2D") as Camera2D
	var viewport_size: Vector2 = root.get_visible_rect().size
	_check("AC-10", viewport_size == Vector2(640, 360), "logical viewport %s" % viewport_size)
	# The block occupies the map centre, so the interior check uses free floor.
	var points: Array = [[Vector2(400, 360), true], [Vector2(30, 30), false], [Vector2(1250, 30), false],
		[Vector2(30, 690), false], [Vector2(1250, 690), false], [Vector2(640, 30), false], [Vector2(30, 360), false]]
	for case: Array in points:
		await _place(case[0])
		await physics_frame
		var view: Rect2 = _view_rect()
		var centre: Vector2 = camera.get_screen_center_position()
		var inside: bool = WORLD.grow(TOL).encloses(view)
		_check("AC-10", inside and view.size.is_equal_approx(viewport_size), "view %s at %s" % [view, case[0]])
		_check("AC-10", centre.is_equal_approx(view.get_center()), "screen centre %s vs canvas %s" % [centre, view.get_center()])
		if case[1]:
			_check("AC-10", centre.distance_to(_player.global_position) <= TOL, "interior tracking %s vs %s" % [centre, _player.global_position])
		_log("AC-10", "player=%s view=%s centre=%s" % [_player.global_position, view, centre])
	# While walking in the interior the view centre equals the feet on every tick.
	var lag: Array[float] = [0.0]
	var track: Callable = func() -> void:
		lag[0] = maxf(lag[0], camera.get_screen_center_position().distance_to(_player.global_position))
	await _drive(Vector2(400, 360), [KEY_S, KEY_D], 60, true, track)
	await _release_and_step()
	_check("AC-10", lag[0] <= TOL, "per-tick camera lag %.4f" % lag[0])
	_log("AC-10", "interior walk per-tick max |centre-feet|=%.4f" % lag[0])
	return true


func _view_rect() -> Rect2:
	var inverse: Transform2D = root.get_canvas_transform().affine_inverse()
	return inverse * Rect2(Vector2.ZERO, root.get_visible_rect().size)


# --- harness ---------------------------------------------------------------------

func _load_map() -> void:
	_map = (load(MAP_SCENE) as PackedScene).instantiate() as Node2D
	root.add_child(_map)
	_player = _map.get_node("Player") as PlayerController
	_solids.clear()
	for body: Node in _map.get_node("WorldCollision").get_children():
		_solids.append(_static_rect(body as StaticBody2D))
	await physics_frame


func _unload_map() -> void:
	_release_all()
	_map.queue_free()
	_map = null
	_player = null
	await process_frame
	await physics_frame


## Resets one case: no input, control open, player on a free point, one settle tick.
func _place(position: Vector2) -> void:
	_release_all()
	_player.set_control_enabled(true)
	await physics_frame
	_player.global_position = position
	_player.velocity = Vector2.ZERO
	await physics_frame


## Holds keys for `ticks` controller updates. With `release`, keys are let go afterwards.
func _drive(start: Vector2, keys: Array, ticks: int, release: bool = true, sample: Callable = Callable()) -> Dictionary:
	await _place(start)
	_press(keys)
	var run: Dictionary = await _continue(ticks, sample)
	if release:
		_release_all()
	return run


func _continue(ticks: int, sample: Callable = Callable()) -> Dictionary:
	var start: Vector2 = _player.global_position
	var frame: int = Engine.get_physics_frames()
	var max_speed: float = 0.0
	var max_penetration: float = 0.0
	var walk_ticks: int = 0
	var idle_ticks: int = 0
	for i: int in ticks:
		await physics_frame
		max_speed = maxf(max_speed, _player.velocity.length())
		max_penetration = maxf(max_penetration, _penetration(_player.global_position))
		if _player.get_locomotion() == PlayerController.Locomotion.WALK:
			walk_ticks += 1
		else:
			idle_ticks += 1
		if sample.is_valid():
			sample.call()
	return {
		"delta": _player.global_position - start, "ticks": Engine.get_physics_frames() - frame,
		"max_speed": max_speed, "max_penetration": max_penetration,
		"walk_ticks": walk_ticks, "idle_ticks": idle_ticks,
	}


func _release_and_step() -> Dictionary:
	_release_all()
	var before: Vector2 = _player.global_position
	await physics_frame
	return {"velocity_zero": _player.velocity == Vector2.ZERO, "moved": _player.global_position.distance_to(before)}


## How deep the feet circle overlaps any solid; 0 when clear.
func _penetration(point: Vector2) -> float:
	var deepest: float = 0.0
	for rect: Rect2 in _solids:
		var closest: Vector2 = point.clamp(rect.position, rect.end)
		var depth: float = RADIUS - point.distance_to(closest)
		if rect.has_point(point):
			depth = RADIUS + minf(minf(point.x - rect.position.x, rect.end.x - point.x), minf(point.y - rect.position.y, rect.end.y - point.y))
		deepest = maxf(deepest, depth)
	return deepest


func _static_rect(body: StaticBody2D) -> Rect2:
	var size: Vector2 = ((body.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size
	return Rect2(body.global_position - size / 2.0, size)


func _key(code: Key, pressed: bool, typed: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	if typed:
		event.unicode = OS.get_keycode_string(code).to_lower().unicode_at(0)
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed and code not in _held:
		_held.append(code)
	elif not pressed:
		_held.erase(code)
	return event


func _press(keys: Array) -> void:
	for code: Key in keys:
		_key(code, true)


func _release_all() -> void:
	for code: Key in _held.duplicate():
		_key(code, false)


func _all_actions_released() -> bool:
	for action: StringName in ACTIONS:
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
	_check("AC-11", first.keys() == second.keys(), "both passes record the same measurements")
	var worst: float = 0.0
	for key: String in first:
		var a: Variant = first[key]
		var b: Variant = second.get(key)
		var difference: float = 0.0
		if a is Vector2:
			difference = (a as Vector2).distance_to(b as Vector2)
		elif a is float:
			difference = absf(float(a) - float(b))
		worst = maxf(worst, difference)
	_check("AC-11", worst <= TOL, "pass-to-pass difference %.6f" % worst)
	_log("AC-11", "passes=2 measurements=%d max_pass_difference=%.6f" % [first.size(), worst])


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
	print("IH-101 automated summary:")
	var keys: Array = _ac_checks.keys()
	keys.sort()
	for ac: String in keys:
		var counts: Array = _ac_checks[ac]
		print("  %s %s (%d checks, %d failed)" % [ac, "PASS" if counts[1] == 0 else "FAIL", counts[0], counts[1]])
	print("  Not covered here: AC-09 real app switch, AC-10 window resize/visual smoothness, AC-12 review.")
	if _failures.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		for failure: String in _failures:
			print("  FAILED " + failure)
		print("RESULT: FAIL (%d)" % _failures.size())
		quit(1)
