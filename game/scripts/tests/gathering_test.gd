extends Node2D
## IH-111 verification map. Owns the single session: one InventoryService (bag, test store
## and every point's hidden stock) and one GatherService. Interaction stays disabled until
## every target ID, point binding and inventory is verified and registered together; a
## failure leaves no partially playable world. Fixtures: normal, --fixture=full, --fixture=rebind.
## Quantities and positions are verification fixtures, not balance.

const ITEM_CATALOG: ItemCatalog = preload("res://data/items/catalog.tres")
const GATHER_CATALOG: GatherCatalog = preload("res://data/gathering/gather_catalog.tres")
const POINTS_SCENE: PackedScene = preload("res://scenes/gathering/gathering_points.tscn")
const MAP_ID: String = "gathering_test"
const BAG_ID: StringName = &"player_bag"
const STORE_ID: StringName = &"test_store"
const BINDINGS: Array = [
	{"point_id": "branch_pile_01", "map_id": MAP_ID, "definition_id": "gather_branches", "stock_inventory_id": "stock_branch_01"},
	{"point_id": "stone_pile_01", "map_id": MAP_ID, "definition_id": "gather_stones", "stock_inventory_id": "stock_stone_01"},
	{"point_id": "berry_bush_01", "map_id": MAP_ID, "definition_id": "gather_berries", "stock_inventory_id": "stock_berry_01"},
]
const TOTAL_ITEMS: Array[StringName] = [&"wood", &"stone", &"berry", &"tool_axe"]
const MESSAGES: Dictionary = {
	&"NO_SPACE": "가방이 가득 찼습니다.",
	&"STALE_REVISION": "상태가 바뀌었습니다. 다시 시도하세요.",
	&"DEPLETED": "더 이상 남은 것이 없습니다.",
	&"INVALID_STOCK": "이 지점은 지금 사용할 수 없습니다.",
	&"BUSY": "처리 중입니다. 다시 시도하세요.",
}

## Display names of PlayerController.Facing, as written in save files (IH-112).
const FACING_NAMES: Dictionary = {
	PlayerController.Facing.UP: "up", PlayerController.Facing.DOWN: "down",
	PlayerController.Facing.LEFT: "left", PlayerController.Facing.RIGHT: "right",
}
const MAP_BOUNDS: Rect2 = Rect2(0, 0, 1280, 720)
const PLAYER_ID: String = "player_01"
const STORE_OWNER: String = "fixture_store_01"
const BUSY_REASON: StringName = &"BUSY"
const NOT_READY: StringName = &"NOT_READY"
## IH-120: every session owns a calendar. This map only creates, saves and restores it
## (passive: nothing ticks it here); a CalendarController outside the world drives time.
const CALENDAR_RULES_PATH: String = "res://data/calendar/calendar_rules.json"
const DEFAULT_CALENDAR_RULE: String = "calendar_test_v1"
const TRUSTED_CALENDAR_RULES: Array = ["calendar_test_v1", "calendar_boundary_fixture_v1"]

## "normal", "full" or "rebind". Tests may set it before the map enters the tree.
var fixture: String = ""
## IH-112 RESTORE boot, injected before the map enters the tree: {"inventory", "gather"}
## from GatherService.restore plus the saved "position" (Vector2) and "facing". When set,
## nothing is built or granted; the map adopts these services as they are.
var restore_context: Dictionary = {}
## True while staged as a load candidate: interaction stays off until activate().
var start_inactive: bool = false
## Only a map that is the whole scene names the window; a hosted map leaves it alone.
var owns_window_title: bool = true
## Calendar profile of a NEW game (a restore takes the saved, verified profile).
var calendar_rule_id: String = DEFAULT_CALENDAR_RULE
var calendar: CalendarService
var inventory: InventoryService
var gather: GatherService
var setup_errors: PackedStringArray = []
var points: Node2D
## Filled by the rebind fixture: point values before and after the one view swap.
var rebind_report: Dictionary = {}

@onready var player: PlayerController = $Interaction/World/Player
@onready var interaction: InteractionController = $Interaction/World/Player/InteractionController
@onready var controller: InventoryController = $InventoryController
@onready var ui: InventoryUI = $InventoryUI
@onready var hud: GatheringHUD = $GatheringHUD


