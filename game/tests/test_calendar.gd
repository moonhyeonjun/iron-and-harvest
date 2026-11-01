extends SceneTree
## IH-120 acceptance runner. Domain cases drive CalendarRules/CalendarService directly with
## expectations written here (date tables are built by nested loops over years, seasons and
## days, not with the service's formula). Scene cases use the real calendar_test scene
## (SaveLoadTest + CalendarController + CalendarHUD) with keys through
## Input.parse_input_event + flush and real files under a unique user://tests/ih120 root;
## AC-C09 also saves and loads in separate Godot processes. Exit 0 only when every
## automated check passes. Real GUI use (AC-C16) is never reported here.

const SCENE: String = "res://scenes/tests/calendar_test.tscn"
const GATHERING_SCENE: String = "res://scenes/tests/gathering_test.tscn"
const SAVE_LOAD_SCENE: String = "res://scenes/tests/save_load_test.tscn"
const CHILD: String = "res://tests/support/calendar_child.gd"
const RULES_PATH: String = "res://data/calendar/calendar_rules.json"
const SAVE_FIXTURES: String = "res://tests/fixtures/save/"
const GatheringMap: Script = preload("res://scripts/tests/gathering_test.gd")
const DEFAULT: String = "calendar_test_v1"
const FAST: String = "calendar_boundary_fixture_v1"
const TRUSTED: Array = ["calendar_test_v1", "calendar_boundary_fixture_v1"]
const SEASONS: Array = ["spring", "summer", "autumn", "winter"]
const MAX_SAFE: int = 9007199254740991
const FILE_NAMES: Array[String] = ["slot_01.a.json", "slot_01.b.json", "slot_01.a.pending", "slot_01.b.pending",
	"child.out", "child.out.ready"]
const STANDS: Dictionary = {"branch_pile_01": [Vector2(228, 360), "right"]}
const FACING_KEYS: Dictionary = {"down": KEY_S, "up": KEY_W, "left": KEY_A, "right": KEY_D}

var _ac_checks: Dictionary = {}
var _failures: Array[String] = []
var _held: Array[Key] = []
var _metrics: Dictionary = {}
var _pass_metrics: Array[Dictionary] = []
var _pass: int = 0
var _run_root: String = ""
var _dirs: Array[String] = []
var _scene: Node
var _commands: Array[Dictionary] = []
var _boundaries: Array[Dictionary] = []
var _saves: Array[Dictionary] = []
var _rules: CalendarRules
var _default: Dictionary
var _fast: Dictionary
var _engine_errors: EngineErrorLog = EngineErrorLog.new()


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
	print("IH-120 runner: engine=%s physics_hz=%d" % [Engine.get_version_info().string, Engine.physics_ticks_per_second])
	_run_root = "user://tests/ih120/runner_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var parsed: CalendarRules.Result = CalendarRules.parse(FileAccess.get_file_as_string(RULES_PATH), TRUSTED)
	_rules = parsed.value
	_default = _rules.get_profile(DEFAULT).value
	_fast = _rules.get_profile(FAST).value
	for pass_index: int in 2:
		_pass = pass_index
		_metrics = {}
		var steps: Array = [
			["AC-C01", _c01_rules], ["AC-C02", _c02_dates], ["AC-C03", _c03_advance], ["AC-C04", _c04_boundary],
			["AC-C10", _c10_migration], ["AC-C11", _c11_codec], ["AC-C14", _c14_years],
			["AC-C13", _c13_passive], ["AC-C05", _c05_adapter], ["AC-C06", _c06_pauses], ["AC-C07", _c07_next_day],
			["AC-C04", _c04_scene_reentry], ["AC-C08", _c08_lifetime], ["AC-C09", _c09_round_trip], ["AC-C12", _c12_sessions],
			["AC-C09", _c09_processes],
		]
		for step: Array in steps:
			var completed: Variant = await (step[1] as Callable).call()
			_check(step[0], completed == true, "%s case list aborted before completion" % step[0])
			_close()
			await process_frame
		_check("AC-C15", _all_released(), "pass %d left a key pressed" % pass_index)
		_pass_metrics.append(_metrics)
	_compare_passes()
	await process_frame
	await process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check("AC-C15", orphans == 0, "orphan nodes after both passes: %d" % orphans)
	_log("AC-C15", "orphan nodes after both passes: %d" % orphans)
	var removed: int = _clean_files()
	_log("AC-C15", "removed %d test files under %s; user://saves present: %s" % [removed, _run_root, DirAccess.dir_exists_absolute("user://saves")])
	if "--inject-failure" in OS.get_cmdline_user_args():
		_check("AC-C15", false, "deliberate failure requested by --inject-failure")
	var errors: PackedStringArray = _engine_errors.entries()
	OS.remove_logger(_engine_errors)
	_check("AC-C15", errors.is_empty(), "engine/script errors during the run: %s" % "; ".join(errors))
	_log("AC-C15", "engine/script errors logged during the run: %d" % errors.size())
	_finish()


# --- AC-C01 rules ------------------------------------------------------------------------

func _c01_rules() -> bool:
	var parsed: CalendarRules.Result = CalendarRules.parse(FileAccess.get_file_as_string(RULES_PATH), TRUSTED)
	var rules: CalendarRules = parsed.value
	var default: Dictionary = rules.get_profile(DEFAULT).value if parsed.ok else {}
	var fast: Dictionary = rules.get_profile(FAST).value if parsed.ok else {}
	_check("AC-C01", parsed.ok and rules.get_rule_ids() == [DEFAULT, FAST]
		and default == {"rule_id": DEFAULT, "physics_hz": 60, "ticks_per_day": 36000, "days_per_season": 14, "seasons": SEASONS,
			"day_start_minute": 360, "max_year": 9999}
		and fast.ticks_per_day == 120 and fast.days_per_season == 2 and typeof(fast.ticks_per_day) == TYPE_INT,
		"two trusted profiles with the proposed values: %s" % [parsed.detail])
	default.ticks_per_day = 1
	(default.seasons as Array).reverse()
	_check("AC-C01", rules.get_profile(DEFAULT).value.ticks_per_day == 36000 and rules.get_profile(DEFAULT).value.seasons == SEASONS,
		"editing a returned profile changes nothing")
	var service: CalendarService = CalendarService.create(rules.get_profile(DEFAULT).value).value
	var profile_copy: Dictionary = service.get_profile()
	profile_copy.ticks_per_day = 5
	_check("AC-C01", service.get_profile().ticks_per_day == 36000 and service.ticks_to_next_dawn() == 36000,
		"the service keeps its own profile copy")
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	var cases: Array = [
		["missing key", func(d: Dictionary) -> void: d.profiles[0].erase("max_year")],
		["extra key", func(d: Dictionary) -> void: d.profiles[0]["hours"] = 24],
		["duplicate id", func(d: Dictionary) -> void: d.profiles[1].rule_id = DEFAULT],
		["untrusted id", func(d: Dictionary) -> void: d.profiles[1].rule_id = "calendar_other_v1"],
		["bool ticks", func(d: Dictionary) -> void: d.profiles[0].ticks_per_day = true],
		["fraction ticks", func(d: Dictionary) -> void: d.profiles[0].ticks_per_day = 1.5],
		["string ticks", func(d: Dictionary) -> void: d.profiles[0].ticks_per_day = "36000"],
		["zero ticks", func(d: Dictionary) -> void: d.profiles[0].ticks_per_day = 0],
		["negative days", func(d: Dictionary) -> void: d.profiles[0].days_per_season = -1],
		["huge ticks", func(d: Dictionary) -> void: d.profiles[0].ticks_per_day = MAX_SAFE + 1],
		["30 Hz", func(d: Dictionary) -> void: d.profiles[0].physics_hz = 30],
		["season order", func(d: Dictionary) -> void: d.profiles[0].seasons = ["summer", "spring", "autumn", "winter"]],
		["three seasons", func(d: Dictionary) -> void: d.profiles[0].seasons = ["spring", "summer", "autumn"]],
		["day start 1440", func(d: Dictionary) -> void: d.profiles[0].day_start_minute = 1440],
		["max year 10000", func(d: Dictionary) -> void: d.profiles[0].max_year = 10000],
		["empty profiles", func(d: Dictionary) -> void: d.profiles = []],
		["extra root key", func(d: Dictionary) -> void: d["note"] = "x"],
	]
	for case: Array in cases:
		var data: Dictionary = base.duplicate(true)
		(case[1] as Callable).call(data)
		var result: CalendarRules.Result = CalendarRules.parse(JSON.stringify(data), TRUSTED)
		_check("AC-C01", not result.ok and result.code == CalendarRules.INVALID_RULES and result.value == null,
			"%s rejected (%s)" % [case[0], result.detail])
	for text: String in ["[1]", "{", "", "{\"profiles\":[{\"rule_id\":NaN}]}"]:
		_check("AC-C01", not CalendarRules.parse(text, TRUSTED).ok, "malformed text rejected: %s" % text)
	_metrics["AC-C01"] = "%d" % cases.size()
	_log("AC-C01", "2 profiles; %d bad definitions rejected; copies independent" % (cases.size() + 4))
	return true


