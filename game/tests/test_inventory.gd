extends SceneTree
## IH-110 acceptance runner. Domain cases (AC-N01..09, N13) drive InventoryService directly
## and compare whole snapshots, revisions and event counts before/after every failure.
## Scene cases (AC-N10..12) use the real inventory_test map; keys go through
## Input.parse_input_event + flush (dispatched to the viewport like a window) and mouse
## clicks through the viewport. Exit 0 only when every automated check passes. Real GUI
## use (AC-N14) is never reported as passed here.

const CATALOG_PATH: String = "res://data/items/catalog.tres"
const MAP_SCENE: String = "res://scenes/tests/inventory_test.tscn"
const TARGET_SCENE: String = "res://scenes/interaction/interaction_target.tscn"
const PROBE: Script = preload("res://tests/support/probe_target.gd")
const FIXTURES: String = "res://tests/fixtures/inventory/"
const ITEM_ORDER: Array = [&"wood", &"stone", &"iron", &"wheat", &"berry", &"seed_wheat", &"tool_axe"]
const S := preload("res://systems/inventory/inventory_service.gd")
const IC := preload("res://scripts/inventory/inventory_controller.gd")
const SEED: int = 1101
## BUG-006: every character must match; no trimming or case folding merges IDs.
const BAD_IDS: Array = ["wood\n", "wood\r\n", "wo\nod", "\nwood", "wood ", " wood", "wo od", "wood\t", "wöod", "목재",
	"Wood", "1wood", "_wood", "wood-1", ""]
const GOOD_IDS: Array = ["a", "wood", "seed_wheat", "a0_9"]
const SEQUENCE_LENGTH: int = 400

var _ac_checks: Dictionary = {}
var _failures: Array[String] = []
var _held: Array[Key] = []
var _metrics: Dictionary = {}
var _pass_metrics: Array[Dictionary] = []
var _events: Array = []
var _catalog: ItemCatalog
var _map: Node2D
var _controller: InventoryController
var _ui: InventoryUI
var _service: InventoryService
var _player: PlayerController
var _interaction: InteractionController
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
	print("IH-110 runner: engine=%s" % Engine.get_version_info().string)
	_catalog = load(CATALOG_PATH) as ItemCatalog
	for pass_index: int in 2:
		_metrics = {}
		var steps: Array = [
			["AC-N01", _n01_definitions], ["AC-N02", _n02_registration], ["AC-N03", _n03_add],
			["AC-N04", _n04_add_failures], ["AC-N05", _n05_remove], ["AC-N06", _n06_transfer],
			["AC-N07", _n07_transfer_failures], ["AC-N08", _n08_stale_and_reentry], ["AC-N09", _n09_snapshot],
			["AC-N13", _n13_sequence], ["AC-N10", _n10_panel], ["AC-N11", _n11_exclusive], ["AC-N12", _n12_lifecycle], ["AC-N12", _n12_ui_service_lifecycle],
		]
		for step: Array in steps:
			# A script error aborts the coroutine and yields null instead of true.
			var completed: Variant = await (step[1] as Callable).call()
			_check(step[0], completed == true, "%s case list aborted before completion" % step[0])
		_check("AC-N13", _all_released(), "pass %d left a key pressed" % pass_index)
		_pass_metrics.append(_metrics)
	_compare_passes()
	await process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("AC-N13", orphans == 0, "orphan nodes after both passes: %d" % orphans)
	_log("AC-N13", "orphan nodes after both passes: %d" % orphans)
	if "--inject-failure" in OS.get_cmdline_user_args():
		_check("AC-N13", false, "deliberate failure requested by --inject-failure")
	var errors: PackedStringArray = _engine_errors.entries()
	OS.remove_logger(_engine_errors)
	_check("AC-N13", errors.is_empty(), "engine/script errors during the run: %s" % "; ".join(errors))
	_log("AC-N13", "engine/script errors logged during the run: %d" % errors.size())
	_finish()


# --- AC-N01 definitions ----------------------------------------------------------

func _n01_definitions() -> bool:
	var compiled: Dictionary = _catalog.compile()
	var order: Array = compiled.order
	_check("AC-N01", compiled.ok and order == ITEM_ORDER, "catalog order %s errors %s" % [order, compiled.errors])
	var records: Dictionary = compiled.records
	_check("AC-N01", compiled.ok and records[&"wood"].fallback_name == "목재" and records[&"wood"].stack_limit == 10
		and records[&"tool_axe"].stack_limit == 1 and records[&"seed_wheat"].category == &"seed", "record values")
	for item_id: StringName in ITEM_ORDER:
		var text: String = FileAccess.get_file_as_string("res://data/items/%s.tres" % item_id)
		_check("AC-N01", text.contains("stack_limit = "), "%s.tres states stack_limit explicitly" % item_id)
	# Format comparison: the same wood definition as .tres and as JSON.
	var resource: ItemDef = load("res://data/items/wood.tres") as ItemDef
	var json_ok: Dictionary = _json_record(FIXTURES + "wood.json")
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "wood.json"))
	var json_limit_type: int = typeof(raw.stack_limit)
	_check("AC-N01", json_ok.ok and json_ok.record == records[&"wood"], "JSON wood equals the .tres record after strict conversion")
	_check("AC-N01", typeof(resource.stack_limit) == TYPE_INT and json_limit_type == TYPE_FLOAT,
		"Resource keeps int, JSON parses stack_limit as float (%s)" % type_string(json_limit_type))
	var json_failures: Dictionary = {}
	for name: String in ["wood_fractional_limit", "wood_string_limit", "wood_missing_name", "wood_syntax_error"]:
		var outcome: Dictionary = _json_record(FIXTURES + name + ".json")
		json_failures[name] = outcome.error
		_check("AC-N01", not outcome.ok and not String(outcome.error).is_empty(), "%s rejected (%s)" % [name, outcome.error])
	_metrics["AC-N01 json"] = str(json_failures)
	_log("AC-N01", "catalog=%s; .tres stack_limit type=int; JSON stack_limit type=%s; JSON rejects=%s" % [
		order, type_string(json_limit_type), json_failures])
	# Invalid catalogs: one defect each, the whole catalog is rejected with a named cause.
	var cases: Array = [
		["null entry", func(defs: Array) -> void: defs.append(null), "null definition"],
		["duplicate id", func(defs: Array) -> void: defs.append(_def("wood")), "duplicate item_id"],
		["empty id", func(defs: Array) -> void: defs.append(_def("")), "invalid item_id"],
		["upper-case id", func(defs: Array) -> void: defs.append(_def("Wood2")), "invalid item_id"],
		["leading digit", func(defs: Array) -> void: defs.append(_def("1wood")), "invalid item_id"],
		["65 chars", func(defs: Array) -> void: defs.append(_def("a".repeat(65))), "invalid item_id"],
		["empty name_key", func(defs: Array) -> void: defs.append(_def("plank", {"name_key": &""})), "empty name_key"],
		["empty fallback", func(defs: Array) -> void: defs.append(_def("plank", {"fallback_name": " "})), "empty fallback_name"],
		["unknown category", func(defs: Array) -> void: defs.append(_def("plank", {"category": &"weapon"})), "unknown category"],
		["limit 0", func(defs: Array) -> void: defs.append(_def("plank", {"stack_limit": 0})), "stack_limit 0"],
		["limit 10000", func(defs: Array) -> void: defs.append(_def("plank", {"stack_limit": 10000})), "stack_limit 10000"],
	]
	for case: Array in cases:
		var bad: ItemCatalog = ItemCatalog.new()
		var defs: Array = []
		for item_id: StringName in ITEM_ORDER:
			defs.append(_def(String(item_id)))
		(case[1] as Callable).call(defs)
		bad.definitions.assign(defs)
		var result: Dictionary = bad.compile()
		var named: bool = "\n".join(result.errors).contains(case[2])
		var service: InventoryService = InventoryService.new(bad)
		var blocked: bool = service.register_inventory("bag", "player_01", 4).code == S.INVALID_CATALOG \
			and service.add("bag", "wood", 1, 0).code == S.INVALID_CATALOG
		_check("AC-N01", not result.ok and (result.records as Dictionary).is_empty() and named and blocked,
			"%s: ok %s errors %s blocked %s" % [case[0], result.ok, result.errors, blocked])
	_check("AC-N01", InventoryService.new(null).register_inventory("bag", "player_01", 1).code == S.INVALID_CATALOG, "null catalog blocks")
	_log("AC-N01", "invalid catalogs rejected as a whole: %d cases" % cases.size())
	var id_rejections: int = 0
	for bad_id: String in BAD_IDS + ["a".repeat(65)]:
		var rejected: bool = not ItemCatalog.is_valid_id(bad_id) and not ItemCatalog.is_valid_id(StringName(bad_id))
		var bad: ItemCatalog = ItemCatalog.new()
		bad.definitions.assign([_def("stone"), _def(bad_id)])
		var result: Dictionary = bad.compile()
		_check("AC-N01", rejected and not result.ok and (result.records as Dictionary).is_empty(),
			"item_id %s must be rejected (is_valid %s, compile ok %s)" % [bad_id.c_escape(), not rejected, result.ok])
		id_rejections += 1 if rejected and not result.ok else 0
	for good_id: String in GOOD_IDS + ["a".repeat(64)]:
		var good: ItemCatalog = ItemCatalog.new()
		good.definitions.assign([_def(good_id)])
		_check("AC-N01", ItemCatalog.is_valid_id(good_id) and good.compile().ok, "item_id %s stays valid" % good_id)
	_metrics["AC-N01 id rejections"] = id_rejections
	_log("AC-N01", "ID boundary: %d malformed IDs (LF/CRLF/inner newline/space/tab/non-ASCII/case/65 chars) rejected; 1- and 64-char IDs valid" % id_rejections)
	return true