func _ready() -> void:
	interaction.set_interaction_enabled(false)
	if not restore_context.is_empty():
		# Shown instead of an initial fixture name, so restored data is never read as one.
		fixture = "저장 복원"
	elif fixture.is_empty():
		fixture = "normal"
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--fixture="):
				fixture = argument.trim_prefix("--fixture=")
	if owns_window_title:
		get_window().title = "IH-111 gathering test (%s)" % fixture
	points = $GatheringPoints
	var errors: PackedStringArray = _audit_targets()
	if not restore_context.is_empty():
		inventory = restore_context.get("inventory")
		gather = restore_context.get("gather")
		calendar = restore_context.get("calendar")
		if inventory == null or gather == null or calendar == null or inventory.is_closed() or gather.is_closed() \
				or calendar.is_closed():
			errors.append("restore context has no open services")
		elif errors.is_empty():
			player.restore_state(restore_context.position, restore_context.facing)
	elif errors.is_empty():
		var built: GatherService.Result = GatherService.build(ITEM_CATALOG, GATHER_CATALOG,
			[_bag_snapshot(), _store_snapshot()], BAG_ID, BINDINGS)
		if built.ok:
			inventory = built.value.inventory
			gather = built.value.gather
		else:
			errors.append(built.detail)
		var profile: Dictionary = calendar_profile(calendar_rule_id)
		var created: CalendarService.Result = CalendarService.create(profile) if not profile.is_empty() else null
		if created != null and created.ok:
			calendar = created.value
		else:
			errors.append("calendar profile '%s' unavailable" % calendar_rule_id)
	if not errors.is_empty():
		setup_errors = errors
		if _hud_usable():
			hud.show_error("시험 맵 구성 오류: 상호작용을 막았습니다.\n" + "\n".join(errors))
		return
	_bind_points()
	controller.setup(inventory, player, interaction, ui, BAG_ID, STORE_ID)
	# A staged candidate refuses session commands until it is published (BUG-011).
	set_session_suspended(start_inactive)
	($FixtureHud/StoreButton as Button).pressed.connect(func() -> void:
		controller.request_open(InventoryController.View.STORE))
	interaction.instant_completed.connect(_on_gathered)
	interaction.request_rejected.connect(_on_rejected)
	inventory.inventories_changed.connect(func(_ids: Array[StringName], _revisions: Dictionary) -> void:
		_update_hud(), CONNECT_DEFERRED)
	_update_hud()
	if not start_inactive:
		activate()


## Turns interaction on for a verified session. A staged load candidate stays inactive
## until the coordinator publishes it (IH-112).
func activate() -> void:
	start_inactive = false
	set_session_suspended(false)
	if setup_errors.is_empty() and gather != null and not gather.is_closed():
		interaction.set_interaction_enabled(true)


## Save/load suspension of this session's command entries (IH-112 BUG-011). Interaction
## input already stops with process_mode and its public calls are no-ops while quiescent;
## the inventory panel is the entry that direct/deferred calls can still reach.
func set_session_suspended(suspended: bool) -> void:
	if is_instance_valid(controller):
		controller.set_session_suspended(suspended)
	if calendar != null:
		calendar.set_session_suspended(suspended)


func _exit_tree() -> void:
	if gather != null:
		gather.close()
	if inventory != null:
		inventory.close()
	if calendar != null:
		calendar.close()


# --- IH-112 save/load hooks ------------------------------------------------------------

## Why this world cannot be saved or replaced right now, or &"" when it is quiescent:
## no open panel, no queued/running interaction, no prepared or running gather and no
## inventory commit. Nothing is cancelled or closed to make it quiescent.
func save_blocker() -> StringName:
	if not setup_errors.is_empty() or inventory == null or gather == null or calendar == null:
		return NOT_READY
	if inventory.is_closed() or gather.is_closed() or calendar.is_closed() or not is_inside_tree() or is_queued_for_deletion():
		return NOT_READY
	if controller.get_state() != InventoryController.State.CLOSED or not interaction.is_quiescent() \
			or inventory.is_busy() or gather.is_busy() or gather.has_pending_command() or calendar.is_busy():
		return BUSY_REASON
	return &""


## The world to save, captured synchronously (no await, no signal): player position and
## facing, every inventory of the session (bag, store, each hidden stock) and the point
## bindings. remaining/depleted are not stored; they are derived from the stocks.
func capture_payload() -> Dictionary:
	var inventories: Array = []
	var ids: Array = [String(BAG_ID), String(STORE_ID)]
	for binding: Dictionary in gather.export_bindings():
		ids.append(binding.stock_inventory_id)
	ids.sort()
	for inventory_id: String in ids:
		inventories.append(inventory.snapshot(inventory_id).value)
	return {
		"map_id": MAP_ID,
		"player": {"player_id": PLAYER_ID, "inventory_id": String(BAG_ID),
			"position": {"x": player.global_position.x, "y": player.global_position.y},
			"facing": FACING_NAMES[player.get_facing()]},
		"inventories": inventories,
		"points": gather.export_bindings(),
		"calendar": calendar.get_snapshot().value,
	}


## Trusted calendar profiles, read and verified once (the file is the single source).
static func calendar_rules() -> CalendarRules.Result:
	return CalendarRules.parse(FileAccess.get_file_as_string(CALENDAR_RULES_PATH), TRUSTED_CALENDAR_RULES)