# --- AC-C02 dates ------------------------------------------------------------------------

func _c02_dates() -> bool:
	var start: Dictionary = _service(DEFAULT).get_date().value
	_check("AC-C02", start == {"year": 1, "season_index": 0, "season_id": "spring", "day_of_season": 1, "hour": 6, "minute": 0, "minute_of_day": 360},
		"new game: year 1 spring day 1 06:00 (%s)" % [start])
	# [profile, day_index, tick, expected year, season, day, "hh:mm"] written by hand.
	var table: Array = [
		[DEFAULT, 0, 35999, 1, "spring", 1, "05:59"], [DEFAULT, 0, 26999, 1, "spring", 1, "23:59"],
		[DEFAULT, 0, 27000, 1, "spring", 1, "00:00"], [DEFAULT, 13, 35999, 1, "spring", 14, "05:59"],
		[DEFAULT, 14, 0, 1, "summer", 1, "06:00"], [DEFAULT, 27, 35999, 1, "summer", 14, "05:59"],
		[DEFAULT, 28, 0, 1, "autumn", 1, "06:00"], [DEFAULT, 42, 0, 1, "winter", 1, "06:00"],
		[DEFAULT, 55, 35999, 1, "winter", 14, "05:59"], [DEFAULT, 56, 0, 2, "spring", 1, "06:00"],
		[DEFAULT, 559943, 35999, 9999, "winter", 14, "05:59"], [DEFAULT, 0, 18000, 1, "spring", 1, "18:00"],
		[FAST, 0, 0, 1, "spring", 1, "06:00"], [FAST, 0, 89, 1, "spring", 1, "23:48"], [FAST, 0, 90, 1, "spring", 1, "00:00"],
		[FAST, 1, 119, 1, "spring", 2, "05:48"], [FAST, 2, 0, 1, "summer", 1, "06:00"], [FAST, 7, 0, 1, "winter", 2, "06:00"],
		[FAST, 8, 0, 2, "spring", 1, "06:00"],
	]
	for row: Array in table:
		var profile: Dictionary = _default if row[0] == DEFAULT else _fast
		var restored: CalendarService.Result = CalendarService.restore({"rule_id": row[0], "day_index": row[1], "tick_in_day": row[2], "revision": 0}, profile)
		var date: Dictionary = restored.value.get_date().value if restored.ok else {}
		var shown: String = "%02d:%02d" % [date.get("hour", -1), date.get("minute", -1)]
		_check("AC-C02", restored.ok and date.year == row[3] and date.season_id == row[4] and date.day_of_season == row[5] and shown == row[6],
			"%s day %d tick %d -> %s (%s)" % [row[0], row[1], row[2], [date.get("year"), date.get("season_id"), date.get("day_of_season"), shown], row.slice(3)])
	# Midnight is not a boundary: from 23:59 the next tick keeps the day_index.
	var night: CalendarService = CalendarService.restore({"rule_id": DEFAULT, "day_index": 3, "tick_in_day": 26999, "revision": 5}, _default).value
	var events: Array = []
	var listener: Callable = func(event: Dictionary) -> void: events.append(event)
	night.day_advanced.connect(listener)
	var across: Dictionary = night.advance_ticks(1, 5)
	night.day_advanced.disconnect(listener)
	_check("AC-C02", across.ok and across.snapshot.day_index == 3 and across.boundary == null and events.is_empty()
		and night.get_date().value.minute_of_day == 0, "23:59 -> 00:00 stays day 3, no event")
	_check("AC-C02", (night.get_snapshot().value as Dictionary).keys().size() == 4, "state holds only rule/day/tick/revision")
	_metrics["AC-C02"] = "%d" % table.size()
	_log("AC-C02", "%d hand-written dates (both profiles), midnight is not a boundary" % table.size())
	return true


# --- AC-C03 advance ----------------------------------------------------------------------

func _c03_advance() -> bool:
	var service: CalendarService = _service(DEFAULT)
	var events: Array = []
	var listener: Callable = func(event: Dictionary) -> void: events.append(event)
	service.day_advanced.connect(listener)
	var one: Dictionary = service.advance_ticks(1, 0)
	var many: Dictionary = service.advance_ticks(500, 1)
	var rest: Dictionary = service.advance_ticks(service.ticks_to_next_dawn(), 2)
	var full: Dictionary = service.advance_ticks(service.ticks_to_next_dawn(), 3)
	_check("AC-C03", one.ok and one.snapshot.tick_in_day == 1 and one.snapshot.revision == 1 and many.snapshot.tick_in_day == 501
		and many.snapshot.revision == 2 and rest.snapshot == {"rule_id": DEFAULT, "day_index": 1, "tick_in_day": 0, "revision": 3}
		and full.snapshot == {"rule_id": DEFAULT, "day_index": 2, "tick_in_day": 0, "revision": 4} and events.size() == 2,
		"1, 500, rest of day, exactly one day from dawn; revision +1 per command, 2 boundaries")
	var before: Dictionary = service.get_snapshot().value
	var bad: Array = [[0, 4], [-1, 4], [36001, 4], [1.0, 4], [true, 4], ["1", 4], [null, 4], [1, 4.0], [1, true]]
	for args: Array in bad:
		var result: Dictionary = service.advance_ticks(args[0], args[1])
		_check("AC-C03", result.code == CalendarService.INVALID_AMOUNT and not result.ok and service.get_snapshot().value == before,
			"advance%s -> %s" % [args, result.code])
	var stale: Dictionary = service.advance_ticks(1, 3)
	_check("AC-C03", stale.code == CalendarService.STALE_REVISION and service.get_snapshot().value == before and events.size() == 2,
		"old revision refused, no change")
	service.day_advanced.disconnect(listener)
	# The last day: ticks inside it are fine, the next dawn is refused as a whole.
	var last: CalendarService = CalendarService.restore({"rule_id": DEFAULT, "day_index": 559943, "tick_in_day": 35990, "revision": 9}, _default).value
	var inside: Dictionary = last.advance_ticks(9, 9)
	var beyond: Dictionary = last.advance_ticks(1, 10)
	_check("AC-C03", inside.ok and inside.snapshot.tick_in_day == 35999 and beyond.code == CalendarService.NUMBER_OUT_OF_RANGE
		and last.get_snapshot().value.tick_in_day == 35999 and last.get_snapshot().value.revision == 10,
		"9999 winter 14 runs to 05:59; the next tick is NUMBER_OUT_OF_RANGE with nothing changed")
	var revision_max: CalendarService = CalendarService.restore({"rule_id": DEFAULT, "day_index": 0, "tick_in_day": 0, "revision": MAX_SAFE}, _default).value
	_check("AC-C03", revision_max.advance_ticks(1, MAX_SAFE).code == CalendarService.NUMBER_OUT_OF_RANGE
		and revision_max.get_snapshot().value.tick_in_day == 0, "revision at 2^53-1 cannot advance")
	service.close()
	service.close()
	_check("AC-C03", service.advance_ticks(1, 4).code == CalendarService.CLOSED and service.get_snapshot().code == CalendarService.CLOSED
		and service.get_date().code == CalendarService.CLOSED, "closed (twice): advance and reads are CLOSED")
	var restores: Array = [{"rule_id": FAST, "day_index": 0, "tick_in_day": 0, "revision": 0},
		{"rule_id": DEFAULT, "day_index": 0, "tick_in_day": 36000, "revision": 0}, {"rule_id": DEFAULT, "day_index": -1, "tick_in_day": 0, "revision": 0},
		{"rule_id": DEFAULT, "day_index": 559944, "tick_in_day": 0, "revision": 0}, {"rule_id": DEFAULT, "day_index": 1.0, "tick_in_day": 0, "revision": 0},
		{"rule_id": DEFAULT, "day_index": 0, "tick_in_day": 0}, {"rule_id": DEFAULT, "day_index": 0, "tick_in_day": 0, "revision": 0, "year": 1}]
	for snapshot: Dictionary in restores:
		_check("AC-C03", CalendarService.restore(snapshot, _default).code == CalendarService.INVALID_STATE, "restore refuses %s" % [snapshot])
	_metrics["AC-C03"] = str(full.snapshot)
	_log("AC-C03", "advance 1/500/rest/day, %d bad arguments, stale, last day and revision limits, close, %d bad restores" % [bad.size(), restores.size()])
	return true


