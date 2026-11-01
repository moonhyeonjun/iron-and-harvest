extends SceneTree
## Child process for the IH-120 runner (AC-C09): the real calendar_test scene and real
## files under user://tests/ih120/ only. --mode=save moves the default calendar two dawns
## and some ticks and saves; --mode=load stops time first and loads. The result file holds
## the calendar snapshot and the number of day boundaries seen in this process.

const SCENE: String = "res://scenes/tests/calendar_test.tscn"

var _args: Dictionary = {}


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			_args[argument.substr(2, argument.find("=") - 2)] = argument.substr(argument.find("=") + 1)
	_run()


func _run() -> void:
	var root_dir: String = String(_args.get("root", ""))
	if not root_dir.begins_with("user://tests/ih120/"):
		_finish({"code": "BAD_ROOT"})
		return
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	scene.set("save_root", root_dir)
	scene.set("calendar_rule_id", "calendar_test_v1")
	root.add_child(scene)
	await process_frame
	for i: int in 3:
		await physics_frame
	var controller: CalendarController = scene.get_node("CalendarController")
	var coordinator: SaveCoordinator = scene.get("save_load").get("coordinator")
	var boundaries: Array = []
	controller.day_boundary.connect(func(event: Dictionary) -> void: boundaries.append(event))
	var calendar: Callable = func() -> Dictionary: return (coordinator.get_world().get("calendar") as CalendarService).get_snapshot().value
	match String(_args.get("mode", "")):
		"save":
			for i: int in 2:
				controller.request_next_day(coordinator.get_epoch(), calendar.call().revision)
				await physics_frame
				await physics_frame
			for i: int in 20:
				await physics_frame
			controller.request_toggle_pause(coordinator.get_epoch())
			await physics_frame
			var saved: Dictionary = coordinator.request_save(coordinator.get_epoch())
			_finish({"code": String(saved.code), "calendar": calendar.call(), "boundaries": boundaries.size()})
		"load":
			controller.request_toggle_pause(coordinator.get_epoch())
			await physics_frame
			var mark: Array = []
			coordinator.operation_finished.connect(func(result: Dictionary) -> void: mark.append(result))
			var before: int = boundaries.size()
			coordinator.request_load(coordinator.get_epoch())
			for i: int in 20:
				if not mark.is_empty():
					break
				await physics_frame
			for i: int in 3:
				await physics_frame
			var code: String = String(mark[0].code) if not mark.is_empty() else "TIMEOUT"
			_finish({"code": code, "calendar": calendar.call(), "boundaries": boundaries.size() - before})
		_:
			_finish({"code": "BAD_MODE"})


func _finish(result: Dictionary) -> void:
	var out: String = String(_args.get("out", ""))
	if out.begins_with("user://tests/ih120/"):
		var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "", true, true))
		file.close()
	for child: Node in root.get_children():
		child.queue_free()
	await process_frame
	quit(0 if result.get("code") == "OK" else 1)