## Strict JSON -> record conversion, the extra work JSON needs that typed Resources avoid.
func _json_record(path: String) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "error": "parse line %d: %s" % [json.get_error_line(), json.get_error_message()]}
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {"ok": false, "error": "not an object"}
	var keys: Array = (data as Dictionary).keys()
	keys.sort()
	if keys != ["category", "fallback_name", "item_id", "name_key", "stack_limit"]:
		return {"ok": false, "error": "keys %s" % [keys]}
	for key: String in ["category", "fallback_name", "item_id", "name_key"]:
		if typeof(data[key]) != TYPE_STRING:
			return {"ok": false, "error": "%s not a string" % key}
	var limit: Variant = data.stack_limit
	if typeof(limit) != TYPE_FLOAT or limit != floorf(limit):
		return {"ok": false, "error": "stack_limit not an integral number (%s)" % type_string(typeof(limit))}
	var record: Dictionary = {
		"item_id": StringName(data.item_id), "name_key": StringName(data.name_key),
		"fallback_name": String(data.fallback_name), "category": StringName(data.category), "stack_limit": int(limit),
	}
	return {"ok": true, "record": record, "error": ""}


func _def(item_id: String, overrides: Dictionary = {}) -> ItemDef:
	var definition: ItemDef = ItemDef.new()
	definition.item_id = StringName(item_id)
	definition.name_key = StringName("item.%s.name" % item_id)
	definition.fallback_name = "시험 " + item_id
	definition.category = &"material"
	definition.stack_limit = 1 if item_id == "tool_axe" else 10
	for key: String in overrides:
		definition.set(key, overrides[key])
	return definition


# --- AC-N02 registration and isolation -------------------------------------------

func _n02_registration() -> bool:
	var service: InventoryService = _new_service()
	var created: InventoryService.Result = service.register_inventory("player_bag", "player_01", 12)
	var snap: Dictionary = service.snapshot("player_bag").value
	_check("AC-N02", created.ok and snap.revision == 0 and snap.capacity == 12 and (snap.slots as Array).count(null) == 12, "empty 12-slot bag")
	for bad: Variant in [0, 257, 12.0, "12", true, -1]:
		_check("AC-N02", service.register_inventory("other_bag", "player_01", bad).code == S.INVALID_ARGUMENT, "capacity %s rejected" % [bad])
	for bad_id: Variant in ["Bag", "", "1bag", 7]:
		_check("AC-N02", service.register_inventory(bad_id, "player_01", 4).code == S.INVALID_ARGUMENT, "inventory id %s rejected" % [bad_id])
	service.add("player_bag", "wood", 3, 0)
	var before: Dictionary = service.snapshot("player_bag").value
	_check("AC-N02", service.register_inventory("player_bag", "someone_else", 4).code == S.DUPLICATE_INVENTORY
		and service.snapshot("player_bag").value == before, "duplicate inventory ID never overwrites")
	# Mutating a returned snapshot changes nothing inside.
	var copy: Dictionary = service.snapshot("player_bag").value
	copy.slots[0].quantity = 99
	copy.slots[5] = {"item_id": "iron", "quantity": 4}
	copy.revision = 42
	_check("AC-N02", service.snapshot("player_bag").value == before, "external snapshot edits are isolated")
	# Mutating the shared, cached ItemDef after the service compiled the catalog.
	var shared: ItemDef = load("res://data/items/wood.tres") as ItemDef
	var original_limit: int = shared.stack_limit
	var original_name: String = shared.fallback_name
	shared.stack_limit = 99
	shared.fallback_name = "변조"
	var spread: InventoryService.Result = service.add("player_bag", "wood", 15, 1)
	var after_mutation: Array = _slots(service, "player_bag")
	var name_after: String = service.get_item_info(&"wood").fallback_name
	shared.stack_limit = original_limit
	shared.fallback_name = original_name
	_check("AC-N02", spread.ok and after_mutation.slice(0, 3) == ["wood10", "wood8", "-"] and name_after == "목재",
		"edited shared ItemDef does not change limits/names: %s %s" % [after_mutation.slice(0, 3), name_after])
	# Two services and two inventories stay independent.
	var other: InventoryService = _new_service()
	other.register_inventory("player_bag", "player_01", 12)
	service.register_inventory("second_bag", "player_01", 4)
	service.add("second_bag", "stone", 2, 0)
	_check("AC-N02", _slots(other, "player_bag").count("-") == 12 and _slots(service, "player_bag").slice(0, 2) == ["wood10", "wood8"],
		"services and inventories are independent")
	_metrics["AC-N02 after mutation"] = str(after_mutation)
	var id_service: InventoryService = _new_service()
	_register(id_service, "keep", ["wood3", "-"])
	var kept: Dictionary = id_service.snapshot("keep").value
	var events_before: int = _events.size()
	for bad_id: String in BAD_IDS + ["a".repeat(65)]:
		var inventory_code: StringName = id_service.register_inventory(bad_id, "player_01", 2).code
		var owner_code: StringName = id_service.register_inventory("other_bag", bad_id, 2).code
		var add_code: StringName = id_service.add("keep", bad_id, 1, 0).code
		var count_code: StringName = id_service.count("keep", bad_id).code
		_check("AC-N02", [inventory_code, owner_code, add_code, count_code] == [S.INVALID_ARGUMENT, S.INVALID_ARGUMENT, S.INVALID_ARGUMENT, S.INVALID_ARGUMENT],
			"ID %s: register %s owner %s add %s count %s" % [bad_id.c_escape(), inventory_code, owner_code, add_code, count_code])
	_check("AC-N02", id_service.snapshot("keep").value == kept and id_service.snapshot("other_bag").code == S.INVENTORY_NOT_FOUND
		and _events.size() == events_before, "malformed IDs left inventories and events unchanged")
	_check("AC-N02", id_service.register_inventory("a".repeat(64), "a", 1).ok and id_service.snapshot("bag\n").code == S.INVALID_ARGUMENT,
		"64-char and 1-char IDs register; lookups with a trailing newline do not alias")
	_log("AC-N02", "malformed inventory/owner/item IDs -> INVALID_ARGUMENT on register/add/count, state unchanged")
	_log("AC-N02", "duplicate/invalid capacity rejected; snapshot edits isolated; shared ItemDef edit (limit 99) ignored -> %s" % [after_mutation.slice(0, 3)])
	return true


# --- AC-N03 add placement --------------------------------------------------------