# --- AC-C04 boundary and re-entry (service) ------------------------------------------------

func _c04_boundary() -> bool:
	var service: CalendarService = CalendarService.restore({"rule_id": DEFAULT, "day_index": 13, "tick_in_day": 35999, "revision": 42}, _default).value
	var seen: Array = []
	var listener: Callable = func(event: Dictionary) -> void:
		seen.append({"event": event, "snapshot": service.get_snapshot().value, "reentry": service.advance_ticks(1, 43).code,
			"busy": service.is_busy(), "read_only": event.is_read_only()})
	service.day_advanced.connect(listener)
	var crossed: Dictionary = service.advance_ticks(1, 42)
	service.day_advanced.disconnect(listener)
	var expected: Dictionary = {"from_day_index": 13, "to_day_index": 14, "completed_day_index": 13, "from_season_id": "spring",
		"to_season_id": "summer", "from_year": 1, "to_year": 1, "revision": 43}
	var inside: Dictionary = seen[0] if seen.size() == 1 else {}
	_check("AC-C04", crossed.ok and seen.size() == 1 and inside.event == expected and inside.snapshot.day_index == 14
		and inside.snapshot.revision == 43 and inside.reentry == CalendarService.BUSY and inside.busy and inside.read_only,
		"one event after install: completed_day_index 13 (spring 14) -> summer 1, re-entry BUSY: %s" % [inside])
	var returned: Dictionary = crossed.boundary
	returned.to_day_index = 99
	(crossed.snapshot as Dictionary).day_index = 99
	_check("AC-C04", service.get_snapshot().value.day_index == 14 and service.advance_ticks(1, 42).code == CalendarService.STALE_REVISION
		and service.get_snapshot().value.revision == 43, "returned values are copies; the same revision again is STALE_REVISION")
	var year: CalendarService = CalendarService.restore({"rule_id": FAST, "day_index": 7, "tick_in_day": 119, "revision": 0}, _fast).value
	var to_year: Dictionary = year.advance_ticks(1, 0)
	_check("AC-C04", to_year.boundary.from_year == 1 and to_year.boundary.to_year == 2 and to_year.boundary.to_season_id == "spring"
		and to_year.boundary.from_season_id == "winter", "winter 2 -> year 2 spring 1 in one event")
	_metrics["AC-C04"] = str(expected)
	_log("AC-C04", "boundary event once after install, read-only, re-entry BUSY, stale request refused")
	return true


# --- AC-C10 migration ----------------------------------------------------------------------

func _c10_migration() -> bool:
	var manifest: Dictionary = GatheringMap.save_manifest(DEFAULT)
	var default_calendar: Dictionary = {"rule_id": DEFAULT, "day_index": 0, "tick_in_day": 0, "revision": 0}
	var v1_text: String = _fixture("v1_valid.json")
	var v0_text: String = _fixture("v0_valid.json")
	var v1_raw: Dictionary = JSON.parse_string(JSON.parse_string(v1_text).payload_json)
	var v1: SaveCodec.Result = SaveCodec.decode(v1_text.to_utf8_buffer(), manifest)
	var v0: SaveCodec.Result = SaveCodec.decode(v0_text.to_utf8_buffer(), manifest)
	_check("AC-C10", v1.ok and v1.migrated_from == 1 and v1.value.schema_version == 2 and v1.value.calendar == default_calendar
		and v1.value.generation == 3 and JSON.stringify(_ints(v1_raw.inventories), "", true) == JSON.stringify(v1.value.inventories, "", true)
		and v1.value.player.facing == "right", "v1 -> 2: default calendar, generation/inventories/revisions/facing kept")
	_check("AC-C10", v0.ok and v0.migrated_from == 0 and v0.value.schema_version == 2 and v0.value.calendar == default_calendar
		and v0.value.player.facing == "down" and v0.value.generation == 2
		and JSON.stringify(v0.value.inventories, "", true) == JSON.stringify(v1.value.inventories, "", true), "v0 -> 1 -> 2: facing down, default calendar")
	# v1 problems are not covered up by the migration (it validates v1 first).
	var cases: Array = [
		["missing key", func(p: Dictionary) -> void: p.erase("points"), SaveCodec.INVALID_SAVE],
		["bad facing", func(p: Dictionary) -> void: p.player.facing = "north", SaveCodec.INVALID_SAVE],
		["bad ID", func(p: Dictionary) -> void: p.map_id = "other_map", SaveCodec.CONTENT_MISMATCH],
		["over stack", func(p: Dictionary) -> void: p.inventories[0].slots[0].quantity = 11, SaveCodec.INVALID_SAVE],
		["v1 with a calendar", func(p: Dictionary) -> void: p["calendar"] = default_calendar.duplicate(), SaveCodec.INVALID_SAVE],
		["v0 with a calendar", func(p: Dictionary) -> void:
			p.schema_version = 0
			p.player.erase("facing")
			p["calendar"] = default_calendar.duplicate(), SaveCodec.INVALID_SAVE],
	]
	for case: Array in cases:
		var payload: Dictionary = v1_raw.duplicate(true)
		(case[1] as Callable).call(payload)
		var result: SaveCodec.Result = SaveCodec.decode(_envelope(payload).to_utf8_buffer(), manifest)
		_check("AC-C10", result.code == case[2], "%s -> %s (%s)" % [case[0], result.code, result.detail])
	var fast_manifest: Dictionary = GatheringMap.save_manifest(FAST)
	_check("AC-C10", SaveCodec.decode(v1_text.to_utf8_buffer(), fast_manifest).code == SaveCodec.CONTENT_MISMATCH,
		"a v1 file is never migrated into the fast profile")
	# Files: loading never writes; the next save writes schema 2 and the next generation.
	var dir: String = _dir("c10")
	_write_bank(dir, "a", v1_text)
	var before: PackedByteArray = FileAccess.get_file_as_bytes(dir + "/slot_01.a.json")
	var store: SaveStore = SaveStore.new(dir, manifest)
	var loaded: SaveStore.Result = store.load_slot()
	var unchanged: bool = FileAccess.get_file_as_bytes(dir + "/slot_01.a.json") == before
	var payload: Dictionary = loaded.payload.duplicate(true)
	for key: String in ["schema_version", "content_version", "generation"]:
		payload.erase(key)
	var saved: SaveStore.Result = store.save_slot(payload)
	var written: Dictionary = JSON.parse_string(JSON.parse_string(FileAccess.get_file_as_string(dir + "/slot_01.b.json")).payload_json)
	_check("AC-C10", loaded.ok and loaded.migrated_from == 1 and unchanged and saved.ok and saved.source_bank == "b" and saved.generation == 4
		and written.schema_version == 2.0 and written.calendar.rule_id == DEFAULT
		and FileAccess.get_file_as_bytes(dir + "/slot_01.a.json") == before, "load writes nothing; next save b4 schema 2; v1 bank kept")
	# Scene: a v1 save loads as 1년 봄 1일 06:00 with the saved stock, no event.
	var scene_dir: String = _dir("c10_scene")
	_write_bank(scene_dir, "a", v1_text)
	await _open(scene_dir, DEFAULT)
	await _pause_time()
	var mark: int = _boundaries.size()
	var result: Dictionary = await _load_and_wait()
	await _ticks(3)
	var calendar: CalendarService = _cal()
	_check("AC-C10", result.get("ok") == true and result.migrated_from == 1 and calendar.get_snapshot().value == default_calendar
		and _boundaries.size() == mark and _bag_slots()[0] == "wood6" and _hud().get_date_text() == "1년 봄 1일 06:00",
		"scene: v1 loads at 1년 봄 1일 06:00 with its stock, no event (%s)" % _hud().get_date_text())
	_metrics["AC-C10"] = "%s %s" % [v1.migrated_from, v0.migrated_from]
	_log("AC-C10", "v1->2 and v0->1->2 keep everything but add the default calendar; %d v1 problems still refused; no write on load" % cases.size())
	return true


