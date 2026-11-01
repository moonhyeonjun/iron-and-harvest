extends SceneTree
## IH-111 acceptance runner. Domain cases drive GatherService/InventoryService and compare
## whole snapshots of every inventory (bag, store, all stocks), revisions, change events and
## independently computed per-item totals around each command. Scene cases use the real
## gathering_test map with keys through Input.parse_input_event + flush. Exit 0 only when
## every automated check passes. Real GUI use (AC-G14) is never reported as passed here.

const ITEM_CATALOG_PATH: String = "res://data/items/catalog.tres"
const GATHER_CATALOG_PATH: String = "res://data/gathering/gather_catalog.tres"
const MAP_SCENE: String = "res://scenes/tests/gathering_test.tscn"
const POINT_SCENE: String = "res://scenes/gathering/gather_target.tscn"
const POINTS_SCENE: String = "res://scenes/gathering/gathering_points.tscn"
const PROBE: Script = preload("res://tests/support/gather_probe_target.gd")
const FIXTURES: String = "res://tests/fixtures/gathering/"
const G := preload("res://systems/gathering/gather_service.gd")
const IV := preload("res://systems/inventory/inventory_service.gd")
const BAG: String = "player_bag"
const STORE: String = "test_store"
const BINDINGS: Array = [
	{"point_id": "branch_pile_01", "map_id": "gathering_test", "definition_id": "gather_branches", "stock_inventory_id": "stock_branch_01"},
	{"point_id": "stone_pile_01", "map_id": "gathering_test", "definition_id": "gather_stones", "stock_inventory_id": "stock_stone_01"},
	{"point_id": "berry_bush_01", "map_id": "gathering_test", "definition_id": "gather_berries", "stock_inventory_id": "stock_berry_01"},
]
const ALL_IDS: Array = ["player_bag", "test_store", "stock_branch_01", "stock_stone_01", "stock_berry_01"]
const ITEMS: Array = ["wood", "stone", "berry", "tool_axe"]
## Written independently of production code: the normal fixture's starting totals.
const NORMAL_TOTALS: Dictionary = {"wood": 14, "stone": 14, "berry": 3, "tool_axe": 1}
## Positions in front of each point (facing key), on free floor of the test map.
const STANDS: Dictionary = {"branch_pile_01": [Vector2(228, 360), "right"], "stone_pile_01": [Vector2(228, 470), "right"],
	"berry_bush_01": [Vector2(360, 322), "up"]}
const FACING_KEYS: Dictionary = {"down": KEY_S, "up": KEY_W, "left": KEY_A, "right": KEY_D}
const SEED: int = 1111

var _ac_checks: Dictionary = {}
var _failures: Array[String] = []
var _held: Array[Key] = []
var _metrics: Dictionary = {}
var _pass_metrics: Array[Dictionary] = []
var _item_catalog: ItemCatalog
var _gather_catalog: GatherCatalog
var _events: Array = []
var _map: Node2D
var _rec: Array[Dictionary] = []
var _engine_errors: EngineErrorLog = EngineErrorLog.new()


## Script runtime errors only abort the failing call; collect them so they fail the run.
class EngineErrorLog extends Logger:
	var _mutex: Mutex = Mutex.new()
	var _entries: PackedStringArray = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text: String = rationale if not rationale.is_empty() else code
		if text.begins_with("FAIL "):
			return
		_mutex.lock()
		_entries.append("%s:%d %s" % [file, line, text])
		_mutex.unlock()

	func entries() -> PackedStringArray:
		_mutex.lock()
		var copy: PackedStringArray = _entries.duplicate()
		_mutex.unlock()
		return copy


func _initialize() -> void:
	OS.add_logger(_engine_errors)
	_run()


func _run() -> void:
	print("IH-111 runner: engine=%s" % Engine.get_version_info().string)
	_item_catalog = load(ITEM_CATALOG_PATH) as ItemCatalog
	_gather_catalog = load(GATHER_CATALOG_PATH) as GatherCatalog
	for pass_index: int in 2:
		_metrics = {}
		var steps: Array = [
			["AC-G01", _g01_definitions], ["AC-G02", _g02_bindings], ["AC-G03", _g03_success], ["AC-G04", _g04_space],
			["AC-G05", _g05_depletion], ["AC-G06", _g06_commands], ["AC-G13", _g13_sequence],
			["AC-G02", _g02_scene_audit], ["AC-G07", _g07_revalidation], ["AC-G08", _g08_cancel_before_commit],
			["AC-G09", _g09_after_commit], ["AC-G10", _g10_reentry], ["AC-G11", _g11_ui_and_movement], ["AC-G12", _g12_rebind],
		]
		for step: Array in steps:
			var completed: Variant = await (step[1] as Callable).call()
			_check(step[0], completed == true, "%s case list aborted before completion" % step[0])
		_check("AC-G13", _all_released(), "pass %d left a key pressed" % pass_index)
		_pass_metrics.append(_metrics)
	_compare_passes()
	await process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("AC-G13", orphans == 0, "orphan nodes after both passes: %d" % orphans)
	_log("AC-G13", "orphan nodes after both passes: %d" % orphans)
	if "--inject-failure" in OS.get_cmdline_user_args():
		_check("AC-G13", false, "deliberate failure requested by --inject-failure")
	var errors: PackedStringArray = _engine_errors.entries()
	OS.remove_logger(_engine_errors)
	_check("AC-G13", errors.is_empty(), "engine/script errors during the run: %s" % "; ".join(errors))
	_log("AC-G13", "engine/script errors logged during the run: %d" % errors.size())
	_finish()


# --- AC-G01 definitions --------------------------------------------------------------

