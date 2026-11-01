class_name SaveCoordinator
extends Node
## Runs one save or load at a time for the session in a host node (IH-112). It lives outside
## the world it replaces, together with the save UI.
##
## Save: refused (BUSY) unless the world is quiescent; nothing is cancelled or closed to make
## it so. The world is captured synchronously, then SaveStore writes the next generation.
## The rename is the commit; whatever happens to UI, focus or host after it never undoes or
## repeats the save.
##
## Load: the current world is suspended (every node with an explicit process mode as well,
## the player's included, so nothing processes or reads input) without touching the
## movement gate or any panel. The file is read and verified, GatherService.restore builds
## new services with no grant, and a candidate map boots inactive and hidden next to the
## suspended one. After a physics step the saved feet position is checked against the
## candidate's real walls. Only then is it published: epoch + 1, the reference swapped,
## the old world detached (its services close), the candidate shown and activated. Any
## failure before publish discards the candidate and resumes the old world unchanged.
## Staging advances in _physics_process, not with await, so freeing the host or this node
## can never resume work on a dead world.

signal operation_finished(result: Dictionary)

enum State { IDLE, CAPTURING, WRITING, READING, VALIDATING, STAGING, PUBLISHING }

const OK: StringName = &"OK"
const BUSY: StringName = &"BUSY"
const STALE_SESSION: StringName = &"STALE_SESSION"
const CANCELLED: StringName = &"CANCELLED"
const REMOVED: StringName = &"REMOVED"
const FOCUS_LOST: StringName = &"FOCUS_LOST"
const NOT_READY: StringName = &"NOT_READY"
const INVALID_POSITION: StringName = &"INVALID_POSITION"
const BOOTSTRAP_FAILED: StringName = &"BOOTSTRAP_FAILED"
const WORLD_COLLISION_PATH: NodePath = ^"Interaction/World/WorldCollision"
const PLAYER_PATH: NodePath = ^"Interaction/World/Player"
const CAMERA_PATH: NodePath = ^"Interaction/World/Player/Camera2D"

## Tests only: called with "candidate_added", "position_checked" and "before_publish"
## during a load, to inject failures at exact stages.
var stage_hook: Callable = Callable()

var _host: Node
var _world: Node
var _world_scene: PackedScene
var _store: SaveStore
var _restorer: Callable
var _state: State = State.IDLE
var _operation_id: int = 0
var _epoch: int = 1
## First reason the running operation must not commit (focus out, removal, cancel).
var _cancel: StringName = &""
var _window_focused: bool = true
var _world_modes: Dictionary = {}
var _load: Dictionary = {}
## True while a result is being reported: a request made from a listener is refused and
## only returned, never reported again (no recursion through the signal).
var _emitting: bool = false


## host: parent of the world; world: the current map; world_scene: map to stage on load;
## restorer: payload -> {"ok", "context"|"detail"} building a candidate's services.
func setup(host: Node, world: Node, world_scene: PackedScene, store: SaveStore, restorer: Callable) -> void:
	_host = host
	_world = world
	_world_scene = world_scene
	_store = store
	_restorer = restorer
	_store.commit_guard = _commit_guard


func get_world() -> Node:
	return _world


func get_epoch() -> int:
	return _epoch


func get_state() -> State:
	return _state


func is_busy() -> bool:
	return _state != State.IDLE


func get_store() -> SaveStore:
	return _store


## Synchronous: returns (and emits) the result. `epoch` is the one the requesting UI saw.
func request_save(epoch: int) -> Dictionary:
	var blocker: StringName = _request_blocker(epoch)
	if blocker != OK:
		return _reject("save", blocker)
	_operation_id += 1
	_cancel = &""
	_state = State.CAPTURING
	var payload: Dictionary = _world.capture_payload()
	_state = State.WRITING
	var saved: SaveStore.Result = _store.save_slot(payload)
	var result: Dictionary = _result("save", saved.code, saved.detail)
	result.cause = saved.cause
	result.committed = saved.committed
	result.generation = saved.generation
	result.bank = saved.source_bank
	result.warning = saved.warning
	_emit_and_idle(result)
	return result