# --- AC-C11 codec failures -----------------------------------------------------------------

func _c11_codec() -> bool:
	var manifest: Dictionary = GatheringMap.save_manifest(DEFAULT)
	var base: Dictionary = SaveCodec.decode(_fixture("v1_valid.json").to_utf8_buffer(), manifest).value
	base.calendar = {"rule_id": DEFAULT, "day_index": 13, "tick_in_day": 35999, "revision": 42}
	var good: SaveCodec.Result = SaveCodec.decode(_envelope(base).to_utf8_buffer(), manifest)
	_check("AC-C11", good.ok and good.migrated_from == -1 and good.value.calendar == base.calendar, "a valid schema 2 file decodes as is")
	var cases: Array = [
		["no calendar", func(p: Dictionary) -> void: p.erase("calendar"), SaveCodec.INVALID_SAVE],
		["key typo", func(p: Dictionary) -> void:
			p.calendar.erase("tick_in_day")
			p.calendar["tick"] = 0, SaveCodec.INVALID_SAVE],
		["extra field", func(p: Dictionary) -> void: p.calendar["season"] = "summer", SaveCodec.INVALID_SAVE],
		["day 1.5", func(p: Dictionary) -> void: p.calendar.day_index = 1.5, SaveCodec.INVALID_SAVE],
		["tick bool", func(p: Dictionary) -> void: p.calendar.tick_in_day = true, SaveCodec.INVALID_SAVE],
		["revision string", func(p: Dictionary) -> void: p.calendar.revision = "42", SaveCodec.INVALID_SAVE],
		["tick 36000", func(p: Dictionary) -> void: p.calendar.tick_in_day = 36000, SaveCodec.NUMBER_OUT_OF_RANGE],
		["day after the last", func(p: Dictionary) -> void: p.calendar.day_index = 559944, SaveCodec.NUMBER_OUT_OF_RANGE],
		["negative day", func(p: Dictionary) -> void: p.calendar.day_index = -1, SaveCodec.NUMBER_OUT_OF_RANGE],
		["revision 2^53", func(p: Dictionary) -> void: p.calendar.revision = MAX_SAFE + 1, SaveCodec.NUMBER_OUT_OF_RANGE],
		["fast rule here", func(p: Dictionary) -> void: p.calendar.rule_id = FAST, SaveCodec.CONTENT_MISMATCH],
		["unknown rule", func(p: Dictionary) -> void: p.calendar.rule_id = "calendar_other_v1", SaveCodec.CONTENT_MISMATCH],
		["calendar not an object", func(p: Dictionary) -> void: p.calendar = [13, 35999], SaveCodec.INVALID_SAVE],
		["schema 3", func(p: Dictionary) -> void: p.schema_version = 3, SaveCodec.UNSUPPORTED_SCHEMA],
		["content 2", func(p: Dictionary) -> void: p.content_version = 2, SaveCodec.CONTENT_MISMATCH],
	]
	var codes: Dictionary = {}
	for case: Array in cases:
		var payload: Dictionary = base.duplicate(true)
		(case[1] as Callable).call(payload)
		var result: SaveCodec.Result = SaveCodec.decode(_envelope(payload).to_utf8_buffer(), manifest)
		codes[case[0]] = String(result.code)
		_check("AC-C11", result.code == case[2] and result.value == null, "%s -> %s (%s)" % [case[0], result.code, result.detail])
	var fixtures: Array = [["schema3_future.json", SaveCodec.UNSUPPORTED_SCHEMA], ["schema2_future.json", SaveCodec.INVALID_SAVE],
		["content2.json", SaveCodec.CONTENT_MISMATCH]]
	for fixture: Array in fixtures:
		var result: SaveCodec.Result = SaveCodec.decode(_fixture(fixture[0]).to_utf8_buffer(), manifest)
		codes[fixture[0]] = String(result.code)
		_check("AC-C11", result.code == fixture[1], "%s -> %s" % fixture)
	var schema3: Dictionary = JSON.parse_string(JSON.parse_string(_fixture("schema3_future.json")).payload_json)
	_check("AC-C11", schema3.schema_version == 3.0 and schema3.schema_version > SaveCodec.SCHEMA_VERSION, "the new future fixture really is schema 3")
	var changed: Dictionary = JSON.parse_string(_envelope(base))
	changed.payload_json = (changed.payload_json as String).replace("\"day_index\":13", "\"day_index\":14")
	_check("AC-C11", SaveCodec.decode(JSON.stringify(changed).to_utf8_buffer(), manifest).code == SaveCodec.CHECKSUM_MISMATCH,
		"a changed calendar with the old hash is a checksum mismatch, not a structure error")
	_metrics["AC-C11"] = str(codes)
	_log("AC-C11", "%d calendar/schema failures and 3 fixtures as expected %s" % [cases.size(), codes])
	return true


# --- AC-C14 years ----------------------------------------------------------------------

## Independent expectation: walk years, seasons and days in order (no service formula).
func _expected_days(days_per_season: int, years: int) -> Array:
	var out: Array = []
	for year: int in range(1, years + 2):
		for season: String in SEASONS:
			for day: int in range(1, days_per_season + 1):
				out.append([year, season, day])
	return out


func _c14_years() -> bool:
	var totals: Dictionary = {}
	for rule: String in [FAST, DEFAULT]:
		var profile: Dictionary = _fast if rule == FAST else _default
		var days: int = 4 * 4 * int(profile.days_per_season)
		var expected: Array = _expected_days(int(profile.days_per_season), 4)
		var service: CalendarService = _service(rule)
		var events: Array = []
		var listener: Callable = func(event: Dictionary) -> void: events.append(event)
		service.day_advanced.connect(listener)
		var order_ok: bool = true
		var mid_ticks: int = int(profile.ticks_per_day) / 3
		for index: int in days:
			# Part of the day, then the rest: two commands per day, one boundary.
			var revision: int = service.get_snapshot().value.revision
			service.advance_ticks(mid_ticks, revision)
			service.advance_ticks(service.ticks_to_next_dawn(), revision + 1)
			var date: Dictionary = service.get_date().value
			var want: Array = expected[index + 1]
			if [date.year, date.season_id, date.day_of_season] != want or date.minute_of_day != 360:
				order_ok = false
		service.day_advanced.disconnect(listener)
		var completed_ok: bool = true
		for index: int in events.size():
			completed_ok = completed_ok and events[index].completed_day_index == index and events[index].to_day_index == index + 1
		var last: Dictionary = service.get_date().value
		totals[rule] = [events.size(), service.get_snapshot().value.revision, [last.year, last.season_id, last.day_of_season]]
		_check("AC-C14", order_ok and completed_ok and events.size() == days and service.get_snapshot().value.revision == days * 2
			and [last.year, last.season_id, last.day_of_season] == [5, "spring", 1],
			"%s 4 years: %d boundaries in order, revision %d, ends at year 5 spring 1 (%s)" % [rule, days, days * 2, totals[rule]])
	_metrics["AC-C14"] = str(totals)
	_log("AC-C14", "4 years of each profile day by day: %s" % [totals])
	return true


# --- AC-C13 passive maps -----------------------------------------------------------------