## A verified profile copy, or {} when the rules or the ID are not usable.
static func calendar_profile(rule_id: String) -> Dictionary:
	var rules: CalendarRules.Result = calendar_rules()
	if not rules.ok:
		return {}
	var profile: CalendarRules.Result = (rules.value as CalendarRules).get_profile(rule_id)
	return profile.value if profile.ok else {}


## What a save of this map must contain, from the trusted local definitions (IH-112).
## IH-120: the calendar must be of `rule_id`'s profile.
static func save_manifest(rule_id: String = DEFAULT_CALENDAR_RULE) -> Dictionary:
	var items_service: InventoryService = InventoryService.new(ITEM_CATALOG)
	var items: Dictionary = {}
	var records: Dictionary = {}
	for item_id: StringName in items_service.get_item_ids():
		records[item_id] = items_service.get_item_info(item_id)
		items[String(item_id)] = int(records[item_id].stack_limit)
	items_service.close()
	var definitions: Dictionary = GATHER_CATALOG.compile(records).get("records", {})
	var inventories: Dictionary = {
		String(BAG_ID): {"owner_id": PLAYER_ID, "capacity": 12},
		String(STORE_ID): {"owner_id": STORE_OWNER, "capacity": 12},
	}
	var points: Array = []
	for binding: Dictionary in BINDINGS:
		var definition: Dictionary = definitions.get(StringName(binding.definition_id), {})
		inventories[binding.stock_inventory_id] = {"owner_id": binding.point_id, "capacity": 1,
			"item_id": String(definition.get("item_id", "")), "initial": int(definition.get("initial_quantity", 0))}
		points.append(binding.duplicate())
	points.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.point_id < b.point_id)
	return {"map_id": MAP_ID, "player_id": PLAYER_ID, "bag_id": String(BAG_ID), "bounds": MAP_BOUNDS,
		"inventories": inventories, "points": points, "items": items, "calendar_profile": calendar_profile(rule_id)}


## RESTORE services for a verified payload: every saved inventory registered once in a new
## InventoryService, stocks bound by the map's own bindings. Nothing is granted. The result
## is a restore_context for a candidate map (or the build error).
static func restore_session(payload: Dictionary) -> Dictionary:
	var restored: GatherService.Result = GatherService.restore(ITEM_CATALOG, GATHER_CATALOG,
		payload.inventories, BAG_ID, BINDINGS)
	if not restored.ok:
		return {"ok": false, "detail": restored.detail}
	# The calendar comes back exactly as saved: no event, no revision change.
	var profile: Dictionary = calendar_profile(String(payload.calendar.rule_id))
	var calendar_restored: CalendarService.Result = CalendarService.restore(payload.calendar, profile)
	if not calendar_restored.ok:
		restored.value.gather.close()
		restored.value.inventory.close()
		return {"ok": false, "detail": "calendar: " + calendar_restored.detail}
	var facing: PlayerController.Facing = PlayerController.Facing.DOWN
	for key: PlayerController.Facing in FACING_NAMES:
		if FACING_NAMES[key] == payload.player.facing:
			facing = key
	return {"ok": true, "context": {"inventory": restored.value.inventory, "gather": restored.value.gather,
		"calendar": calendar_restored.value,
		"position": Vector2(payload.player.position.x, payload.player.position.y), "facing": facing}}


## Swaps the point views for a new instance (or `replacement`) bound to the same stocks.
## Never re-registers or refills anything. Returns audit errors (and stays unbound) if any.
func rebind_points(replacement: Node2D = null) -> PackedStringArray:
	var old: Node2D = points
	var index: int = old.get_index()
	for target: GatherTarget in _gather_targets(old):
		target.unbind()
	remove_child(old)
	old.queue_free()
	points = replacement if replacement != null else POINTS_SCENE.instantiate() as Node2D
	add_child(points)
	move_child(points, index)
	var errors: PackedStringArray = _audit_targets()
	if errors.is_empty():
		_bind_points()
	_update_hud()
	return errors


## Every interaction target in the whole map (inspect and gather, available or not) must
## have a valid unique ID, and each bound point exactly one view.
func _audit_targets() -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen: Dictionary = {}
	for node: Node in find_children("*", "InteractionTarget", true, false):
		var target: InteractionTarget = node as InteractionTarget
		if not ItemCatalog.is_valid_id(target.target_id):
			errors.append("invalid target_id '%s' at %s" % [String(target.target_id).c_escape(), get_path_to(target)])
		elif seen.has(target.target_id):
			errors.append("duplicate target_id %s" % target.target_id)
		seen[target.target_id] = true
	var views: Dictionary = {}
	for target: GatherTarget in _gather_targets(points):
		views[target.target_id] = int(views.get(target.target_id, 0)) + 1
	for binding: Dictionary in BINDINGS:
		var count: int = int(views.get(StringName(binding.point_id), 0))
		if count != 1:
			errors.append("point %s has %d views" % [binding.point_id, count])
		views.erase(StringName(binding.point_id))
	for extra: StringName in views:
		errors.append("view %s has no binding" % extra)
	return errors