func _n03_add() -> bool:
	var cases: Array = [
		["merge then empty slot", ["wood8", "stone10", "-"], "wood", 5, ["wood10", "stone10", "wood3"]],
		["several partial stacks", ["wood4", "-", "wood9", "stone10", "-"], "wood", 8, ["wood10", "wood1", "wood10", "stone10", "-"]],
		["limit 1 tools", ["-", "stone10", "-"], "tool_axe", 2, ["tool_axe1", "stone10", "tool_axe1"]],
		["large spread", ["-", "-", "-"], "berry", 25, ["berry10", "berry10", "berry5"]],
	]
	for case: Array in cases:
		var service: InventoryService = _new_service()
		_register(service, "box", case[1])
		var result: InventoryService.Result = service.add("box", case[2], case[3], 0)
		var after: Array = _slots(service, "box")
		_check("AC-N03", result.ok and after == case[4] and result.applied_quantity == case[3] and result.revisions == {"box": 1},
			"%s: %s -> %s" % [case[0], case[1], after])
		_metrics["AC-N03 %s" % case[0]] = str(after)
		_log("AC-N03", "%s: %s + %s%d -> %s" % [case[0], case[1], case[2], case[3], after])
	return true


# --- AC-N04 add failures ---------------------------------------------------------

func _n04_add_failures() -> bool:
	var service: InventoryService = _new_service()
	_register(service, "full", ["stone10", "wheat10"])
	_register(service, "almost", ["wood9", "stone10"])
	_register(service, "roomy", ["wood9", "-", "-"])
	var cases: Array = [
		["full inventory", "full", "wood", 1, 0, S.NO_SPACE],
		["wood9+2 with one unit of room", "almost", "wood", 2, 0, S.NO_SPACE],
		["quantity 0", "roomy", "wood", 0, 0, S.INVALID_ARGUMENT],
		["negative quantity", "roomy", "wood", -1, 0, S.INVALID_ARGUMENT],
		["above request ceiling", "roomy", "wood", S.MAX_REQUEST + 1, 0, S.INVALID_ARGUMENT],
		["unknown item", "roomy", "gold", 1, 0, S.UNKNOWN_ITEM],
		["float quantity", "roomy", "wood", 2.0, 0, S.INVALID_ARGUMENT],
		["bool quantity", "roomy", "wood", true, 0, S.INVALID_ARGUMENT],
		["string quantity", "roomy", "wood", "2", 0, S.INVALID_ARGUMENT],
		["float revision", "roomy", "wood", 1, 0.0, S.INVALID_ARGUMENT],
		["stale revision", "roomy", "wood", 1, 3, S.STALE_REVISION],
		["missing inventory", "nowhere", "wood", 1, 0, S.INVENTORY_NOT_FOUND],
		["bad item id format", "roomy", "Wood", 1, 0, S.INVALID_ARGUMENT],
	]
	for case: Array in cases:
		_frozen("AC-N04", case[0], service, ["full", "almost", "roomy"],
			func() -> InventoryService.Result: return service.add(case[1], case[2], case[3], case[4]), case[5])
	# Decision order when several conditions fail together.
	_frozen("AC-N04", "stale beats unknown item", service, ["roomy"],
		func() -> InventoryService.Result: return service.add("roomy", "gold", 1, 7), S.STALE_REVISION)
	_frozen("AC-N04", "argument beats missing inventory", service, ["roomy"],
		func() -> InventoryService.Result: return service.add("nowhere", "wood", 0, 0), S.INVALID_ARGUMENT)
	service.close()
	_frozen("AC-N04", "closed service", service, [],
		func() -> InventoryService.Result: return service.add("roomy", "wood", 1, 0), S.CLOSED)
	service.close()
	_check("AC-N04", service.snapshot("roomy").code == S.CLOSED and service.is_closed(), "reads closed too, double close harmless")
	_log("AC-N04", "%d add failures left slots/revision/events unchanged" % (cases.size() + 3))
	return true


# --- AC-N05 remove ---------------------------------------------------------------

func _n05_remove() -> bool:
	var service: InventoryService = _new_service()
	_register(service, "box", ["wood4", "wood3", "stone5"])
	var result: InventoryService.Result = service.remove("box", "wood", 5, 0)
	_check("AC-N05", result.ok and _slots(service, "box") == ["-", "wood2", "stone5"], "remove 5 from [wood4,wood3] -> %s" % [_slots(service, "box")])
	result = service.remove("box", "wood", 2, 1)
	_check("AC-N05", result.ok and _slots(service, "box") == ["-", "-", "stone5"], "remove exactly all")
	_frozen("AC-N05", "insufficient 8", service, ["box"],
		func() -> InventoryService.Result: return service.remove("box", "stone", 8, 2), S.INSUFFICIENT_QUANTITY)
	_frozen("AC-N05", "valid but not held", service, ["box"],
		func() -> InventoryService.Result: return service.remove("box", "iron", 1, 2), S.INSUFFICIENT_QUANTITY)
	_frozen("AC-N05", "unknown item", service, ["box"],
		func() -> InventoryService.Result: return service.remove("box", "gold", 1, 2), S.UNKNOWN_ITEM)
	_check("AC-N05", service.count("box", "stone").value == 5, "other items untouched")
	_log("AC-N05", "[wood4,wood3]-5 -> [-,wood2]; exact removal leaves no 0 stack; shortfall/unheld/unknown unchanged")
	return true


# --- AC-N06 transfer -------------------------------------------------------------

func _n06_transfer() -> bool:
	var service: InventoryService = _new_service()
	_register(service, "bag", ["wood8", "stone10", "tool_axe1", "-"])
	_register(service, "store", ["wood7", "seed_wheat4", "wood9", "-"])
	var totals: Dictionary = _totals(service, ["bag", "store"])
	var seen: Array = []
	var observer: Callable = func(ids: Array[StringName], revisions: Dictionary) -> void:
		seen.append({"ids": ids.map(func(id: StringName) -> String: return String(id)), "revisions": revisions.duplicate(), "totals": _totals(service, ["bag", "store"]),
			"bag": _slots(service, "bag"), "store": _slots(service, "store")})
	service.inventories_changed.connect(observer)
	var moves: Array = [
		["bag->store partial", "bag", 0, "store", 5, ["wood3", "stone10", "tool_axe1", "-"], ["wood10", "seed_wheat4", "wood10", "wood1"]],
		["store->bag full slot", "store", 2, "bag", 10, ["wood10", "stone10", "tool_axe1", "wood3"], ["wood10", "seed_wheat4", "-", "wood1"]],
		["bag->store tool", "bag", 2, "store", 1, ["wood10", "stone10", "-", "wood3"], ["wood10", "seed_wheat4", "tool_axe1", "wood1"]],
	]
	var ok: bool = true
	for move: Array in moves:
		var before_revisions: Array = [service.snapshot(move[1]).value.revision, service.snapshot(move[3]).value.revision]
		var count_before: int = seen.size()
		var result: InventoryService.Result = service.transfer(move[1], move[2], move[3], move[4], before_revisions[0], before_revisions[1])
		var event: Dictionary = seen[seen.size() - 1] if seen.size() > count_before else {}
		var expected_ids: Array = ["bag", "store"]
		var good: bool = result.ok and seen.size() == count_before + 1 and event.ids == expected_ids \
			and result.revisions == {move[1]: before_revisions[0] + 1, move[3]: before_revisions[1] + 1} \
			and event.totals == totals and _slots(service, "bag") == move[5] and _slots(service, "store") == move[6] \
			and event.bag == move[5] and event.store == move[6]
		ok = ok and good
		_check("AC-N06", good, "%s: %s bag %s store %s" % [move[0], result.code, _slots(service, "bag"), _slots(service, "store")])
		_log("AC-N06", "%s: bag=%s store=%s revisions=%s callback saw final both=%s" % [move[0], _slots(service, "bag"),
			_slots(service, "store"), result.revisions, event.get("bag") == move[5] and event.get("store") == move[6]])
	_check("AC-N06", _totals(service, ["bag", "store"]) == totals, "per-item totals conserved %s" % [totals])
	_metrics["AC-N06 final"] = str([_slots(service, "bag"), _slots(service, "store")])
	return true


# --- AC-N07 transfer failures ----------------------------------------------------