func _g01_definitions() -> bool:
	var items: Dictionary = _item_records()
	var compiled: Dictionary = _gather_catalog.compile(items)
	var records: Dictionary = compiled.records
	_check("AC-G01", compiled.ok and compiled.order == [&"gather_branches", &"gather_stones", &"gather_berries"]
		and records[&"gather_branches"].item_id == &"wood" and records[&"gather_branches"].initial_quantity == 6
		and records[&"gather_stones"].initial_quantity == 4 and records[&"gather_berries"].item_id == &"berry"
		and records[&"gather_berries"].action_label == "따기", "three definitions and values %s" % [compiled.errors])
	for definition_id: String in ["gather_branches", "gather_stones", "gather_berries"]:
		var text: String = FileAccess.get_file_as_string("res://data/gathering/%s.tres" % definition_id)
		_check("AC-G01", text.contains("initial_quantity = "), "%s.tres states initial_quantity" % definition_id)
	var bad_cases: Array = [
		["unknown item", {"item_id": &"gold"}], ["quantity 0", {"initial_quantity": 0}], ["quantity -1", {"initial_quantity": -1}],
		["over wood limit", {"initial_quantity": 11}], ["over axe limit", {"item_id": &"tool_axe", "initial_quantity": 2}],
		["empty id", {"definition_id": &""}], ["trailing newline id", {"definition_id": &"gather_x\n"}],
		["space id", {"definition_id": &"gather x"}], ["65 char id", {"definition_id": StringName("g".repeat(65))}],
		["empty display", {"display_name": " "}], ["empty action", {"action_label": ""}],
	]
	for case: Array in bad_cases:
		var catalog: GatherCatalog = _catalog_with(_def("gather_extra", case[1]))
		var result: Dictionary = catalog.compile(items)
		var built: GatherService.Result = GatherService.build(_item_catalog, catalog, _snapshots(), &"player_bag", BINDINGS)
		_check("AC-G01", not result.ok and (result.records as Dictionary).is_empty() and built.code == G.INVALID_SETUP and built.value == null,
			"%s rejected (%s)" % [case[0], result.errors])
	# The engine silently turns 2.5/true/"3" into ints for a typed field; the authored text is checked.
	var literal_errors: Dictionary = {}
	for name: String in ["float_quantity", "bool_quantity", "string_quantity", "missing_quantity"]:
		var loaded: GatherDef = load(FIXTURES + name + ".tres") as GatherDef
		var catalog: GatherCatalog = _catalog_with(loaded)
		var result: Dictionary = catalog.compile(items)
		literal_errors[name] = [loaded.initial_quantity, "\n".join(result.errors).contains("integer literal")]
		_check("AC-G01", not result.ok and literal_errors[name][1], "%s rejected though loaded as %d" % [name, loaded.initial_quantity])
	_log("AC-G01", "fixture values after engine load %s -> all rejected by literal check" % [literal_errors])
	# Edits to shared Resources or returned copies after build never reach live state.
	var session: Dictionary = _session()
	var gather: GatherService = session.gather
	var shared: GatherDef = load("res://data/gathering/gather_branches.tres") as GatherDef
	var original: Array = [shared.initial_quantity, shared.item_id, shared.display_name]
	shared.initial_quantity = 99
	shared.item_id = &"stone"
	shared.display_name = "변조"
	var info: Dictionary = gather.query("branch_pile_01").value
	var copy: Dictionary = gather.query("branch_pile_01").value
	copy.remaining = 50
	var gathered: GatherService.Result = _gather_once(gather, "branch_pile_01", 1)
	shared.initial_quantity = original[0]
	shared.item_id = original[1]
	shared.display_name = original[2]
	_check("AC-G01", info.initial == 6 and info.item_id == "wood" and info.display_name == "나뭇가지" and gathered.ok
		and gathered.item_id == &"wood" and gather.query("branch_pile_01").value.remaining == 5,
		"shared GatherDef and query copies are isolated: %s" % [info])
	_log("AC-G01", "3 definitions; %d invalid definitions rejected as a whole; shared Resource edit ignored" % bad_cases.size())
	return true


# --- AC-G02 bindings -----------------------------------------------------------------

func _g02_bindings() -> bool:
	var cases: Array = [
		["duplicate point", func(b: Array) -> void: b[1].point_id = "branch_pile_01"],
		["duplicate stock", func(b: Array) -> void: b[1].stock_inventory_id = "stock_branch_01"],
		["stock is the bag", func(b: Array) -> void: b[2].stock_inventory_id = "player_bag"],
		["stock is the store", func(b: Array) -> void: b[2].stock_inventory_id = "test_store"],
		["point id newline", func(b: Array) -> void: b[0].point_id = "branch_pile_01\n"],
		["empty map id", func(b: Array) -> void: b[0].map_id = ""],
		["65 char stock", func(b: Array) -> void: b[0].stock_inventory_id = "s".repeat(65)],
		["unknown definition", func(b: Array) -> void: b[1].definition_id = "gather_gold"],
		["missing key", func(b: Array) -> void: b[0].erase("map_id")],
		["extra key", func(b: Array) -> void: b[0]["note"] = "x"],
		["not a dictionary", func(b: Array) -> void: b[1] = "stone_pile_01"],
		["last binding bad", func(b: Array) -> void: b.append({"point_id": "late_point", "map_id": "gathering_test", "definition_id": "gather_missing", "stock_inventory_id": "stock_late"})],
	]
	for case: Array in cases:
		var bindings: Array = BINDINGS.duplicate(true)
		(case[1] as Callable).call(bindings)
		var built: GatherService.Result = GatherService.build(_item_catalog, _gather_catalog, _snapshots(), &"player_bag", bindings)
		_check("AC-G02", built.code == G.INVALID_SETUP and built.value == null and not built.detail.is_empty(),
			"%s: %s" % [case[0], built.code])
	var bad_bag: GatherService.Result = GatherService.build(_item_catalog, _gather_catalog, _snapshots(), &"missing_bag", BINDINGS)
	_check("AC-G02", bad_bag.code == G.INVALID_SETUP, "bag must be a registered inventory")
	# Two points of the same definition are independent.
	var twin: Array = BINDINGS.duplicate(true)
	twin.append({"point_id": "branch_pile_02", "map_id": "gathering_test", "definition_id": "gather_branches", "stock_inventory_id": "stock_branch_02"})
	var built: GatherService.Result = GatherService.build(_item_catalog, _gather_catalog, _snapshots(), &"player_bag", twin)
	var gather: GatherService = built.value.gather if built.ok else null
	var first: GatherService.Result = _gather_once(gather, "branch_pile_01", 1) if gather != null else null
	_check("AC-G02", built.ok and first.ok and gather.query("branch_pile_01").value.remaining == 5
		and gather.query("branch_pile_02").value.remaining == 6, "same definition, independent stocks")
	_log("AC-G02", "%d bad binding sets rejected without a partial session; twin points independent" % cases.size())
	return true


# --- AC-G03 success ------------------------------------------------------------------