func _gather_targets(root: Node) -> Array[GatherTarget]:
	var found: Array[GatherTarget] = []
	for node: Node in find_children("*", "GatherTarget", true, false):
		if root.is_ancestor_of(node):
			found.append(node as GatherTarget)
	return found


func _bind_points() -> void:
	for target: GatherTarget in _gather_targets(points):
		target.bind_service(gather, BAG_ID)


## The HUD is display only: if it was freed, detached or is being deleted the message is
## skipped and nothing else changes (BUG-007). The committed transfer is never affected.
func _hud_usable() -> bool:
	return is_instance_valid(hud) and hud.is_inside_tree() and not hud.is_queued_for_deletion()


func _on_gathered(_request_id: int, target_id: StringName, result: RefCounted) -> void:
	if _hud_usable():
		var item: Dictionary = inventory.get_item_info(StringName(result.get("item_id")))
		var info: GatherService.Result = gather.query(target_id)
		var left: String = " (남은 %d)" % info.value.remaining if info.ok else ""
		hud.show_toast("%s 1개를 얻었습니다%s" % [item.get("fallback_name", "?"), left])
	if fixture == "rebind" and rebind_report.is_empty():
		_rebind_fixture.call_deferred()


func _on_rejected(_request_id: int, reason: StringName) -> void:
	if MESSAGES.has(reason) and _hud_usable():
		hud.show_toast(MESSAGES[reason])


func _rebind_fixture() -> void:
	var before: Dictionary = _point_values()
	rebind_points()
	rebind_report = {"before": before, "after": _point_values()}
	if _hud_usable():
		hud.show_toast("지점 뷰를 다시 연결했습니다: %s → %s" % [_short(before), _short(rebind_report.after)])


func _point_values() -> Dictionary:
	var values: Dictionary = {}
	for binding: Dictionary in BINDINGS:
		var info: GatherService.Result = gather.query(binding.point_id)
		values[binding.point_id] = [int(info.value.remaining), int(info.value.revision)] if info.ok else [-1, -1]
	return values


func _short(values: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in values:
		parts.append("%d" % values[key][0])
	return "/".join(parts)


func _update_hud() -> void:
	if gather == null or gather.is_closed() or inventory.is_closed() or not _hud_usable():
		return
	var point_parts: PackedStringArray = []
	var held: Dictionary = {}
	for binding: Dictionary in BINDINGS:
		var info: GatherService.Result = gather.query(binding.point_id)
		if info.ok:
			point_parts.append("%s %d" % [info.value.display_name, info.value.remaining])
			held[StringName(info.value.item_id)] = int(held.get(StringName(info.value.item_id), 0)) + int(info.value.remaining)
	var total_parts: PackedStringArray = []
	for item_id: StringName in TOTAL_ITEMS:
		var total: int = int(held.get(item_id, 0))
		for inventory_id: StringName in [BAG_ID, STORE_ID]:
			var counted: InventoryService.Result = inventory.count(inventory_id, item_id)
			total += int(counted.value) if counted.ok else 0
		total_parts.append("%s %d" % [inventory.get_item_info(item_id).fallback_name, total])
	# The fixture name is shown in-game too: the window title alone was not enough to tell
	# the normal/full/rebind windows apart during the manual GUI check.
	hud.show_lines("[%s] 지점 " % fixture + " · ".join(point_parts), "합계(가방+보관함+지점) " + " · ".join(total_parts))


func _bag_snapshot() -> Dictionary:
	var slots: Array = []
	slots.resize(12)
	if fixture == "full":
		slots[0] = {"item_id": "wood", "quantity": 10}
		for index: int in range(1, 12):
			slots[index] = {"item_id": "stone", "quantity": 10}
	else:
		slots[0] = {"item_id": "wood", "quantity": 8}
		slots[1] = {"item_id": "stone", "quantity": 10}
		slots[2] = {"item_id": "tool_axe", "quantity": 1}
	return {"inventory_id": String(BAG_ID), "owner_id": "player_01", "capacity": 12, "revision": 0, "slots": slots}


func _store_snapshot() -> Dictionary:
	var slots: Array = []
	slots.resize(12)
	return {"inventory_id": String(STORE_ID), "owner_id": "fixture_store_01", "capacity": 12, "revision": 0, "slots": slots}
