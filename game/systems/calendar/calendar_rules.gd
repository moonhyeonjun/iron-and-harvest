class_name CalendarRules
extends RefCounted
## Trusted calendar profiles (IH-120). parse() takes the JSON text (the caller reads the
## file) and validates every profile before anything is usable: exact keys, IDs from the
## caller's allowed list, whole numbers through the IH-112 number contract (no bool,
## finite, inside range), the fixed season order, 60 Hz and limits that cannot overflow.
## One problem rejects the whole definition. Profiles are handed out as copies.
## The values are verification proposals, not product balance.

const OK: StringName = &"OK"
const INVALID_RULES: StringName = &"INVALID_RULES"
const UNKNOWN_RULE: StringName = &"UNKNOWN_RULE"

const ROOT_KEYS: Array = ["profiles"]
const PROFILE_KEYS: Array = ["day_start_minute", "days_per_season", "max_year", "physics_hz", "rule_id", "seasons", "ticks_per_day"]
const SEASONS: Array = ["spring", "summer", "autumn", "winter"]
const SUPPORTED_PHYSICS_HZ: int = 60
const MAX_TICKS_PER_DAY: int = 10_000_000
const MAX_DAYS_PER_SEASON: int = 1000
const MAX_YEAR: int = 9999


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


## rule_id -> normalized profile (ints, seasons copy).
var _profiles: Dictionary = {}
var _order: Array[String] = []


## `allowed` lists the rule IDs the caller trusts; anything else in the file is refused.
static func parse(text: String, allowed: Array) -> Result:
	var json: JSON = JSON.new()
	if json.parse(text) != Error.OK or typeof(json.data) != TYPE_DICTIONARY:
		return Result.make(INVALID_RULES, "not a JSON object")
	var root: Dictionary = json.data
	if _keys(root) != ROOT_KEYS or typeof(root.profiles) != TYPE_ARRAY or (root.profiles as Array).is_empty():
		return Result.make(INVALID_RULES, "root must be {profiles: [..]}")
	var rules: CalendarRules = CalendarRules.new()
	for index: int in (root.profiles as Array).size():
		var checked: Result = _profile(root.profiles[index], allowed)
		if not checked.ok:
			return Result.make(INVALID_RULES, "profiles[%d]: %s" % [index, checked.detail])
		var profile: Dictionary = checked.value
		if rules._profiles.has(profile.rule_id):
			return Result.make(INVALID_RULES, "duplicate rule_id %s" % profile.rule_id)
		rules._profiles[profile.rule_id] = profile
		rules._order.append(profile.rule_id)
	var result: Result = Result.make(OK)
	result.value = rules
	return result


func get_rule_ids() -> Array[String]:
	return _order.duplicate()


## Independent copy of a profile, or UNKNOWN_RULE.
func get_profile(rule_id: String) -> Result:
	if not _profiles.has(rule_id):
		return Result.make(UNKNOWN_RULE, rule_id)
	var result: Result = Result.make(OK)
	result.value = (_profiles[rule_id] as Dictionary).duplicate(true)
	return result


## Last valid day_index of a profile (the max_year's last winter day).
static func max_day_index(profile: Dictionary) -> int:
	return int(profile.max_year) * SEASONS.size() * int(profile.days_per_season) - 1


static func _profile(data: Variant, allowed: Array) -> Result:
	if typeof(data) != TYPE_DICTIONARY or _keys(data) != PROFILE_KEYS:
		return Result.make(INVALID_RULES, "keys must be exactly %s" % [PROFILE_KEYS])
	if typeof(data.rule_id) != TYPE_STRING or not ItemCatalog.is_valid_id(data.rule_id):
		return Result.make(INVALID_RULES, "rule_id")
	if not allowed.has(data.rule_id):
		return Result.make(INVALID_RULES, "rule_id %s is not trusted" % data.rule_id)
	var out: Dictionary = {"rule_id": data.rule_id}
	var ranges: Dictionary = {"physics_hz": [1, 1000], "ticks_per_day": [1, MAX_TICKS_PER_DAY],
		"days_per_season": [1, MAX_DAYS_PER_SEASON], "day_start_minute": [0, 1439], "max_year": [1, MAX_YEAR]}
	for key: String in ranges:
		var number: Dictionary = SaveCodec.json_int(data[key], ranges[key][0], ranges[key][1])
		if not number.ok:
			return Result.make(INVALID_RULES, "%s: %s" % [key, number.detail])
		out[key] = number.value
	if out.physics_hz != SUPPORTED_PHYSICS_HZ:
		return Result.make(INVALID_RULES, "physics_hz %d (supported %d)" % [out.physics_hz, SUPPORTED_PHYSICS_HZ])
	if typeof(data.seasons) != TYPE_ARRAY or data.seasons != SEASONS:
		return Result.make(INVALID_RULES, "seasons must be %s" % [SEASONS])
	out["seasons"] = SEASONS.duplicate()
	var result: Result = Result.make(OK)
	result.value = out
	return result


static func _keys(data: Dictionary) -> Array:
	var keys: Array = data.keys()
	for key: Variant in keys:
		if typeof(key) != TYPE_STRING:
			return []
	keys.sort()
	return keys
