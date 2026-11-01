extends SceneTree
## IH-112 acceptance runner. Everything runs on real files under a unique test-only root
## (user://tests/ih112/runner_<pid>_<usec>/); the product save root and the GUI test root
## are never touched, and only the fixed file names created here are removed at the end.
## Codec cases decode whole files; store cases use the real SaveFileAdapter (or a subclass
## that injects read/write/flush/rename failures and short writes on the same real files);
## scene cases use the real SaveLoadTest scene with keys through Input.parse_input_event +
## flush; AC-S13 starts separate Godot processes and kills them at exact save stages.
## Expected values (quantities, totals, file states) are written here independently.
## Exit 0 only when every automated check passes. Real GUI use (AC-S16) is never reported.

const SCENE: String = "res://scenes/tests/save_load_test.tscn"
const MAP_SCENE: String = "res://scenes/tests/gathering_test.tscn"
const POINTS_SCENE: String = "res://scenes/gathering/gathering_points.tscn"
const POINT_SCENE: String = "res://scenes/gathering/gather_target.tscn"
const PROBE: Script = preload("res://tests/support/gather_probe_target.gd")
const CHILD: String = "res://tests/support/save_child.gd"
const FIXTURES: String = "res://tests/fixtures/save/"
const GatheringMap: Script = preload("res://scripts/tests/gathering_test.gd")
const FILE_NAMES: Array[String] = ["slot_01.a.json", "slot_01.b.json", "slot_01.a.pending", "slot_01.b.pending",
	"child.out", "child.out.ready"]
## Written independently of production code.
const NORMAL_TOTALS: Dictionary = {"wood": 14, "stone": 14, "berry": 3, "tool_axe": 1}
const ITEMS: Array = ["wood", "stone", "berry", "tool_axe"]
const MAX_SAFE: int = 9007199254740991
## float32 of 228.12345, the fixture's player x, as a double.
const FIXTURE_X: float = 228.12344360351563
const STANDS: Dictionary = {"branch_pile_01": [Vector2(228, 360), "right"], "stone_pile_01": [Vector2(228, 470), "right"],
	"berry_bush_01": [Vector2(360, 322), "up"], "sign": [Vector2(128, 360), "down"]}
const FACING_KEYS: Dictionary = {"down": KEY_S, "up": KEY_W, "left": KEY_A, "right": KEY_D}

var _ac_checks: Dictionary = {}
var _failures: Array[String] = []
var _held: Array[Key] = []
var _metrics: Dictionary = {}
var _pass_metrics: Array[Dictionary] = []
var _pass: int = 0
var _run_root: String = ""
var _dirs: Array[String] = []
var _manifest: Dictionary = {}
var _scene: Node
var _finished: Array[Dictionary] = []
var _engine_errors: EngineErrorLog = EngineErrorLog.new()


## Script runtime errors only abort the failing call; collect them so they fail the run.
class EngineErrorLog extends Logger:
	var _mutex: Mutex = Mutex.new()
	var _entries: PackedStringArray = []

	## The JSON reader warns once per overflowing literal (1e99999 -> INF); the INF cases
	## produce exactly these, counted and checked instead of failing the run.
	var expected_overflow_warnings: int = 0

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text: String = rationale if not rationale.is_empty() else code
		if text.begins_with("FAIL "):
			return
		if error_type == ERROR_TYPE_WARNING and text == "Exponent too high":
			_mutex.lock()
			expected_overflow_warnings += 1
			_mutex.unlock()
			return
		_mutex.lock()
		_entries.append("%s:%d %s" % [file, line, text])
		_mutex.unlock()

	func entries() -> PackedStringArray:
		_mutex.lock()
		var copy: PackedStringArray = _entries.duplicate()
		_mutex.unlock()
		return copy


## Real files, injected faults: a failing write/flush/read/rename, a short write that
## claims success, a read-back that differs, or every read failing after the commit.
class FaultFiles extends SaveFileAdapter:
	var fail: String = ""

	func write(path: String, bytes: PackedByteArray) -> Dictionary:
		match fail:
			"write":
				return {"code": IO_ERROR, "detail": "injected write failure"}
			"short_write":
				super.write(path, bytes.slice(0, bytes.size() / 2))
				return {"code": OK, "detail": ""}
			"flush":
				super.write(path, bytes)
				return {"code": IO_ERROR, "detail": "injected flush failure"}
		return super.write(path, bytes)

	func read(path: String, max_bytes: int) -> Dictionary:
		if fail == "all_reads" or (fail == "read_bank_b" and path.ends_with(".b.json")) \
				or (fail == "read_back" and path.ends_with(".pending")):
			return {"code": IO_ERROR, "bytes": PackedByteArray(), "detail": "injected read failure"}
		var result: Dictionary = super.read(path, max_bytes)
		if fail == "corrupt_read_back" and path.ends_with(".pending") and result.code == OK and result.bytes.size() > 0:
			var bytes: PackedByteArray = result.bytes
			bytes[bytes.size() - 3] = 48 if bytes[bytes.size() - 3] != 48 else 49
			result.bytes = bytes
		return result

	func rename(from_path: String, to_path: String) -> StringName:
		if fail == "rename":
			return IO_ERROR
		if fail == "rename_moved":
			super.rename(from_path, to_path)
			return IO_ERROR
		return super.rename(from_path, to_path)


func _initialize() -> void:
	OS.add_logger(_engine_errors)
	_run()


func _run() -> void:
	print("IH-112 runner: engine=%s" % Engine.get_version_info().string)
	_run_root = "user://tests/ih112/runner_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_manifest = GatheringMap.save_manifest()
	for pass_index: int in 2:
		_pass = pass_index
		_metrics = {}
		var steps: Array = [
			["AC-S01", _s01_codec], ["AC-S02", _s02_numbers], ["AC-S03", _s03_references], ["AC-S05", _s05_commit],
			["AC-S06", _s06_selection], ["AC-S07", _s07_migration], ["AC-S04", _s04_snapshot], ["AC-S08", _s08_restore],
			["AC-S09", _s09_position], ["AC-S10", _s10_candidate_failures], ["AC-S11", _s11_epochs], ["AC-S12", _s12_keys],
			["AC-S11", _b010_report_reentry], ["AC-S10", _b011_suspended_commands], ["AC-S12", _b009_ui_lifecycle],
			["AC-S14", _s14_sequence], ["AC-S06", _s06_scene_recovery], ["AC-S13", _s13_processes],
		]
		for step: Array in steps:
			var completed: Variant = await (step[1] as Callable).call()
			_check(step[0], completed == true, "%s case list aborted before completion" % step[0])
			_close_scene()
			await process_frame
		_check("AC-S15", _all_released(), "pass %d left a key pressed" % pass_index)
		_pass_metrics.append(_metrics)
	_compare_passes()
	await process_frame
	await process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("AC-S15", orphans == 0, "orphan nodes after both passes: %d" % orphans)
	_log("AC-S15", "orphan nodes after both passes: %d" % orphans)
	var removed: int = _clean_files()
	_log("AC-S15", "removed %d test files; product user://saves untouched: %s" % [removed, not DirAccess.dir_exists_absolute("user://saves")])
	if "--inject-failure" in OS.get_cmdline_user_args():
		_check("AC-S15", false, "deliberate failure requested by --inject-failure")
	var errors: PackedStringArray = _engine_errors.entries()
	OS.remove_logger(_engine_errors)
	_check("AC-S15", _engine_errors.expected_overflow_warnings == 4, "overflow warnings only from the 2 INF cases x 2 passes: %d"
		% _engine_errors.expected_overflow_warnings)
	_check("AC-S15", errors.is_empty(), "engine/script errors during the run: %s" % "; ".join(errors))
	_log("AC-S15", "engine/script errors logged during the run: %d" % errors.size())
	_finish()


# --- AC-S01 codec ----------------------------------------------------------------------

func _s01_codec() -> bool:
	var text: String = _fixture("v1_valid.json")
	var bytes: PackedByteArray = text.to_utf8_buffer()
	var decoded: SaveCodec.Result = SaveCodec.decode(bytes, _manifest)
	var envelope: Dictionary = JSON.parse_string(text)
	var keys: Array = envelope.keys()
	keys.sort()
	_check("AC-S01", decoded.ok and keys == ["format", "payload_json", "sha256"] and envelope.format == "iron-and-harvest-save"
		and (envelope.payload_json as String).sha256_text() == envelope.sha256 and text.contains("\\\"inventories\\\""),
		"v1 fixture decodes; checksum is over the payload_json text (escaped inside the envelope)")
	var value: Dictionary = decoded.value if decoded.ok else {}
	_check("AC-S01", decoded.ok and value.generation == 3 and value.player.facing == "right"
		and absf(float(value.player.position.x) - FIXTURE_X) <= 0.0001 and value.player.position.y == 360.0
		and _slots(_inv_of(value, "player_bag")) == ["wood6", "stone10", "tool_axe1", "berry3", "-", "-", "-", "-", "-", "-", "-", "-"]
		and _slots(_inv_of(value, "stock_berry_01")) == ["-"] and _inv_of(value, "stock_berry_01").revision == 3
		and _slots(_inv_of(value, "stock_branch_01")) == ["wood5"] and _inv_of(value, "stock_branch_01").revision == 1,
		"fixture values: %s" % [value.get("player")])
	var again: SaveCodec.Result = SaveCodec.encode(value, _manifest)
	var twice: SaveCodec.Result = SaveCodec.decode((again.value as String).to_utf8_buffer(), _manifest) if again.ok else null
	_check("AC-S01", again.ok and twice != null and twice.ok and JSON.stringify(_without_position(twice.value), "", true)
		== JSON.stringify(_without_position(value), "", true)
		and absf(float(twice.value.player.position.x) - float(value.player.position.x)) <= 0.0001,
		"encode -> decode round trip (position within 0.0001)")
	# The hash covers UTF-8 bytes: a non-ASCII map_id with a matching hash passes the
	# checksum and is then refused as unknown content; hashing other bytes is a mismatch.
	var korean: Dictionary = value.duplicate(true)
	korean.map_id = "시험맵"
	var utf8_case: SaveCodec.Result = SaveCodec.decode(_envelope(korean).to_utf8_buffer(), _manifest)
	var other_bytes: String = _envelope(korean, true)
	_check("AC-S01", utf8_case.code == SaveCodec.CONTENT_MISMATCH
		and SaveCodec.decode(other_bytes.to_utf8_buffer(), _manifest).code == SaveCodec.CHECKSUM_MISMATCH,
		"UTF-8 checksum: %s / other bytes mismatch" % utf8_case.code)
	var changed_payload: Dictionary = envelope.duplicate()
	changed_payload.payload_json = (envelope.payload_json as String).replace("\"generation\":3", "\"generation\":4")
	var no_hash: Dictionary = envelope.duplicate()
	no_hash.erase("sha256")
	var extra: Dictionary = envelope.duplicate()
	extra["note"] = "x"
	var wrong_format: Dictionary = envelope.duplicate()
	wrong_format.format = "other-save"
	var upper: Dictionary = envelope.duplicate()
	upper.sha256 = (envelope.sha256 as String).to_upper()
	var object_payload: Dictionary = envelope.duplicate()
	object_payload.payload_json = {}
	var oversize: PackedByteArray = bytes.duplicate()
	oversize.resize(SaveCodec.MAX_FILE_BYTES + 1)
	oversize.fill(32)
	var bad_utf8: PackedByteArray = bytes.duplicate()
	bad_utf8[40] = 0xFF
	var cases: Array = [
		["truncated", bytes.slice(0, bytes.size() / 2), SaveCodec.CORRUPT_SAVE],
		["empty", PackedByteArray(), SaveCodec.CORRUPT_SAVE],
		["root array", "[1]".to_utf8_buffer(), SaveCodec.CORRUPT_SAVE],
		["root null", "null".to_utf8_buffer(), SaveCodec.CORRUPT_SAVE],
		["missing sha256", JSON.stringify(no_hash).to_utf8_buffer(), SaveCodec.CORRUPT_SAVE],
		["extra envelope key", JSON.stringify(extra).to_utf8_buffer(), SaveCodec.CORRUPT_SAVE],
		["wrong format", JSON.stringify(wrong_format).to_utf8_buffer(), SaveCodec.CORRUPT_SAVE],
		["uppercase sha256", JSON.stringify(upper).to_utf8_buffer(), SaveCodec.CORRUPT_SAVE],
		["payload_json not a string", JSON.stringify(object_payload).to_utf8_buffer(), SaveCodec.CORRUPT_SAVE],
		["payload changed, hash kept", JSON.stringify(changed_payload).to_utf8_buffer(), SaveCodec.CHECKSUM_MISMATCH],
		["payload is an array (rehashed)", _raw_envelope("[1]").to_utf8_buffer(), SaveCodec.INVALID_SAVE],
		["payload truncated (rehashed)", _raw_envelope("{\"schema_version\":1,").to_utf8_buffer(), SaveCodec.INVALID_SAVE],
		["over 1 MiB", oversize, SaveCodec.CORRUPT_SAVE],
		["invalid UTF-8", bad_utf8, SaveCodec.CORRUPT_SAVE],
	]
	var codes: Dictionary = {}
	for case: Array in cases:
		var result: SaveCodec.Result = SaveCodec.decode(case[1], _manifest)
		codes[case[0]] = String(result.code)
		_check("AC-S01", not result.ok and result.code == case[2] and result.value == null,
			"%s -> %s (%s), expected %s" % [case[0], result.code, result.detail, case[2]])
	_metrics["AC-S01"] = str(codes)
	_log("AC-S01", "fixture ok, round trip ok, UTF-8 hash ok; %d damaged inputs refused with no value" % cases.size())
	return true