func _g03_success() -> bool:
	var session: Dictionary = _session()
	var inventory: InventoryService = session.inventory
	var gather: GatherService = session.gather
	var before: Dictionary = _all_snapshots(inventory)
	var seen: Array = []
	# The observer captures the services it listens to; disconnect it so no RefCounted cycle remains.
	var observer: Callable = func(ids: Array[StringName], revisions: Dictionary) -> void:
		seen.append({"ids": ids.map(func(id: StringName) -> String: return String(id)), "revisions": revisions.duplicate(),
			"bag_wood": inventory.count("player_bag", "wood").value, "remaining": gather.query("branch_pile_01").value.remaining})
	inventory.inventories_changed.connect(observer)
	var result: GatherService.Result = _gather_once(gather, "branch_pile_01", 7)
	inventory.inventories_changed.disconnect(observer)
	var after: Dictionary = _all_snapshots(inventory)
	var event: Dictionary = seen[0] if seen.size() == 1 else {}
	var others_same: bool = after.test_store == before.test_store and after.stock_stone_01 == before.stock_stone_01 \
		and after.stock_berry_01 == before.stock_berry_01
	_check("AC-G03", result.ok and result.applied_quantity == 1 and result.request_id == 7 and result.point_id == &"branch_pile_01"
		and result.item_id == &"wood" and _slots(after.player_bag)[0] == "wood9" and _slots(after.stock_branch_01) == ["wood5"]
		and after.player_bag.revision == before.player_bag.revision + 1 and after.stock_branch_01.revision == before.stock_branch_01.revision + 1
		and result.revisions == {"player_bag": 1, "stock_branch_01": 1}, "stock -1 / bag +1 / revisions +1: %s" % [result.revisions])
	_check("AC-G03", seen.size() == 1 and event.ids == ["player_bag", "stock_branch_01"] and event.bag_wood == 9 and event.remaining == 5,
		"one change signal with both final states: %s" % [seen])
	_check("AC-G03", others_same and _totals(inventory) == NORMAL_TOTALS, "other inventories untouched, totals %s" % [_totals(inventory)])
	_metrics["AC-G03"] = str(_slots(after.player_bag))
	_log("AC-G03", "gather -> bag wood9, branch 5, revisions %s, signal ids %s, totals %s" % [result.revisions, event.get("ids"), _totals(inventory)])
	return true


# --- AC-G04 space --------------------------------------------------------------------

func _g04_space() -> bool:
	var room: Dictionary = _session(_full_bag(9))
	var fits: GatherService.Result = _gather_once(room.gather, "branch_pile_01", 1)
	_check("AC-G04", fits.ok and _slots(room.inventory.snapshot("player_bag").value)[0] == "wood10", "existing stack room is enough")
	var session: Dictionary = _session(_full_bag(10))
	var inventory: InventoryService = session.inventory
	var gather: GatherService = session.gather
	var before: Dictionary = _all_snapshots(inventory)
	var events_before: int = _events.size()
	var full: GatherService.Result = _gather_once(gather, "branch_pile_01", 2)
	_check("AC-G04", full.code == G.NO_SPACE and full.applied_quantity == 0 and _all_snapshots(inventory) == before
		and _events.size() == events_before and not gather.has_pending_command(), "full bag: NO_SPACE, everything unchanged")
	for point_id: String in ["stone_pile_01", "berry_bush_01"]:
		_check("AC-G04", _gather_once(gather, point_id, 3).code == G.NO_SPACE, "%s also NO_SPACE when full" % point_id)
	var moved: InventoryService.Result = inventory.transfer("player_bag", 0, "test_store", 10, 0, 0)
	var after_move: GatherService.Result = _gather_once(gather, "branch_pile_01", 4)
	_check("AC-G04", moved.ok and after_move.ok and _slots(inventory.snapshot("player_bag").value)[0] == "wood1"
		and _totals(inventory) == {"wood": 16, "stone": 114, "berry": 3, "tool_axe": 0}, "after moving wood to the store the gather succeeds")
	_log("AC-G04", "stack room ok; full -> NO_SPACE unchanged (3 points); store move then gather ok; totals %s" % [_totals(inventory)])
	return true


# --- AC-G05 depletion ----------------------------------------------------------------

func _g05_depletion() -> bool:
	var session: Dictionary = _session()
	var inventory: InventoryService = session.inventory
	var gather: GatherService = session.gather
	for index: int in 3:
		_gather_once(gather, "berry_bush_01", 10 + index)
	var info: Dictionary = gather.query("berry_bush_01").value
	var events_before: int = _events.size()
	var before: Dictionary = _all_snapshots(inventory)
	var again: GatherService.Result = gather.prepare("berry_bush_01", "player_bag", 20)
	_check("AC-G05", info.remaining == 0 and info.depleted and _slots(inventory.snapshot("stock_berry_01").value) == ["-"]
		and inventory.count("player_bag", "berry").value == 3 and again.code == G.DEPLETED and _events.size() == events_before
		and _all_snapshots(inventory) == before, "berries depleted after 3, further prepare DEPLETED")
	# Corrupted stock is reported, never silently refilled or used.
	var revision: int = inventory.snapshot("stock_berry_01").value.revision
	inventory.add("stock_berry_01", "stone", 1, revision)
	var corrupt: GatherService.Result = gather.query("berry_bush_01")
	var corrupt_prepare: GatherService.Result = gather.prepare("berry_bush_01", "player_bag", 21)
	var over: Dictionary = _session()
	over.inventory.add("stock_stone_01", "stone", 1, 0)
	_check("AC-G05", corrupt.code == G.INVALID_STOCK and corrupt_prepare.code == G.INVALID_STOCK
		and over.gather.query("stone_pile_01").code == G.INVALID_STOCK, "foreign item or quantity above initial -> INVALID_STOCK")
	_log("AC-G05", "berry 3 -> 0 (slot empty), prepare DEPLETED, events 0; corrupt stocks INVALID_STOCK")
	return true


# --- AC-G06 commands -----------------------------------------------------------------