## Starts a load and returns OK, or refuses at once (the refusal is emitted as well).
## The outcome arrives with operation_finished.
func request_load(epoch: int, source: StringName = SaveStore.SOURCE_LATEST) -> StringName:
	var blocker: StringName = _request_blocker(epoch)
	if blocker != OK:
		_reject("load", blocker)
		return blocker
	_operation_id += 1
	_cancel = &""
	_state = State.READING
	_world_modes = _suspend(_world, true)
	var read: SaveStore.Result = _store.load_slot(source)
	if not read.ok:
		_fail_load(read.code, read.detail, read.cause)
		return OK
	_state = State.VALIDATING
	var restored: Dictionary = _restorer.call(read.payload)
	if not restored.get("ok", false):
		_fail_load(SaveCodec.INVALID_SAVE, String(restored.get("detail", "restore failed")))
		return OK
	_state = State.STAGING
	var candidate: Node = _world_scene.instantiate()
	_load = {"operation_id": _operation_id, "candidate": candidate, "context": restored.context, "read": read,
		"modes": _suspend(candidate, false), "hidden": _hide_layers(candidate), "frame": 0}
	candidate.set("restore_context", restored.context)
	candidate.set("start_inactive", true)
	candidate.set("owns_window_title", false)
	var camera: Camera2D = candidate.get_node_or_null(CAMERA_PATH) as Camera2D
	_load["camera_enabled"] = camera != null and camera.enabled
	if camera != null:
		camera.enabled = false
	# Only the candidate's walls take part in physics while staged: the position check.
	var walls: Node = candidate.get_node_or_null(WORLD_COLLISION_PATH)
	if walls != null:
		walls.process_mode = Node.PROCESS_MODE_ALWAYS
	_host.add_child(candidate)
	_load.frame = Engine.get_physics_frames()
	_stage("candidate_added")
	if not _load.is_empty():
		var errors: PackedStringArray = candidate.get("setup_errors")
		if not errors.is_empty():
			_fail_load(BOOTSTRAP_FAILED, "\n".join(errors))
	return OK


func _physics_process(_delta: float) -> void:
	if _state != State.STAGING or _load.is_empty():
		return
	# One physics step after the candidate entered the tree, its walls are in the space.
	if Engine.get_physics_frames() <= int(_load.frame):
		return
	var blocker: StringName = _staging_blocker()
	if blocker != OK:
		_fail_load(blocker, "before position check")
		return
	var problem: String = _position_problem(_load.candidate)
	if not problem.is_empty():
		_fail_load(INVALID_POSITION, problem)
		return
	_stage("position_checked")
	if _load.is_empty():
		return
	_stage("before_publish")
	if _load.is_empty():
		return
	blocker = _staging_blocker()
	if blocker != OK:
		_fail_load(blocker, "before publish")
		return
	_publish()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false
		# A running operation keeps this latch even if focus comes back: no auto resume.
		if _state != State.IDLE and _cancel.is_empty():
			_cancel = FOCUS_LOST
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_focused = true


func _exit_tree() -> void:
	if _state != State.IDLE and _cancel.is_empty():
		_cancel = REMOVED
	if not _load.is_empty():
		_fail_load(REMOVED, "coordinator removed")


## Publish: no await and no signal of ours until the swap is complete.
func _publish() -> void:
	_state = State.PUBLISHING
	var candidate: Node = _load.candidate as Node
	var read: SaveStore.Result = _load.read
	var old: Variant = _world
	_epoch += 1
	_world = candidate
	_world_modes = {}
	if is_instance_valid(old):
		# Leaving the tree closes the old session's services; its panels and commands are gone.
		(old as Node).get_parent().remove_child(old)
		(old as Node).queue_free()
	_resume(_load.modes)
	_show_layers(_load.hidden)
	var walls: Node = candidate.get_node_or_null(WORLD_COLLISION_PATH)
	if walls != null:
		walls.process_mode = Node.PROCESS_MODE_INHERIT
	var camera: Camera2D = candidate.get_node_or_null(CAMERA_PATH) as Camera2D
	if camera != null and _load.camera_enabled:
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()
	_load = {}
	candidate.call("activate")
	var result: Dictionary = _result("load", OK, "")
	result.generation = read.generation
	result.bank = read.source_bank
	result.recovered = read.recovered
	result.migrated_from = read.migrated_from
	_emit_and_idle(result)


## Before publish: drop the candidate (its services close as it leaves the tree) and give
## the suspended world back exactly as it was, unless the host itself is gone.
func _fail_load(code: StringName, detail: String, cause: StringName = &"") -> void:
	if not _load.is_empty():
		# Untyped: the candidate may already be freed (host freed, queue_free) by now.
		var candidate: Variant = _load.candidate
		var context: Dictionary = _load.context
		_load = {}
		if is_instance_valid(candidate):
			if (candidate as Node).is_inside_tree():
				(candidate as Node).get_parent().remove_child(candidate)
			(candidate as Node).free()
		for key: String in ["gather", "inventory"]:
			var service: RefCounted = context.get(key)
			if service != null:
				service.call("close")
	if _host_alive() and is_instance_valid(_world):
		_resume(_world_modes)
	_world_modes = {}
	var result: Dictionary = _result("load", code, detail)
	result.cause = cause if not cause.is_empty() else code
	_emit_and_idle(result)


func _request_blocker(epoch: int) -> StringName:
	if _state != State.IDLE:
		return BUSY
	if epoch != _epoch:
		return STALE_SESSION
	if not is_inside_tree() or is_queued_for_deletion() or not _host_alive() or not is_instance_valid(_world) \
			or not _world.is_inside_tree() or _world.is_queued_for_deletion():
		return REMOVED
	if not _window_focused:
		return FOCUS_LOST
	var world_blocker: StringName = _world.call("save_blocker")
	return world_blocker if not world_blocker.is_empty() else OK