# --- AC-S02 numbers --------------------------------------------------------------------

func _s02_numbers() -> bool:
	var base: Dictionary = _base_payload()
	var cases: Array = [
		["generation 1.0", func(p: Dictionary) -> void: p.generation = 1.0, SaveCodec.OK],
		["generation true", func(p: Dictionary) -> void: p.generation = true, SaveCodec.INVALID_SAVE],
		["generation 1.5", func(p: Dictionary) -> void: p.generation = 1.5, SaveCodec.INVALID_SAVE],
		["generation \"1\"", func(p: Dictionary) -> void: p.generation = "1", SaveCodec.INVALID_SAVE],
		["generation null", func(p: Dictionary) -> void: p.generation = null, SaveCodec.INVALID_SAVE],
		["generation 0", func(p: Dictionary) -> void: p.generation = 0, SaveCodec.NUMBER_OUT_OF_RANGE],
		["generation max", func(p: Dictionary) -> void: p.generation = MAX_SAFE, SaveCodec.OK],
		["generation max+1", func(p: Dictionary) -> void: p.generation = MAX_SAFE + 1, SaveCodec.NUMBER_OUT_OF_RANGE],
		["generation INF", func(p: Dictionary) -> void: p.generation = INF, SaveCodec.NUMBER_OUT_OF_RANGE],
		["revision -1", func(p: Dictionary) -> void: _inv_of(p, "player_bag").revision = -1, SaveCodec.NUMBER_OUT_OF_RANGE],
		["revision 0", func(p: Dictionary) -> void: _inv_of(p, "player_bag").revision = 0, SaveCodec.OK],
		["revision max", func(p: Dictionary) -> void: _inv_of(p, "player_bag").revision = MAX_SAFE, SaveCodec.OK],
		["revision max+1", func(p: Dictionary) -> void: _inv_of(p, "player_bag").revision = MAX_SAFE + 1, SaveCodec.NUMBER_OUT_OF_RANGE],
		["revision 2.0", func(p: Dictionary) -> void: _inv_of(p, "player_bag").revision = 2.0, SaveCodec.OK],
		["capacity 12.0", func(p: Dictionary) -> void: _inv_of(p, "test_store").capacity = 12.0, SaveCodec.OK],
		["capacity true", func(p: Dictionary) -> void: _inv_of(p, "test_store").capacity = true, SaveCodec.INVALID_SAVE],
		["quantity 3.0", func(p: Dictionary) -> void: _inv_of(p, "player_bag").slots[3].quantity = 3.0, SaveCodec.OK],
		["quantity \"3\"", func(p: Dictionary) -> void: _inv_of(p, "player_bag").slots[3].quantity = "3", SaveCodec.INVALID_SAVE],
		["quantity 0", func(p: Dictionary) -> void: _inv_of(p, "player_bag").slots[3].quantity = 0, SaveCodec.NUMBER_OUT_OF_RANGE],
		["quantity -2", func(p: Dictionary) -> void: _inv_of(p, "player_bag").slots[3].quantity = -2, SaveCodec.NUMBER_OUT_OF_RANGE],
		["quantity 2.5", func(p: Dictionary) -> void: _inv_of(p, "player_bag").slots[3].quantity = 2.5, SaveCodec.INVALID_SAVE],
		["quantity over stack", func(p: Dictionary) -> void: _inv_of(p, "player_bag").slots[0].quantity = 11, SaveCodec.INVALID_SAVE],
		["schema 1.0", func(p: Dictionary) -> void: p.schema_version = 1.0, SaveCodec.OK],
		["content true", func(p: Dictionary) -> void: p.content_version = true, SaveCodec.INVALID_SAVE],
		["position int", func(p: Dictionary) -> void: p.player.position.x = 300, SaveCodec.OK],
		["position \"1\"", func(p: Dictionary) -> void: p.player.position.x = "1", SaveCodec.INVALID_SAVE],
		["position bool", func(p: Dictionary) -> void: p.player.position.y = true, SaveCodec.INVALID_SAVE],
		["position INF", func(p: Dictionary) -> void: p.player.position.x = INF, SaveCodec.NUMBER_OUT_OF_RANGE],
		["position -1", func(p: Dictionary) -> void: p.player.position.x = -1.0, SaveCodec.NUMBER_OUT_OF_RANGE],
		["position 1281", func(p: Dictionary) -> void: p.player.position.x = 1281.0, SaveCodec.NUMBER_OUT_OF_RANGE],
	]
	var codes: Dictionary = {}
	var inventory: InventoryService = InventoryService.new(load("res://data/items/catalog.tres"))
	for case: Array in cases:
		var payload: Dictionary = base.duplicate(true)
		(case[1] as Callable).call(payload)
		var result: SaveCodec.Result = SaveCodec.decode(_envelope(payload).to_utf8_buffer(), _manifest)
		codes[case[0]] = String(result.code)
		var typed: bool = true
		if result.ok:
			# Normalized to int: the existing strict snapshot decoder accepts every inventory.
			for entry: Dictionary in result.value.inventories:
				typed = typed and inventory.decode_snapshot(entry).ok and typeof(entry.revision) == TYPE_INT
			typed = typed and typeof(result.value.generation) == TYPE_INT
		_check("AC-S02", result.code == case[2] and (result.ok == (result.value != null)) and typed,
			"%s -> %s (%s), expected %s" % [case[0], result.code, result.detail, case[2]])
	# NaN is not JSON: written as text it fails the payload parse.
	var nan_text: String = JSON.stringify(base, "", true, true).replace("\"generation\":3", "\"generation\":NaN")
	var nan_case: SaveCodec.Result = SaveCodec.decode(_raw_envelope(nan_text).to_utf8_buffer(), _manifest)
	_check("AC-S02", nan_case.code == SaveCodec.INVALID_SAVE, "NaN literal refused: %s" % nan_case.code)
	inventory.close()
	# Encoding never rounds: an internal revision above 2^53-1 is refused and nothing is written.
	var dir: String = _dir("s02_encode")
	var store: SaveStore = SaveStore.new(dir, _manifest)
	var too_big: Dictionary = _store_payload()
	_inv_of(too_big, "player_bag").revision = MAX_SAFE + 1
	var refused: SaveStore.Result = store.save_slot(too_big)
	_check("AC-S02", refused.code == SaveCodec.NUMBER_OUT_OF_RANGE and not refused.committed and _bank_state(dir) == ["missing", "missing"],
		"oversized revision refused before any file: %s %s" % [refused.code, _bank_state(dir)])
	_metrics["AC-S02"] = str(codes)
	_log("AC-S02", "%d number cases as expected; NaN text refused; revision 2^53 refused on save, no file" % cases.size())
	return true


# --- AC-S03 references and content ---------------------------------------------------

func _s03_references() -> bool:
	var base: Dictionary = _base_payload()
	var cases: Array = [
		["missing inventory", func(p: Dictionary) -> void: (p.inventories as Array).remove_at(4), SaveCodec.INVALID_SAVE],
		["duplicate bag", func(p: Dictionary) -> void: p.inventories[1] = p.inventories[0].duplicate(true), SaveCodec.INVALID_SAVE],
		["extra inventory", func(p: Dictionary) -> void: (p.inventories as Array).append(p.inventories[4].duplicate(true)), SaveCodec.INVALID_SAVE],
		["unknown inventory", func(p: Dictionary) -> void: _inv_of(p, "test_store").inventory_id = "test_store_2", SaveCodec.CONTENT_MISMATCH],
		["unknown item", func(p: Dictionary) -> void: _inv_of(p, "player_bag").slots[3].item_id = "gold", SaveCodec.CONTENT_MISMATCH],
		["unknown map", func(p: Dictionary) -> void: p.map_id = "other_map", SaveCodec.CONTENT_MISMATCH],
		["unknown definition", func(p: Dictionary) -> void: p.points[0].definition_id = "gather_gold", SaveCodec.CONTENT_MISMATCH],
		["bag as stock", func(p: Dictionary) -> void: p.points[1].stock_inventory_id = "player_bag", SaveCodec.CONTENT_MISMATCH],
		["missing binding", func(p: Dictionary) -> void: (p.points as Array).remove_at(2), SaveCodec.INVALID_SAVE],
		["stock owner", func(p: Dictionary) -> void: _inv_of(p, "stock_branch_01").owner_id = "stone_pile_01", SaveCodec.CONTENT_MISMATCH],
		["stock capacity", func(p: Dictionary) -> void:
			_inv_of(p, "stock_branch_01").capacity = 2
			(_inv_of(p, "stock_branch_01").slots as Array).append(null), SaveCodec.CONTENT_MISMATCH],
		["stock foreign item", func(p: Dictionary) -> void: _inv_of(p, "stock_branch_01").slots[0] = {"item_id": "stone", "quantity": 1}, SaveCodec.INVALID_SAVE],
		["stock above initial", func(p: Dictionary) -> void: _inv_of(p, "stock_branch_01").slots[0].quantity = 7, SaveCodec.INVALID_SAVE],
		["empty stack", func(p: Dictionary) -> void: _inv_of(p, "stock_stone_01").slots[0].quantity = 0, SaveCodec.NUMBER_OUT_OF_RANGE],
		["player id", func(p: Dictionary) -> void: p.player.player_id = "player_02", SaveCodec.CONTENT_MISMATCH],
		["extra payload key", func(p: Dictionary) -> void: p["note"] = "x", SaveCodec.INVALID_SAVE],
		["stored remaining", func(p: Dictionary) -> void: p.points[0]["remaining"] = 3, SaveCodec.INVALID_SAVE],
		["depleted stock null", func(p: Dictionary) -> void: _inv_of(p, "stock_stone_01").slots[0] = null, SaveCodec.OK],
	]
	var codes: Dictionary = {}
	for case: Array in cases:
		var payload: Dictionary = base.duplicate(true)
		(case[1] as Callable).call(payload)
		var result: SaveCodec.Result = SaveCodec.decode(_envelope(payload).to_utf8_buffer(), _manifest)
		codes[case[0]] = String(result.code)
		_check("AC-S03", result.code == case[2], "%s -> %s (%s), expected %s" % [case[0], result.code, result.detail, case[2]])
	# The service layer refuses the same pollution on its own, as a whole.
	var item_catalog: ItemCatalog = load("res://data/items/catalog.tres")
	var gather_catalog: GatherCatalog = load("res://data/gathering/gather_catalog.tres")
	var good: GatherService.Result = GatherService.restore(item_catalog, gather_catalog, base.inventories, &"player_bag", GatheringMap.BINDINGS)
	_check("AC-S03", good.ok and good.value.gather.query("berry_bush_01").value.depleted
		and good.value.gather.query("branch_pile_01").value.remaining == 5, "restore of the fixture inventories")
	if good.ok:
		good.value.gather.close()
		good.value.inventory.close()
	var service_cases: Array = [
		["stock owner", func(list: Array, _b: Array) -> void: _inv_in(list, "stock_branch_01").owner_id = "stone_pile_01"],
		["foreign item", func(list: Array, _b: Array) -> void: _inv_in(list, "stock_stone_01").slots[0] = {"item_id": "wood", "quantity": 1}],
		["above initial", func(list: Array, _b: Array) -> void: _inv_in(list, "stock_stone_01").slots[0].quantity = 5],
		["duplicate stock", func(list: Array, _b: Array) -> void: list.append(_inv_in(list, "stock_stone_01").duplicate(true))],
		["missing stock", func(list: Array, _b: Array) -> void: list.erase(_inv_in(list, "stock_stone_01"))],
		["bag as stock", func(_list: Array, b: Array) -> void: b[0].stock_inventory_id = "player_bag"],
		["stock capacity", func(list: Array, _b: Array) -> void:
			_inv_in(list, "stock_branch_01").capacity = 2
			(_inv_in(list, "stock_branch_01").slots as Array).append(null)],
	]
	for case: Array in service_cases:
		var list: Array = (base.inventories as Array).duplicate(true)
		var bindings: Array = GatheringMap.BINDINGS.duplicate(true)
		(case[1] as Callable).call(list, bindings)
		var built: GatherService.Result = GatherService.restore(item_catalog, gather_catalog, list, &"player_bag", bindings)
		_check("AC-S03", built.code == GatherService.INVALID_SETUP and built.value == null, "restore refuses %s: %s" % [case[0], built.code])
	_metrics["AC-S03"] = str(codes)
	_log("AC-S03", "%d reference/content cases as expected; GatherService.restore refuses %d polluted sets" % [cases.size(), service_cases.size()])
	return true


