extends Node2D
## IH-110 verification map: owns one InventoryService with a 12-slot bag and a finite
## 12-slot test store, wires the coordinator and UI, and shows item totals so moves can be
## seen to conserve quantities. Contents are test fixtures; nothing is granted on open.
## Run with `-- --fixture=full` for a store with no room for the bag's wood.

const CATALOG: ItemCatalog = preload("res://data/items/catalog.tres")
const BAG_ID: StringName = &"player_bag"
const STORE_ID: StringName = &"test_store"
const TOTAL_ITEMS: Array[StringName] = [&"wood", &"stone", &"tool_axe", &"seed_wheat"]

var service: InventoryService
## Empty when both inventories registered; otherwise the failure codes, kept for checks.
var setup_errors: PackedStringArray = []

@onready var controller: InventoryController = $InventoryController
@onready var ui: InventoryUI = $InventoryUI
@onready var player: PlayerController = $Interaction/World/Player
@onready var interaction: InteractionController = $Interaction/World/Player/InteractionController
@onready var _totals: Label = $FixtureHud/Totals


func _ready() -> void:
	service = InventoryService.new(CATALOG)
	var full: bool = "--fixture=full" in OS.get_cmdline_user_args()
	for snapshot: Dictionary in [_bag_snapshot(), _store_snapshot(full)]:
		var result: InventoryService.Result = service.register_snapshot(snapshot)
		if not result.ok:
			setup_errors.append("%s: %s %s" % [snapshot.inventory_id, result.code, result.detail])
	controller.setup(service, player, interaction, ui, BAG_ID, STORE_ID)
	($FixtureHud/StoreButton as Button).pressed.connect(func() -> void:
		controller.request_open(InventoryController.View.STORE))
	service.inventories_changed.connect(func(_ids: Array[StringName], _revisions: Dictionary) -> void: _update_totals())
	_update_totals()


func _exit_tree() -> void:
	if service != null:
		service.close()


func _update_totals() -> void:
	var parts: PackedStringArray = []
	for item_id: StringName in TOTAL_ITEMS:
		var bag: InventoryService.Result = service.count(BAG_ID, item_id)
		var store: InventoryService.Result = service.count(STORE_ID, item_id)
		if bag.ok and store.ok:
			parts.append("%s %d" % [service.get_item_info(item_id).fallback_name, int(bag.value) + int(store.value)])
	_totals.text = "합계 " + " · ".join(parts)


func _bag_snapshot() -> Dictionary:
	var slots: Array = []
	slots.resize(12)
	slots[0] = {"item_id": "wood", "quantity": 8}
	slots[1] = {"item_id": "stone", "quantity": 10}
	slots[2] = {"item_id": "tool_axe", "quantity": 1}
	return {"inventory_id": String(BAG_ID), "owner_id": "player_01", "capacity": 12, "revision": 0, "slots": slots}


func _store_snapshot(full: bool) -> Dictionary:
	var slots: Array = []
	slots.resize(12)
	slots[0] = {"item_id": "wood", "quantity": 10 if full else 7}
	if full:
		for index: int in range(1, 12):
			slots[index] = {"item_id": "stone", "quantity": 10}
	else:
		slots[1] = {"item_id": "seed_wheat", "quantity": 4}
	return {"inventory_id": String(STORE_ID), "owner_id": "fixture_store_01", "capacity": 12, "revision": 0, "slots": slots}