func _g06_commands() -> bool:
	var session: Dictionary = _session()
	var inventory: InventoryService = session.inventory
	var gather: GatherService = session.gather
	var before: Dictionary = _all_snapshots(inventory)
	var events_before: int = _events.size()
	var prepared: GatherService.Result = gather.prepare("branch_pile_01", "player_bag", 1)
	_check("AC-G06", prepared.ok and _all_snapshots(inventory) == before and _events.size() == events_before, "prepare grants nothing")
	_check("AC-G06", gather.prepare("stone_pile_01", "player_bag", 2).code == G.BUSY and gather.has_pending_command(),
		"second prepare BUSY, first stays")
	# Tampering with the token changes nothing about what it commits.
	var command: GatherService.GatherCommand = prepared.value
	command.set("_point_id", &"stone_pile_01")
	command.set("_request_id", 999)
	var committed: GatherService.Result = command.commit()
	_check("AC-G06", committed.ok and committed.point_id == &"branch_pile_01" and committed.request_id == 1
		and gather.query("stone_pile_01").value.remaining == 4, "token edits ignored: %s %d" % [committed.point_id, committed.request_id])
	var reuse: GatherService.Result = command.commit()
	_check("AC-G06", reuse.code == G.INVALID_COMMAND and gather.query("branch_pile_01").value.remaining == 5, "a used command grants nothing")
	# Stale after prepare: bag or stock changed in between.
	var stale_cases: Array = [
		["bag changed", func() -> void: inventory.add("player_bag", "iron", 1, inventory.snapshot("player_bag").value.revision)],
		["stock changed", func() -> void: inventory.remove("stock_stone_01", "stone", 1, inventory.snapshot("stock_stone_01").value.revision)],
	]
	for case: Array in stale_cases:
		var point: String = "branch_pile_01" if case[0] == "bag changed" else "stone_pile_01"
		var stale_command: GatherService.Result = gather.prepare(point, "player_bag", 3)
		(case[1] as Callable).call()
		var snapshot_after_change: Dictionary = _all_snapshots(inventory)
		var stale: GatherService.Result = (stale_command.value as GatherService.GatherCommand).commit()
		_check("AC-G06", stale.code == G.STALE_REVISION and _all_snapshots(inventory) == snapshot_after_change
			and not gather.has_pending_command(), "%s -> STALE_REVISION, nothing more changed" % case[0])
	# Cancel, then cancel again; commit after cancel; new prepare afterwards.
	var cancelled: GatherService.GatherCommand = gather.prepare("berry_bush_01", "player_bag", 4).value
	cancelled.cancel()
	cancelled.cancel()
	_check("AC-G06", cancelled.commit().code == G.INVALID_COMMAND and gather.query("berry_bush_01").value.remaining == 3
		and gather.prepare("berry_bush_01", "player_bag", 5).ok, "cancelled command dead, new prepare fine")
	# A command from another service, or a wrong one, never disturbs the valid pending one.
	var other: Dictionary = _session()
	var foreign: GatherService.GatherCommand = other.gather.prepare("branch_pile_01", "player_bag", 6).value
	_check("AC-G06", gather.execute(foreign).code == G.INVALID_COMMAND and gather.has_pending_command(), "foreign command refused, pending kept")
	gather.close()
	var closed_codes: Array = [gather.prepare("branch_pile_01", "player_bag", 7).code, gather.query("branch_pile_01").code]
	_check("AC-G06", closed_codes == [G.CLOSED, G.CLOSED] and not gather.has_pending_command(), "closed service refuses %s" % [closed_codes])
	var fresh: Dictionary = _session()
	var bad_args: Array = [["request 0", ["branch_pile_01", "player_bag", 0]], ["request float", ["branch_pile_01", "player_bag", 1.0]],
		["request bool", ["branch_pile_01", "player_bag", true]], ["store as bag", ["branch_pile_01", "test_store", 1]],
		["newline point", ["branch_pile_01\n", "player_bag", 1]]]
	for case: Array in bad_args:
		_check("AC-G06", fresh.gather.prepare(case[1][0], case[1][1], case[1][2]).code == G.INVALID_ARGUMENT, "%s rejected" % case[0])
	_check("AC-G06", fresh.gather.prepare("nowhere", "player_bag", 1).code == G.INVALID_POINT and not fresh.gather.has_pending_command(),
		"unknown point INVALID_POINT")
	_log("AC-G06", "prepare grants 0; BUSY while pending; token edits ignored; reuse/cancel/foreign INVALID_COMMAND; stale bag/stock; closed CLOSED")
	return true


# --- AC-G13 deterministic sequence ---------------------------------------------------

func _g13_sequence() -> bool:
	var runs: Array = [_sequence(), _sequence()]
	_check("AC-G13", runs[0] == runs[1], "same sequence, same final snapshots and codes")
	_metrics["AC-G13 sequence"] = str(runs[0].hash())
	_log("AC-G13", "scripted+seeded sequence codes=%s (repeated identically)" % [runs[0].codes])
	return true


## gather -> store move -> full fail -> stale fail -> cancel -> deplete -> rebind-like reuse,
## then seeded random gathers/moves; every step is checked against the starting totals.
func _sequence() -> Dictionary:
	var session: Dictionary = _session()
	var inventory: InventoryService = session.inventory
	var gather: GatherService = session.gather
	var codes: Array = []
	var violations: PackedStringArray = []
	var step: Callable = func(label: String, code: StringName) -> void:
		codes.append("%s:%s" % [label, code])
		if _totals(inventory) != NORMAL_TOTALS:
			violations.append("%s totals %s" % [label, _totals(inventory)])
	step.call("gather", _gather_once(gather, "branch_pile_01", 1).code)
	step.call("to_store", inventory.transfer("player_bag", 1, "test_store", 10, inventory.snapshot("player_bag").value.revision, 0).code)
	var filler: Dictionary = inventory.snapshot("player_bag").value
	var revision: int = filler.revision
	for index: int in (filler.slots as Array).size():
		if filler.slots[index] == null:
			inventory.transfer("test_store", 0, "player_bag", 1, inventory.snapshot("test_store").value.revision, revision)
			revision = inventory.snapshot("player_bag").value.revision
	step.call("spread", &"OK")
	var stale: GatherService.GatherCommand = gather.prepare("berry_bush_01", "player_bag", 2).value
	inventory.transfer("player_bag", 0, "test_store", 1, inventory.snapshot("player_bag").value.revision, inventory.snapshot("test_store").value.revision)
	step.call("stale", stale.commit().code)
	var cancel: GatherService.GatherCommand = gather.prepare("berry_bush_01", "player_bag", 3).value
	cancel.cancel()
	step.call("cancel", cancel.commit().code)
	for index: int in 3:
		step.call("deplete", _gather_once(gather, "berry_bush_01", 4 + index).code)
	step.call("depleted", gather.prepare("berry_bush_01", "player_bag", 9).code)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	for index: int in 120:
		if rng.randf() < 0.6:
			var binding: Dictionary = BINDINGS[rng.randi_range(0, 2)]
			step.call("g", _gather_once(gather, binding.point_id, 100 + index).code)
		else:
			var bag: Dictionary = inventory.snapshot("player_bag").value
			var store: Dictionary = inventory.snapshot("test_store").value
			var forward: bool = rng.randf() < 0.5
			var source: Dictionary = bag if forward else store
			var slot: int = rng.randi_range(0, 11)
			var stack: Variant = source.slots[slot]
			var amount: int = rng.randi_range(1, 3) if stack == null else rng.randi_range(1, stack.quantity)
			step.call("m", inventory.transfer(source.inventory_id, slot, store.inventory_id if forward else bag.inventory_id, amount,
				source.revision, store.revision if forward else bag.revision).code)
	_check("AC-G13", violations.is_empty(), "totals held at every step: %s" % ", ".join(violations.slice(0, 4)))
	var finals: Array = []
	for id: String in ALL_IDS:
		finals.append(inventory.snapshot(id).value)
	var summary: Dictionary = {}
	for entry: String in codes:
		var code: String = entry.get_slice(":", 1)
		summary[code] = int(summary.get(code, 0)) + 1
	return {"codes": summary, "sequence": codes.slice(0, 9), "final": finals}