# --- AC-S04 snapshot and quiescence ------------------------------------------------------

func _s04_snapshot() -> bool:
	var dir: String = _dir("s04")
	await _open_scene(dir)
	await _stand("branch_pile_01")
	await _press_e()
	var world: Node = _world()
	var inventory: InventoryService = _inv()
	var captured: Dictionary = world.call("capture_payload")
	var live: Array = []
	for inventory_id: String in ["player_bag", "stock_berry_01", "stock_branch_01", "stock_stone_01", "test_store"]:
		live.append(inventory.snapshot(inventory_id).value)
	_check("AC-S04", captured.inventories == live and captured.player.facing == "right"
		and Vector2(captured.player.position.x, captured.player.position.y) == _player().global_position
		and captured.points == GatheringMap.save_manifest().points and not (captured.points[0] as Dictionary).has("remaining"),
		"capture = live snapshots, position, facing and bindings only")
	captured.inventories[0].slots[0].quantity = 99
	_check("AC-S04", inventory.count("player_bag", "wood").value == 9, "editing the capture leaves the live bag alone")
	var busy: Dictionary = {}
	# (a) bag panel open: BUSY, panel and gate stay as they are.
	var controller: InventoryController = world.get("controller")
	controller.request_open(InventoryController.View.BAG)
	busy["bag open"] = [_save_code(), _load_code(), controller.get_state() == InventoryController.State.OPEN and controller.owns_movement_gate()]
	controller.request_close(&"CLOSED_BY_USER")
	# (b) inspect panel open on the sign.
	await _stand("sign")
	await _press_e()
	var interaction: InteractionController = world.get("interaction")
	var active: bool = interaction.get_state() == InteractionController.State.ACTIVE
	busy["inspect open"] = [_save_code(), _load_code(), active and interaction.get_state() == InteractionController.State.ACTIVE
		and not _player().is_control_effective()]
	interaction.finish_active(interaction.get_active_request_id(), InteractionController.COMPLETED)
	await _ticks(2)
	# (c) a prepared gather command.
	var gather: GatherService = _gather()
	var prepared: GatherService.Result = gather.prepare("stone_pile_01", "player_bag", 900)
	busy["prepared command"] = [_save_code(), _load_code(), gather.has_pending_command()]
	(prepared.value as GatherService.GatherCommand).cancel()
	# (d) inside the commit (inventory busy, interaction EXECUTING) and (e) its report.
	await _stand("branch_pile_01")
	var inside: Array = []
	var during_commit: Callable = func(_ids: Array[StringName], _revisions: Dictionary) -> void:
		inside.append([_save_code(), _load_code(), interaction.get_state() == InteractionController.State.EXECUTING])
	var during_report: Callable = func(_id: int, _target: StringName, _result: RefCounted) -> void:
		inside.append([_save_code(), _load_code(), not interaction.is_quiescent()])
	inventory.inventories_changed.connect(during_commit)
	interaction.instant_completed.connect(during_report)
	await _press_e()
	inventory.inventories_changed.disconnect(during_commit)
	interaction.instant_completed.disconnect(during_report)
	busy["commit"] = inside[0] if inside.size() > 0 else []
	busy["report"] = inside[1] if inside.size() > 1 else []
	# (f) E queued but not yet processed: the queue is kept and runs normally.
	_key(KEY_E, true)
	_key(KEY_E, false)
	busy["queued E"] = [_save_code(), _load_code(), not interaction.is_quiescent()]
	var wood_before: int = inventory.count("player_bag", "wood").value
	await _ticks(3)
	var queued_ran: bool = inventory.count("player_bag", "wood").value == wood_before + 1
	# (g) RESOLVING: a probe target asks for a save inside try_begin.
	var probe_codes: Array = []
	await _install_probe(func(_map: Node2D) -> void: probe_codes.append(_save_code()))
	await _stand("branch_pile_01")
	await _press_e()
	busy["resolving"] = [probe_codes[0] if not probe_codes.is_empty() else &"", &"BUSY", true]
	# (h) OPENING: a queued E is discarded while the bag opens; its rejection asks for a save.
	var opening: Array = []
	var on_rejected: Callable = func(_id: int, _reason: StringName) -> void:
		opening.append([_save_code(), controller.get_state() == InventoryController.State.OPENING])
	interaction.request_rejected.connect(on_rejected)
	_key(KEY_E, true)
	_key(KEY_E, false)
	controller.request_open(InventoryController.View.BAG)
	interaction.request_rejected.disconnect(on_rejected)
	busy["opening"] = [opening[0][0] if not opening.is_empty() else &"", &"BUSY", not opening.is_empty() and opening[0][1]]
	controller.request_close(&"CLOSED_BY_USER")
	await _ticks(2)
	for key: String in busy:
		var entry: Array = busy[key]
		_check("AC-S04", entry.size() == 3 and entry[0] == &"BUSY" and entry[1] == &"BUSY" and entry[2] == true,
			"%s: save/load BUSY and state untouched %s" % [key, entry])
	_check("AC-S04", queued_ran and _bank_state(dir) == ["missing", "missing"], "queued E still ran; no file written while busy")
	var saved: Dictionary = _coord().request_save(_coord().get_epoch())
	_check("AC-S04", saved.ok and saved.generation == 1, "quiescent again: save gen 1 (%s)" % saved.code)
	_metrics["AC-S04"] = str(busy.keys())
	_log("AC-S04", "capture consistent and independent; BUSY without side effects for %s" % [busy.keys()])
	return true


# --- AC-S05 file commit ------------------------------------------------------------------

func _s05_commit() -> bool:
	var dir: String = _dir("s05")
	var store: SaveStore = SaveStore.new(dir, _manifest)
	var payload: Dictionary = _store_payload()
	var order: Array = []
	for expected: Array in [["a", 1], ["b", 2], ["a", 3], ["b", 4]]:
		var before: Dictionary = _bank_bytes(dir)
		var saved: SaveStore.Result = store.save_slot(payload)
		var after: Dictionary = _bank_bytes(dir)
		var other: String = "b" if expected[0] == "a" else "a"
		order.append("%s%d" % [saved.source_bank, saved.generation])
		_check("AC-S05", saved.ok and saved.committed and saved.source_bank == expected[0] and saved.generation == expected[1]
			and after[other] == before[other] and after[expected[0]] != before[expected[0]] and not _exists(dir, expected[0] + ".pending"),
			"save -> %s%d replaces only the older bank" % expected)
	_check("AC-S05", store.inspect().latest == "b" and store.inspect().banks.b.generation == 4, "newest is generation 4 in b")
	# Every failure before the rename leaves both banks byte-identical and no pending file.
	var faults: Array = [["write", SaveStore.IO_ERROR], ["flush", SaveStore.IO_ERROR], ["short_write", SaveStore.IO_ERROR],
		["read_back", SaveStore.IO_ERROR], ["corrupt_read_back", SaveStore.IO_ERROR], ["rename", SaveStore.IO_ERROR]]
	var outcomes: Dictionary = {}
	for fault: Array in faults:
		var files: FaultFiles = FaultFiles.new()
		files.fail = fault[0]
		var faulty: SaveStore = SaveStore.new(dir, _manifest, files)
		var before: Dictionary = _bank_bytes(dir)
		var result: SaveStore.Result = faulty.save_slot(payload)
		outcomes[fault[0]] = String(result.code)
		_check("AC-S05", result.code == fault[1] and not result.committed and _bank_bytes(dir) == before
			and not _exists(dir, "a.pending"), "%s: %s, banks unchanged, pending removed (%s)" % [fault[0], result.code, result.detail])
	# A bank changed by someone else between verification and rename: FILE_CHANGED.
	var before_change: Dictionary = _bank_bytes(dir)
	var intruder: SaveStore = SaveStore.new(dir, _manifest)
	intruder.stage_hook = func(stage: String) -> void:
		if stage == "pending_verified":
			_write_file(dir + "/slot_01.b.json", (before_change.a as PackedByteArray).get_string_from_utf8())
	var changed: SaveStore.Result = intruder.save_slot(payload)
	_check("AC-S05", changed.code == SaveStore.FILE_CHANGED and _bank_bytes(dir).a == before_change.a and not _exists(dir, "a.pending"),
		"bank changed during save: FILE_CHANGED, target bank untouched")
	_write_file(dir + "/slot_01.b.json", (before_change.b as PackedByteArray).get_string_from_utf8())
	# The commit guard (cancel latch) refuses right before the rename.
	var guarded: SaveStore = SaveStore.new(dir, _manifest)
	guarded.commit_guard = func() -> StringName: return &"CANCELLED"
	var cancelled: SaveStore.Result = guarded.save_slot(payload)
	_check("AC-S05", cancelled.code == &"CANCELLED" and _bank_bytes(dir) == before_change, "guard refusal: banks unchanged")
	# Rename reported failure but the bank changed: COMMIT_UNCERTAIN, no retry; inspect decides.
	var moved_files: FaultFiles = FaultFiles.new()
	moved_files.fail = "rename_moved"
	var uncertain: SaveStore.Result = SaveStore.new(dir, _manifest, moved_files).save_slot(payload)
	var status: Dictionary = store.inspect()
	_check("AC-S05", uncertain.code == SaveStore.COMMIT_UNCERTAIN and not uncertain.committed and status.latest == "a"
		and status.banks.a.generation == 5, "uncertain rename: %s, next inspect sees generation %d" % [uncertain.code, status.banks.a.generation])
	# After the commit a failing diagnostic read is a warning, never a failure or retry.
	var late_files: FaultFiles = FaultFiles.new()
	var late: SaveStore = SaveStore.new(dir, _manifest, late_files)
	late.stage_hook = func(stage: String) -> void:
		if stage == "after_rename":
			late_files.fail = "all_reads"
	var committed: SaveStore.Result = late.save_slot(payload)
	_check("AC-S05", committed.ok and committed.committed and committed.generation == 6 and not committed.warning.is_empty()
		and store.inspect().banks.b.generation == 6, "post-commit read failure: ok with warning '%s'" % committed.warning)
	# A stale pending file is ignored on read and replaced by the next save.
	_write_file(dir + "/slot_01.a.pending", "garbage")
	var with_pending: Dictionary = store.inspect()
	var next: SaveStore.Result = store.save_slot(payload)
	_check("AC-S05", with_pending.latest == "b" and next.ok and next.source_bank == "a" and next.generation == 7
		and not _exists(dir, "a.pending"), "leftover pending ignored, then replaced")
	_metrics["AC-S05"] = "%s %s" % [order, outcomes]
	_log("AC-S05", "A1 B2 A3 B4 alternate; %s pre-commit faults keep both banks; FILE_CHANGED/guard/uncertain/post-commit warning" % [outcomes])
	return true