func _c13_passive() -> bool:
	var outcomes: Dictionary = {}
	for path: String in [GATHERING_SCENE, SAVE_LOAD_SCENE]:
		var node: Node = (load(path) as PackedScene).instantiate()
		if path == SAVE_LOAD_SCENE:
			node.set("save_root", _dir("c13_save_load"))
		root.add_child(node)
		await process_frame
		var world: Node = node if path == GATHERING_SCENE else (node.get("coordinator") as SaveCoordinator).get_world()
		var calendar: CalendarService = world.get("calendar")
		var before: Dictionary = calendar.get_snapshot().value
		await _ticks(30)
		_tap_now(KEY_P)
		_tap_now(KEY_N)
		await _ticks(5)
		var after: Dictionary = calendar.get_snapshot().value
		outcomes[path.get_file()] = after
		_check("AC-C13", before == {"rule_id": DEFAULT, "day_index": 0, "tick_in_day": 0, "revision": 0} and after == before,
			"%s: passive calendar, no natural tick and P/N do nothing (%s)" % [path.get_file(), after])
		node.queue_free()
		await process_frame
		_check("AC-C13", calendar.is_closed(), "%s: leaving the tree closes the calendar" % path.get_file())
	_metrics["AC-C13"] = str(outcomes)
	_log("AC-C13", "gathering and save/load maps keep a passive calendar")
	return true


# --- AC-C05 adapter ----------------------------------------------------------------------

func _c05_adapter() -> bool:
	await _open(_dir("c05"), FAST)
	var outcomes: Dictionary = {}
	for fps: int in [30, 60, 144]:
		Engine.max_fps = fps
		await _ticks(2)
		var rev0: int = _snap().revision
		var frames0: int = Engine.get_physics_frames()
		await _ticks(40)
		outcomes[fps] = [_snap().revision - rev0, Engine.get_physics_frames() - frames0]
		_check("AC-C05", outcomes[fps][0] == outcomes[fps][1] and outcomes[fps][0] >= 40,
			"max_fps %d: ticks %d = physics steps %d" % [fps, outcomes[fps][0], outcomes[fps][1]])
	Engine.max_fps = 0
	# A stall: only the physics steps actually processed count, nothing is made up.
	var rev_stall: int = _snap().revision
	var frames_stall: int = Engine.get_physics_frames()
	var started: int = Time.get_ticks_msec()
	OS.delay_msec(400)
	await _ticks(4)
	var ticks: int = _snap().revision - rev_stall
	var steps: int = Engine.get_physics_frames() - frames_stall
	var wall_ticks: int = (Time.get_ticks_msec() - started) * 60 / 1000
	outcomes["stall"] = [ticks, steps, wall_ticks]
	_check("AC-C05", ticks == steps, "after a 400 ms stall ticks %d = processed steps %d (wall clock would be %d)" % [ticks, steps, wall_ticks])
	# A user pause is not made up when time resumes.
	await _pause_time()
	var paused_rev: int = _snap().revision
	await _ticks(30)
	var during: int = _snap().revision - paused_rev
	var frames_resume: int = Engine.get_physics_frames()
	await _pause_time()
	await _ticks(5)
	var resumed: int = _snap().revision - paused_rev
	_check("AC-C05", during == 0 and resumed == Engine.get_physics_frames() - frames_resume, "30 paused steps add nothing; after resume %d ticks" % resumed)
	# Another physics rate is refused, not converted.
	Engine.physics_ticks_per_second = 30
	await _ticks(3)
	var hz_rev: int = _snap().revision
	var hz_reasons: PackedStringArray = _ctrl().get_stop_reasons()
	await _ticks(6)
	var hz_moved: int = _snap().revision - hz_rev
	Engine.physics_ticks_per_second = 60
	await _ticks(3)
	_check("AC-C05", hz_reasons.has("physics_hz") and hz_moved == 0, "physics 30 Hz: stopped (%s), moved %d" % [hz_reasons, hz_moved])
	# A queued N replaces the natural tick of its step.
	await _pause_time()
	await _pause_time()
	var before: Dictionary = _snap()
	var queued: StringName = _ctrl().request_next_day(_coord().get_epoch(), before.revision)
	await _ticks(1)
	var after: Dictionary = _snap()
	_check("AC-C05", queued == &"QUEUED" and after.day_index == before.day_index + 1 and after.tick_in_day == 0 and after.revision == before.revision + 1,
		"N step: next dawn only, no extra natural tick (%s -> %s)" % [before, after])
	_metrics["AC-C05"] = "%s %s" % [outcomes[30][0] == outcomes[30][1], outcomes[144][0] == outcomes[144][1]]
	_log("AC-C05", "ticks = physics steps at 30/60/144 fps %s; stall/pause not made up; 30 Hz refused; N replaces the step's tick" % [outcomes])
	return true


# --- AC-C06 stop reasons -----------------------------------------------------------------

func _c06_pauses() -> bool:
	await _open(_dir("c06"), FAST)
	var controller: CalendarController = _ctrl()
	var world: Node = _world()
	var inventory_controller: InventoryController = world.get("controller")
	var player: PlayerController = world.get("player")
	# User pause: time stops, walking and gathering still work, P resumes.
	await _pause_time()
	var rev: int = _snap().revision
	await _stand("branch_pile_01")
	var x: float = player.global_position.x
	_key(KEY_A, true)
	await _ticks(10)
	_key(KEY_A, false)
	await _ticks(1)
	var walked: bool = player.global_position.x < x - 1.0
	await _stand("branch_pile_01")
	var wood: int = (world.get("inventory") as InventoryService).count("player_bag", "wood").value
	await _press_e()
	var gathered: bool = (world.get("inventory") as InventoryService).count("player_bag", "wood").value == wood + 1
	_check("AC-C06", _snap().revision == rev and walked and gathered and controller.get_stop_reasons() == PackedStringArray(["user_paused"])
		and player.is_control_effective(), "P: time stops, walking and gathering work, the gate is untouched")
	# User pause + bag: closing the bag leaves the user pause.
	inventory_controller.request_open(InventoryController.View.BAG)
	await _ticks(2)
	var both: PackedStringArray = controller.get_stop_reasons()
	inventory_controller.request_close(&"CLOSED_BY_USER")
	await _ticks(3)
	_check("AC-C06", both.has("user_paused") and both.has("modal") and controller.get_stop_reasons() == PackedStringArray(["user_paused"])
		and _snap().revision == rev, "pause + bag %s; bag closed -> still paused" % [both])
	await _pause_time()
	# Bag alone stops time; closing it resumes.
	inventory_controller.request_open(InventoryController.View.BAG)
	await _ticks(2)
	var bag_rev: int = _snap().revision
	await _ticks(5)
	var bag_moved: int = _snap().revision - bag_rev
	inventory_controller.request_close(&"CLOSED_BY_USER")
	await _ticks(4)
	_check("AC-C06", bag_moved == 0 and _snap().revision > bag_rev and inventory_controller.get_state() == InventoryController.State.CLOSED,
		"bag open: no tick; closed: time runs again (panel never forced)")
	# Focus out + user pause: focus back needs neutral keys and keeps the user pause.
	await _pause_time()
	controller.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focus_reasons: PackedStringArray = controller.get_stop_reasons()
	controller.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	var neutral_reasons: PackedStringArray = controller.get_stop_reasons()
	await _ticks(2)
	_check("AC-C06", focus_reasons.has("focus") and focus_reasons.has("user_paused") and neutral_reasons.has("neutral")
		and controller.get_stop_reasons() == PackedStringArray(["user_paused"]), "focus %s -> back %s -> still user pause" % [focus_reasons, neutral_reasons])
	await _pause_time()
	# Suspended session: the controller stops and the service refuses direct and deferred calls.
	var calendar: CalendarService = _cal()
	world.call("set_session_suspended", true)
	var suspended_rev: int = _snap().revision
	var direct: Dictionary = calendar.advance_ticks(1, suspended_rev)
	calendar.advance_ticks.call_deferred(1, suspended_rev)
	await _ticks(4)
	var suspended_reasons: PackedStringArray = controller.get_stop_reasons()
	world.call("set_session_suspended", false)
	_check("AC-C06", direct.code == CalendarService.BUSY and _snap().revision == suspended_rev and suspended_reasons.has("suspended"),
		"suspended: direct and deferred advance refused, no tick (%s)" % [suspended_reasons])
	# SceneTree pause stops time (controller runs ALWAYS but never ticks), with a user pause on top.
	await _pause_time()
	paused = true
	var tree_reasons: PackedStringArray = controller.get_stop_reasons()
	await _ticks(4)
	paused = false
	await _ticks(2)
	var after_tree: PackedStringArray = controller.get_stop_reasons()
	await _pause_time()
	var tree_rev: int = _snap().revision
	paused = true
	await _ticks(5)
	var tree_moved: int = _snap().revision - tree_rev
	paused = false
	await _ticks(2)
	_check("AC-C06", tree_reasons.has("tree_paused") and tree_reasons.has("user_paused") and after_tree == PackedStringArray(["user_paused"])
		and tree_moved == 0, "tree pause + user pause; tree resumed -> user pause stays; tree pause alone: no tick")
	# Saving while only the user pause holds is allowed.
	await _pause_time()
	var saved: Dictionary = _coord().request_save(_coord().get_epoch())
	await _pause_time()
	_check("AC-C06", saved.get("ok") == true and controller.is_user_paused() == false, "F5 works during a user pause")
	_metrics["AC-C06"] = "%s %s" % [both, tree_reasons]
	_log("AC-C06", "user pause, bag, focus/neutral, suspended, tree pause each stop time and release independently")
	return true


