extends Node
## IH-120 verification scene. It reuses the IH-112 SaveLoadTest (world in SessionHost,
## SaveCoordinator and SaveUI outside it) and adds, also outside the world, the only
## CalendarController that lets time flow, and the CalendarHUD. Saves go to
## user://tests/ih120/ only. Default profile calendar_test_v1 at normal speed;
## --fixture=calendar-boundary picks the fast profile and its own root.
## Options: --save-root=user://tests/ih120/<name>, --fixture=calendar-boundary.

const DEFAULT_ROOT: String = "user://tests/ih120/gui"
const BOUNDARY_ROOT: String = "user://tests/ih120/gui_boundary"
const ROOT_PREFIX: String = "user://tests/ih120/"
const DEFAULT_RULE: String = "calendar_test_v1"
const BOUNDARY_RULE: String = "calendar_boundary_fixture_v1"

## Tests set these before the scene enters the tree.
var save_root: String = ""
var calendar_rule_id: String = ""
var setup_error: String = ""

@onready var save_load: Node = $SaveLoad
@onready var controller: CalendarController = $CalendarController
@onready var hud: CalendarHUD = $CalendarHUD


## The wrapped SaveLoadTest reads its root and profile in its own _ready, which runs before
## ours: they are set here, while the children are not ready yet.
func _enter_tree() -> void:
	var fixture: String = ""
	var cli_root: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture="):
			fixture = argument.trim_prefix("--fixture=")
		elif argument.begins_with("--save-root="):
			cli_root = argument.trim_prefix("--save-root=")
	if calendar_rule_id.is_empty():
		calendar_rule_id = BOUNDARY_RULE if fixture == "calendar-boundary" else DEFAULT_RULE
	if save_root.is_empty():
		save_root = cli_root if not cli_root.is_empty() else (BOUNDARY_ROOT if fixture == "calendar-boundary" else DEFAULT_ROOT)
	if not save_root.begins_with(ROOT_PREFIX) or save_root.contains(".."):
		setup_error = "save root must be under %s" % ROOT_PREFIX
		save_root = DEFAULT_ROOT
	var wrapped: Node = get_node("SaveLoad")
	wrapped.set("save_root", save_root)
	wrapped.set("calendar_rule_id", calendar_rule_id)


func _ready() -> void:
	get_window().title = "IH-120 calendar test (%s)" % calendar_rule_id
	var coordinator: SaveCoordinator = save_load.get("coordinator")
	controller.setup(coordinator)
	coordinator.set_external_blocker(controller.save_blocker)
	hud.pause_requested.connect(func(epoch: int) -> void: controller.request_toggle_pause(epoch))
	hud.next_day_requested.connect(func(epoch: int, revision: int) -> void: controller.request_next_day(epoch, revision))
	controller.state_changed.connect(func(view: Dictionary) -> void:
		if _hud_usable():
			hud.show_view(view))
	controller.command_finished.connect(func(result: Dictionary) -> void:
		if _hud_usable():
			hud.show_result(result))
	controller.day_boundary.connect(func(event: Dictionary) -> void:
		print("IH-120 day boundary: completed #%d -> #%d %s/%s revision %d" % [event.completed_day_index, event.to_day_index,
			event.to_season_id, event.to_year, event.revision])
		if _hud_usable():
			hud.show_boundary(event))
	if _hud_usable():
		hud.show_info("프로필 %s · 저장 %s%s\n하루는 06:00에 바뀝니다(자정은 같은 날)" % [calendar_rule_id, save_root,
			" (" + setup_error + ")" if not setup_error.is_empty() else ""])


## The HUD is display only: a freed, detached or deleting HUD is skipped; keys and time go on.
func _hud_usable() -> bool:
	return is_instance_valid(hud) and hud.is_inside_tree() and not hud.is_queued_for_deletion()