# --- AC-S06 selection and recovery -------------------------------------------------------

func _s06_selection() -> bool:
	var g1: String = _bank_text(1)
	var g2: String = _bank_text(2)
	var g2_other: String = _bank_text(2, func(p: Dictionary) -> void: _inv_of(p, "test_store").slots[5] = {"item_id": "stone", "quantity": 1})
	var corrupt: String = _damaged(g2)
	var future: String = _fixture("schema2_future.json")
	var content2: String = _fixture("content2.json")
	# [name, a, b, inspect code, latest, recovery, default load code, recovery load code, save code, save bank, save gen]
	var rows: Array = [
		["none", "", "", SaveStore.NO_SAVE, "", "", SaveStore.NO_SAVE, SaveStore.NO_RECOVERY, SaveStore.OK, "a", 1],
		["valid+missing", g2, "", SaveStore.OK, "a", "", SaveStore.OK, SaveStore.NO_RECOVERY, SaveStore.OK, "b", 3],
		["valid2 different", g1, g2, SaveStore.OK, "b", "a", SaveStore.OK, SaveStore.OK, SaveStore.OK, "a", 3],
		["valid+corrupt", g2, corrupt, SaveStore.RECOVERY_AVAILABLE, "", "a", SaveStore.RECOVERY_AVAILABLE, SaveStore.OK, SaveStore.OK, "b", 3],
		["corrupt+corrupt", corrupt, _damaged(g1), SaveStore.CORRUPT_SAVE, "", "", SaveStore.CORRUPT_SAVE, SaveStore.NO_RECOVERY, SaveStore.CORRUPT_SAVE, "", 0],
		["corrupt+missing", corrupt, "", SaveStore.CORRUPT_SAVE, "", "", SaveStore.CORRUPT_SAVE, SaveStore.NO_RECOVERY, SaveStore.CORRUPT_SAVE, "", 0],
		["same generation same payload", g2, g2, SaveStore.OK, "a", "", SaveStore.OK, SaveStore.NO_RECOVERY, SaveStore.OK, "b", 3],
		["same generation different payload", g2, g2_other, SaveStore.AMBIGUOUS_SAVE, "", "", SaveStore.AMBIGUOUS_SAVE, SaveStore.NO_RECOVERY, SaveStore.AMBIGUOUS_SAVE, "", 0],
		["valid+future schema", g2, future, SaveStore.INCOMPATIBLE_SAVE, "", "", SaveStore.INCOMPATIBLE_SAVE, SaveStore.NO_RECOVERY, SaveStore.INCOMPATIBLE_SAVE, "", 0],
		["valid+content 2", content2, g1, SaveStore.INCOMPATIBLE_SAVE, "", "", SaveStore.INCOMPATIBLE_SAVE, SaveStore.NO_RECOVERY, SaveStore.INCOMPATIBLE_SAVE, "", 0],
		["io error", g1, g2, SaveStore.IO_ERROR, "", "", SaveStore.IO_ERROR, SaveStore.NO_RECOVERY, SaveStore.IO_ERROR, "", 0],
	]
	var codes: Dictionary = {}
	for row: Array in rows:
		var dir: String = _dir("s06_" + String(row[0]).replace(" ", "_").replace("+", "_"))
		_write_bank(dir, "a", row[1])
		_write_bank(dir, "b", row[2])
		var files: FaultFiles = FaultFiles.new()
		if row[0] == "io error":
			files.fail = "read_bank_b"
		var store: SaveStore = SaveStore.new(dir, _manifest, files)
		var before: Dictionary = _bank_bytes(dir)
		var status: Dictionary = store.inspect()
		var latest: SaveStore.Result = store.load_slot()
		var recovery: SaveStore.Result = store.load_slot(SaveStore.SOURCE_RECOVERY)
		var unchanged_by_reads: bool = _bank_bytes(dir) == before
		var saved: SaveStore.Result = store.save_slot(_store_payload())
		var after: Dictionary = _bank_bytes(dir)
		var save_ok: bool = saved.code == row[8] and saved.source_bank == row[9] and saved.generation == row[10]
		if saved.ok:
			var untouched: String = "b" if row[9] == "a" else "a"
			save_ok = save_ok and after[untouched] == before[untouched]
		else:
			save_ok = save_ok and after == before
		codes[row[0]] = [String(status.code), String(latest.code), String(recovery.code), String(saved.code)]
		_check("AC-S06", status.code == row[3] and status.latest == row[4] and status.recovery == row[5] and latest.code == row[6]
			and recovery.code == row[7] and unchanged_by_reads and save_ok and (not recovery.ok or recovery.recovered),
			"%s: inspect %s latest '%s' recovery '%s' load %s/%s save %s %s%d" % [row[0], status.code, status.latest, status.recovery,
			latest.code, recovery.code, saved.code, saved.source_bank, saved.generation])
	# File times never decide: the older generation rewritten last stays the older one.
	var dir_m: String = _dir("s06_mtime")
	_write_bank(dir_m, "b", g2)
	_write_bank(dir_m, "a", g1)
	OS.delay_msec(1100)
	_write_bank(dir_m, "a", g1)
	var newer_a: bool = FileAccess.get_modified_time(dir_m + "/slot_01.a.json") > FileAccess.get_modified_time(dir_m + "/slot_01.b.json")
	var by_generation: Dictionary = SaveStore.new(dir_m, _manifest).inspect()
	_check("AC-S06", newer_a and by_generation.latest == "b" and by_generation.recovery == "a",
		"a has the newer mtime (%s) but b (generation 2) is chosen" % newer_a)
	# Pending files are never read.
	var dir_p: String = _dir("s06_pending")
	_write_bank(dir_p, "a", g1)
	_write_file(dir_p + "/slot_01.b.pending", g2)
	var ignored: Dictionary = SaveStore.new(dir_p, _manifest).inspect()
	_check("AC-S06", ignored.latest == "a" and ignored.banks.b.state == SaveStore.BANK_MISSING, "pending b ignored")
	_metrics["AC-S06"] = str(codes)
	_log("AC-S06", "%d A/B rows as in the table; generation beats mtime; pending ignored" % rows.size())
	return true


## Scene part of AC-S06: with the newest bank damaged, F9 keeps the world; only the
## explicit recovery request loads the previous generation; files stay as they were.
func _s06_scene_recovery() -> bool:
	var dir: String = _dir("s06_scene")
	await _open_scene(dir)
	_coord().request_save(_coord().get_epoch())
	await _stand("branch_pile_01")
	await _press_e()
	_coord().request_save(_coord().get_epoch())
	await _press_e()
	var world: Node = _world()
	var before_world: Dictionary = _world_state()
	var newest: String = "b"
	_write_file(dir + "/slot_01.%s.json" % newest, _damaged(_read_text(dir + "/slot_01.b.json")))
	var files_before: Dictionary = _bank_bytes(dir)
	var first: int = _finished.size()
	_tap_now(KEY_F9)
	var refused: Dictionary = await _wait_finished(first)
	_check("AC-S06", refused.code == SaveStore.RECOVERY_AVAILABLE and _world() == world and _world_state() == before_world
		and not _inv().is_closed() and (_ui() as SaveUI).get_message().contains("이전 세대로 복구"),
		"F9 with damaged newest: %s, world kept, recovery offered" % refused.code)
	var mark: int = _finished.size()
	(_ui() as SaveUI).load_requested.emit((_ui() as SaveUI).get_epoch(), SaveStore.SOURCE_RECOVERY)
	var recovered: Dictionary = await _wait_finished(mark)
	_check("AC-S06", recovered.ok and recovered.recovered and recovered.generation == 1 and _world() != world
		and _inv().count("player_bag", "wood").value == 8 and _bank_bytes(dir) == files_before,
		"explicit recovery loads generation 1 (wood 8); files untouched")
	var next: Dictionary = _coord().request_save(_coord().get_epoch())
	_check("AC-S06", next.ok and next.bank == "b" and next.generation == 2, "next save replaces the damaged bank: %s%d" % [next.bank, next.generation])
	_metrics["AC-S06 scene"] = "%s %s %d" % [refused.code, recovered.code, next.generation]
	_log("AC-S06", "scene: F9 -> RECOVERY_AVAILABLE (world kept), recovery -> gen 1, next save -> b2")
	return true


# --- AC-S07 migration ----------------------------------------------------------------------

func _s07_migration() -> bool:
	var v0_text: String = _fixture("v0_valid.json")
	var v1: SaveCodec.Result = SaveCodec.decode(_fixture("v1_valid.json").to_utf8_buffer(), _manifest)
	var migrated: SaveCodec.Result = SaveCodec.decode(v0_text.to_utf8_buffer(), _manifest)
	var raw: Dictionary = JSON.parse_string(JSON.parse_string(v0_text).payload_json)
	_check("AC-S07", migrated.ok and migrated.migrated_from == 0 and migrated.value.schema_version == 1
		and migrated.value.player.facing == "down" and migrated.value.generation == 2 and raw.generation == 2.0
		and not (raw.player as Dictionary).has("facing")
		and JSON.stringify(migrated.value.inventories, "", true) == JSON.stringify(v1.value.inventories, "", true),
		"v0 -> v1: facing down, generation 2, every slot/quantity/revision kept")
	var dir: String = _dir("s07")
	_write_bank(dir, "a", v0_text)
	var before: Dictionary = _bank_bytes(dir)
	var store: SaveStore = SaveStore.new(dir, _manifest)
	var loaded: SaveStore.Result = store.load_slot()
	_check("AC-S07", loaded.ok and loaded.migrated_from == 0 and loaded.generation == 2 and _bank_bytes(dir) == before,
		"loading v0 never rewrites the file")
	var saved: SaveStore.Result = store.save_slot(_without_versions(loaded.payload))
	var written: Dictionary = JSON.parse_string(JSON.parse_string(_read_text(dir + "/slot_01.b.json")).payload_json)
	_check("AC-S07", saved.ok and saved.source_bank == "b" and saved.generation == 3 and written.schema_version == 1.0
		and written.player.facing == "down" and _bank_bytes(dir).a == before.a, "the next save writes v1 (b3), v0 file kept")
	var base: Dictionary = _base_payload()
	var refused: Dictionary = {}
	for case: Array in [["schema 2", _fixture("schema2_future.json").to_utf8_buffer(), SaveCodec.UNSUPPORTED_SCHEMA],
			["content 2", _fixture("content2.json").to_utf8_buffer(), SaveCodec.CONTENT_MISMATCH],
			["schema -1", _envelope(_with(base, "schema_version", -1)).to_utf8_buffer(), SaveCodec.UNSUPPORTED_SCHEMA],
			["schema 99", _envelope(_with(base, "schema_version", 99)).to_utf8_buffer(), SaveCodec.UNSUPPORTED_SCHEMA],
			["content 0", _envelope(_with(base, "content_version", 0)).to_utf8_buffer(), SaveCodec.CONTENT_MISMATCH],
			["v0 with facing", _envelope(_with(base, "schema_version", 0)).to_utf8_buffer(), SaveCodec.INVALID_SAVE]]:
		var result: SaveCodec.Result = SaveCodec.decode(case[1], _manifest)
		refused[case[0]] = String(result.code)
		_check("AC-S07", result.code == case[2] and not result.ok, "%s -> %s" % [case[0], result.code])
	# An incompatible bank next to a valid one is neither loaded around nor overwritten.
	var dir_f: String = _dir("s07_future")
	_write_bank(dir_f, "a", _bank_text(1))
	_write_bank(dir_f, "b", _fixture("schema2_future.json"))
	var kept: Dictionary = _bank_bytes(dir_f)
	var future_store: SaveStore = SaveStore.new(dir_f, _manifest)
	var no_load: SaveStore.Result = future_store.load_slot()
	var no_save: SaveStore.Result = future_store.save_slot(_store_payload())
	_check("AC-S07", no_load.code == SaveStore.INCOMPATIBLE_SAVE and no_save.code == SaveStore.INCOMPATIBLE_SAVE
		and _bank_bytes(dir_f) == kept, "future bank: load and save refused, both files kept")
	_metrics["AC-S07"] = str(refused)
	_log("AC-S07", "v0 migrated in memory only, next save v1; refused %s" % [refused])
	return true