# --- scene cases ---------------------------------------------------------------------

func _g02_scene_audit() -> bool:
	var variants: Array = [
		["point id equals sign", func(map: Node2D) -> void: map.get_node("GatheringPoints/StonePile").target_id = &"sign_entrance"],
		["unavailable duplicate", func(map: Node2D) -> void:
			var crate: InteractionTarget = map.get_node("Interaction/Targets/CrateSupplies")
			crate.available = false
			crate.target_id = &"berry_bush_01"],
		["two views of one point", func(map: Node2D) -> void:
			var extra: GatherTarget = (load(POINT_SCENE) as PackedScene).instantiate() as GatherTarget
			extra.target_id = &"branch_pile_01"
			extra.position = Vector2(500, 600)
			map.get_node("GatheringPoints").add_child(extra)],
		["view without binding", func(map: Node2D) -> void: map.get_node("GatheringPoints/BerryBush").target_id = &"orphan_point"],
	]
	for variant: Array in variants:
		var map: Node2D = (load(MAP_SCENE) as PackedScene).instantiate() as Node2D
		(variant[1] as Callable).call(map)
		root.add_child(map)
		await process_frame
		await _ticks(3)
		var errors: PackedStringArray = map.get("setup_errors")
		var controller: InventoryController = map.get("controller")
		var interaction: InteractionController = map.get("interaction")
		_check("AC-G02", not errors.is_empty() and map.get("gather") == null and not interaction.is_interaction_enabled()
			and controller.request_open(InventoryController.View.BAG) == InventoryController.NOT_READY,
			"%s: setup refused (%s)" % [variant[0], errors])
		_log("AC-G02", "scene %s -> setup refused: %s" % [variant[0], errors[0] if errors.size() > 0 else "-"])
		map.queue_free()
		await _ticks(2)
	return true


func _g07_revalidation() -> bool:
	var mutations: Array = [
		["out of range", func(map: Node2D, _t: GatherTarget) -> void: (map.get("player") as Node2D).global_position = Vector2(150, 360), InteractionController.OUT_OF_RANGE],
		["wall between", func(map: Node2D, _t: GatherTarget) -> void: _wall(map, Rect2(236, 340, 4, 40)), InteractionController.OCCLUDED],
		["id changed", func(_m: Node2D, t: GatherTarget) -> void: t.target_id = &"renamed_point", InteractionController.INVALID_TARGET],
		["unavailable", func(_m: Node2D, t: GatherTarget) -> void: t.available = false, InteractionController.INVALID_TARGET],
		["queue_freed", func(_m: Node2D, t: GatherTarget) -> void: t.queue_free(), InteractionController.INVALID_TARGET],
		["twin becomes usable", func(map: Node2D, _t: GatherTarget) -> void:
			(map.get_node("GatheringPoints/Twin") as GatherTarget).available = true, InteractionController.INVALID_TARGET],
	]
	for case: Array in mutations:
		await _load_map()
		if case[0] == "twin becomes usable":
			# A same-ID view that is already a Detector candidate but unavailable until after E.
			var twin: GatherTarget = (load(POINT_SCENE) as PackedScene).instantiate() as GatherTarget
			twin.name = "Twin"
			twin.target_id = &"branch_pile_01"
			twin.available = false
			twin.position = Vector2(244, 368)
			_map.get_node("GatheringPoints").add_child(twin)
			twin.bind_service(_map.get("gather"), &"player_bag")
		await _stand("branch_pile_01")
		var target: GatherTarget = _map.get_node("GatheringPoints/BranchPile")
		var before: Dictionary = _all_snapshots(_map.get("inventory"))
		var events_before: int = _events.size()
		var mark: int = _rec.size()
		var selected: StringName = (_map.get("interaction") as InteractionController).get_selected_target_id()
		_key(KEY_E, true)
		_key(KEY_E, false)
		(case[1] as Callable).call(_map, target)
		await _ticks(3)
		var rejected: Array = _since(mark, "rejected")
		_check("AC-G07", selected == &"branch_pile_01" and rejected.size() == 1 and rejected[0].reason == case[2]
			and _since(mark, "gathered").is_empty() and _all_snapshots(_map.get("inventory")) == before and _events.size() == events_before
			and not (_map.get("gather") as GatherService).has_pending_command(), "%s: %s" % [case[0], rejected])
		_metrics["AC-G07 %s" % case[0]] = String(rejected[0].reason) if rejected.size() > 0 else "-"
		_log("AC-G07", "%s after E -> %s, payout 0, events 0" % [case[0], rejected[0].reason if rejected.size() > 0 else "-"])
		await _unload_map()
	return true


func _g08_cancel_before_commit() -> bool:
	var actions: Array = [
		["disable then enable", func(m: Node2D) -> void:
			m.interaction.set_interaction_enabled(false)
			m.interaction.set_interaction_enabled(true), InteractionController.DISABLED],
		["focus out then in", func(_m: Node2D) -> void:
			root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN), InteractionController.FOCUS_LOST],
		["controller leaves tree", func(m: Node2D) -> void: m.player.remove_child(m.interaction), InteractionController.REMOVED],
		["target queue_free", func(_m: Node2D) -> void: _probe_target().queue_free(), InteractionController.INVALID_TARGET],
		["Escape pressed", func(_m: Node2D) -> void:
			_key(KEY_ESCAPE, true)
			_key(KEY_ESCAPE, false), InteractionController.CANCELLED],
	]
	for case: Array in actions:
		await _load_map()
		var probe: GatherTarget = await _install_probe(case[1])
		await _stand("branch_pile_01")
		var inventory: InventoryService = _map.get("inventory")
		var before: Dictionary = _all_snapshots(inventory)
		var events_before: int = _events.size()
		var mark: int = _rec.size()
		await _press_e()
		var journal: Array = probe.get("journal") if is_instance_valid(probe) else ["(freed)"]
		var rejected: Array = _since(mark, "rejected")
		var unchanged: bool = _all_snapshots(inventory) == before and _events.size() == events_before
		var released: bool = not (_map.get("gather") as GatherService).has_pending_command()
		var interaction: InteractionController = _map.get("interaction")
		if not interaction.is_inside_tree():
			(_map.get("player") as Node).add_child(interaction)
		if is_instance_valid(probe):
			probe.set("on_begin", Callable())
		else:
			_map.call("rebind_points")
		await _ticks(3)
		await _stand("branch_pile_01")
		await _press_e()
		var retried: bool = _since(mark, "gathered").size() == 1 and inventory.count("player_bag", "wood").value == 9
		_check("AC-G08", rejected.size() == 1 and rejected[0].reason == case[2] and unchanged and released
			and journal.count("end:cancelled") <= 1 and retried, "%s: %s journal %s unchanged %s released %s retry %s" % [
			case[0], rejected, journal, unchanged, released, retried])
		_metrics["AC-G08 %s" % case[0]] = String(rejected[0].reason) if rejected.size() > 0 else "-"
		_log("AC-G08", "%s inside try_begin -> %s, journal %s, payout 0, command released, next E gathers 1" % [
			case[0], rejected[0].reason if rejected.size() > 0 else "-", journal])
		await _unload_map()
	return true


