extends SceneTree
## Infrastructure smoke check only; no gameplay or persistent state changes.


func _initialize() -> void:
	var scene_path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		push_error("Cannot load the configured foundation scene: " + scene_path)
		quit(1)
		return
	var instance: Node = scene.instantiate()
	if instance == null:
		push_error("Cannot instantiate the configured foundation scene")
		quit(1)
		return
	if instance.name != &"Foundation" or instance.get_child_count() != 0:
		instance.free()
		push_error("Expected the empty Foundation baseline")
		quit(1)
		return
	instance.free()
	print("PASS: typed GDScript and Foundation PackedScene instantiation")
	quit(0)
