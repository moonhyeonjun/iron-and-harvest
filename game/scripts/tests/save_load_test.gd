extends Node
## IH-112 verification scene: SessionHost holds the replaceable world (the IH-111 gathering
## map), SaveCoordinator and SaveUI live outside it and survive every load. It starts a new
## normal-fixture game; nothing is loaded automatically. Saves go only to the test-only
## root under user://tests/ih112/ (never the product user://saves). F5 saves, F9 loads the
## newest generation; the previous generation is loaded only with the explicit button.
## The keys work without SaveUI (results are then only printed); buttons need the UI.
## Options: --save-root=user://tests/ih112/<name>, --fixture=corrupt-latest (test fixture:
## damages the newest bank before start so the recovery path can be tried by hand).

const WORLD_SCENE: PackedScene = preload("res://scenes/tests/gathering_test.tscn")
const GatheringMap: Script = preload("res://scripts/tests/gathering_test.gd")
const TEST_ROOT_PREFIX: String = "user://tests/ih112/"
const DEFAULT_ROOT: String = "user://tests/ih112/gui"

## Tests set it before the scene enters the tree; must be under TEST_ROOT_PREFIX.
var save_root: String = ""
var store: SaveStore
var setup_error: String = ""
var _last_key_frame: int = -1

@onready var host: Node2D = $SessionHost
@onready var coordinator: SaveCoordinator = $SaveCoordinator
@onready var ui: SaveUI = $SaveUI


func _ready() -> void:
	var fixture: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--save-root=") and save_root.is_empty():
			save_root = argument.trim_prefix("--save-root=")
		elif argument.begins_with("--fixture="):
			fixture = argument.trim_prefix("--fixture=")
	if save_root.is_empty():
		save_root = DEFAULT_ROOT
	if not save_root.begins_with(TEST_ROOT_PREFIX) or save_root.contains(".."):
		setup_error = "save root must be under %s" % TEST_ROOT_PREFIX
		save_root = DEFAULT_ROOT
	# The fixture is named in the title and the panel so manual windows can be told apart.
	get_window().title = "IH-112 save/load test%s" % (" (corrupt-latest)" if fixture == "corrupt-latest" else "")
	store = SaveStore.new(save_root, GatheringMap.save_manifest())
	var fixture_note: String = ""
	if fixture == "corrupt-latest":
		fixture_note = corrupt_latest_bank()
		print("IH-112 fixture: ", fixture_note)
	var world: Node = WORLD_SCENE.instantiate()
	world.set("owns_window_title", false)
	host.add_child(world)
	coordinator.setup(host, world, WORLD_SCENE, store, GatheringMap.restore_session)
	ui.save_requested.connect(func(epoch: int) -> void: coordinator.request_save(epoch))
	ui.load_requested.connect(func(epoch: int, source: StringName) -> void: coordinator.request_load(epoch, source))
	coordinator.operation_finished.connect(_on_finished)
	ui.show_root("시험 저장 루트: %s%s%s" % [save_root, " (" + setup_error + ")" if not setup_error.is_empty() else "",
		"\n시험 fixture: " + fixture_note if not fixture_note.is_empty() else ""])
	refresh_slot()


## F5/F9: a new press only (echo ignored), at most one request per frame.
func _unhandled_input(event: InputEvent) -> void:
	var save: bool = event.is_action_pressed(&"save_game", false)
	var load: bool = event.is_action_pressed(&"load_game", false)
	if not save and not load:
		return
	get_viewport().set_input_as_handled()
	if Engine.get_process_frames() == _last_key_frame:
		return
	# Keys are live input, not an intent shown on the panel (BUG-009): they use the
	# coordinator's current epoch, so F5/F9 keep working when SaveUI is freed, queued for
	# deletion or detached; only the display is skipped. Without a coordinator in the tree
	# the key does nothing (no file is touched).
	if not is_instance_valid(coordinator) or not coordinator.is_inside_tree() or coordinator.is_queued_for_deletion():
		return
	_last_key_frame = Engine.get_process_frames()
	if save:
		coordinator.request_save(coordinator.get_epoch())
	else:
		coordinator.request_load(coordinator.get_epoch())


func refresh_slot() -> void:
	var status: Dictionary = store.inspect()
	var summary: Dictionary = {"code": status.code}
	if not String(status.latest).is_empty():
		summary["latest_generation"] = status.banks[status.latest].generation
	if not String(status.recovery).is_empty():
		summary["recovery_generation"] = status.banks[status.recovery].generation
	if is_instance_valid(ui) and ui.is_inside_tree():
		ui.show_slot(summary)


## Test fixture only (GUI step 4): flips one checksum character of the newest bank so it
## reads as damaged. Never used by the save code; works only inside the test root.
func corrupt_latest_bank() -> String:
	var status: Dictionary = store.inspect()
	if String(status.latest).is_empty():
		return "no newest bank to damage (%s)" % status.code
	var path: String = store.bank_path(status.latest)
	var text: String = FileAccess.get_file_as_string(path)
	var at: int = text.find("\"sha256\":\"") + 10
	var flipped: String = "0" if text[at] != "0" else "1"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text.substr(0, at) + flipped + text.substr(at + 1))
	file.close()
	return "damaged generation %d in bank %s" % [status.banks[status.latest].generation, status.latest]


func _on_finished(result: Dictionary) -> void:
	# The UI is display only: a missing UI skips display, the result stands.
	if is_instance_valid(ui) and ui.is_inside_tree() and not ui.is_queued_for_deletion():
		ui.set_epoch(coordinator.get_epoch())
		ui.show_result(result)
	print("IH-112 %s: %s gen=%d bank=%s recovered=%s %s" % [result.kind, result.code, result.generation, result.bank,
		result.recovered, result.detail])
	refresh_slot.call_deferred()