func _g09_after_commit() -> bool:
	var actions: Array = ["free_target", "queue_free_target", "free_prompt_ui", "queue_free_prompt_ui", "controller_leaves_tree",
		"queue_free_controller", "queue_free_map", "close_gather", "close_inventory"]
	for action: String in actions:
		await _load_map()
		await _stand("branch_pile_01")
		var inventory: InventoryService = _map.get("inventory")
		var gather: GatherService = _map.get("gather")
		var map: Node2D = _map
		var seen: Array = []
		var once: Array = [false]
		var breaker: Callable = func(_ids: Array[StringName], _revisions: Dictionary) -> void:
			if once[0]:
				return
			once[0] = true
			seen.append([inventory.count("player_bag", "wood").value, gather.query("branch_pile_01").value.remaining])
			match action:
				"free_target":
					map.get_node("GatheringPoints/BranchPile").free()
				"queue_free_target":
					map.get_node("GatheringPoints/BranchPile").queue_free()
				"free_prompt_ui":
					map.get_node("Interaction/InteractionUI").free()
				"queue_free_prompt_ui":
					map.get_node("Interaction/InteractionUI").queue_free()
				"controller_leaves_tree":
					map.player.remove_child(map.interaction)
				"queue_free_controller":
					map.interaction.queue_free()
				"queue_free_map":
					map.queue_free()
				"close_gather":
					gather.close()
				"close_inventory":
					inventory.close()
		inventory.inventories_changed.connect(breaker)
		var events_before: int = _events.size()
		await _press_e()
		await _ticks(4)
		inventory.inventories_changed.disconnect(breaker)
		var payouts: int = _events.size() - events_before
		_check("AC-G09", seen.size() == 1 and seen[0] == [9, 5] and payouts == 1 and not gather.has_pending_command(),
			"%s during the change signal: committed once %s, events %d" % [action, seen, payouts])
		_metrics["AC-G09 %s" % action] = str(seen)
		_log("AC-G09", "%s inside the commit signal: bag wood 9 / branch 5 once, later events 0" % action)
		if is_instance_valid(map) and not map.is_queued_for_deletion():
			# Untyped on purpose: the controller may already be freed by this case.
			var interaction: Variant = map.get("interaction")
			if is_instance_valid(interaction) and not (interaction as Node).is_inside_tree() \
					and not (interaction as Node).is_queued_for_deletion():
				(interaction as Node).free()
			await _unload_map()
		else:
			_map = null
			await _ticks(2)
	return true


func _g10_reentry() -> bool:
	await _load_map()
	await _stand("branch_pile_01")
	var inventory: InventoryService = _map.get("inventory")
	var gather: GatherService = _map.get("gather")
	var controller: InventoryController = _map.get("controller")
	var inside: Array = []
	var once: Array = [false]
	var probe_signal: Callable = func(_ids: Array[StringName], _revisions: Dictionary) -> void:
		if once[0]:
			return
		once[0] = true
		inside.append(gather.prepare("stone_pile_01", "player_bag", 900).code)
		_key(KEY_E, true)
		_key(KEY_E, false)
		_key(KEY_I, true)
		_key(KEY_I, false)
		inside.append(controller.get_state())
	inventory.inventories_changed.connect(probe_signal)
	var events_before: int = _events.size()
	await _press_e()
	await _ticks(5)
	inventory.inventories_changed.disconnect(probe_signal)
	_check("AC-G10", inside == [G.BUSY, InventoryController.State.CLOSED] and _events.size() - events_before == 1
		and inventory.count("player_bag", "wood").value == 9, "re-entrant prepare BUSY, E dropped, I refused: %s events %d" % [inside, _events.size() - events_before])
	# E from inside the completion report is dropped as well.
	var reporting_once: Array = [false]
	var on_done: Callable = func(_id: int, _t: StringName, _r: RefCounted) -> void:
		if reporting_once[0]:
			return
		reporting_once[0] = true
		_key(KEY_E, true)
		_key(KEY_E, false)
	(_map.get("interaction") as InteractionController).instant_completed.connect(on_done)
	events_before = _events.size()
	await _press_e()
	await _ticks(5)
	(_map.get("interaction") as InteractionController).instant_completed.disconnect(on_done)
	_check("AC-G10", _events.size() - events_before == 1, "E pressed in the completion report adds no next-tick gather (%d)" % (_events.size() - events_before))
	# Held E with echoes, and two presses in one tick: one gather each time.
	events_before = _events.size()
	_key(KEY_E, true)
	for index: int in 8:
		await physics_frame
		_key(KEY_E, true, true)
	_release_all()
	await _ticks(3)
	var held: int = _events.size() - events_before
	events_before = _events.size()
	_key(KEY_E, true)
	_key(KEY_E, false)
	_key(KEY_E, true)
	_key(KEY_E, false)
	await _ticks(3)
	var doubled: int = _events.size() - events_before
	events_before = _events.size()
	await _press_e()
	var fresh: int = _events.size() - events_before
	_check("AC-G10", held == 1 and doubled == 1 and fresh == 1, "held+echo %d, same-tick double %d, new press %d" % [held, doubled, fresh])
	_log("AC-G10", "inside commit: prepare=BUSY, E dropped, I refused (bag %s); report-time E dropped; held=%d double=%d fresh=%d" % [
		inside[1] if inside.size() > 1 else "-", held, doubled, fresh])
	await _unload_map()
	return true


