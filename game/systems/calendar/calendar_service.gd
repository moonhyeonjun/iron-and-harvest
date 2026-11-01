class_name CalendarService
extends RefCounted
## The one writer of a session's date (IH-120). State is only
## {rule_id, day_index, tick_in_day, revision}; year, season and time of day are derived
## from it and the profile, never stored. advance_ticks() checks everything first, installs
## a new copy in one step and then reports a crossed dawn once through day_advanced, while
## still busy, so a re-entrant advance from a listener is BUSY. A command moves at most one
## day. restore() builds a new service from a saved snapshot with no event, no revision
## change and nothing granted. No Node, file, input or time source: the caller ticks it.

signal day_advanced(event: Dictionary)

const OK: StringName = &"OK"
const BUSY: StringName = &"BUSY"
const CLOSED: StringName = &"CLOSED"
const INVALID_AMOUNT: StringName = &"INVALID_AMOUNT"
const INVALID_STATE: StringName = &"INVALID_STATE"
const STALE_REVISION: StringName = &"STALE_REVISION"
const NUMBER_OUT_OF_RANGE: StringName = &"NUMBER_OUT_OF_RANGE"
const STATE_KEYS: Array = ["day_index", "revision", "rule_id", "tick_in_day"]
const MINUTES_PER_DAY: int = 1440


class Result extends RefCounted:
	var ok: bool = false
	var code: StringName = &""
	var detail: String = ""
	var value: Variant = null

	static func make(result_code: StringName, result_detail: String = "") -> Result:
		var result: Result = Result.new()
		result.ok = result_code == OK
		result.code = result_code
		result.detail = result_detail
		return result


var _profile: Dictionary = {}
var _state: Dictionary = {}
var _busy: bool = false
var _closed: bool = false
var _suspended: bool = false


## New game: year 1, spring day 1, the profile's day start (tick 0), revision 0.
static func create(profile: Dictionary) -> Result:
	return restore({"rule_id": profile.get("rule_id"), "day_index": 0, "tick_in_day": 0, "revision": 0}, profile)


## A new service from a snapshot. Only plain ints in range and the profile's own rule_id
## are accepted; nothing is emitted and the revision is kept as it was saved.
static func restore(snapshot: Variant, profile: Dictionary) -> Result:
	if typeof(snapshot) != TYPE_DICTIONARY or _keys(snapshot) != STATE_KEYS:
		return Result.make(INVALID_STATE, "keys must be exactly %s" % [STATE_KEYS])
	if typeof(snapshot.rule_id) != TYPE_STRING or snapshot.rule_id != profile.get("rule_id"):
		return Result.make(INVALID_STATE, "rule_id %s does not match the profile" % [snapshot.rule_id])
	var limits: Dictionary = {"day_index": CalendarRules.max_day_index(profile),
		"tick_in_day": int(profile.ticks_per_day) - 1, "revision": SaveCodec.MAX_SAFE_INT}
	for key: String in limits:
		if typeof(snapshot[key]) != TYPE_INT or snapshot[key] < 0 or snapshot[key] > limits[key]:
			return Result.make(INVALID_STATE, "%s must be an int in 0..%d" % [key, limits[key]])
	var service: CalendarService = CalendarService.new()
	service._profile = profile.duplicate(true)
	service._state = {"rule_id": String(snapshot.rule_id), "day_index": int(snapshot.day_index),
		"tick_in_day": int(snapshot.tick_in_day), "revision": int(snapshot.revision)}
	var result: Result = Result.make(OK)
	result.value = service
	return result


## Pure date view of any state of a profile (also used to check expectations elsewhere).
static func derive(profile: Dictionary, day_index: int, tick_in_day: int) -> Dictionary:
	var days_per_year: int = 4 * int(profile.days_per_season)
	var season_index: int = (day_index / int(profile.days_per_season)) % 4
	var minute_of_day: int = (int(profile.day_start_minute) + tick_in_day * MINUTES_PER_DAY / int(profile.ticks_per_day)) % MINUTES_PER_DAY
	return {"year": day_index / days_per_year + 1, "season_index": season_index,
		"season_id": String(profile.seasons[season_index]), "day_of_season": day_index % int(profile.days_per_season) + 1,
		"hour": minute_of_day / 60, "minute": minute_of_day % 60, "minute_of_day": minute_of_day}


