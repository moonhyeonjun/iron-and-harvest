extends SceneTree
## Child process for the IH-112 runner (AC-S13): a real, separate Godot process using the
## real SaveLoadTest scene and real files under a test-only root. The parent starts it and
## reads its result file; it never touches other processes or the product save root.
##   --root=user://tests/ih112/...  --out=<result file>  --mode=save|load|hang
##   --stage=<SaveStore stage> (hang): at that stage write <out>.ready and block until the
##   parent kills this process, so the kill lands exactly there.

const SCENE: String = "res://scenes/tests/save_load_test.tscn"

var _args: Dictionary = {}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			_args[argument.substr(2, argument.find("=") - 2)] = argument.substr(argument.find("=") + 1)
	_run()


func _run() -> void:
	var root_dir: String = String(_args.get("root", ""))
	if not root_dir.begins_with("user://tests/ih112/"):
		_finish({"code": "BAD_ROOT"})
		return
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	scene.set("save_root", root_dir)
	root.add_child(scene)
	await process_frame
	var coordinator: SaveCoordinator = scene.get("coordinator")
	match String(_args.get("mode", "")):
		"save", "hang":
			var world: Node = coordinator.get_world()
			var gather: GatherService = world.get("gather")
			var inventory: InventoryService = world.get("inventory")
			# A fixed piece of play through the services: two branches, one berry, 2 wood to the store.
			for point_id: String in ["branch_pile_01", "branch_pile_01", "berry_bush_01"]:
				var prepared: GatherService.Result = gather.prepare(point_id, "player_bag", 1)
				(prepared.value as GatherService.GatherCommand).commit()
			inventory.transfer("player_bag", 0, "test_store", 2, inventory.snapshot("player_bag").value.revision,
				inventory.snapshot("test_store").value.revision)
			if _args.get("mode") == "hang":
				var stage: String = String(_args.get("stage", ""))
				coordinator.get_store().stage_hook = func(at: String) -> void:
					if at == stage:
						var marker: FileAccess = FileAccess.open(String(_args.out) + ".ready", FileAccess.WRITE)
						marker.store_string(stage)
						marker.close()
						while true:
							OS.delay_msec(20)
			var saved: Dictionary = coordinator.request_save(coordinator.get_epoch())
			_finish({"code": String(saved.code), "generation": saved.generation, "world": _world_state(coordinator.get_world())})
		"load":
			var finished: Array = []
			coordinator.operation_finished.connect(func(result: Dictionary) -> void: finished.append(result))
			coordinator.request_load(coordinator.get_epoch())
			for i: int in 30:
				if not finished.is_empty():
					break
				await physics_frame
			var result: Dictionary = finished[0] if not finished.is_empty() else {"code": "TIMEOUT", "generation": 0}
			_finish({"code": String(result.code), "generation": result.generation, "world": _world_state(coordinator.get_world())})
		_:
			_finish({"code": "BAD_MODE"})


## Plain values only: position, facing, every inventory snapshot.
func _world_state(world: Node) -> Dictionary:
	var payload: Dictionary = world.call("capture_payload")
	return {"player": payload.player, "inventories": payload.inventories}


func _finish(result: Dictionary) -> void:
	var out: String = String(_args.get("out", ""))
	if out.begins_with("user://tests/ih112/"):
		var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "", true, true))
		file.close()
	for child: Node in root.get_children():
		child.queue_free()
	await process_frame
	quit(0 if result.get("code") == "OK" else 1)