func _g11_ui_and_movement() -> bool:
	await _load_map()
	var player: PlayerController = _map.get("player")
	var interaction: InteractionController = _map.get("interaction")
	var inventory: InventoryService = _map.get("inventory")
	var controller: InventoryController = _map.get("controller")
	var ui: InventoryUI = _map.get("ui")
	var hud: GatheringHUD = _map.get("hud")
	var opened: Array = [0]
	interaction.session_opened.connect(func(_id: int, _t: String, _d: String) -> void: opened[0] += 1)
	await _stand("branch_pile_01")
	var effective_inside: Array = []
	var sample: Callable = func(_ids: Array[StringName], _revisions: Dictionary) -> void:
		effective_inside.append(player.is_control_effective())
	inventory.inventories_changed.connect(sample)
	await _press_e()
	inventory.inventories_changed.disconnect(sample)
	_check("AC-G11", opened[0] == 0 and effective_inside == [true] and player.is_control_effective() and not controller.owns_movement_gate()
		and hud.get_toast() == "목재 1개를 얻었습니다 (남은 5)", "instant: no panel, no gate, toast '%s'" % hud.get_toast())
	# Bag open: E gathers nothing; after closing (keys neutral) gathering works again.
	await _tap(KEY_I)
	var events_before: int = _events.size()
	await _press_e()
	var while_bag: int = _events.size() - events_before
	var bag_model: String = str(ui.get("_model"))
	controller.request_open(InventoryController.View.STORE)
	await _ticks(1)
	var store_model: String = str(ui.get("_model"))
	await _tap(KEY_I)
	await _press_e()
	_check("AC-G11", while_bag == 0 and _events.size() - events_before == 1 and not bag_model.contains("stock_")
		and not store_model.contains("stock_") and store_model.contains("test_store"), "bag blocks gathering; stocks never shown in bag/store")
	# Inspect panel open: E is BUSY and gathers nothing; the crate grants nothing either.
	await _stand_at(Vector2(128, 360), "right")
	events_before = _events.size()
	await _press_e()
	var crate_open: bool = interaction.get_state() == InteractionController.State.ACTIVE
	await _press_e()
	await _tap(KEY_ESCAPE)
	_check("AC-G11", crate_open and _events.size() == events_before and opened[0] == 1, "crate inspect grants nothing; E while open BUSY")
	await _stand("branch_pile_01")
	events_before = _events.size()
	await _press_e()
	_check("AC-G11", _events.size() - events_before == 1 and player.is_control_effective(), "after closing the inspect panel gathering works")
	_log("AC-G11", "instant: session_opened 0, movement gate untouched, toast ok; bag/inspect block payouts; stocks hidden from bag UI")
	await _unload_map()
	return true


func _g12_rebind() -> bool:
	await _load_map()
	var gather: GatherService = _map.get("gather")
	await _stand("branch_pile_01")
	await _press_e()
	for index: int in 3:
		await _stand("berry_bush_01")
		await _press_e()
	var target: GatherTarget = _map.get_node("GatheringPoints/BranchPile")
	_check("AC-G12", target.try_begin(777), "a view-held command is prepared before the swap")
	var held_command: RefCounted = target.get_prepared_command(777)
	var before: Dictionary = _map.call("_point_values")
	var errors: PackedStringArray = _map.call("rebind_points")
	await _ticks(3)
	var after: Dictionary = _map.call("_point_values")
	var new_branch: GatherTarget = _map.get_node("GatheringPoints").get_child(0) as GatherTarget
	var berry_view: GatherTarget = _map.get_node("GatheringPoints").get_child(2) as GatherTarget
	_check("AC-G12", errors.is_empty() and before == after and before.branch_pile_01 == [5, 1] and before.berry_bush_01 == [0, 3]
		and (held_command.commit() as GatherService.Result).code == G.INVALID_COMMAND and new_branch.get_remaining() == 5
		and not berry_view.can_interact(), "rebind keeps values %s -> %s, no refill, old command dead" % [before, after])
	await _stand("branch_pile_01")
	await _press_e()
	_check("AC-G12", gather.query("branch_pile_01").value.remaining == 4, "the new view gathers from the same stock")
	# The rebind fixture swaps the view after the first gather on its own.
	await _unload_map()
	await _load_map("rebind")
	await _stand("branch_pile_01")
	await _press_e()
	await _ticks(3)
	var report: Dictionary = _map.get("rebind_report")
	_check("AC-G12", not report.is_empty() and report.before == report.after and report.after.branch_pile_01 == [5, 1],
		"rebind fixture report %s" % [report])
	# Session end: the old command is refused and queries are closed.
	var session_gather: GatherService = _map.get("gather")
	var late: GatherService.Result = session_gather.prepare("stone_pile_01", "player_bag", 1)
	await _unload_map()
	_check("AC-G12", (late.value as GatherService.GatherCommand).commit().code == G.CLOSED
		and session_gather.query("stone_pile_01").code == G.CLOSED, "after the session ends commands and queries are CLOSED")
	_log("AC-G12", "partial(5)/depleted(0) kept across rebind %s; view command INVALID_COMMAND; fixture report equal; session end CLOSED" % [after])
	return true


# --- harness ---------------------------------------------------------------------

func _item_records() -> Dictionary:
	var inventory: InventoryService = InventoryService.new(_item_catalog)
	var items: Dictionary = {}
	for item_id: StringName in inventory.get_item_ids():
		items[item_id] = inventory.get_item_info(item_id)
	return items


func _def(definition_id: String, overrides: Dictionary = {}) -> GatherDef:
	var definition: GatherDef = GatherDef.new()
	definition.definition_id = StringName(definition_id)
	definition.display_name = "시험"
	definition.action_label = "줍기"
	definition.item_id = &"wood"
	definition.initial_quantity = 2
	for key: String in overrides:
		definition.set(key, overrides[key])
	return definition


func _catalog_with(extra: GatherDef) -> GatherCatalog:
	var catalog: GatherCatalog = GatherCatalog.new()
	var definitions: Array = []
	for definition: GatherDef in _gather_catalog.definitions:
		definitions.append(definition)
	definitions.append(extra)
	catalog.definitions.assign(definitions)
	return catalog


func _bag_slots(spec: Array) -> Array:
	var slots: Array = []
	for entry: Variant in spec:
		slots.append(null if entry == null else {"item_id": entry[0], "quantity": entry[1]})
	while slots.size() < 12:
		slots.append(null)
	return slots


func _full_bag(wood: int) -> Array:
	var spec: Array = [["wood", wood]]
	for index: int in 11:
		spec.append(["stone", 10])
	return spec


func _snapshots(bag_spec: Array = [["wood", 8], ["stone", 10], ["tool_axe", 1]]) -> Array:
	return [
		{"inventory_id": "player_bag", "owner_id": "player_01", "capacity": 12, "revision": 0, "slots": _bag_slots(bag_spec)},
		{"inventory_id": "test_store", "owner_id": "fixture_store_01", "capacity": 12, "revision": 0, "slots": _bag_slots([])},
	]