# --- AC-C07 next dawn input ----------------------------------------------------------------

func _c07_next_day() -> bool:
	var dir: String = _dir("c07")
	await _open(dir, DEFAULT)
	await _pause_time()
	await _pause_time()
	await _ticks(3)
	var mark: int = _boundaries.size()
	var before: Dictionary = _snap()
	_key(KEY_N, true)
	for i: int in 4:
		_key(KEY_N, true, true)
		await _ticks(1)
	_key(KEY_N, false)
	await _ticks(2)
	_check("AC-C07", _boundaries.size() - mark == 1 and _snap().day_index == before.day_index + 1,
		"N press + held echoes: one dawn (%d boundaries)" % (_boundaries.size() - mark))
	# Two presses before the step: the second is BUSY, still one dawn.
	mark = _boundaries.size()
	var cmd: int = _commands.size()
	_tap_now(KEY_N)
	_tap_now(KEY_N)
	await _ticks(2)
	var codes: Array = _commands.slice(cmd).map(func(c: Dictionary) -> String: return String(c.code))
	_check("AC-C07", _boundaries.size() - mark == 1 and codes == ["BUSY", "OK"], "two presses in one step: %s, one dawn" % [codes])
	# Pending blocks F5/F9 (nothing written, nothing loaded).
	var files: Dictionary = _bank_bytes(dir)
	var queued: StringName = _ctrl().request_next_day(_coord().get_epoch(), _snap().revision)
	var f5: Dictionary = _coord().request_save(_coord().get_epoch())
	var f9: StringName = _coord().request_load(_coord().get_epoch())
	await _ticks(2)
	_check("AC-C07", queued == &"QUEUED" and f5.code == &"BUSY" and f9 == &"BUSY" and _bank_bytes(dir) == files, "pending N: F5/F9 BUSY")
	# Cancelled by P, by focus loss; an old epoch or revision is refused.
	mark = _boundaries.size()
	var day: int = _snap().day_index
	cmd = _commands.size()
	_ctrl().request_next_day(_coord().get_epoch(), _snap().revision)
	_tap_now(KEY_P)
	await _ticks(3)
	await _pause_time()
	_ctrl().request_next_day(_coord().get_epoch(), _snap().revision)
	_ctrl().notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_ctrl().notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _ticks(3)
	var stale_epoch: StringName = _ctrl().request_next_day(_coord().get_epoch() - 1, _snap().revision)
	var stale_revision: StringName = _ctrl().request_next_day(_coord().get_epoch(), _snap().revision - 1)
	codes = _commands.slice(cmd).map(func(c: Dictionary) -> String: return "%s:%s" % [c.command, c.code])
	_check("AC-C07", _boundaries.size() == mark and _snap().day_index == day and codes.has("next_day:CANCELLED")
		and codes.has("next_day:FOCUS_LOST") and stale_epoch == &"STALE_SESSION" and stale_revision == &"STALE_REVISION",
		"cancel by P and focus, stale epoch/revision refused, no dawn: %s" % [codes])
	# After a load, the HUD button of the old epoch is refused; a fresh press works.
	_coord().request_save(_coord().get_epoch())
	var old_epoch: int = _coord().get_epoch()
	await _load_and_wait()
	cmd = _commands.size()
	(_hud() as CalendarHUD).next_day_requested.emit(old_epoch, _snap().revision)
	var stale_button: String = String(_commands[cmd].code) if _commands.size() > cmd else ""
	mark = _boundaries.size()
	_tap_now(KEY_N)
	await _ticks(2)
	_check("AC-C07", stale_button == "STALE_SESSION" and _boundaries.size() - mark == 1, "old-epoch button refused, new press works")
	_metrics["AC-C07"] = str(codes)
	_log("AC-C07", "N once per press, second press BUSY, F5/F9 BUSY while queued, cancel/focus/stale refusals %s" % [codes])
	return true


# --- AC-C04 re-entry in the real scene ----------------------------------------------------

func _c04_scene_reentry() -> bool:
	var dir: String = _dir("c04_scene")
	await _open(dir, DEFAULT)
	await _pause_time()
	var coordinator: SaveCoordinator = _coord()
	var controller: CalendarController = _ctrl()
	# During the day boundary report: F5/F9 and time requests are BUSY; nothing written.
	var inside: Array = []
	var listener: Callable = func(_event: Dictionary) -> void:
		inside.append([coordinator.request_save(coordinator.get_epoch()).code, coordinator.request_load(coordinator.get_epoch()),
			controller.request_next_day(coordinator.get_epoch(), _snap().revision), controller.request_toggle_pause(coordinator.get_epoch())])
	controller.day_boundary.connect(listener)
	await _pause_time()
	var epoch: int = coordinator.get_epoch()
	controller.request_next_day(epoch, _snap().revision)
	await _ticks(2)
	controller.day_boundary.disconnect(listener)
	_check("AC-C04", inside.size() == 1 and inside[0] == [&"BUSY", &"BUSY", &"BUSY", &"BUSY"] and _bank_state(dir) == ["missing", "missing"]
		and coordinator.get_epoch() == epoch, "inside the boundary report: F5/F9/N/P all BUSY, no file, same epoch: %s" % [inside])
	# Inside the calendar's own event (service busy) the world refuses saving.
	var service_inside: Array = []
	var calendar: CalendarService = _cal()
	var direct: Callable = func(_event: Dictionary) -> void: service_inside.append(coordinator.request_save(coordinator.get_epoch()).code)
	calendar.day_advanced.connect(direct)
	controller.request_next_day(epoch, _snap().revision)
	await _ticks(2)
	calendar.day_advanced.disconnect(direct)
	_check("AC-C04", service_inside == [&"BUSY"] and _bank_state(dir) == ["missing", "missing"], "inside day_advanced: save BUSY")
	# While a refusal of the coordinator is reported, time requests are BUSY too.
	var paused_before: bool = controller.is_user_paused()
	var refused: Array = []
	var once: Array = [false]
	var on_refusal: Callable = func(_result: Dictionary) -> void:
		if once[0]:
			return
		once[0] = true
		refused.append([controller.request_next_day(coordinator.get_epoch(), _snap().revision), controller.request_toggle_pause(coordinator.get_epoch())])
	coordinator.operation_finished.connect(on_refusal)
	coordinator.request_save(epoch - 1)
	coordinator.operation_finished.disconnect(on_refusal)
	await _ticks(2)
	_check("AC-C04", refused == [[&"BUSY", &"BUSY"]] and not controller.has_pending() and controller.is_user_paused() == paused_before,
		"inside a refusal report: N/P BUSY, nothing queued or toggled")
	var normal: Dictionary = coordinator.request_save(coordinator.get_epoch())
	_check("AC-C04", normal.get("ok") == true, "after the reports a save works")
	_log("AC-C04", "scene: reports make every save/load/time request BUSY")
	return true


# --- AC-C08 lifetime ---------------------------------------------------------------------