# --- AC-S08 new context --------------------------------------------------------------------

func _s08_restore() -> bool:
	var dir: String = _dir("s08")
	await _open_scene(dir)
	await _stand("branch_pile_01")
	await _press_e()
	await _stand("berry_bush_01")
	for i: int in 3:
		await _press_e()
	var inventory: InventoryService = _inv()
	inventory.transfer("player_bag", 0, "test_store", 4, inventory.snapshot("player_bag").value.revision,
		inventory.snapshot("test_store").value.revision)
	var saved_state: Dictionary = _world_state()
	var saved: Dictionary = _coord().request_save(_coord().get_epoch())
	# Independent expectation: wood 8+1-4 in the bag, 4 in the store, branch 5, berry 0.
	_check("AC-S08", saved.ok and _slots(_inv_snapshot("player_bag"))[0] == "wood5" and _slots(_inv_snapshot("test_store"))[0] == "wood4"
		and _slots(_inv_snapshot("stock_berry_01")) == ["-"] and _slots(_inv_snapshot("stock_branch_01")) == ["wood5"]
		and _totals(inventory) == NORMAL_TOTALS, "saved world as expected")
	await _stand("stone_pile_01")
	await _press_e()
	await _press_e()
	var old_inventory: InventoryService = inventory
	var old_gather: GatherService = _gather()
	var loaded: Dictionary = await _load_and_wait()
	var restored_state: Dictionary = _world_state()
	var gather: GatherService = _gather()
	inventory = _inv()
	_check("AC-S08", loaded.ok and restored_state.inventories == saved_state.inventories and old_inventory.is_closed() and old_gather.is_closed()
		and gather.query("berry_bush_01").value.depleted and gather.query("branch_pile_01").value.remaining == 5
		and gather.query("stone_pile_01").value.remaining == 4 and _totals(inventory) == NORMAL_TOTALS,
		"restored every inventory exactly (revisions included), no refill, old services closed")
	var events: Array = []
	var counter: Callable = func(ids: Array[StringName], _revisions: Dictionary) -> void: events.append(ids.duplicate())
	inventory.inventories_changed.connect(counter)
	var bag_revision: int = _inv_snapshot("player_bag").revision
	var stone_revision: int = _inv_snapshot("stock_stone_01").revision
	await _stand("stone_pile_01")
	await _press_e()
	var moved: InventoryService.Result = inventory.transfer("player_bag", 1, "test_store", 1, inventory.snapshot("player_bag").value.revision,
		inventory.snapshot("test_store").value.revision)
	inventory.inventories_changed.disconnect(counter)
	_check("AC-S08", events.size() == 2 and _inv_snapshot("stock_stone_01").revision == stone_revision + 1
		and _inv_snapshot("player_bag").revision == bag_revision + 2 and moved.ok and gather.query("stone_pile_01").value.remaining == 3
		and _totals(inventory) == NORMAL_TOTALS, "after load: gather and store move work, revisions +1, totals kept")
	# The NEW path is unchanged: build still starts every stock full.
	var built: GatherService.Result = GatherService.build(load("res://data/items/catalog.tres"), load("res://data/gathering/gather_catalog.tres"),
		[(saved_state.inventories as Array)[0], (saved_state.inventories as Array)[4]], &"player_bag", GatheringMap.BINDINGS)
	_check("AC-S08", built.ok and built.value.gather.query("berry_bush_01").value.remaining == 3
		and built.value.gather.query("branch_pile_01").value.remaining == 6, "GatherService.build NEW stocks 6/4/3")
	if built.ok:
		built.value.gather.close()
		built.value.inventory.close()
	_metrics["AC-S08"] = str(restored_state.inventories)
	_log("AC-S08", "save -> 2 more stones -> load: 5 inventories equal the save, berry depleted, branch 5; then gather/move ok")
	return true


# --- AC-S09 position -----------------------------------------------------------------------

func _s09_position() -> bool:
	var dir: String = _dir("s09")
	await _open_scene(dir)
	await _stand_at(Vector2(300.5, 410.25), "left")
	var position: Vector2 = _player().global_position
	_coord().request_save(_coord().get_epoch())
	await _stand("branch_pile_01")
	var loaded: Dictionary = await _load_and_wait()
	var player: PlayerController = _player()
	var camera: Camera2D = _world().get_node("Interaction/World/Player/Camera2D")
	_check("AC-S09", loaded.ok and player.global_position.distance_to(position) <= 0.0001
		and player.get_facing() == PlayerController.Facing.LEFT and player.velocity == Vector2.ZERO
		and player.get_locomotion() == PlayerController.Locomotion.IDLE and camera.is_current() and camera.enabled,
		"position %s -> %s, facing left, still, camera current" % [position, player.global_position])
	await _ticks(2)
	_check("AC-S09", camera.get_screen_center_position().distance_to(player.global_position) < 200.0 and root.get_camera_2d() == camera,
		"camera follows the restored player")
	var cases: Array = [["inside left wall", Vector2(8, 360), &"INVALID_POSITION"], ["inside block", Vector2(632, 360), &"INVALID_POSITION"],
		["outside the map", Vector2(1290, 360), SaveCodec.CORRUPT_SAVE]]
	for case: Array in cases:
		var world: Node = _world()
		var before: Dictionary = _world_state()
		var text: String = _bank_text(50, func(p: Dictionary) -> void:
			p.player.position = {"x": case[1].x, "y": case[1].y})
		_write_bank(dir, "a", text)
		_write_bank(dir, "b", "")
		var result: Dictionary = await _load_and_wait()
		var expected: StringName = case[2]
		_check("AC-S09", result.code == expected and _world() == world and _world_state() == before and not _inv().is_closed()
			and _host_children() == 1, "%s: %s (%s), world and position unchanged, no teleport" % [case[0], result.code, result.detail])
	await _stand("branch_pile_01")
	var wood: int = _inv().count("player_bag", "wood").value
	await _press_e()
	_check("AC-S09", _inv().count("player_bag", "wood").value == wood + 1, "after refused loads the world plays normally")
	_metrics["AC-S09"] = "%s" % [player.global_position]
	_log("AC-S09", "position within 0.0001, facing/IDLE/velocity 0/camera; wall/block -> INVALID_POSITION, outside map -> refused")
	return true


# --- AC-S10 candidate failures -------------------------------------------------------------

func _s10_candidate_failures() -> bool:
	var outcomes: Dictionary = {}
	var cases: Array = ["focus out-in", "candidate freed", "bootstrap duplicate id", "closed services", "restore refused", "coordinator removed", "host freed"]
	for name: String in cases:
		var dir: String = _dir("s10_" + name.replace(" ", "_"))
		await _open_scene(dir)
		_coord().request_save(_coord().get_epoch())
		await _stand("branch_pile_01")
		await _press_e()
		var world: Node = _world()
		var before: Dictionary = _world_state()
		var coordinator: SaveCoordinator = _coord()
		var store: SaveStore = coordinator.get_store()
		var contexts: Array = []
		var restorer: Callable = func(payload: Dictionary) -> Dictionary:
			var made: Dictionary = GatheringMap.restore_session(payload)
			if made.ok:
				contexts.append(made.context)
			return made
		var scene_for_load: PackedScene = load(MAP_SCENE)
		match name:
			"focus out-in":
				coordinator.stage_hook = func(stage: String) -> void:
					if stage == "candidate_added":
						coordinator.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
						coordinator.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			"candidate freed":
				coordinator.stage_hook = func(stage: String) -> void:
					if stage == "before_publish":
						var host: Node = _scene.get("host")
						for child: Node in host.get_children():
							if child != world:
								child.queue_free()
			"bootstrap duplicate id":
				# A second target with an existing ID, owned by the map root so it is packed.
				var broken: Node = scene_for_load.instantiate()
				var twin: InteractionTarget = (load("res://scenes/interaction/interaction_target.tscn") as PackedScene).instantiate()
				twin.name = "Twin"
				twin.target_id = &"branch_pile_01"
				twin.position = Vector2(700, 600)
				broken.add_child(twin)
				twin.owner = broken
				scene_for_load = PackedScene.new()
				scene_for_load.pack(broken)
				broken.free()
			"closed services":
				restorer = func(payload: Dictionary) -> Dictionary:
					var made: Dictionary = GatheringMap.restore_session(payload)
					if made.ok:
						contexts.append(made.context)
						made.context.gather.close()
					return made
			"restore refused":
				restorer = func(_payload: Dictionary) -> Dictionary: return {"ok": false, "detail": "injected restore failure"}
			"coordinator removed":
				coordinator.stage_hook = func(stage: String) -> void:
					if stage == "candidate_added":
						coordinator.queue_free()
			"host freed":
				coordinator.stage_hook = func(stage: String) -> void:
					if stage == "candidate_added":
						(_scene.get("host") as Node).queue_free()
		coordinator.setup(_scene.get("host"), world, scene_for_load, store, restorer)
		var mark: int = _finished.size()
		coordinator.request_load(coordinator.get_epoch())
		for i: int in 6:
			if _finished.size() > mark:
				break
			await physics_frame
		await process_frame
		var result: Dictionary = _finished[mark] if _finished.size() > mark else {"code": &"TIMEOUT"}
		outcomes[name] = String(result.code)
		var candidates_closed: bool = true
		for context: Dictionary in contexts:
			candidates_closed = candidates_closed and (context.inventory as InventoryService).is_closed() and (context.gather as GatherService).is_closed()
		if name == "host freed":
			_check("AC-S10", result.code == &"REMOVED" and not is_instance_valid(world) and candidates_closed and not coordinator.is_busy(),
				"host freed while staging: REMOVED, nothing revived, candidate services closed")
		else:
			var player: PlayerController = world.get("player")
			var interaction: InteractionController = world.get("interaction")
			var current: bool = not is_instance_valid(coordinator) or coordinator.is_queued_for_deletion() or coordinator.get_world() == world
			_check("AC-S10", not result.ok and is_instance_valid(world) and current and _world_state_of(world) == before
				and not (world.get("inventory") as InventoryService).is_closed() and not (world.get("gather") as GatherService).is_closed()
				and world.process_mode == Node.PROCESS_MODE_INHERIT and player.process_mode == Node.PROCESS_MODE_PAUSABLE
				and interaction.is_interaction_enabled() and candidates_closed and (_scene.get("host") as Node).get_child_count() == 1,
				"%s: %s; old world resumed, services open, candidate discarded" % [name, result.code])
			if is_instance_valid(world):
				var wood: int = (world.get("inventory") as InventoryService).count("player_bag", "wood").value
				await _press_e()
				_check("AC-S10", (world.get("inventory") as InventoryService).count("player_bag", "wood").value == wood + 1,
					"%s: the resumed world gathers again" % name)
		_close_scene()
		await process_frame
	_check("AC-S10", outcomes.get("focus out-in") == "FOCUS_LOST" and outcomes.get("candidate freed") == "REMOVED"
		and outcomes.get("bootstrap duplicate id") == "BOOTSTRAP_FAILED" and outcomes.get("closed services") == "BOOTSTRAP_FAILED"
		and outcomes.get("restore refused") == "INVALID_SAVE" and outcomes.get("coordinator removed") == "REMOVED",
		"failure codes %s" % [outcomes])
	_metrics["AC-S10"] = str(outcomes)
	_log("AC-S10", "stage failures %s" % [outcomes])
	return true


# --- AC-S11 epochs and re-entry ----------------------------------------------------------