func _session(bag_spec: Array = [["wood", 8], ["stone", 10], ["tool_axe", 1]]) -> Dictionary:
	var built: GatherService.Result = GatherService.build(_item_catalog, _gather_catalog, _snapshots(bag_spec), &"player_bag", BINDINGS)
	_check("AC-G01", built.ok, "session builds (%s)" % built.detail)
	var inventory: InventoryService = built.value.inventory
	inventory.inventories_changed.connect(func(ids: Array[StringName], revisions: Dictionary) -> void:
		_events.append([ids.duplicate(), revisions.duplicate()]))
	return built.value


func _gather_once(gather: GatherService, point_id: String, request_id: int) -> GatherService.Result:
	var prepared: GatherService.Result = gather.prepare(point_id, "player_bag", request_id)
	if not prepared.ok:
		return prepared
	return (prepared.value as GatherService.GatherCommand).commit()


func _all_snapshots(inventory: InventoryService) -> Dictionary:
	var out: Dictionary = {}
	for id: String in ALL_IDS:
		var snap: InventoryService.Result = inventory.snapshot(id)
		out[id] = snap.value if snap.ok else snap.code
	return out


func _totals(inventory: InventoryService) -> Dictionary:
	var totals: Dictionary = {}
	for item: String in ITEMS:
		var total: int = 0
		for id: String in ALL_IDS:
			total += int(inventory.count(id, item).value)
		totals[item] = total
	return totals


func _slots(snapshot: Dictionary) -> Array:
	var out: Array = []
	for stack: Variant in snapshot.slots:
		out.append("-" if stack == null else "%s%d" % [stack.item_id, stack.quantity])
	return out


func _load_map(fixture: String = "normal") -> void:
	# A map left behind by an aborted case would share the physics space and its targets.
	var leftovers: Array = root.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("GatheringTest"))
	_check("AC-G13", leftovers.is_empty(), "no gathering map may be left in the tree (%d)" % leftovers.size())
	for leftover: Node in leftovers:
		leftover.free()
	_map = (load(MAP_SCENE) as PackedScene).instantiate() as Node2D
	_map.set("fixture", fixture)
	root.add_child(_map)
	await process_frame
	_rec.clear()
	var interaction: InteractionController = _map.get("interaction")
	interaction.instant_completed.connect(func(id: int, target_id: StringName, result: RefCounted) -> void:
		_rec.append({"kind": "gathered", "id": id, "target": target_id, "code": result.get("code")}))
	interaction.request_rejected.connect(func(id: int, reason: StringName) -> void:
		_rec.append({"kind": "rejected", "id": id, "reason": reason}))
	(_map.get("inventory") as InventoryService).inventories_changed.connect(func(ids: Array[StringName], revisions: Dictionary) -> void:
		_events.append([ids.duplicate(), revisions.duplicate()]))
	await _ticks(4)


func _unload_map() -> void:
	_release_all()
	if is_instance_valid(_map):
		_map.queue_free()
	_map = null
	await process_frame
	await physics_frame


## Swaps the branch view for a probe whose on_begin runs `action(map)` inside try_begin.
func _install_probe(action: Callable) -> GatherTarget:
	var points: Node2D = (load(POINTS_SCENE) as PackedScene).instantiate() as Node2D
	var original: Node = points.get_node("BranchPile")
	var probe: GatherTarget = (load(POINT_SCENE) as PackedScene).instantiate() as GatherTarget
	probe.set_script(PROBE)
	probe.name = "BranchPile"
	probe.target_id = &"branch_pile_01"
	probe.position = (original as Node2D).position
	points.remove_child(original)
	original.free()
	points.add_child(probe)
	points.move_child(probe, 0)
	var map: Node2D = _map
	probe.set("on_begin", func() -> void: action.call(map))
	var errors: PackedStringArray = _map.call("rebind_points", points)
	_check("AC-G08", errors.is_empty(), "probe view binds (%s)" % [errors])
	await _ticks(2)
	return probe


func _probe_target() -> GatherTarget:
	return _map.get_node("GatheringPoints/BranchPile") as GatherTarget


func _stand(point_id: String) -> void:
	await _stand_at(STANDS[point_id][0], STANDS[point_id][1])


func _stand_at(position: Vector2, facing: String) -> void:
	_release_all()
	await physics_frame
	var player: PlayerController = _map.get("player")
	_key(FACING_KEYS[facing], true)
	await physics_frame
	_release_all()
	player.global_position = position
	player.velocity = Vector2.ZERO
	await _ticks(3)


func _press_e() -> void:
	_key(KEY_E, true)
	_key(KEY_E, false)
	await _ticks(3)


func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)
	await _ticks(2)


func _wall(map: Node2D, rect: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 2
	var shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	body.position = rect.get_center()
	map.add_child(body)


func _key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	if pressed and code not in _held:
		_held.append(code)
	elif not pressed:
		_held.erase(code)


func _release_all() -> void:
	for code: Key in _held.duplicate():
		_key(code, false)


func _ticks(count: int) -> void:
	for i: int in count:
		await physics_frame


func _since(mark: int, kind: String) -> Array:
	return _rec.slice(mark).filter(func(entry: Dictionary) -> bool: return entry.kind == kind)


func _all_released() -> bool:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"interact", &"inventory_toggle"]:
		if Input.is_action_pressed(action):
			return false
	return _held.is_empty()


func _compare_passes() -> void:
	var first: Dictionary = _pass_metrics[0]
	var second: Dictionary = _pass_metrics[1]
	var differences: PackedStringArray = []
	for key: String in first:
		if not second.has(key) or str(first[key]) != str(second[key]):
			differences.append("%s: %s vs %s" % [key, first[key], second.get(key)])
	_check("AC-G13", first.keys() == second.keys() and differences.is_empty(), "pass differences %s" % differences)
	_log("AC-G13", "passes=2 measurements=%d differences=%d" % [first.size(), differences.size()])


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
	print("IH-111 automated summary:")
	var keys: Array = _ac_checks.keys()
	keys.sort()
	for ac: String in keys:
		var counts: Array = _ac_checks[ac]
		print("  %s %s (%d checks, %d failed)" % [ac, "PASS" if counts[1] == 0 else "FAIL", counts[0], counts[1]])
	print("  Not covered here: real GUI use (AC-G14), code/doc review.")
	if _failures.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		for failure: String in _failures:
			print("  FAILED " + failure)
		print("RESULT: FAIL (%d)" % _failures.size())
		quit(1)