func _c08_lifetime() -> bool:
	var outcomes: Dictionary = {}
	for mode: String in ["free", "queue_free", "remove_child"]:
		var dir: String = _dir("c08_" + mode)
		await _open(dir, DEFAULT)
		var hud: Node = _hud()
		match mode:
			"free":
				hud.free()
			"queue_free":
				hud.queue_free()
			"remove_child":
				hud.get_parent().remove_child(hud)
		await _ticks(3)
		var rev: int = _snap().revision
		await _ticks(5)
		var ticking: bool = _snap().revision > rev
		_tap_now(KEY_P)
		await _ticks(2)
		var paused_by_key: bool = _ctrl().is_user_paused()
		_tap_now(KEY_P)
		await _ticks(1)
		var day: int = _snap().day_index
		_tap_now(KEY_N)
		await _ticks(2)
		var f5: Dictionary = await _key_save(KEY_F5)
		var f9: Dictionary = await _key_save(KEY_F9)
		outcomes[mode] = [ticking, paused_by_key, _snap().day_index > day, f5.get("code"), f9.get("code")]
		_check("AC-C08", ticking and paused_by_key and f5.get("ok") == true and f9.get("ok") == true,
			"HUD %s: time, P, N, F5, F9 still work: %s" % [mode, outcomes[mode]])
		if is_instance_valid(hud) and not hud.is_inside_tree():
			hud.free()
	# The HUD freed from the boundary report; the next N still works.
	await _open(_dir("c08_in_report"), DEFAULT)
	var remove_hud: Callable = func(_event: Dictionary) -> void:
		if _hud() != null:
			_hud().queue_free()
	_ctrl().day_boundary.connect(remove_hud, CONNECT_ONE_SHOT)
	_ctrl().request_next_day(_coord().get_epoch(), _snap().revision)
	await _ticks(3)
	var day_after: int = _snap().day_index
	_ctrl().request_next_day(_coord().get_epoch(), _snap().revision)
	await _ticks(2)
	_check("AC-C08", _hud() == null and _snap().day_index == day_after + 1, "HUD freed in the report: next N works")
	# The old calendar after a load is CLOSED; a staged candidate is never ticked.
	var dir_l: String = _dir("c08_load")
	await _open(dir_l, DEFAULT)
	_coord().request_save(_coord().get_epoch())
	var old: CalendarService = _cal()
	var staged: Array = []
	_coord().stage_hook = func(stage: String) -> void:
		if stage == "position_checked":
			var candidate: Node = null
			for child: Node in (_scene.get("save_load").get("host") as Node).get_children():
				if child != _world():
					candidate = child
			var candidate_calendar: CalendarService = candidate.get("calendar")
			staged.append([old.get_snapshot().value.revision, candidate_calendar.is_suspended(),
				candidate_calendar.advance_ticks(1, candidate_calendar.get_snapshot().value.revision).code])
	var rev_at_start: int = old.get_snapshot().value.revision
	await _load_and_wait()
	_coord().stage_hook = Callable()
	_check("AC-C08", staged.size() == 1 and staged[0][0] == rev_at_start and staged[0][1] == true and staged[0][2] == CalendarService.BUSY
		and old.is_closed() and old.advance_ticks(1, 0).code == CalendarService.CLOSED and _cal() != old and not _cal().is_suspended(),
		"staging: old calendar not ticked, candidate suspended (direct advance BUSY); after publish the old one is CLOSED: %s" % [staged])
	# Coordinator removed: no tick, keys do nothing, no error.
	var calendar: CalendarService = _cal()
	(_scene.get("save_load").get("coordinator") as Node).queue_free()
	await _ticks(2)
	var rev_gone: int = calendar.get_snapshot().value.revision
	_tap_now(KEY_P)
	_tap_now(KEY_N)
	await _ticks(4)
	_check("AC-C08", calendar.get_snapshot().value.revision == rev_gone and not _ctrl().has_pending() and _ctrl().get_stop_reasons().has("removed"),
		"coordinator removed: no tick, keys ignored")
	_metrics["AC-C08"] = str(outcomes)
	_log("AC-C08", "HUD removal %s; old calendar CLOSED; candidate never ticked; coordinator removal safe" % [outcomes])
	return true


# --- AC-C09 schema 2 round trip ------------------------------------------------------------

func _c09_round_trip() -> bool:
	var results: Dictionary = {}
	for rule: String in [DEFAULT, FAST]:
		var dir: String = _dir("c09_" + rule)
		await _open(dir, rule)
		await _pause_time()
		await _pause_time()
		for i: int in 2:
			_ctrl().request_next_day(_coord().get_epoch(), _snap().revision)
			await _ticks(2)
		await _ticks(37)
		await _pause_time()
		var saved_calendar: Dictionary = _snap()
		var saved_world: Dictionary = _world().call("capture_payload")
		var saved: Dictionary = _coord().request_save(_coord().get_epoch())
		await _pause_time()
		_ctrl().request_next_day(_coord().get_epoch(), _snap().revision)
		await _ticks(3)
		await _pause_time()
		var mark: int = _boundaries.size()
		var loaded: Dictionary = await _load_and_wait()
		await _ticks(5)
		var restored: Dictionary = _snap()
		var restored_world: Dictionary = _world().call("capture_payload")
		var date: Dictionary = _cal().get_date().value
		var expected_text: String = "%d년 %s %d일 %02d:%02d" % [date.year, {"spring": "봄", "summer": "여름", "autumn": "가을", "winter": "겨울"}[date.season_id],
			date.day_of_season, date.hour, date.minute]
		_check("AC-C09", saved.get("ok") == true and loaded.get("ok") == true and saved_calendar.day_index == 2 and saved_calendar.tick_in_day > 0
			and restored == saved_calendar and restored_world.inventories == saved_world.inventories and _boundaries.size() == mark
			and _ctrl().is_user_paused() and _hud().get_date_text() == expected_text,
			"%s: saved %s restored exactly, paused stays, no event, HUD %s" % [rule, saved_calendar, _hud().get_date_text()])
		await _pause_time()
		await _ticks(1)
		var resumed: Dictionary = _snap()
		_ctrl().request_next_day(_coord().get_epoch(), _snap().revision)
		await _ticks(2)
		_check("AC-C09", resumed.revision > restored.revision and _boundaries.size() == mark + 1, "%s: after load time runs and one dawn is reported" % rule)
		# Running time makes the exact tick depend on frame timing; the metric keeps the day.
		results[rule] = saved_calendar.day_index
	_metrics["AC-C09"] = str(results)
	_log("AC-C09", "schema 2 save/load round trip of both profiles %s" % [results])
	return true


func _c09_processes() -> bool:
	var dir: String = _dir("c09_process")
	var saved: Dictionary = _child(["--mode=save", "--root=" + dir, "--out=" + dir + "/child.out"])
	var loaded: Dictionary = _child(["--mode=load", "--root=" + dir, "--out=" + dir + "/child.out"])
	var saved_calendar: Dictionary = _ints(saved.result.get("calendar", {}))
	_check("AC-C09", saved.exit == 0 and saved.result.code == "OK" and loaded.exit == 0 and loaded.result.code == "OK"
		and saved_calendar.get("day_index") == 2 and _ints(loaded.result.get("calendar", {})) == saved_calendar
		and loaded.result.get("boundaries") == 0.0, "child save %s, other process loads the same calendar, no event" % [saved_calendar])
	_metrics["AC-C09 process"] = str(saved_calendar.get("day_index"))
	_log("AC-C09", "separate processes: save -> exit -> load %s" % [saved_calendar])
	return true


# --- AC-C12 sessions and recovery --------------------------------------------------------