func _s11_epochs() -> bool:
	var dir: String = _dir("s11")
	await _open_scene(dir)
	var coordinator: SaveCoordinator = _coord()
	var ui: SaveUI = _ui()
	var old_epoch: int = coordinator.get_epoch()
	var old_world: Node = _world()
	var old_inventory: InventoryService = _inv()
	var old_gather: GatherService = _gather()
	var old_ui: InventoryUI = old_world.get("ui")
	var old_command: GatherService.Result = old_gather.prepare("stone_pile_01", "player_bag", 77)
	(old_command.value as GatherService.GatherCommand).cancel()
	var nested: Array = []
	var stale_intent: Array = []
	var listener: Callable = func(result: Dictionary) -> void:
		nested.append([result.kind, coordinator.request_save(coordinator.get_epoch()).code])
		nested.append([result.kind, coordinator.request_load(coordinator.get_epoch())])
		if result.kind == "load" and result.ok and is_instance_valid(old_ui):
			# The old UI (still alive until the frame ends) sends session ID 1, the ID the new
			# bag will get: it reaches only the old, closed controller and changes nothing.
			var codes: Array = []
			(old_world.get("controller") as InventoryController).command_finished.connect(func(_s: int, code: StringName) -> void: codes.append(code))
			var before_new: Dictionary = _world_state()
			old_ui.transfer_requested.emit(1, &"player_bag", 0, &"wood", 1, 0, 0)
			stale_intent.append([1, codes, _world_state() == before_new])
	coordinator.operation_finished.connect(listener)
	var first_save: Dictionary = coordinator.request_save(old_epoch)
	var loaded: Dictionary = await _load_and_wait()
	coordinator.operation_finished.disconnect(listener)
	var new_state: Dictionary = _world_state()
	var stale_commit: GatherService.Result = (old_command.value as GatherService.GatherCommand).commit()
	_check("AC-S11", first_save.ok and loaded.ok and coordinator.get_epoch() == old_epoch + 1 and old_gather.prepare("branch_pile_01", "player_bag", 5).code == GatherService.CLOSED
		and old_inventory.transfer("player_bag", 0, "test_store", 1, 0, 0).code == InventoryService.CLOSED and not stale_commit.ok
		and _world_state() == new_state, "old services/commands are CLOSED/INVALID_COMMAND and change nothing")
	await _ticks(2)
	var new_controller: InventoryController = _world().get("controller")
	new_controller.request_open(InventoryController.View.STORE)
	var reused: int = new_controller.get_session_id()
	new_controller.request_close(&"CLOSED_BY_USER")
	_check("AC-S11", stale_intent.size() == 1 and stale_intent[0][1] == [&"STALE_SESSION"] and stale_intent[0][2] and reused == 1
		and not is_instance_valid(old_ui), "old UI intent with session ID 1 (new bag also got 1): %s" % [stale_intent])
	_check("AC-S11", nested.size() == 4 and nested.all(func(entry: Array) -> bool: return entry[1] == &"BUSY"),
		"requests from the completion signal are BUSY and not reported again: %s" % [nested])
	# Stale epoch from the UI: refused, no generation written.
	var mark: int = _finished.size()
	ui.save_requested.emit(old_epoch)
	ui.load_requested.emit(old_epoch, SaveStore.SOURCE_LATEST)
	_check("AC-S11", _finished.size() == mark + 2 and _finished[mark].code == &"STALE_SESSION" and _finished[mark + 1].code == &"STALE_SESSION"
		and SaveStore.new(dir, _manifest).inspect().banks.a.generation == 1 and _bank_state(dir)[1] == "missing",
		"old-epoch save/load intents refused")
	# After the rename the UI is freed and focus is lost: the save stands, once.
	coordinator.get_store().stage_hook = func(stage: String) -> void:
		if stage == "after_rename":
			_ui().free()
			coordinator.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var saved: Dictionary = coordinator.request_save(coordinator.get_epoch())
	coordinator.get_store().stage_hook = Callable()
	coordinator.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var status: Dictionary = SaveStore.new(dir, _manifest).inspect()
	_check("AC-S11", saved.ok and saved.committed and saved.generation == 2 and status.latest == "b" and status.banks.b.generation == 2,
		"UI removed and focus lost after the rename: save kept once (%s)" % saved.code)
	# After publish, focus loss in the completion listener does not undo the load.
	var after_publish: Callable = func(_result: Dictionary) -> void:
		coordinator.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	coordinator.operation_finished.connect(after_publish)
	var epoch: int = coordinator.get_epoch()
	var second: Dictionary = await _load_and_wait()
	coordinator.operation_finished.disconnect(after_publish)
	coordinator.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _ticks(3)
	_check("AC-S11", second.ok and coordinator.get_epoch() == epoch + 1 and _host_children() == 1 and not _inv().is_closed(),
		"focus lost after publish: the load stands, no second swap")
	_metrics["AC-S11"] = "%s %s" % [stale_intent, nested.size()]
	_log("AC-S11", "old services CLOSED, old UI intent STALE_SESSION, nested BUSY x%d, stale epoch refused, post-commit removal kept" % nested.size())
	return true


# --- AC-S12 keys and modals ----------------------------------------------------------------

func _s12_keys() -> bool:
	var dir: String = _dir("s12")
	await _open_scene(dir)
	var mark: int = _finished.size()
	_key(KEY_F5, true)
	_key(KEY_F5, false)
	_key(KEY_F5, true, true)
	_key(KEY_F5, false)
	_key(KEY_F5, true)
	_key(KEY_F5, false)
	await process_frame
	var saves: int = _finished.size() - mark
	_check("AC-S12", saves == 1 and SaveStore.new(dir, _manifest).inspect().banks.a.generation == 1 and _bank_state(dir)[1] == "missing",
		"F5 press + echo + second press in one frame: one save (%d)" % saves)
	# Bag open: F5/F9 are refused, the bag stays open and keeps its gate.
	await _stand("branch_pile_01")
	var controller: InventoryController = _world().get("controller")
	_tap_now(KEY_I)
	await _ticks(1)
	mark = _finished.size()
	_tap_now(KEY_F5)
	await _ticks(1)
	_tap_now(KEY_F9)
	await _ticks(2)
	_check("AC-S12", _finished.size() - mark == 2 and _finished[mark].code == &"BUSY" and _finished[mark + 1].code == &"BUSY"
		and controller.get_state() == InventoryController.State.OPEN and controller.owns_movement_gate(), "bag open: F5/F9 BUSY, bag kept")
	_tap_now(KEY_I)
	await _ticks(2)
	# Inspect panel open: refused, panel kept; Escape then closes it as before.
	await _stand("sign")
	await _press_e()
	var interaction: InteractionController = _world().get("interaction")
	mark = _finished.size()
	_tap_now(KEY_F9)
	await _ticks(2)
	_check("AC-S12", _finished.size() - mark == 1 and _finished[mark].code == &"BUSY" and interaction.get_state() == InteractionController.State.ACTIVE,
		"inspect open: F9 BUSY, panel kept")
	_tap_now(KEY_ESCAPE)
	await _ticks(3)
	# F9 with E, I and D pressed (D held) while staging: no ghost action after publish.
	await _stand("branch_pile_01")
	_coord().request_save(_coord().get_epoch())
	var saved_state: Dictionary = _world_state()
	mark = _finished.size()
	_tap_now(KEY_F9)
	_tap_now(KEY_E)
	_tap_now(KEY_I)
	_key(KEY_D, true)
	var loaded: Dictionary = await _wait_finished(mark)
	await _ticks(10)
	var still: Vector2 = _player().global_position
	var after_load: Dictionary = _world_state()
	var new_controller: InventoryController = _world().get("controller")
	_check("AC-S12", loaded.ok and after_load.inventories == saved_state.inventories and new_controller.get_state() == InventoryController.State.CLOSED
		and still.distance_to(Vector2(saved_state.player.position.x, saved_state.player.position.y)) <= 0.0001,
		"keys pressed during load: no gather, no bag, no walk while D is still held")
	_key(KEY_D, false)
	await _ticks(2)
	_key(KEY_D, true)
	await _ticks(8)
	_key(KEY_D, false)
	await _ticks(2)
	var walked: bool = _player().global_position.x > still.x + 1.0
	await _stand("branch_pile_01")
	var wood: int = _inv().count("player_bag", "wood").value
	await _press_e()
	_check("AC-S12", walked and _inv().count("player_bag", "wood").value == wood + 1, "after release, new presses walk and gather")
	# A failed load gives the world back with its gate and interaction as they were.
	_write_bank(dir, "a", _damaged(_read_text(dir + "/slot_01.a.json")))
	_write_bank(dir, "b", _damaged(_read_text(dir + "/slot_01.b.json")))
	mark = _finished.size()
	_tap_now(KEY_F9)
	var failed: Dictionary = await _wait_finished(mark)
	_check("AC-S12", failed.code == SaveStore.CORRUPT_SAVE and _player().is_control_effective()
		and (_world().get("interaction") as InteractionController).is_interaction_enabled(), "failed load: control and interaction restored")
	_metrics["AC-S12"] = "%d %s" % [saves, loaded.code]
	_log("AC-S12", "F5 x1 for press+echo+repeat; bag/inspect BUSY; keys during load ignored; failed load restores control")
	return true


# --- BUG-009 SaveUI lifetime and keys ----------------------------------------------------

## Policy: F5/F9 are live input routed by the scene, not an intent shown on the panel, so
## they use the coordinator's current epoch and keep working when SaveUI is freed, queued
## for deletion or detached; only the display is skipped. A committed save/load stands.
func _b009_ui_lifecycle() -> bool:
	var outcomes: Dictionary = {}
	for mode: String in ["free", "queue_free", "remove_child"]:
		var dir: String = _dir("b009_" + mode)
		await _open_scene(dir)
		var ui: Node = _ui()
		_remove_ui(ui, mode)
		await _ticks(2)
		var first: Dictionary = await _key_request(KEY_F5)
		await _stand("branch_pile_01")
		await _press_e()
		var loaded: Dictionary = await _key_request(KEY_F9)
		var wood: int = _inv().count("player_bag", "wood").value
		await _ticks(2)
		var second: Dictionary = await _key_request(KEY_F5)
		var status: Dictionary = SaveStore.new(dir, _manifest).inspect()
		outcomes[mode] = [String(first.get("code", "")), String(loaded.get("code", "")), String(second.get("code", ""))]
		_check("AC-S12", first.get("ok") == true and first.generation == 1 and loaded.get("ok") == true and wood == 8
			and second.get("ok") == true and second.generation == 2 and status.banks.a.generation == 1 and status.banks.b.generation == 2,
			"UI %s: F5 gen1, F9 restores wood 8, next F5 gen2 (%s)" % [mode, outcomes[mode]])
		if is_instance_valid(ui) and not ui.is_inside_tree():
			ui.free()
	# The UI is removed by the completion listener of a save; the next keys still work.
	var dir_c: String = _dir("b009_in_callback")
	await _open_scene(dir_c)
	var remover: Callable = func(_result: Dictionary) -> void:
		var current: Node = _ui()
		if current != null:
			current.queue_free()
	_coord().operation_finished.connect(remover, CONNECT_ONE_SHOT)
	var saved: Dictionary = await _key_request(KEY_F5)
	await _ticks(2)
	var after_free: Dictionary = await _key_request(KEY_F9)
	var again: Dictionary = await _key_request(KEY_F5)
	_check("AC-S12", saved.get("ok") == true and _ui() == null and after_free.get("ok") == true and again.get("generation") == 2,
		"UI freed by the save listener: F9 and F5 still work once each")
	# Removed while a load is staged, then the next key.
	var dir_l: String = _dir("b009_during_load")
	await _open_scene(dir_l)
	await _key_request(KEY_F5)
	_coord().stage_hook = func(stage: String) -> void:
		if stage == "candidate_added" and _ui() != null:
			_ui().queue_free()
	var staged: Dictionary = await _key_request(KEY_F9)
	_coord().stage_hook = Callable()
	await _ticks(2)
	var next: Dictionary = await _key_request(KEY_F5)
	_check("AC-S12", staged.get("ok") == true and _ui() == null and next.get("ok") == true and next.generation == 2,
		"UI freed while staging: load published, next F5 gen2")
	# A failed load without a UI, then the next key.
	var dir_f: String = _dir("b009_failed_load")
	await _open_scene(dir_f)
	var world: Node = _world()
	_ui().free()
	var failed: Dictionary = await _key_request(KEY_F9)
	var after_fail: Dictionary = await _key_request(KEY_F5)
	_check("AC-S12", failed.get("code") == SaveStore.NO_SAVE and _world() == world and after_fail.get("ok") == true
		and after_fail.generation == 1, "no UI: F9 NO_SAVE keeps the world, next F5 gen1")
	_metrics["BUG-009"] = str(outcomes)
	_log("AC-S12", "BUG-009: keys without SaveUI (free/queue_free/remove_child, in callback, while staging, after failure) %s" % [outcomes])
	return true