func _n07_transfer_failures() -> bool:
	var service: InventoryService = _new_service()
	_register(service, "bag", ["wood8", "-", "wood9"])
	_register(service, "store", ["stone10", "wheat10", "berry10"])
	_register(service, "roomy", ["-", "-", "-"])
	var ids: Array = ["bag", "store", "roomy"]
	var cases: Array = [
		["destination NO_SPACE", "bag", 0, "store", 1, 0, 0, S.NO_SPACE],
		["empty source slot", "bag", 1, "roomy", 1, 0, 0, S.EMPTY_SLOT],
		["slot -1", "bag", -1, "roomy", 1, 0, 0, S.INVALID_SLOT],
		["slot past capacity", "bag", 3, "roomy", 1, 0, 0, S.INVALID_SLOT],
		["same inventory", "bag", 0, "bag", 1, 0, 0, S.SAME_INVENTORY],
		["missing source", "nowhere", 0, "roomy", 1, 0, 0, S.INVENTORY_NOT_FOUND],
		["missing destination", "bag", 0, "nowhere", 1, 0, 0, S.INVENTORY_NOT_FOUND],
		["more than the slot (other slot has enough)", "bag", 0, "roomy", 12, 0, 0, S.INSUFFICIENT_QUANTITY],
		["float slot", "bag", 0.0, "roomy", 1, 0, 0, S.INVALID_ARGUMENT],
		["stale source", "bag", 0, "roomy", 1, 1, 0, S.STALE_REVISION],
		["stale destination", "bag", 0, "roomy", 1, 0, 1, S.STALE_REVISION],
		["stale beats no space", "bag", 0, "store", 1, 5, 0, S.STALE_REVISION],
		["same inventory beats stale", "bag", 0, "bag", 1, 5, 5, S.SAME_INVENTORY],
	]
	for case: Array in cases:
		_frozen("AC-N07", case[0], service, ids,
			func() -> InventoryService.Result: return service.transfer(case[1], case[2], case[3], case[4], case[5], case[6]), case[7])
	_log("AC-N07", "%d transfer failures: both sides, revisions and events unchanged; no other slot drawn" % cases.size())
	return true


# --- AC-N08 stale requests and re-entry ------------------------------------------

func _n08_stale_and_reentry() -> bool:
	var service: InventoryService = _new_service()
	_register(service, "bag", ["wood8", "-"])
	_register(service, "store", ["-", "-"])
	var first: InventoryService.Result = service.transfer("bag", 0, "store", 1, 0, 0)
	_frozen("AC-N08", "same expected revisions again", service, ["bag", "store"],
		func() -> InventoryService.Result: return service.transfer("bag", 0, "store", 1, 0, 0), S.STALE_REVISION)
	service.add("store", "stone", 1, 1)
	_frozen("AC-N08", "only the destination moved on", service, ["bag", "store"],
		func() -> InventoryService.Result: return service.transfer("bag", 0, "store", 1, 1, 1), S.STALE_REVISION)
	var fresh: InventoryService.Result = service.transfer("bag", 0, "store", 1, 1, 2)
	_check("AC-N08", first.ok and fresh.ok and _slots(service, "bag")[0] == "wood6", "fresh revisions are a new valid command")
	# A write from inside the change callback is refused, never queued or retried.
	var nested: Array = []
	var reentry: Callable = func(_ids: Array[StringName], revisions: Dictionary) -> void:
		nested.append(service.transfer("bag", 0, "store", 1, revisions.get("bag", 0), revisions.get("store", 0)).code)
		nested.append(service.add("bag", "wood", 1, revisions.get("bag", 0)).code)
		nested.append(service.snapshot("bag").code)
	service.inventories_changed.connect(reentry)
	var outer: InventoryService.Result = service.transfer("bag", 0, "store", 1, 2, 3)
	service.inventories_changed.disconnect(reentry)
	var bag_after: Array = _slots(service, "bag")
	var events_before: int = _events.size()
	await _ticks(3)
	_check("AC-N08", outer.ok and nested == [S.BUSY, S.BUSY, S.OK] and bag_after[0] == "wood5" and _events.size() == events_before,
		"re-entrant writes BUSY, reads allowed, nothing retried later: %s" % [nested])
	_log("AC-N08", "repeat=STALE_REVISION; destination-only stale=STALE_REVISION; fresh ok; nested writes=%s; later retries=0" % [nested])
	return true


# --- AC-N09 snapshots ------------------------------------------------------------

func _n09_snapshot() -> bool:
	var service: InventoryService = _new_service()
	_register(service, "bag", ["wood10", "-", "tool_axe1"])
	service.add("bag", "berry", 3, 0)
	var original: Dictionary = service.snapshot("bag").value
	var copy: Dictionary = original.duplicate(true)
	var decoded: InventoryService.Result = service.decode_snapshot(copy)
	var round_trip: Dictionary = (decoded.value as InventoryState).to_snapshot() if decoded.ok else {}
	copy.slots[0].quantity = 1
	_check("AC-N09", decoded.ok and round_trip == original and round_trip.revision == 1, "memory round trip keeps layout and revision")
	_check("AC-N09", _plain(original), "snapshot holds only String/int/null/Array/Dictionary values")
	_check("AC-N09", (decoded.value as InventoryState).to_snapshot() == original, "decoded state is independent of the edited copy")
	var other: InventoryService = _new_service()
	var registered: InventoryService.Result = other.register_snapshot(original)
	_check("AC-N09", registered.ok and other.snapshot("bag").value == original, "valid snapshot registers as a fresh copy")
	var corruptions: Array = [
		["missing key", func(d: Dictionary) -> void: d.erase("owner_id")],
		["extra key", func(d: Dictionary) -> void: d["note"] = "x"],
		["slots too short", func(d: Dictionary) -> void: (d.slots as Array).pop_back()],
		["capacity 0", func(d: Dictionary) -> void: d.capacity = 0],
		["bad inventory id", func(d: Dictionary) -> void: d.inventory_id = "Bag"],
		["unknown item", func(d: Dictionary) -> void: d.slots[0] = {"item_id": "gold", "quantity": 1}],
		["quantity 0", func(d: Dictionary) -> void: d.slots[0] = {"item_id": "wood", "quantity": 0}],
		["over stack limit", func(d: Dictionary) -> void: d.slots[0] = {"item_id": "wood", "quantity": 11}],
		["float quantity", func(d: Dictionary) -> void: d.slots[0] = {"item_id": "wood", "quantity": 10.0}],
		["negative revision", func(d: Dictionary) -> void: d.revision = -1],
		["float revision", func(d: Dictionary) -> void: d.revision = 1.0],
		["stack extra key", func(d: Dictionary) -> void: d.slots[2] = {"item_id": "tool_axe", "quantity": 1, "quality": 3}],
		["slot not a Dictionary", func(d: Dictionary) -> void: d.slots[1] = "wood"],
		["not a Dictionary", func(_d: Dictionary) -> void: pass],
	]
	for case: Array in corruptions:
		var data: Variant = original.duplicate(true)
		(case[1] as Callable).call(data)
		if case[0] == "not a Dictionary":
			data = [data]
		var target: InventoryService = _new_service()
		_register(target, "keep", ["stone3", "-"])
		var before: Dictionary = target.snapshot("keep").value
		var decode_code: StringName = target.decode_snapshot(data).code
		var register_code: StringName = target.register_snapshot(data).code
		_check("AC-N09", decode_code == S.INVALID_SNAPSHOT and register_code == S.INVALID_SNAPSHOT
			and target.snapshot("keep").value == before and target.snapshot("bag").code == S.INVENTORY_NOT_FOUND,
			"%s rejected without side effects (%s/%s)" % [case[0], decode_code, register_code])
	var holder: InventoryService = _new_service()
	_register(holder, "bag", ["stone3", "-", "-"])
	var kept: Dictionary = holder.snapshot("bag").value
	_check("AC-N09", holder.register_snapshot(original).code == S.DUPLICATE_INVENTORY and holder.snapshot("bag").value == kept,
		"a valid snapshot never overwrites a live inventory")
	for field: String in ["inventory_id", "owner_id", "item_id"]:
		for bad_id: String in ["bag\n", "bag\r\n", "b ag", "bäg"]:
			var data: Dictionary = original.duplicate(true)
			if field == "item_id":
				data.slots[0] = {"item_id": bad_id.replace("bag", "wood"), "quantity": 1}
			else:
				data[field] = bad_id
			var target: InventoryService = _new_service()
			_register(target, "keep", ["stone3", "-"])
			var before_keep: Dictionary = target.snapshot("keep").value
			_check("AC-N09", target.register_snapshot(data).code == S.INVALID_SNAPSHOT and target.snapshot("keep").value == before_keep,
				"snapshot %s %s rejected" % [field, bad_id.c_escape()])
	_log("AC-N09", "snapshot inventory_id/owner_id/item_id with newline/space/non-ASCII rejected")
	_log("AC-N09", "round trip equal (revision %d); %d corruptions rejected; duplicate ID not overwritten" % [round_trip.get("revision", -1), corruptions.size()])
	return true