func close() -> void:
	_closed = true


func is_closed() -> bool:
	return _closed


## Set by the session owner only (save/load staging). Changes no date.
func set_session_suspended(suspended: bool) -> void:
	_suspended = suspended


func is_suspended() -> bool:
	return _suspended


## True while an advance installs and reports (read-only, for save/load and the clock).
func is_busy() -> bool:
	return _busy


func get_profile() -> Dictionary:
	return _profile.duplicate(true)


## Independent copy of the state, or CLOSED.
func get_snapshot() -> Result:
	if _closed:
		return Result.make(CLOSED)
	var result: Result = Result.make(OK)
	result.value = _state.duplicate()
	return result


## Derived date of the current state, or CLOSED.
func get_date() -> Result:
	if _closed:
		return Result.make(CLOSED)
	var result: Result = Result.make(OK)
	result.value = derive(_profile, _state.day_index, _state.tick_in_day)
	return result


## Ticks from now to the next dawn (a full day when it is exactly dawn now).
func ticks_to_next_dawn() -> int:
	return int(_profile.ticks_per_day) - int(_state.get("tick_in_day", 0))


## {ok, code, before_revision, snapshot, boundary}. Order: closed, busy/suspended, argument
## types and range (1..ticks_per_day), expected revision, limits; then one install and at
## most one boundary report. Any failure changes nothing and emits nothing.
func advance_ticks(amount: Variant, expected_revision: Variant) -> Dictionary:
	var before: int = int(_state.get("revision", 0))
	if _closed:
		return _fail(CLOSED, before)
	if _busy or _suspended:
		return _fail(BUSY, before)
	if typeof(amount) != TYPE_INT or typeof(expected_revision) != TYPE_INT \
			or amount < 1 or amount > int(_profile.ticks_per_day):
		return _fail(INVALID_AMOUNT, before)
	if expected_revision != before:
		return _fail(STALE_REVISION, before)
	var total: int = int(_state.tick_in_day) + amount
	var day: int = int(_state.day_index)
	var tick: int = total
	if total >= int(_profile.ticks_per_day):
		day += 1
		tick = total - int(_profile.ticks_per_day)
	if day > CalendarRules.max_day_index(_profile) or before >= SaveCodec.MAX_SAFE_INT:
		return _fail(NUMBER_OUT_OF_RANGE, before)
	var from_day: int = int(_state.day_index)
	_busy = true
	_state = {"rule_id": _state.rule_id, "day_index": day, "tick_in_day": tick, "revision": before + 1}
	var boundary: Variant = null
	if day != from_day:
		var from_date: Dictionary = derive(_profile, from_day, 0)
		var to_date: Dictionary = derive(_profile, day, 0)
		var event: Dictionary = {"from_day_index": from_day, "to_day_index": day, "completed_day_index": from_day,
			"from_season_id": from_date.season_id, "to_season_id": to_date.season_id,
			"from_year": from_date.year, "to_year": to_date.year, "revision": before + 1}
		event.make_read_only()
		boundary = event.duplicate()
		day_advanced.emit(event)
	_busy = false
	return {"ok": true, "code": OK, "before_revision": before, "snapshot": _state.duplicate(), "boundary": boundary}


func _fail(code: StringName, before: int) -> Dictionary:
	return {"ok": false, "code": code, "before_revision": before, "snapshot": _state.duplicate(), "boundary": null}


static func _keys(data: Dictionary) -> Array:
	var keys: Array = data.keys()
	for key: Variant in keys:
		if typeof(key) != TYPE_STRING:
			return []
	keys.sort()
	return keys