# --- BUG-010 re-entry while a refusal is reported ----------------------------------------

func _b010_report_reentry() -> bool:
	var dir: String = _dir("b010")
	await _open_scene(dir)
	var coordinator: SaveCoordinator = _coord()
	var outcomes: Dictionary = {}
	for name: String in ["stale save", "stale load", "no save load", "bag open save", "bag open load"]:
		var nested: Array = []
		var once: Array = [false]
		var observer: Callable = func(_result: Dictionary) -> void:
			if once[0]:
				return
			once[0] = true
			nested.append(coordinator.request_save(coordinator.get_epoch()).code)
			nested.append(coordinator.request_load(coordinator.get_epoch()))
		var controller: InventoryController = _world().get("controller")
		var bag_open: bool = true
		if name.begins_with("bag open"):
			controller.request_open(InventoryController.View.BAG)
			bag_open = controller.get_state() == InventoryController.State.OPEN
		var files: Dictionary = _bank_bytes(dir)
		var epoch: int = coordinator.get_epoch()
		var world: Node = _world()
		var state: Dictionary = _world_state()
		var mark: int = _finished.size()
		coordinator.operation_finished.connect(observer)
		var outer: StringName = &""
		match name:
			"stale save":
				outer = coordinator.request_save(epoch - 1).code
			"stale load":
				outer = coordinator.request_load(epoch - 1)
			"no save load":
				coordinator.request_load(epoch)
				outer = _finished[mark].code if _finished.size() > mark else &""
			"bag open save":
				outer = coordinator.request_save(epoch).code
			"bag open load":
				outer = coordinator.request_load(epoch)
		coordinator.operation_finished.disconnect(observer)
		await _ticks(2)
		outcomes[name] = [String(outer), nested]
		_check("AC-S11", bag_open and outer != SaveCoordinator.OK and nested == [&"BUSY", &"BUSY"] and _finished.size() - mark == 1
			and _bank_bytes(dir) == files and coordinator.get_epoch() == epoch and _world() == world and _world_state() == state,
			"%s: outer %s, nested %s, reports %d, files/epoch/world unchanged" % [name, outer, nested, _finished.size() - mark])
		if name.begins_with("bag open"):
			controller.request_close(&"CLOSED_BY_USER")
			# The player needs one neutral tick before the gate counts as free again.
			await _ticks(2)
	var fresh: Dictionary = coordinator.request_save(coordinator.get_epoch())
	_check("AC-S11", fresh.ok and fresh.generation == 1, "after the reports a normal save works: %s" % fresh.code)
	_metrics["BUG-010"] = str(outcomes)
	_log("AC-S11", "BUG-010: requests from refusal/failure reports all BUSY %s" % [outcomes])
	return true


# --- BUG-011 deferred commands into a suspended session ----------------------------------

func _b011_suspended_commands() -> bool:
	var outcomes: Dictionary = {}
	for name: String in ["published", "invalid position", "focus out-in", "candidate removed"]:
		var dir: String = _dir("b011_" + name.replace(" ", "_"))
		await _open_scene(dir)
		var coordinator: SaveCoordinator = _coord()
		coordinator.request_save(coordinator.get_epoch())
		var saved_state: Dictionary = _world_state()
		if name == "invalid position":
			_write_bank(dir, "a", _bank_text(1, func(p: Dictionary) -> void: p.player.position = {"x": 632.0, "y": 360.0}))
		await _stand("branch_pile_01")
		await _press_e()
		var world: Node = _world()
		var controller: InventoryController = world.get("controller")
		var ui: InventoryUI = world.get("ui")
		var before: Dictionary = _world_state()
		var bag_revision: int = _inv_snapshot("player_bag").revision
		var store_revision: int = _inv_snapshot("test_store").revision
		var opens: Array = []
		var transfers: Array = []
		controller.open_rejected.connect(func(reason: StringName) -> void: opens.append(reason))
		controller.opened.connect(func(_session: int, _view: int) -> void: opens.append(&"OPENED"))
		controller.command_finished.connect(func(_session: int, code: StringName) -> void: transfers.append(code))
		match name:
			"focus out-in":
				coordinator.stage_hook = func(stage: String) -> void:
					if stage == "position_checked":
						coordinator.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
						coordinator.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			"candidate removed":
				coordinator.stage_hook = func(stage: String) -> void:
					if stage == "before_publish":
						for child: Node in (_scene.get("host") as Node).get_children():
							if child != world:
								child.queue_free()
		var mark: int = _finished.size()
		coordinator.request_load(coordinator.get_epoch())
		# Deferred intents of the old session land while it is suspended (before publish).
		controller.request_open.call_deferred(InventoryController.View.STORE)
		ui.view_requested.emit.call_deferred(1, InventoryController.View.STORE)
		ui.transfer_requested.emit.call_deferred(1, &"player_bag", 0, &"wood", 1, bag_revision, store_revision)
		var result: Dictionary = await _wait_finished(mark)
		coordinator.stage_hook = Callable()
		await _ticks(3)
		outcomes[name] = [String(result.get("code", "")), opens.duplicate(), transfers.duplicate()]
		var refused: bool = opens == [&"BUSY"] and transfers.size() == 1 and transfers[0] != &"" \
			and transfers[0] != InventoryController.OK and transfers[0] != &"OK"
		if name == "published":
			var current: InventoryController = _world().get("controller")
			_check("AC-S10", result.get("ok") == true and _world() != world and refused and _world_state().inventories == saved_state.inventories
				and current.get_state() == InventoryController.State.CLOSED and not current.owns_movement_gate(),
				"%s: old-session intents refused %s, new world as saved, its bag closed" % [name, outcomes[name]])
		else:
			var interaction: InteractionController = world.get("interaction")
			_check("AC-S10", result.get("ok") == false and _world() == world and refused and _world_state() == before
				and controller.get_state() == InventoryController.State.CLOSED and not controller.owns_movement_gate()
				and interaction.is_interaction_enabled() and not _gather().has_pending_command() and _player().is_control_effective(),
				"%s: %s; deferred open/view/transfer refused %s, panel/gate/stock unchanged" % [name, result.get("code"), outcomes[name]])
			_tap_now(KEY_I)
			await _ticks(2)
			var opened_now: bool = controller.get_state() == InventoryController.State.OPEN
			_tap_now(KEY_I)
			await _ticks(2)
			_check("AC-S10", opened_now and controller.get_state() == InventoryController.State.CLOSED, "%s: a new I opens and closes the bag" % name)
	# The guard itself on an open panel (a load never starts with it open, so this is
	# reached only by a suspension set directly): a transfer intent and a view switch are
	# refused, the panel, its session and the stock stay as they are.
	var direct_dir: String = _dir("b011_direct")
	await _open_scene(direct_dir)
	var direct: InventoryController = _world().get("controller")
	var direct_ui: InventoryUI = _world().get("ui")
	direct.request_open(InventoryController.View.STORE)
	var session: int = direct.get_session_id()
	var codes: Array = []
	direct.command_finished.connect(func(_s: int, code: StringName) -> void: codes.append(code))
	var state_before: Dictionary = _world_state()
	_world().call("set_session_suspended", true)
	direct_ui.transfer_requested.emit(session, &"player_bag", 0, &"wood", 1, _inv_snapshot("player_bag").revision, _inv_snapshot("test_store").revision)
	var switched: StringName = direct.request_open(InventoryController.View.BAG)
	_world().call("set_session_suspended", false)
	_check("AC-S10", codes == [&"BUSY"] and switched == &"BUSY" and _world_state() == state_before and direct.get_session_id() == session
		and direct.get_view() == InventoryController.View.STORE, "open panel while suspended: transfer %s, view switch %s, nothing changed" % [codes, switched])
	direct.request_close(&"CLOSED_BY_USER")
	_metrics["BUG-011"] = str(outcomes)
	_log("AC-S10", "BUG-011: deferred intents while suspended %s" % [outcomes])
	return true


func _remove_ui(ui: Node, mode: String) -> void:
	match mode:
		"free":
			ui.free()
		"queue_free":
			ui.queue_free()
		"remove_child":
			ui.get_parent().remove_child(ui)


## Presses a key through the real viewport and returns the one result it produced (or {}).
func _key_request(code: Key) -> Dictionary:
	var mark: int = _finished.size()
	_tap_now(code)
	for i: int in 6:
		if _finished.size() > mark:
			break
		await physics_frame
	await _ticks(1)
	_check("AC-S12", _finished.size() - mark <= 1, "one key produced %d results" % (_finished.size() - mark))
	return _finished[mark] if _finished.size() > mark else {}


# --- AC-S13 restart and kill ---------------------------------------------------------------

func _s13_processes() -> bool:
	# Save in one process, load in another and in this one: the same world from disk.
	var dir: String = _dir("s13_restart")
	var saved: Dictionary = _child(["--mode=save", "--root=" + dir, "--out=" + dir + "/child.out"])
	var loaded: Dictionary = _child(["--mode=load", "--root=" + dir, "--out=" + dir + "/child.out"])
	await _open_scene(dir)
	var here: Dictionary = await _load_and_wait()
	var mine: Dictionary = _world_state()
	var child_world: Dictionary = saved.get("result", {}).get("world", {})
	_check("AC-S13", saved.exit == 0 and saved.result.code == "OK" and saved.result.generation == 1 and loaded.exit == 0
		and loaded.result.code == "OK" and _same_world(loaded.result.world, child_world) and here.ok and _same_world(mine, child_world)
		and _count(mine, "player_bag", "wood") == 8 + 2 - 2 and _count(mine, "test_store", "wood") == 2,
		"child save -> exit -> child load and this process load the same world (%s)" % [here.code])
	_close_scene()
	# Kill a saving child at each stage: before the rename the previous generation stays the
	# newest and its bytes are unchanged; after it the new generation is chosen.
	var stages: Dictionary = {}
	for stage: String in ["pending_written", "pending_verified", "before_rename", "after_rename"]:
		var kdir: String = _dir("s13_kill_" + stage)
		SaveStore.new(kdir, _manifest).save_slot(_store_payload())
		var before: Dictionary = _bank_bytes(kdir)
		var killed: Dictionary = await _kill_child(kdir, stage)
		var status: Dictionary = SaveStore.new(kdir, _manifest).inspect()
		var expected_generation: int = 2 if stage == "after_rename" else 1
		var kept: bool = _bank_bytes(kdir).a == before.a
		var next: SaveStore.Result = SaveStore.new(kdir, _manifest).save_slot(_store_payload())
		stages[stage] = [killed.ready, status.code, status.banks[status.latest].generation if not String(status.latest).is_empty() else 0]
		_check("AC-S13", killed.ready and killed.killed and status.code == SaveStore.OK and status.banks[status.latest].generation == expected_generation
			and kept and next.ok and next.generation == expected_generation + 1,
			"killed at %s: newest generation %s, bank a unchanged %s, next save %d" % [stage, stages[stage], kept, next.generation])
	_metrics["AC-S13"] = str(stages)
	_log("AC-S13", "restart across processes ok; kill at stages %s" % [stages])
	return true


# --- AC-S14 deterministic sequence ---------------------------------------------------------

func _s14_sequence() -> bool:
	var dir: String = _dir("s14")
	await _open_scene(dir)
	var trace: Array = []
	var step: Callable = func(label: String) -> void:
		var inventory: InventoryService = _inv()
		_check("AC-S14", _totals(inventory) == NORMAL_TOTALS, "%s: totals %s" % [label, _totals(inventory)])
		trace.append("%s:%s" % [label, _slots(_inv_snapshot("player_bag")).slice(0, 4) + _slots(_inv_snapshot("test_store")).slice(0, 2)])
	await _stand("branch_pile_01")
	await _press_e()
	step.call("gather")
	_inv().transfer("player_bag", 0, "test_store", 9, _inv_snapshot("player_bag").revision, _inv_snapshot("test_store").revision)
	step.call("store")
	await _stand("berry_bush_01")
	for i: int in 3:
		await _press_e()
	step.call("deplete")
	var saved: Dictionary = _coord().request_save(_coord().get_epoch())
	var saved_state: Dictionary = _world_state()
	await _stand("stone_pile_01")
	await _press_e()
	step.call("after save")
	var loaded: Dictionary = await _load_and_wait()
	step.call("loaded")
	_check("AC-S14", saved.ok and loaded.ok and _world_state().inventories == saved_state.inventories
		and _slots(_inv_snapshot("player_bag")).slice(0, 4) == ["berry3", "stone10", "tool_axe1", "-"]
		and _slots(_inv_snapshot("test_store")).slice(0, 1) == ["wood9"], "independent expectation after load")
	await _stand("branch_pile_01")
	await _press_e()
	step.call("continue")
	_metrics["AC-S14"] = str(trace)
	_log("AC-S14", "sequence %s" % [trace])
	return true