func _plain(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_STRING, TYPE_INT:
			return true
		TYPE_ARRAY:
			return (value as Array).all(func(entry: Variant) -> bool: return _plain(entry))
		TYPE_DICTIONARY:
			for key: Variant in value:
				if typeof(key) != TYPE_STRING or not _plain(value[key]):
					return false
			return true
	return false


# --- AC-N13 seeded sequence --------------------------------------------------------

func _n13_sequence() -> bool:
	var outcomes: Array = []
	for attempt: int in 2:
		outcomes.append(_run_sequence())
	_check("AC-N13", outcomes[0] == outcomes[1], "same seed, same final snapshots and result codes")
	_metrics["AC-N13 sequence"] = str(outcomes[0].hash())
	_log("AC-N13", "seed=%d ops=%d codes=%s final_hash=%d (repeated identically)" % [SEED, SEQUENCE_LENGTH,
		outcomes[0].codes, str(outcomes[0].final).hash()])
	return true


## Random add/remove/transfer with occasional stale revisions, checked against an
## independent per-item counts model and the slot invariants after every command.
func _run_sequence() -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var service: InventoryService = _new_service()
	var ids: Array = ["bag", "store"]
	for id: String in ids:
		service.register_inventory(id, "owner_" + id, 6)
	var model: Dictionary = {"bag": {}, "store": {}}
	var events: Array = [0]
	service.inventories_changed.connect(func(_c: Array[StringName], _r: Dictionary) -> void: events[0] += 1)
	var codes: Dictionary = {}
	var violations: PackedStringArray = []
	for step: int in SEQUENCE_LENGTH:
		var before: Dictionary = {"bag": service.snapshot("bag").value, "store": service.snapshot("store").value}
		var events_before: int = events[0]
		var op: int = rng.randi_range(0, 2)
		var target: String = ids[rng.randi_range(0, 1)]
		var other: String = "store" if target == "bag" else "bag"
		var item: StringName = ITEM_ORDER[rng.randi_range(0, ITEM_ORDER.size() - 1)]
		var quantity: int = rng.randi_range(1, 14)
		var stale: bool = rng.randf() < 0.1
		var revision: int = before[target].revision + (1 if stale else 0)
		var result: InventoryService.Result
		var moved_item: StringName = &""
		match op:
			0:
				result = service.add(target, item, quantity, revision)
			1:
				result = service.remove(target, item, quantity, revision)
			2:
				var slot: int = rng.randi_range(0, 5)
				var stack: Variant = before[target].slots[slot]
				moved_item = StringName(stack.item_id) if stack != null else &""
				result = service.transfer(target, slot, other, quantity, revision, before[other].revision)
		codes[result.code] = int(codes.get(result.code, 0)) + 1
		if result.ok:
			match op:
				0:
					model[target][item] = int(model[target].get(item, 0)) + quantity
				1:
					model[target][item] = int(model[target].get(item, 0)) - quantity
				2:
					model[target][moved_item] = int(model[target].get(moved_item, 0)) - quantity
					model[other][moved_item] = int(model[other].get(moved_item, 0)) + quantity
			var changed: Array = [target] if op != 2 else ids
			for id: String in ids:
				var expected_revision: int = before[id].revision + (1 if id in changed else 0)
				if service.snapshot(id).value.revision != expected_revision:
					violations.append("step %d %s revision" % [step, id])
			if events[0] != events_before + 1:
				violations.append("step %d event count" % step)
		else:
			for id: String in ids:
				if service.snapshot(id).value != before[id]:
					violations.append("step %d failure changed %s" % [step, id])
			if events[0] != events_before:
				violations.append("step %d failure emitted" % step)
		for id: String in ids:
			var snap: Dictionary = service.snapshot(id).value
			if (snap.slots as Array).size() != 6:
				violations.append("step %d %s length" % [step, id])
			for stack: Variant in snap.slots:
				if stack != null and (stack.quantity < 1 or stack.quantity > service.get_item_info(StringName(stack.item_id)).stack_limit):
					violations.append("step %d %s stack %s" % [step, id, stack])
			for item_id: StringName in ITEM_ORDER:
				if service.count(id, item_id).value != int(model[id].get(item_id, 0)):
					violations.append("step %d %s count %s" % [step, id, item_id])
	_check("AC-N13", violations.is_empty(), "sequence invariants: %s" % ", ".join(violations.slice(0, 5)))
	var successes: int = SEQUENCE_LENGTH - codes.keys().filter(func(c: StringName) -> bool: return c != S.OK).reduce(
		func(total: int, c: StringName) -> int: return total + int(codes[c]), 0)
	_check("AC-N13", successes > 50 and codes.has(S.NO_SPACE) and codes.has(S.STALE_REVISION) and codes.has(S.INSUFFICIENT_QUANTITY),
		"sequence exercised successes and failures %s" % [codes])
	return {"codes": codes, "final": [service.snapshot("bag").value, service.snapshot("store").value]}


# --- AC-N10 panel and store --------------------------------------------------------

func _n10_panel() -> bool:
	await _load_map()
	var initial: Dictionary = {"bag": _service.snapshot("player_bag").value, "store": _service.snapshot("test_store").value}
	var setup_errors: PackedStringArray = _map.get("setup_errors")
	_check("AC-N10", setup_errors.is_empty() and initial.bag.revision == 0
		and _slots(_service, "player_bag").slice(0, 3) == ["wood8", "stone10", "tool_axe1"]
		and _slots(_service, "test_store").slice(0, 2) == ["wood7", "seed_wheat4"], "map registers the fixture once")
	var mark: int = _rec.size()
	await _tap(KEY_I)
	var opened_bag: bool = _controller.get_state() == IC.State.OPEN and _ui.is_open() and _controller.get_view() == IC.View.BAG
	await _tap(KEY_I)
	await _tap(KEY_I)
	await _tap(KEY_I)
	var reopen_same: bool = _service.snapshot("player_bag").value == initial.bag and _service.snapshot("test_store").value == initial.store
	_check("AC-N10", opened_bag and _since(mark, "opened").size() == 2 and _since(mark, "closed").size() == 2 and reopen_same,
		"I opens/closes the bag; reopening grants nothing")
	# Store via the HUD button (mouse), bag slot 0 selected by keyboard, one wood moved.
	await _click(_map.get_node("FixtureHud/StoreButton") as Control)
	var store_open: bool = _controller.get_state() == IC.State.OPEN and _controller.get_view() == IC.View.STORE
	await _tap(KEY_ENTER)
	await _click(_ui.get_node("Panel/Layout/Actions/MoveOne") as Control)
	var after_one: Array = [_slots(_service, "player_bag")[0], _slots(_service, "test_store")[0]]
	# Whole stack from the store's first slot back to the bag (mouse).
	await _click(_slot_button("store", 0))
	await _click(_ui.get_node("Panel/Layout/Actions/MoveStack") as Control)
	var bag_after: Array = _slots(_service, "player_bag")
	var store_after: Array = _slots(_service, "test_store")
	var wood_total: int = _service.count("player_bag", "wood").value + _service.count("test_store", "wood").value
	_check("AC-N10", store_open and after_one == ["wood7", "wood8"] and bag_after.slice(0, 4) == ["wood10", "stone10", "tool_axe1", "wood5"]
		and store_after[0] == "-" and wood_total == 15 and _totals_text().contains("목재 15"),
		"store moves: one %s, stack bag %s store %s total %d" % [after_one, bag_after.slice(0, 4), store_after.slice(0, 2), wood_total])
	_log("AC-N10", "HUD store opened=%s; one wood -> %s; store stack -> bag %s; wood total %d; HUD '%s'" % [
		store_open, after_one, bag_after.slice(0, 4), wood_total, _totals_text()])
	# Stale UI intents: old session, changed selection, old revision. Nothing applies or retries.
	var session: int = _controller.get_session_id()
	var bag_rev: int = _service.snapshot("player_bag").value.revision
	var store_rev: int = _service.snapshot("test_store").value.revision
	var stale_cases: Array = [
		["old session", session - 1, &"player_bag", 0, &"wood", 1, bag_rev, store_rev, IC.STALE_SESSION],
		["changed selection", session, &"player_bag", 0, &"stone", 1, bag_rev, store_rev, IC.SELECTION_CHANGED],
		["old revision", session, &"player_bag", 0, &"wood", 1, bag_rev - 1, store_rev, S.STALE_REVISION],
	]
	for case: Array in stale_cases:
		var before: Array = [_service.snapshot("player_bag").value, _service.snapshot("test_store").value]
		var events_before: int = _events.size()
		mark = _rec.size()
		_ui.transfer_requested.emit(case[1], case[2], case[3], case[4], case[5], case[6], case[7])
		await _ticks(3)
		var finished: Array = _since(mark, "finished")
		var unchanged: bool = [_service.snapshot("player_bag").value, _service.snapshot("test_store").value] == before
		var message: String = (_ui.get_node("Panel/Layout/Message") as Label).text
		_check("AC-N10", finished.size() == 1 and finished[0].code == case[8] and unchanged and _events.size() == events_before,
			"%s: %s unchanged %s events +%d" % [case[0], finished, unchanged, _events.size() - events_before])
		_metrics["AC-N10 %s" % case[0]] = String(finished[0].code) if finished.size() > 0 else "-"
		_log("AC-N10", "%s -> %s, state unchanged, message '%s'" % [case[0], finished[0].code if finished.size() > 0 else "-", message])
	# A full store: the move fails with a message and both sides keep their quantities.
	var store_snap: Dictionary = _service.snapshot("test_store").value
	var revision: int = store_snap.revision
	for index: int in (store_snap.slots as Array).size():
		if store_snap.slots[index] == null:
			_service.add("test_store", "stone", 10, revision)
			revision += 1
	await _ticks(1)
	await _click(_slot_button("bag", 0))
	var before_full: Array = [_service.snapshot("player_bag").value, _service.snapshot("test_store").value]
	mark = _rec.size()
	await _click(_ui.get_node("Panel/Layout/Actions/MoveOne") as Control)
	var full_result: Array = _since(mark, "finished")
	var full_message: String = (_ui.get_node("Panel/Layout/Message") as Label).text
	_check("AC-N10", full_result.size() == 1 and full_result[0].code == S.NO_SPACE and full_message.contains("공간")
		and [_service.snapshot("player_bag").value, _service.snapshot("test_store").value] == before_full,
		"full store refuses with a message: %s '%s'" % [full_result, full_message])
	_log("AC-N10", "full store: %s, message '%s', both unchanged" % [full_result[0].code if full_result.size() > 0 else "-", full_message])
	await _tap(KEY_ESCAPE)
	var ui_source: String = FileAccess.get_file_as_string("res://ui/inventory/inventory_ui.gd")
	_check("AC-N10", not ui_source.contains("InventoryService") and not ui_source.contains("set_control_enabled")
		and not ui_source.contains("_service"), "UI script has no service or gate access")
	await _end_case("AC-N10")
	await _unload_map()
	return true


# --- AC-N11 exclusive panels and key routing ---------------------------------------

func _n11_exclusive() -> bool:
	await _load_map()
	# Inspect panel ACTIVE: I is refused and the session stays.
	await _press_world(KEY_E)
	var mark: int = _rec.size()
	await _tap(KEY_I)
	var refused: Array = _since(mark, "rejected")
	_check("AC-N11", refused.size() == 1 and refused[0].reason == IC.INTERACTION_BUSY and not _ui.is_open()
		and _interaction.get_state() == InteractionController.State.ACTIVE and not _player.is_control_effective(),
		"I during an open inspect panel: %s" % [refused])
	await _press_world(KEY_ESCAPE)
	await _ticks(2)
	# RESOLVING: the target presses I from inside try_begin.
	var press_i: Callable = func() -> void:
		_key(KEY_I, true)
		_key(KEY_I, false)
	var probe: InteractionTarget = _probe("probe_resolving", Vector2(128, 375), press_i)
	await _ticks(4)
	mark = _rec.size()
	await _press_world(KEY_E)
	var resolving_refused: Array = _since(mark, "rejected")
	var inspect_open: bool = _interaction.get_state() == InteractionController.State.ACTIVE
	_check("AC-N11", resolving_refused.size() == 1 and resolving_refused[0].reason == IC.INTERACTION_BUSY and inspect_open and not _ui.is_open(),
		"I during RESOLVING refused, only the inspect panel opens: %s" % [resolving_refused])
	await _press_world(KEY_ESCAPE)
	probe.queue_free()
	await _ticks(3)
	# E queued, then I in the same frame: the bag discards the queued E.
	var interaction_rejects: Array = []
	var collect: Callable = func(id: int, reason: StringName) -> void: interaction_rejects.append(reason)
	_interaction.request_rejected.connect(collect)
	var opened_sessions: Array = [0]
	var count_open: Callable = func(_id: int, _t: String, _d: String) -> void: opened_sessions[0] += 1
	_interaction.session_opened.connect(count_open)
	_key(KEY_E, true)
	_key(KEY_E, false)
	_key(KEY_I, true)
	_key(KEY_I, false)
	await _ticks(3)
	_check("AC-N11", _ui.is_open() and interaction_rejects == [InteractionController.DISABLED] and opened_sessions[0] == 0,
		"same-frame E then I: E dropped (%s), bag open" % [interaction_rejects])
	# Inside the bag: E/echo do nothing in the world; Escape closes once; repeats are harmless.
	interaction_rejects.clear()
	mark = _rec.size()
	await _tap(KEY_E)
	_key(KEY_I, true, true)
	await _ticks(2)
	var still_open: bool = _ui.is_open()
	await _tap(KEY_ESCAPE)
	await _tap(KEY_ESCAPE)
	await _ticks(2)
	_check("AC-N11", still_open and interaction_rejects.is_empty() and opened_sessions[0] == 0 and _since(mark, "closed").size() == 1
		and _player.is_control_effective() and _interaction.is_interaction_enabled(),
		"in-bag E/echo ignored, Escape closes once, gate and interaction restored")
	# Focused Button: I and Escape still reach the single route.
	for key: Key in [KEY_I, KEY_ESCAPE]:
		await _tap(KEY_I)
		var focus: Control = root.gui_get_focus_owner()
		(_ui.get_node("Panel/Layout/Actions/Close") as Button).grab_focus()
		mark = _rec.size()
		await _tap(key)
		_check("AC-N11", focus is Button and _since(mark, "closed").size() == 1 and not _ui.is_open() and interaction_rejects.is_empty(),
			"%s on a focused Button closes once" % OS.get_keycode_string(key))
	# One I press is one command (never open-and-close in the same event).
	mark = _rec.size()
	await _tap(KEY_I)
	_check("AC-N11", _since(mark, "opened").size() == 1 and _since(mark, "closed").is_empty() and _ui.is_open(), "one press, one open")
	await _tap(KEY_I)
	_interaction.request_rejected.disconnect(collect)
	_interaction.session_opened.disconnect(count_open)
	_log("AC-N11", "active inspect: %s; resolving: %s; same-frame E->I: E=%s; in-bag E world events=0; focused Button I/Escape close once" % [
		refused[0].reason if refused.size() > 0 else "-", resolving_refused[0].reason if resolving_refused.size() > 0 else "-",
		InteractionController.DISABLED])
	await _end_case("AC-N11")
	await _unload_map()
	return true


# --- AC-N12 movement, focus and lifecycle --------------------------------------------

func _n12_lifecycle() -> bool:
	await _load_map()
	# Walking into the bag: stop at once, held keys do nothing until released.
	_press([KEY_S])
	await _ticks(5)
	await _tap(KEY_I)
	var stopped: bool = _player.velocity == Vector2.ZERO
	var at: Vector2 = _player.global_position
	await _ticks(10)
	var drift: float = _player.global_position.distance_to(at)
	await _tap(KEY_I)
	await _ticks(10)
	var held_move: float = _player.global_position.distance_to(at)
	_release_all()
	await _ticks(1)
	_press([KEY_S])
	await _ticks(10)
	var resumed: float = _player.global_position.distance_to(at)
	_release_all()
	_check("AC-N12", stopped and drift == 0.0 and held_move == 0.0 and resumed > 10.0,
		"walk->bag: stop %s drift %.4f held %.4f resumed %.4f" % [stopped, drift, held_move, resumed])
	# Opposite keys held through close: neutral needs both released.
	await _tap(KEY_I)
	_press([KEY_A, KEY_D])
	await _tap(KEY_I)
	_key(KEY_A, false)
	await _ticks(2)
	var one_left: bool = _player.is_control_effective()
	_key(KEY_D, false)
	await _ticks(2)
	_check("AC-N12", not one_left and _player.is_control_effective(), "A+D held: blocked until both released")
	_log("AC-N12", "walking open velocity0=%s drift=%.4f held_after_close=%.4f resumed=%.4f opposite_keys_blocked=%s" % [
		stopped, drift, held_move, resumed, not one_left])
	# Focus out closes; focus in reopens nothing.
	await _tap(KEY_I)
	var mark: int = _rec.size()
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _ticks(1)
	var focus_closed: Array = _since(mark, "closed")
	root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _ticks(3)
	_check("AC-N12", focus_closed.size() == 1 and focus_closed[0].reason == IC.FOCUS_LOST and not _ui.is_open()
		and _since(mark, "opened").is_empty() and _player.is_control_effective(), "focus out closes, focus in does not reopen")
	# Notifications before ready on a fresh coordinator.
	var early: InventoryController = InventoryController.new()
	early.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	early.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_map.add_child(early)
	await _ticks(1)
	var early_ok: bool = early.get_state() == IC.State.CLOSED and early.request_open(IC.View.BAG) == IC.NOT_READY
	early.queue_free()
	await _ticks(1)
	_check("AC-N12", early_ok, "pre-ready notifications and an unwired coordinator stay closed")
	# Cancelled while opening: callbacks fired by disabling interaction take focus or close.
	for variant: String in ["focus_out", "close_request"]:
		await _ticks(2)
		var fired: Array = [false]
		var during: Callable = func(_id: StringName, _a: String, _d: String) -> void:
			if fired[0]:
				return
			fired[0] = true
			if variant == "focus_out":
				root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			else:
				_controller.request_close(&"TEST_CLOSE")
		_interaction.target_changed.connect(during)
		mark = _rec.size()
		var had_prompt: bool = not _interaction.get_selected_target_id().is_empty()
		await _tap(KEY_I)
		_interaction.target_changed.disconnect(during)
		var aborted: Array = _since(mark, "rejected")
		var clean: bool = had_prompt and fired[0] and aborted.size() == 1 and not _ui.is_open() and _since(mark, "opened").is_empty() \
			and not _controller.owns_movement_gate() and _interaction.is_interaction_enabled()
		root.propagate_notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		await _ticks(3)
		_check("AC-N12", clean and _player.is_control_effective(), "%s while opening: %s" % [variant, aborted])
		_log("AC-N12", "cancel while opening (%s): result=%s panel=false gate_owned=false interaction_restored=true" % [
			variant, aborted[0].reason if aborted.size() > 0 else "-"])
	# Late UI intent after close.
	await _tap(KEY_I)
	var old_session: int = _controller.get_session_id()
	await _tap(KEY_I)
	mark = _rec.size()
	var before: Array = [_service.snapshot("player_bag").value, _service.snapshot("test_store").value]
	_ui.transfer_requested.emit(old_session, &"player_bag", 0, &"wood", 1, 0, 0)
	await _ticks(2)
	var late: Array = _since(mark, "finished")
	_check("AC-N12", late.size() == 1 and late[0].code == IC.STALE_SESSION
		and [_service.snapshot("player_bag").value, _service.snapshot("test_store").value] == before, "late intent after close refused")
	# Coordinator removed while open: the remaining player and interaction recover.
	await _tap(KEY_I)
	mark = _rec.size()
	_map.remove_child(_controller)
	var removed_closed: Array = _since(mark, "closed")
	await _ticks(2)
	var recovered: bool = _player.is_control_effective() and _interaction.is_interaction_enabled() and not _ui.is_open()
	_map.add_child(_controller)
	await _ticks(2)
	_check("AC-N12", removed_closed.size() == 1 and removed_closed[0].reason == IC.REMOVED and recovered, "coordinator removal releases its gate")
	# Player removed while open: closed on the next tick, no calls into freed nodes.
	await _tap(KEY_I)
	mark = _rec.size()
	var world: Node = _player.get_parent()
	world.remove_child(_player)
	await _ticks(2)
	var player_closed: Array = _since(mark, "closed")
	world.add_child(_player)
	await _ticks(3)
	_check("AC-N12", player_closed.size() == 1 and player_closed[0].reason == IC.REMOVED and not _ui.is_open()
		and _player.is_control_effective(), "player removal closes the panel")
	_log("AC-N12", "late intent=%s; coordinator removed=%s recovered=%s; player removed=%s" % [
		late[0].code if late.size() > 0 else "-", removed_closed[0].reason if removed_closed.size() > 0 else "-", recovered,
		player_closed[0].reason if player_closed.size() > 0 else "-"])
	# Whole map freed while the bag is open.
	await _tap(KEY_I)
	_check("AC-N12", _ui.is_open(), "bag open before freeing the map")
	await _unload_map()
	return true


## BUG-005: the panel UI or the service goes away inside the opening callback or while the
## bag is open. Opening must be refused once, an open bag must close once, and the gate,
## interaction and inventories must recover; nothing may call into a removed UI.
func _n12_ui_service_lifecycle() -> bool:
	var actions: Array = ["queue_free_ui", "remove_ui", "free_ui", "close_service"]
	for action: String in actions:
		await _load_map()
		var ui: InventoryUI = _ui
		var service: InventoryService = _service
		var before: Array = [service.snapshot("player_bag").value, service.snapshot("test_store").value]
		var events_before: int = _events.size()
		var fired: Array = [false]
		var during: Callable = func(_id: StringName, _a: String, _d: String) -> void:
			if fired[0]:
				return
			fired[0] = true
			_break(action, ui, service)
		_interaction.target_changed.connect(during)
		var had_prompt: bool = not _interaction.get_selected_target_id().is_empty()
		var mark: int = _rec.size()
		var result: StringName = _controller.request_open(IC.View.BAG)
		if _interaction.target_changed.is_connected(during):
			_interaction.target_changed.disconnect(during)
		await _ticks(2)
		var refused: Array = _since(mark, "rejected")
		var ok: bool = had_prompt and fired[0] and result != IC.OK and refused.size() == 1 and _since(mark, "opened").is_empty() \
			and _controller.get_state() == IC.State.CLOSED and not _controller.owns_movement_gate() \
			and _interaction.is_interaction_enabled() and _player.is_control_effective() and _events.size() == events_before
		if action != "close_service":
			ok = ok and [service.snapshot("player_bag").value, service.snapshot("test_store").value] == before
		_check("AC-N12", ok, "%s while opening: result %s refused %s state %s gate %s interaction %s player %s" % [action, result,
			refused, _controller.get_state(), _controller.owns_movement_gate(), _interaction.is_interaction_enabled(), _player.is_control_effective()])
		_metrics["AC-N12 opening %s" % action] = String(result)
		_log("AC-N12", "%s while opening: result=%s refused=%d opened=0 gate_owned=%s interaction_restored=%s" % [
			action, result, refused.size(), _controller.owns_movement_gate(), _interaction.is_interaction_enabled()])
		if is_instance_valid(ui) and not ui.is_inside_tree():
			ui.free()
		await _unload_map()
	for action: String in actions:
		await _load_map()
		var ui: InventoryUI = _ui
		var service: InventoryService = _service
		await _tap(KEY_I)
		var open_session: int = _controller.get_session_id()
		var before: Array = [service.snapshot("player_bag").value, service.snapshot("test_store").value]
		var events_before: int = _events.size()
		var mark: int = _rec.size()
		_break(action, ui, service)
		# Same frame: a late intent must not reach the stock.
		if is_instance_valid(ui):
			ui.transfer_requested.emit(open_session, &"player_bag", 0, &"wood", 1, 0, 0)
		# The per-tick check alone must close the bag; only then try a view switch.
		await _ticks(2)
		var closed: Array = _since(mark, "closed")
		var switched: StringName = _controller.request_open(IC.View.STORE)
		await _ticks(1)
		var expected: StringName = IC.SERVICE_UNAVAILABLE if action == "close_service" else IC.REMOVED
		var ok: bool = closed.size() == 1 and closed[0].reason == expected and switched != IC.OK \
			and _controller.get_state() == IC.State.CLOSED and not _controller.owns_movement_gate() \
			and _interaction.is_interaction_enabled() and _player.is_control_effective() and _events.size() == events_before
		if action != "close_service":
			ok = ok and [service.snapshot("player_bag").value, service.snapshot("test_store").value] == before
		if action == "remove_ui":
			ok = ok and not ui.is_open()
		_check("AC-N12", ok, "%s while open: closed %s switch %s state %s gate %s" % [action, closed, switched,
			_controller.get_state(), _controller.owns_movement_gate()])
		_metrics["AC-N12 open %s" % action] = String(closed[0].reason) if closed.size() > 0 else "-"
		_log("AC-N12", "%s while open: closed=%s view_switch=%s late_intent_events=%d gate_released=%s" % [action,
			closed[0].reason if closed.size() > 0 else "-", switched, _events.size() - events_before, not _controller.owns_movement_gate()])
		if is_instance_valid(ui) and not ui.is_inside_tree():
			ui.free()
		await _unload_map()
	return true


func _break(action: String, ui: InventoryUI, service: InventoryService) -> void:
	match action:
		"queue_free_ui":
			ui.queue_free()
		"remove_ui":
			ui.get_parent().remove_child(ui)
		"free_ui":
			ui.free()
		"close_service":
			service.close()


# --- harness ---------------------------------------------------------------------

func _new_service() -> InventoryService:
	var service: InventoryService = InventoryService.new(_catalog)
	service.inventories_changed.connect(func(ids: Array[StringName], revisions: Dictionary) -> void:
		_events.append([ids.duplicate(), revisions.duplicate()]))
	return service


## Registers `id` from compact slot strings like ["wood8", "-"].
func _register(service: InventoryService, id: String, spec: Array) -> void:
	var slots: Array = []
	for entry: String in spec:
		if entry == "-":
			slots.append(null)
		else:
			var split: int = entry.length()
			while split > 0 and entry[split - 1].is_valid_int():
				split -= 1
			slots.append({"item_id": entry.substr(0, split), "quantity": entry.substr(split).to_int()})
	var result: InventoryService.Result = service.register_snapshot(
		{"inventory_id": id, "owner_id": "owner_" + id, "capacity": spec.size(), "revision": 0, "slots": slots})
	_check("AC-N02", result.ok, "fixture %s registers (%s %s)" % [id, result.code, result.detail])


func _slots(service: InventoryService, id: String) -> Array:
	var out: Array = []
	for stack: Variant in service.snapshot(id).value.slots:
		out.append("-" if stack == null else "%s%d" % [stack.item_id, stack.quantity])
	return out


func _totals(service: InventoryService, ids: Array) -> Dictionary:
	var totals: Dictionary = {}
	for item_id: StringName in ITEM_ORDER:
		var total: int = 0
		for id: String in ids:
			total += int(service.count(id, item_id).value)
		totals[String(item_id)] = total
	return totals


## A failing command must return `code` and leave every listed inventory and the event
## count exactly as they were.
func _frozen(ac: String, label: String, service: InventoryService, ids: Array, command: Callable, code: StringName) -> void:
	var before: Dictionary = {}
	for id: String in ids:
		before[id] = service.snapshot(id).value
	var events_before: int = _events.size()
	var result: InventoryService.Result = command.call()
	var same: bool = true
	for id: String in ids:
		same = same and service.snapshot(id).value == before[id]
	_check(ac, result.code == code and not result.ok and result.applied_quantity == 0 and result.revisions.is_empty()
		and same and _events.size() == events_before, "%s: got %s (%s) unchanged %s" % [label, result.code, result.detail, same])
	_metrics["%s %s" % [ac, label]] = String(result.code)


func _load_map() -> void:
	_map = (load(MAP_SCENE) as PackedScene).instantiate() as Node2D
	root.add_child(_map)
	await process_frame
	_controller = _map.get("controller") as InventoryController
	_ui = _map.get("ui") as InventoryUI
	_service = _map.get("service") as InventoryService
	_player = _map.get("player") as PlayerController
	_interaction = _map.get("interaction") as InteractionController
	_rec.clear()
	_service.inventories_changed.connect(func(ids: Array[StringName], revisions: Dictionary) -> void:
		_events.append([ids.duplicate(), revisions.duplicate()]))
	_controller.opened.connect(func(id: int, view: int) -> void: _rec.append({"kind": "opened", "id": id, "view": view}))
	_controller.closed.connect(func(id: int, reason: StringName) -> void: _rec.append({"kind": "closed", "id": id, "reason": reason}))
	_controller.open_rejected.connect(func(reason: StringName) -> void: _rec.append({"kind": "rejected", "reason": reason}))
	_controller.command_finished.connect(func(id: int, code: StringName) -> void: _rec.append({"kind": "finished", "id": id, "code": code}))
	await _ticks(4)


func _unload_map() -> void:
	_release_all()
	_map.queue_free()
	_map = null
	await process_frame
	await physics_frame


func _end_case(ac: String) -> void:
	_release_all()
	await _ticks(2)
	_check(ac, _controller.get_state() == IC.State.CLOSED and not _controller.owns_movement_gate() and not _ui.is_open()
		and _player.is_control_effective() and _interaction.is_interaction_enabled()
		and _interaction.get_state() == InteractionController.State.IDLE, "case left a panel, gate or disabled interaction")


func _probe(id: String, position: Vector2, on_begin: Callable) -> InteractionTarget:
	var node: Node = (load(TARGET_SCENE) as PackedScene).instantiate()
	node.set_script(PROBE)
	var target: InteractionTarget = node as InteractionTarget
	target.target_id = StringName(id)
	target.display_name = "Probe " + id
	target.description = "Probe target for the IH-110 runner."
	target.set("on_begin", on_begin)
	target.position = position
	_map.get_node("Interaction/Targets").add_child(target)
	return target


func _slot_button(side: String, index: int) -> Control:
	return _ui.get_node("Panel/Layout/Columns/%s/Grid" % side.capitalize()).get_child(index) as Control


func _totals_text() -> String:
	return (_map.get_node("FixtureHud/Totals") as Label).text


## Mouse click at the control's centre through the viewport (local canvas coordinates).
func _click(control: Control) -> void:
	var centre: Vector2 = control.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = centre
		event.global_position = centre
		root.push_input(event, true)
	await _ticks(2)


func _tap(code: Key) -> void:
	_key(code, true)
	_key(code, false)
	await _ticks(2)


## E/Escape for the world: resolved by the interaction controller on the next tick.
func _press_world(code: Key) -> void:
	_key(code, true)
	_key(code, false)
	await _ticks(3)


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


func _press(keys: Array) -> void:
	for code: Key in keys:
		_key(code, true)


func _release_all() -> void:
	for code: Key in _held.duplicate():
		_key(code, false)


func _ticks(count: int) -> void:
	for i: int in count:
		await physics_frame


func _since(mark: int, kind: String) -> Array:
	return _rec.slice(mark).filter(func(entry: Dictionary) -> bool: return entry.kind == kind)


func _all_released() -> bool:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"interact", &"inventory_toggle", &"inventory_cancel"]:
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
	_check("AC-N13", first.keys() == second.keys() and differences.is_empty(), "pass differences %s" % differences)
	_log("AC-N13", "passes=2 measurements=%d differences=%d" % [first.size(), differences.size()])


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
	print("IH-110 automated summary:")
	var keys: Array = _ac_checks.keys()
	keys.sort()
	for ac: String in keys:
		var counts: Array = _ac_checks[ac]
		print("  %s %s (%d checks, %d failed)" % [ac, "PASS" if counts[1] == 0 else "FAIL", counts[0], counts[1]])
	print("  Not covered here: real GUI use (AC-N14), code/doc review.")
	if _failures.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		for failure: String in _failures:
			print("  FAILED " + failure)
		print("RESULT: FAIL (%d)" % _failures.size())
		quit(1)
