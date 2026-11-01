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

## "normal", "full" or "rebind". Tests may set it before the map enters the tree.
var fixture: String = ""
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
	if fixture.is_empty():
		fixture = "normal"
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--fixture="):
				fixture = argument.trim_prefix("--fixture=")
	get_window().title = "IH-111 gathering test (%s)" % fixture
	points = $GatheringPoints
	var errors: PackedStringArray = _audit_targets()
	if errors.is_empty():
		var built: GatherService.Result = GatherService.build(ITEM_CATALOG, GATHER_CATALOG,
			[_bag_snapshot(), _store_snapshot()], BAG_ID, BINDINGS)
		if built.ok:
			inventory = built.value.inventory
			gather = built.value.gather
		else:
			errors.append(built.detail)
	if not errors.is_empty():
		setup_errors = errors
		if _hud_usable():
			hud.show_error("시험 맵 구성 오류: 상호작용을 막았습니다.\n" + "\n".join(errors))
		return
	_bind_points()
	controller.setup(inventory, player, interaction, ui, BAG_ID, STORE_ID)
	($FixtureHud/StoreButton as Button).pressed.connect(func() -> void:
		controller.request_open(InventoryController.View.STORE))
	interaction.instant_completed.connect(_on_gathered)
	interaction.request_rejected.connect(_on_rejected)
	inventory.inventories_changed.connect(func(_ids: Array[StringName], _revisions: Dictionary) -> void:
		_update_hud(), CONNECT_DEFERRED)
	interaction.set_interaction_enabled(true)
	_update_hud()


func _exit_tree() -> void:
	if gather != null:
		gather.close()
	if inventory != null:
		inventory.close()


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
	hud.show_lines("지점 " + " · ".join(point_parts), "합계(가방+보관함+지점) " + " · ".join(total_parts))


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