func _staging_blocker() -> StringName:
	if not _cancel.is_empty():
		return _cancel
	if not is_inside_tree() or is_queued_for_deletion():
		return REMOVED
	if int(_load.operation_id) != _operation_id:
		return CANCELLED
	if not _window_focused:
		return FOCUS_LOST
	var candidate: Variant = _load.candidate
	if not _host_alive() or not is_instance_valid(_world) or not _world.is_inside_tree() \
			or not is_instance_valid(candidate) or not (candidate as Node).is_inside_tree() \
			or (candidate as Node).is_queued_for_deletion():
		return REMOVED
	var errors: PackedStringArray = (candidate as Node).get("setup_errors")
	return BOOTSTRAP_FAILED if not errors.is_empty() else OK


## The saved feet position against the candidate's own walls (mask 1, bodies only) with the
## player's real foot shape. Inside the map bounds is not enough; a wall overlap is refused
## and nothing is moved to a "safe" spot.
func _position_problem(candidate: Node) -> String:
	var player: CharacterBody2D = candidate.get_node_or_null(PLAYER_PATH) as CharacterBody2D
	var feet: CollisionShape2D = player.get_node_or_null(^"BodyCollision") as CollisionShape2D if player != null else null
	if feet == null or feet.shape == null:
		return "candidate has no player foot shape"
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = feet.shape
	query.transform = Transform2D(0.0, player.global_position)
	query.collision_mask = player.collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var hits: Array[Dictionary] = player.get_world_2d().direct_space_state.intersect_shape(query, 1)
	if hits.is_empty():
		return ""
	var collider: Object = hits[0].get("collider")
	return "feet at %s overlap %s" % [player.global_position, (collider as Node).name if collider is Node else "a wall"]


func _commit_guard() -> StringName:
	if not _cancel.is_empty():
		return _cancel
	if not _host_alive():
		return REMOVED
	return &""


func _host_alive() -> bool:
	return is_instance_valid(_host) and _host.is_inside_tree() and not _host.is_queued_for_deletion()


## Disables `root` and every descendant with an explicit (non-inherited) process mode, and
## returns what to restore. No movement gate, panel or interaction state is touched.
## keep_physics (the live world): its bodies and areas stay in the physics space while it
## is suspended, so a world that is given back finds its overlaps exactly as before
## (measured: removing and re-adding the areas left no target selected for one step).
## A staged candidate is not kept: only its walls are enabled, for the position check.
func _suspend(root: Node, keep_physics: bool) -> Dictionary:
	var modes: Dictionary = {"process": {}, "physics": {}}
	if not is_instance_valid(root):
		return modes
	var nodes: Array[Node] = root.find_children("*", "", true, false)
	# Physics first: disabling a parent (the player) would otherwise remove its children's
	# areas before they are marked to stay.
	if keep_physics:
		for node: Node in nodes:
			if node is CollisionObject2D:
				modes.physics[node] = (node as CollisionObject2D).disable_mode
				(node as CollisionObject2D).disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	for node: Node in nodes:
		if node.process_mode != Node.PROCESS_MODE_INHERIT:
			modes.process[node] = node.process_mode
			node.process_mode = Node.PROCESS_MODE_DISABLED
	modes.process[root] = root.process_mode
	root.process_mode = Node.PROCESS_MODE_DISABLED
	return modes


func _resume(modes: Dictionary) -> void:
	for node: Variant in modes.get("process", {}):
		if is_instance_valid(node):
			(node as Node).process_mode = modes.process[node]
	for node: Variant in modes.get("physics", {}):
		if is_instance_valid(node):
			(node as CollisionObject2D).disable_mode = modes.physics[node]


func _hide_layers(root: Node) -> Array:
	var hidden: Array = []
	for node: Node in root.find_children("*", "CanvasLayer", true, false):
		var layer: CanvasLayer = node as CanvasLayer
		if layer.visible:
			layer.visible = false
			hidden.append(layer)
	return hidden


func _show_layers(layers: Array) -> void:
	for layer: Variant in layers:
		if is_instance_valid(layer):
			(layer as CanvasLayer).visible = true


func _stage(stage: String) -> void:
	if stage_hook.is_valid():
		stage_hook.call(stage)


func _reject(kind: String, code: StringName) -> Dictionary:
	var result: Dictionary = _result(kind, code, "refused before start")
	result.operation_id = 0
	if not _emitting:
		_emitting = true
		operation_finished.emit(result)
		_emitting = false
	return result


func _result(kind: String, code: StringName, detail: String) -> Dictionary:
	return {"kind": kind, "operation_id": _operation_id, "ok": code == OK, "code": code, "cause": code,
		"detail": detail, "generation": 0, "bank": "", "recovered": false, "committed": false,
		"migrated_from": -1, "warning": "", "epoch": _epoch}


## The result is reported while still busy, so a request made from a listener is BUSY.
func _emit_and_idle(result: Dictionary) -> void:
	result.epoch = _epoch
	var outer: bool = _emitting
	_emitting = true
	operation_finished.emit(result)
	_emitting = outer
	_state = State.IDLE
	_cancel = &""