func _c12_sessions() -> bool:
	var manifest: Dictionary = GatheringMap.save_manifest(DEFAULT)
	# A = v1 fixture (generation 3), B = schema 2 generation 4 at day 5.
	var dir: String = _dir("c12_mixed")
	var v2: Dictionary = SaveCodec.decode(_fixture("v1_valid.json").to_utf8_buffer(), manifest).value
	v2.generation = 4
	v2.calendar = {"rule_id": DEFAULT, "day_index": 5, "tick_in_day": 100, "revision": 7}
	_write_bank(dir, "a", _fixture("v1_valid.json"))
	_write_bank(dir, "b", _envelope(v2))
	await _open(dir, DEFAULT)
	await _pause_time()
	var latest: Dictionary = await _load_and_wait()
	var latest_calendar: Dictionary = _snap()
	var recovery: Dictionary = await _load_and_wait(SaveStore.SOURCE_RECOVERY)
	_check("AC-C12", latest.get("generation") == 4 and latest_calendar == v2.calendar and recovery.get("recovered") == true
		and recovery.get("generation") == 3 and _snap() == {"rule_id": DEFAULT, "day_index": 0, "tick_in_day": 0, "revision": 0},
		"A v1 / B v2: latest is B (day 5), explicit recovery is A migrated (day 0)")
	# Failures keep the current calendar instance and state; success swaps all services.
	var failures: Dictionary = {}
	for name: String in ["bad calendar", "blocked position", "focus out-in", "candidate removed"]:
		var case_dir: String = _dir("c12_" + name.replace(" ", "_"))
		await _open(case_dir, DEFAULT)
		_ctrl().request_next_day(_coord().get_epoch(), _snap().revision)
		await _ticks(2)
		await _pause_time()
		_coord().request_save(_coord().get_epoch())
		var payload: Dictionary = _coord().get_store().load_slot().payload
		match name:
			"bad calendar":
				payload.calendar.tick_in_day = 36000
				_write_bank(case_dir, "a", _envelope(payload))
			"blocked position":
				payload.player.position = {"x": 632.0, "y": 360.0}
				_write_bank(case_dir, "a", _envelope(payload))
			"focus out-in":
				_coord().stage_hook = func(stage: String) -> void:
					if stage == "position_checked":
						_coord().notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
						_coord().notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			"candidate removed":
				_coord().stage_hook = func(stage: String) -> void:
					if stage == "before_publish":
						for child: Node in (_scene.get("save_load").get("host") as Node).get_children():
							if child != _world():
								child.queue_free()
		var world: Node = _world()
		var calendar: CalendarService = _cal()
		var before: Dictionary = _snap()
		var state: Dictionary = world.call("capture_payload")
		var epoch: int = _coord().get_epoch()
		var result: Dictionary = await _load_and_wait()
		_coord().stage_hook = Callable()
		await _ticks(2)
		failures[name] = String(result.get("code", ""))
		_check("AC-C12", result.get("ok") == false and _world() == world and _cal() == calendar and _snap() == before
			and not calendar.is_suspended() and not calendar.is_closed() and _coord().get_epoch() == epoch
			and (world.call("capture_payload") as Dictionary).inventories == state.inventories,
			"%s: %s; same calendar instance and state, stock and epoch" % [name, result.get("code")])
	# Success: inventory, gather and calendar are all new together; the old ones are closed.
	var ok_dir: String = _dir("c12_success")
	await _open(ok_dir, DEFAULT)
	await _pause_time()
	_coord().request_save(_coord().get_epoch())
	var services: Array = [_world().get("inventory"), _world().get("gather"), _cal()]
	await _load_and_wait()
	_check("AC-C12", (services[0] as InventoryService).is_closed() and (services[1] as GatherService).is_closed() and (services[2] as CalendarService).is_closed()
		and _world().get("inventory") != services[0] and _cal() != services[2], "publish swaps inventory, gather and calendar together")
	_metrics["AC-C12"] = str(failures)
	_log("AC-C12", "mixed A v1/B v2 selection and recovery; failures %s keep the calendar; success swaps all" % [failures])
	return true


# --- helpers -----------------------------------------------------------------------------

func _service(rule: String) -> CalendarService:
	return CalendarService.create(_default if rule == DEFAULT else _fast).value


func _open(dir: String, rule: String) -> void:
	_close()
	_scene = (load(SCENE) as PackedScene).instantiate()
	_scene.set("save_root", dir)
	_scene.set("calendar_rule_id", rule)
	root.add_child(_scene)
	await process_frame
	_ctrl().command_finished.connect(func(result: Dictionary) -> void: _commands.append(result))
	_ctrl().day_boundary.connect(func(event: Dictionary) -> void: _boundaries.append(event))
	_coord().operation_finished.connect(func(result: Dictionary) -> void: _saves.append(result))
	await _ticks(3)


func _close() -> void:
	_release_all()
	paused = false
	if is_instance_valid(_scene):
		_scene.get_parent().remove_child(_scene)
		_scene.queue_free()
	_scene = null


func _ctrl() -> CalendarController:
	return _scene.get_node("CalendarController") as CalendarController


func _coord() -> SaveCoordinator:
	return _scene.get("save_load").get("coordinator")


func _hud() -> Node:
	return _scene.get_node_or_null("CalendarHUD")


func _world() -> Node:
	return _coord().get_world()


func _cal() -> CalendarService:
	return _world().get("calendar")


func _snap() -> Dictionary:
	return _cal().get_snapshot().value


func _bag_slots() -> Array:
	var out: Array = []
	for stack: Variant in (_world().get("inventory") as InventoryService).snapshot("player_bag").value.slots:
		out.append("-" if stack == null else "%s%d" % [stack.item_id, stack.quantity])
	return out


## Toggles the user time stop through the real controller (current epoch).
func _pause_time() -> void:
	_ctrl().request_toggle_pause(_coord().get_epoch())
	await _ticks(1)


func _load_and_wait(source: StringName = SaveStore.SOURCE_LATEST) -> Dictionary:
	var mark: int = _saves.size()
	_coord().request_load(_coord().get_epoch(), source)
	for i: int in 10:
		if _saves.size() > mark:
			break
		await physics_frame
	return _saves[mark] if _saves.size() > mark else {"code": &"TIMEOUT", "ok": false}


func _key_save(code: Key) -> Dictionary:
	var mark: int = _saves.size()
	_tap_now(code)
	for i: int in 6:
		if _saves.size() > mark:
			break
		await physics_frame
	await _ticks(1)
	return _saves[mark] if _saves.size() > mark else {}


func _child(arguments: Array) -> Dictionary:
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", CHILD, "--"]
	var out: String = ""
	for argument: String in arguments:
		args.append(argument)
		if argument.begins_with("--out="):
			out = argument.trim_prefix("--out=")
	var output: Array = []
	var exit: int = OS.execute(OS.get_executable_path(), args, output, true)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(out)) if FileAccess.file_exists(out) else null
	return {"exit": exit, "result": parsed if typeof(parsed) == TYPE_DICTIONARY else {"code": "NO_RESULT"}}


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


func _fixture(name: String) -> String:
	return FileAccess.get_file_as_string(SAVE_FIXTURES + name)


## Envelope with a correct SHA-256 of the payload text, written independently of SaveCodec.
func _envelope(payload: Dictionary) -> String:
	var text: String = JSON.stringify(payload, "", true, true)
	return JSON.stringify({"format": "iron-and-harvest-save", "payload_json": text, "sha256": text.sha256_text()})


func _dir(name: String) -> String:
	var dir: String = "%s/p%d_%s" % [_run_root, _pass, name]
	_dirs.append(dir)
	return dir


func _write_bank(dir: String, bank: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var file: FileAccess = FileAccess.open("%s/slot_01.%s.json" % [dir, bank], FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _bank_bytes(dir: String) -> Dictionary:
	var out: Dictionary = {}
	for bank: String in ["a", "b"]:
		var path: String = "%s/slot_01.%s.json" % [dir, bank]
		out[bank] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	return out


func _bank_state(dir: String) -> Array:
	return ["present" if FileAccess.file_exists(dir + "/slot_01.a.json") else "missing",
		"present" if FileAccess.file_exists(dir + "/slot_01.b.json") else "missing"]


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
	_check("AC-C15", not DirAccess.dir_exists_absolute(_run_root), "test root removed: %s" % _run_root)
	return removed


func _stand(point_id: String) -> void:
	_release_all()
	await physics_frame
	var player: PlayerController = _world().get("player")
	_key(FACING_KEYS[STANDS[point_id][1]], true)
	await physics_frame
	_release_all()
	player.global_position = STANDS[point_id][0]
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
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"interact", &"calendar_pause", &"calendar_next_day"]:
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
	_check("AC-C14", first.keys() == second.keys() and differences.is_empty(), "pass differences %s" % differences)
	_log("AC-C14", "passes=2 measurements=%d differences=%d" % [first.size(), differences.size()])


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
	print("IH-120 automated summary:")
	var keys: Array = _ac_checks.keys()
	keys.sort()
	for ac: String in keys:
		var counts: Array = _ac_checks[ac]
		print("  %s %s (%d checks, %d failed)" % [ac, "PASS" if counts[1] == 0 else "FAIL", counts[0], counts[1]])
	print("  Not covered here: real GUI use (AC-C16), code/doc review.")
	if _failures.is_empty():
		print("RESULT: PASS")
		quit(0)
	else:
		for failure: String in _failures:
			print("  FAILED " + failure)
		print("RESULT: FAIL (%d)" % _failures.size())
		quit(1)