# --- helpers -------------------------------------------------------------------------------

func _open_scene(dir: String) -> void:
	_close_scene()
	var leftovers: Array = root.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("SaveLoadTest"))
	_check("AC-S15", leftovers.is_empty(), "no save/load scene may be left in the tree (%d)" % leftovers.size())
	for leftover: Node in leftovers:
		leftover.free()
	_scene = (load(SCENE) as PackedScene).instantiate()
	_scene.set("save_root", dir)
	root.add_child(_scene)
	await process_frame
	(_scene.get("coordinator") as SaveCoordinator).operation_finished.connect(func(result: Dictionary) -> void: _finished.append(result))
	await _ticks(3)


func _close_scene() -> void:
	_release_all()
	if is_instance_valid(_scene):
		_scene.get_parent().remove_child(_scene)
		_scene.queue_free()
	_scene = null


func _coord() -> SaveCoordinator:
	return _scene.get("coordinator")


func _ui() -> Node:
	return _scene.get_node_or_null("SaveUI")


func _world() -> Node:
	return _coord().get_world()


func _inv() -> InventoryService:
	return _world().get("inventory")


func _gather() -> GatherService:
	return _world().get("gather")


func _player() -> PlayerController:
	return _world().get("player")


func _host_children() -> int:
	return (_scene.get("host") as Node).get_child_count()


func _inv_snapshot(inventory_id: String) -> Dictionary:
	return _inv().snapshot(inventory_id).value


func _world_state() -> Dictionary:
	return _world_state_of(_world())


func _world_state_of(world: Node) -> Dictionary:
	return world.call("capture_payload")


func _save_code() -> StringName:
	return _coord().request_save(_coord().get_epoch()).code


func _load_code() -> StringName:
	return _coord().request_load(_coord().get_epoch())


func _load_and_wait(source: StringName = SaveStore.SOURCE_LATEST) -> Dictionary:
	var mark: int = _finished.size()
	_coord().request_load(_coord().get_epoch(), source)
	return await _wait_finished(mark)


func _wait_finished(mark: int = -1) -> Dictionary:
	if mark < 0:
		mark = _finished.size() - 1 if not _finished.is_empty() else 0
	for i: int in 10:
		if _finished.size() > mark:
			break
		await physics_frame
	return _finished[mark] if _finished.size() > mark else {"code": &"TIMEOUT", "ok": false, "detail": "no result"}


func _install_probe(action: Callable) -> void:
	var map: Node2D = _world()
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
	probe.set("on_begin", func() -> void: action.call(map))
	var errors: PackedStringArray = map.call("rebind_points", points)
	_check("AC-S04", errors.is_empty(), "probe view binds (%s)" % [errors])
	await _ticks(2)


## Runs a child Godot process to completion. {exit, result}
func _child(arguments: Array) -> Dictionary:
	var output: Array = []
	var exit: int = OS.execute(OS.get_executable_path(), _child_args(arguments), output, true)
	var out: String = ""
	for argument: String in arguments:
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	var parsed: Variant = JSON.parse_string(_read_text(out)) if FileAccess.file_exists(out) else null
	return {"exit": exit, "result": parsed if typeof(parsed) == TYPE_DICTIONARY else {"code": "NO_RESULT", "output": output}}


## Starts a saving child that blocks at `stage`, waits for its marker, kills it.
func _kill_child(dir: String, stage: String) -> Dictionary:
	var out: String = dir + "/child.out"
	var pid: int = OS.create_process(OS.get_executable_path(), _child_args(["--mode=hang", "--stage=" + stage, "--root=" + dir, "--out=" + out]))
	var ready: bool = false
	for i: int in 400:
		if FileAccess.file_exists(out + ".ready"):
			ready = true
			break
		OS.delay_msec(25)
	# On Unix OS.kill sends SIGKILL and waits for the child (measured on 4.7.2: asking
	# is_process_running afterwards reports the reaped PID as unknown), so OK means it ended.
	var killed: bool = ready and pid > 0 and OS.kill(pid) == OK
	await process_frame
	return {"ready": ready, "killed": killed}


func _child_args(arguments: Array) -> PackedStringArray:
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", CHILD, "--"]
	for argument: String in arguments:
		args.append(argument)
	return args


func _same_world(a: Variant, b: Variant) -> bool:
	if typeof(a) != TYPE_DICTIONARY or typeof(b) != TYPE_DICTIONARY or not a.has("player") or not b.has("player"):
		return false
	var pa: Dictionary = a.player.position
	var pb: Dictionary = b.player.position
	return a.player.facing == b.player.facing and absf(float(pa.x) - float(pb.x)) <= 0.0001 and absf(float(pa.y) - float(pb.y)) <= 0.0001 \
		and JSON.stringify(_ints(a.inventories), "", true) == JSON.stringify(_ints(b.inventories), "", true)


## Child results come back through JSON (floats); compare as ints.
func _ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(value)
		TYPE_ARRAY:
			return (value as Array).map(func(entry: Variant) -> Variant: return _ints(entry))
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key: Variant in value:
				out[key] = _ints(value[key])
			return out
	return value


func _count(world: Dictionary, inventory_id: String, item_id: String) -> int:
	var total: int = 0
	for entry: Dictionary in world.inventories:
		if entry.inventory_id == inventory_id:
			for stack: Variant in entry.slots:
				if stack != null and stack.item_id == item_id:
					total += int(stack.quantity)
	return total


func _fixture(name: String) -> String:
	return FileAccess.get_file_as_string(FIXTURES + name)


## The v1 fixture payload, normalized (ints).
func _base_payload() -> Dictionary:
	return SaveCodec.decode(_fixture("v1_valid.json").to_utf8_buffer(), _manifest).value.duplicate(true)


## What SaveStore.save_slot takes: the payload without versions or generation.
func _store_payload() -> Dictionary:
	return _without_versions(_base_payload())


func _without_versions(payload: Dictionary) -> Dictionary:
	var copy: Dictionary = payload.duplicate(true)
	for key: String in ["schema_version", "content_version", "generation"]:
		copy.erase(key)
	return copy


func _without_position(payload: Dictionary) -> Dictionary:
	var copy: Dictionary = payload.duplicate(true)
	copy.player.erase("position")
	return copy


func _with(payload: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy: Dictionary = payload.duplicate(true)
	copy[key] = value
	return copy


## A valid bank file of the fixture at `generation`, optionally changed first.
func _bank_text(generation: int, change: Callable = Callable()) -> String:
	var payload: Dictionary = _base_payload()
	payload.generation = generation
	if change.is_valid():
		change.call(payload)
	return _envelope(payload)


## Envelope with a correct SHA-256 of the payload text, written independently of SaveCodec.
## other_bytes: hash the UTF-16 bytes instead (must not match).
func _envelope(payload: Dictionary, other_bytes: bool = false) -> String:
	var text: String = JSON.stringify(payload, "", true, true)
	if not other_bytes:
		return _raw_envelope(text)
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf16_buffer())
	return JSON.stringify({"format": "iron-and-harvest-save", "payload_json": text, "sha256": context.finish().hex_encode()})


func _raw_envelope(payload_text: String) -> String:
	return JSON.stringify({"format": "iron-and-harvest-save", "payload_json": payload_text, "sha256": payload_text.sha256_text()})


## Damage that keeps the file ASCII JSON: one checksum character changed.
func _damaged(text: String) -> String:
	var at: int = text.find("\"sha256\":\"") + 10
	return text.substr(0, at) + ("0" if text[at] != "0" else "1") + text.substr(at + 1)


func _inv_of(payload: Dictionary, inventory_id: String) -> Dictionary:
	return _inv_in(payload.inventories, inventory_id)


func _inv_in(list: Array, inventory_id: String) -> Dictionary:
	for entry: Dictionary in list:
		if entry.inventory_id == inventory_id:
			return entry
	return {}


func _dir(name: String) -> String:
	var dir: String = "%s/p%d_%s" % [_run_root, _pass, name]
	_dirs.append(dir)
	return dir


func _write_bank(dir: String, bank: String, text: String) -> void:
	var path: String = "%s/slot_01.%s.json" % [dir, bank]
	if text.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return
	_write_file(path, text)


func _write_file(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _exists(dir: String, suffix: String) -> bool:
	return FileAccess.file_exists("%s/slot_01.%s" % [dir, suffix])


func _bank_bytes(dir: String) -> Dictionary:
	var out: Dictionary = {}
	for bank: String in ["a", "b"]:
		var path: String = "%s/slot_01.%s.json" % [dir, bank]
		out[bank] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	return out


func _bank_state(dir: String) -> Array:
	return ["present" if _exists(dir, "a.json") else "missing", "present" if _exists(dir, "b.json") else "missing"]


## Removes only the fixed file names this runner creates, then the empty directories.
func _clean_files() -> int:
	var removed: int = 0
	for dir: String in _dirs:
		for name: String in FILE_NAMES:
			if FileAccess.file_exists(dir + "/" + name) and DirAccess.remove_absolute(dir + "/" + name) == OK:
				removed += 1
		if DirAccess.dir_exists_absolute(dir) and DirAccess.get_files_at(dir).is_empty() and DirAccess.get_directories_at(dir).is_empty():
			DirAccess.remove_absolute(dir)
	if DirAccess.dir_exists_absolute(_run_root) and DirAccess.get_files_at(_run_root).is_empty() and DirAccess.get_directories_at(_run_root).is_empty():
		DirAccess.remove_absolute(_run_root)
	_check("AC-S15", not DirAccess.dir_exists_absolute(_run_root), "test root removed: %s" % _run_root)
	return removed


func _totals(inventory: InventoryService) -> Dictionary:
	var totals: Dictionary = {}
	for item_id: String in ITEMS:
		var total: int = 0
		for inventory_id: String in ["player_bag", "test_store", "stock_branch_01", "stock_stone_01", "stock_berry_01"]:
			var counted: InventoryService.Result = inventory.count(inventory_id, item_id)
			total += int(counted.value) if counted.ok else 0
		totals[item_id] = total
	return totals


func _slots(snapshot: Dictionary) -> Array:
	var out: Array = []
	for stack: Variant in snapshot.get("slots", []):
		out.append("-" if stack == null else "%s%d" % [stack.item_id, stack.quantity])
	return out


func _stand(point_id: String) -> void:
	await _stand_at(STANDS[point_id][0], STANDS[point_id][1])


func _stand_at(position: Vector2, facing: String) -> void:
	_release_all()
	await physics_frame
	var player: PlayerController = _player()
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


func _tap_now(code: Key) -> void:
	_key(code, true)
	_key(code, false)


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


func _all_released() -> bool:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"interact", &"inventory_toggle", &"save_game", &"load_game"]:
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
	_check("AC-S14", first.keys() == second.keys() and differences.is_empty(), "pass differences %s" % differences)
	_log("AC-S14", "passes=2 measurements=%d differences=%d" % [first.size(), differences.size()])


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
	print("IH-112 automated summary:")
	var keys: Array = _ac_checks.keys()
	keys.sort()
	for ac: String in keys:
		var counts: Array = _ac_checks[ac]
		print("  %s %s (%d checks, %d failed)" % [ac, "PASS" if counts[1] == 0 else "FAIL", counts[0], counts[1]])
	print("  Not covered here: real GUI use (AC-S16), Windows file system, power loss, code/doc review.")
	if _failures.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		for failure: String in _failures:
			print("  FAILED " + failure)
		print("RESULT: FAIL (%d)" % _failures.size())
		quit(1)
