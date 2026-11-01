class_name SaveCodec
extends RefCounted
## Save file format (IH-112): pure values in and out, no Node, file or Resource access.
## A file is a UTF-8 JSON envelope {format, payload_json, sha256}; payload_json is the JSON
## text itself and sha256 covers exactly its UTF-8 bytes, so a parse/re-serialize never
## changes what is hashed. The checksum only detects accidental damage, not editing.
##
## Godot's JSON reads every number as a float (ints stay exact up to 2^53), accepts some
## non-standard text (trailing commas) and keeps the last of duplicate keys. So nothing is
## trusted from the parse alone: every number is checked (no bool, finite, whole, in range)
## before it becomes an int, and every key, ID, count and reference is compared with the
## caller's manifest of the trusted map. The first problem rejects the whole file.

const OK: StringName = &"OK"
const CORRUPT_SAVE: StringName = &"CORRUPT_SAVE"
const CHECKSUM_MISMATCH: StringName = &"CHECKSUM_MISMATCH"
const INVALID_SAVE: StringName = &"INVALID_SAVE"
const NUMBER_OUT_OF_RANGE: StringName = &"NUMBER_OUT_OF_RANGE"
const UNSUPPORTED_SCHEMA: StringName = &"UNSUPPORTED_SCHEMA"
const CONTENT_MISMATCH: StringName = &"CONTENT_MISMATCH"

const FORMAT: String = "iron-and-harvest-save"
## 2 since IH-120: adds the required calendar object.
const SCHEMA_VERSION: int = 2
## schema 0 exists only as a test fixture: v1 without player.facing.
const OLDEST_SCHEMA: int = 0
const CONTENT_VERSION: int = 1
## Largest integer a JSON number (double) holds exactly: 2^53 - 1.
const MAX_SAFE_INT: int = 9007199254740991
## Checked before reading a file and again on the text.
const MAX_FILE_BYTES: int = 1048576
## Largest accepted position drift through write and read, in world units.
const POSITION_TOLERANCE: float = 0.0001
const ENVELOPE_KEYS: Array = ["format", "payload_json", "sha256"]
const PAYLOAD_KEYS: Array = ["content_version", "generation", "inventories", "map_id", "player", "points", "schema_version"]
const PAYLOAD_KEYS_V2: Array = ["calendar", "content_version", "generation", "inventories", "map_id", "player", "points", "schema_version"]
const CALENDAR_KEYS: Array = ["day_index", "revision", "rule_id", "tick_in_day"]
## schema 1 -> 2 adds this profile at its first moment. A save of another profile is never
## produced by migration (a fast-fixture root refuses such a file as content mismatch).
const MIGRATION_RULE_ID: String = "calendar_test_v1"
const PLAYER_KEYS: Array = ["facing", "inventory_id", "player_id", "position"]
const POSITION_KEYS: Array = ["x", "y"]
const SNAPSHOT_KEYS: Array = ["capacity", "inventory_id", "owner_id", "revision", "slots"]
const STACK_KEYS: Array = ["item_id", "quantity"]
const BINDING_KEYS: Array = ["definition_id", "map_id", "point_id", "stock_inventory_id"]
const FACINGS: Array = ["up", "down", "left", "right"]


## `value` is the normalized payload (ints as int, position as float) or the encoded text.
class Result extends RefCounted:
	var ok: bool = false
	var code: StringName = &""
	var detail: String = ""
	var value: Variant = null
	## Schema the file was written with when it was migrated on read, else -1.
	var migrated_from: int = -1

	static func make(result_code: StringName, result_detail: String = "") -> Result:
		var result: Result = Result.new()
		result.ok = result_code == OK
		result.code = result_code
		result.detail = result_detail
		return result


## True for codes that mean "written by another version or content" rather than damage:
## such a file is kept and never overwritten or skipped silently.
static func is_incompatible(code: StringName) -> bool:
	return code == UNSUPPORTED_SCHEMA or code == CONTENT_MISMATCH


## Validates a current (schema 2) payload, generation included, and returns the envelope text. The text is
## decoded again before it is returned: every value must come back identical, except the
## position, which must come back within POSITION_TOLERANCE (measured on 4.7.2: the JSON
## reader can change the last digit of a 17-digit double, e.g. ...351563 -> ...351565).
static func encode(payload: Dictionary, manifest: Dictionary) -> Result:
	var checked: Result = _validate(payload, manifest, SCHEMA_VERSION)
	if not checked.ok:
		return checked
	var payload_json: String = JSON.stringify(checked.value, "", true, true)
	var envelope: Dictionary = {"format": FORMAT, "payload_json": payload_json, "sha256": payload_json.sha256_text()}
	var text: String = JSON.stringify(envelope, "", true)
	var again: Result = decode(text.to_utf8_buffer(), manifest)
	var same: bool = again.ok and again.migrated_from == -1
	if same:
		var saved: Dictionary = checked.value.player.position
		var read: Dictionary = again.value.player.position
		same = absf(float(read.x) - float(saved.x)) <= POSITION_TOLERANCE and absf(float(read.y) - float(saved.y)) <= POSITION_TOLERANCE
		again.value.player.position = saved
		same = same and JSON.stringify(again.value, "", true, true) == payload_json
	if not same:
		return Result.make(INVALID_SAVE, "encoded payload does not decode to the same value (%s)" % again.detail)
	var result: Result = Result.make(OK)
	result.value = text
	return result


## Bytes of a whole file -> normalized v1 payload. Order: size, UTF-8, envelope, checksum,
## payload type, then the version check before any v1-only structure (a later version may
## add fields, which must read as "incompatible", not as damage), migration, validation.
static func decode(bytes: PackedByteArray, manifest: Dictionary) -> Result:
	if bytes.size() > MAX_FILE_BYTES:
		return Result.make(CORRUPT_SAVE, "file larger than %d bytes" % MAX_FILE_BYTES)
	if not _is_utf8(bytes):
		return Result.make(CORRUPT_SAVE, "not UTF-8")
	var envelope: Variant = _parse(bytes.get_string_from_utf8())
	if typeof(envelope) != TYPE_DICTIONARY or not _has_keys(envelope, ENVELOPE_KEYS):
		return Result.make(CORRUPT_SAVE, "not a save envelope")
	if typeof(envelope.format) != TYPE_STRING or envelope.format != FORMAT:
		return Result.make(CORRUPT_SAVE, "format")
	if typeof(envelope.payload_json) != TYPE_STRING or typeof(envelope.sha256) != TYPE_STRING \
			or not _is_sha256_hex(envelope.sha256):
		return Result.make(CORRUPT_SAVE, "payload_json/sha256 types")
	var payload_json: String = envelope.payload_json
	if payload_json.sha256_text() != envelope.sha256:
		return Result.make(CHECKSUM_MISMATCH, "payload bytes do not match sha256")
	var payload: Variant = _parse(payload_json)
	if typeof(payload) != TYPE_DICTIONARY:
		return Result.make(INVALID_SAVE, "payload is not an object")
	var schema: Dictionary = _int(payload.get("schema_version"), -MAX_SAFE_INT, MAX_SAFE_INT)
	var content: Dictionary = _int(payload.get("content_version"), -MAX_SAFE_INT, MAX_SAFE_INT)
	if not schema.ok:
		return Result.make(schema.code, "schema_version: %s" % schema.detail)
	if schema.value > SCHEMA_VERSION or schema.value < OLDEST_SCHEMA:
		return Result.make(UNSUPPORTED_SCHEMA, "schema_version %d (supported %d..%d)" % [schema.value, OLDEST_SCHEMA, SCHEMA_VERSION])
	if not content.ok:
		return Result.make(content.code, "content_version: %s" % content.detail)
	if content.value != CONTENT_VERSION:
		return Result.make(CONTENT_MISMATCH, "content_version %d (supported %d)" % [content.value, CONTENT_VERSION])
	# Migration runs one exact step at a time on copies: 0 -> 1 (facing), then the whole v1
	# contract is checked before 1 -> 2 adds the default calendar. The file is never written.
	var migrated_from: int = -1 if schema.value == SCHEMA_VERSION else schema.value
	if schema.value == 0:
		var to_v1: Result = migrate_v0(payload)
		if not to_v1.ok:
			return to_v1
		payload = to_v1.value
	if schema.value <= 1:
		var v1: Result = _validate(payload, manifest, 1)
		if not v1.ok:
			return v1
		payload = migrate_v1(v1.value).value
	var result: Result = _validate(payload, manifest, SCHEMA_VERSION)
	result.migrated_from = migrated_from if result.ok else -1
	return result


## v0 -> v1 on an independent copy: adds player.facing = "down" and sets schema 1. Every
## other value (quantities, slots, revisions, generation) is carried over unchanged.
static func migrate_v0(payload: Dictionary) -> Result:
	var copy: Dictionary = payload.duplicate(true)
	var player: Variant = copy.get("player")
	if typeof(player) != TYPE_DICTIONARY or (player as Dictionary).has("facing"):
		return Result.make(INVALID_SAVE, "v0 player must be an object without facing")
	player["facing"] = "down"
	# Exactly schema 1, never the latest: the result must still pass the v1 contract.
	copy["schema_version"] = 1
	var result: Result = Result.make(OK)
	result.value = copy
	return result


## A verified v1 payload -> v2 copy: the default calendar at day 0, tick 0, revision 0.
## Nothing else changes; no time is guessed for a save that had none.
static func migrate_v1(payload: Dictionary) -> Result:
	var copy: Dictionary = payload.duplicate(true)
	copy["calendar"] = {"rule_id": MIGRATION_RULE_ID, "day_index": 0, "tick_in_day": 0, "revision": 0}
	copy["schema_version"] = 2
	var result: Result = Result.make(OK)
	result.value = copy
	return result


## The whole contract of `schema` (1 or 2) against the trusted manifest; returns a
## normalized deep copy.
static func _validate(payload: Dictionary, manifest: Dictionary, schema: int) -> Result:
	if not _has_keys(payload, PAYLOAD_KEYS_V2 if schema >= 2 else PAYLOAD_KEYS):
		return Result.make(INVALID_SAVE, "payload keys %s" % [_sorted_keys(payload)])
	var out: Dictionary = {}
	for key: String in ["schema_version", "content_version"]:
		var number: Dictionary = _int(payload[key], 0, MAX_SAFE_INT)
		var expected: int = schema if key == "schema_version" else CONTENT_VERSION
		if not number.ok or number.value != expected:
			return Result.make(UNSUPPORTED_SCHEMA if key == "schema_version" else CONTENT_MISMATCH, "%s must be %d" % [key, expected])
		out[key] = number.value
	var generation: Dictionary = _int(payload.generation, 1, MAX_SAFE_INT)
	if not generation.ok:
		return Result.make(generation.code, "generation: %s" % generation.detail)
	out["generation"] = generation.value
	if typeof(payload.map_id) != TYPE_STRING:
		return Result.make(INVALID_SAVE, "map_id type")
	if payload.map_id != manifest.map_id:
		return Result.make(CONTENT_MISMATCH, "unknown map_id '%s'" % String(payload.map_id).c_escape())
	out["map_id"] = payload.map_id
	var player: Result = _player(payload.player, manifest)
	if not player.ok:
		return player
	out["player"] = player.value
	var inventories: Result = _inventories(payload.inventories, manifest)
	if not inventories.ok:
		return inventories
	out["inventories"] = inventories.value
	var points: Result = _points(payload.points, manifest)
	if not points.ok:
		return points
	out["points"] = points.value
	if schema >= 2:
		var calendar: Result = _calendar(payload.calendar, manifest)
		if not calendar.ok:
			return calendar
		out["calendar"] = calendar.value
	var result: Result = Result.make(OK)
	result.value = out
	return result


## The calendar state of the manifest's trusted profile: exact keys, ints in the profile's
## ranges. A file can never choose the day length or season length.
static func _calendar(calendar: Variant, manifest: Dictionary) -> Result:
	if typeof(calendar) != TYPE_DICTIONARY or not _has_keys(calendar, CALENDAR_KEYS):
		return Result.make(INVALID_SAVE, "calendar keys must be %s" % [CALENDAR_KEYS])
	if typeof(calendar.rule_id) != TYPE_STRING:
		return Result.make(INVALID_SAVE, "calendar rule_id type")
	var profile: Dictionary = manifest.get("calendar_profile", {})
	if profile.is_empty() or calendar.rule_id != profile.rule_id:
		return Result.make(CONTENT_MISMATCH, "calendar rule '%s' is not this map's profile" % String(calendar.rule_id).c_escape())
	var limits: Dictionary = {"day_index": CalendarRules.max_day_index(profile),
		"tick_in_day": int(profile.ticks_per_day) - 1, "revision": MAX_SAFE_INT}
	var out: Dictionary = {"rule_id": calendar.rule_id}
	for key: String in limits:
		var number: Dictionary = _int(calendar[key], 0, limits[key])
		if not number.ok:
			return Result.make(number.code, "calendar %s: %s" % [key, number.detail])
		out[key] = number.value
	var result: Result = Result.make(OK)
	result.value = out
	return result


static func _player(player: Variant, manifest: Dictionary) -> Result:
	if typeof(player) != TYPE_DICTIONARY or not _has_keys(player, PLAYER_KEYS):
		return Result.make(INVALID_SAVE, "player keys")
	if typeof(player.player_id) != TYPE_STRING or typeof(player.inventory_id) != TYPE_STRING:
		return Result.make(INVALID_SAVE, "player IDs type")
	if player.player_id != manifest.player_id or player.inventory_id != manifest.bag_id:
		return Result.make(CONTENT_MISMATCH, "player %s / bag %s" % [String(player.player_id).c_escape(), String(player.inventory_id).c_escape()])
	if typeof(player.facing) != TYPE_STRING or not FACINGS.has(player.facing):
		return Result.make(INVALID_SAVE, "facing")
	var position: Variant = player.position
	if typeof(position) != TYPE_DICTIONARY or not _has_keys(position, POSITION_KEYS):
		return Result.make(INVALID_SAVE, "position keys")
	var bounds: Rect2 = manifest.bounds
	var xy: Array = []
	for axis: String in POSITION_KEYS:
		var value: Variant = position[axis]
		if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
			return Result.make(INVALID_SAVE, "position.%s type" % axis)
		if not is_finite(float(value)):
			return Result.make(NUMBER_OUT_OF_RANGE, "position.%s not finite" % axis)
		xy.append(float(value))
	if xy[0] < bounds.position.x or xy[0] > bounds.end.x or xy[1] < bounds.position.y or xy[1] > bounds.end.y:
		return Result.make(NUMBER_OUT_OF_RANGE, "position %s outside the map %s" % [xy, bounds])
	var result: Result = Result.make(OK)
	result.value = {"player_id": player.player_id, "inventory_id": player.inventory_id,
		"position": {"x": xy[0], "y": xy[1]}, "facing": player.facing}
	return result


## Exactly the manifest's inventories (bag, store, every stock), sorted by ID, each with
## the manifest's owner and capacity; stocks hold only their item, 1..initial or empty.
static func _inventories(list: Variant, manifest: Dictionary) -> Result:
	var expected: Dictionary = manifest.inventories
	if typeof(list) != TYPE_ARRAY or (list as Array).size() != expected.size():
		return Result.make(INVALID_SAVE, "inventories must list exactly %d entries" % expected.size())
	var out: Array = []
	var previous: String = ""
	for entry: Variant in list:
		if typeof(entry) != TYPE_DICTIONARY or not _has_keys(entry, SNAPSHOT_KEYS):
			return Result.make(INVALID_SAVE, "inventory keys")
		if typeof(entry.inventory_id) != TYPE_STRING or typeof(entry.owner_id) != TYPE_STRING:
			return Result.make(INVALID_SAVE, "inventory IDs type")
		var inventory_id: String = entry.inventory_id
		if not expected.has(inventory_id):
			return Result.make(CONTENT_MISMATCH, "unknown inventory '%s'" % inventory_id.c_escape())
		if not previous.is_empty() and inventory_id <= previous:
			return Result.make(INVALID_SAVE, "inventories not sorted/unique at %s" % inventory_id)
		previous = inventory_id
		var spec: Dictionary = expected[inventory_id]
		var capacity: Dictionary = _int(entry.capacity, 1, MAX_SAFE_INT)
		if not capacity.ok:
			return Result.make(capacity.code, "%s capacity: %s" % [inventory_id, capacity.detail])
		if entry.owner_id != spec.owner_id or capacity.value != spec.capacity:
			return Result.make(CONTENT_MISMATCH, "%s owner/capacity" % inventory_id)
		var revision: Dictionary = _int(entry.revision, 0, MAX_SAFE_INT)
		if not revision.ok:
			return Result.make(revision.code, "%s revision: %s" % [inventory_id, revision.detail])
		if typeof(entry.slots) != TYPE_ARRAY or (entry.slots as Array).size() != capacity.value:
			return Result.make(INVALID_SAVE, "%s slots length" % inventory_id)
		var slots: Array = []
		for index: int in (entry.slots as Array).size():
			var stack: Result = _stack(entry.slots[index], spec, manifest.items)
			if not stack.ok:
				return Result.make(stack.code, "%s slot %d: %s" % [inventory_id, index, stack.detail])
			slots.append(stack.value)
		out.append({"inventory_id": inventory_id, "owner_id": entry.owner_id, "capacity": capacity.value,
			"revision": revision.value, "slots": slots})
	var result: Result = Result.make(OK)
	result.value = out
	return result


static func _stack(stack: Variant, spec: Dictionary, items: Dictionary) -> Result:
	var result: Result = Result.make(OK)
	if stack == null:
		return result
	if typeof(stack) != TYPE_DICTIONARY or not _has_keys(stack, STACK_KEYS):
		return Result.make(INVALID_SAVE, "stack keys")
	if typeof(stack.item_id) != TYPE_STRING:
		return Result.make(INVALID_SAVE, "item_id type")
	if not items.has(stack.item_id):
		return Result.make(CONTENT_MISMATCH, "unknown item '%s'" % String(stack.item_id).c_escape())
	var quantity: Dictionary = _int(stack.quantity, 1, MAX_SAFE_INT)
	if not quantity.ok:
		return Result.make(quantity.code, "quantity: %s" % quantity.detail)
	if quantity.value > int(items[stack.item_id]):
		return Result.make(INVALID_SAVE, "quantity above stack limit")
	if spec.has("item_id") and (stack.item_id != spec.item_id or quantity.value > int(spec.initial)):
		return Result.make(INVALID_SAVE, "stock must hold only %s, at most %d" % [spec.item_id, spec.initial])
	result.value = {"item_id": stack.item_id, "quantity": quantity.value}
	return result


## The point bindings are fixed by the trusted map: a save can never re-point a stock.
static func _points(list: Variant, manifest: Dictionary) -> Result:
	var expected: Array = manifest.points
	if typeof(list) != TYPE_ARRAY or (list as Array).size() != expected.size():
		return Result.make(INVALID_SAVE, "points must list exactly %d bindings" % expected.size())
	var out: Array = []
	for index: int in expected.size():
		var entry: Variant = list[index]
		if typeof(entry) != TYPE_DICTIONARY or not _has_keys(entry, BINDING_KEYS):
			return Result.make(INVALID_SAVE, "binding %d keys" % index)
		var copy: Dictionary = {}
		for key: String in BINDING_KEYS:
			if typeof(entry[key]) != TYPE_STRING:
				return Result.make(INVALID_SAVE, "binding %d %s type" % [index, key])
			copy[key] = entry[key]
		if copy != expected[index]:
			return Result.make(CONTENT_MISMATCH, "binding %d differs from the map: %s" % [index, copy])
		out.append(copy)
	var result: Result = Result.make(OK)
	result.value = out
	return result


## The shared number contract for other trusted JSON (calendar rules, IH-120).
static func json_int(value: Variant, low: int, high: int) -> Dictionary:
	return _int(value, low, high)


## {ok, value: int, code, detail}. JSON numbers arrive as float: allowed only when finite,
## whole and inside [low, high]. Bool, String, null and anything else are refused.
static func _int(value: Variant, low: int, high: int) -> Dictionary:
	var number: float = 0.0
	match typeof(value):
		TYPE_INT:
			if value < low or value > high:
				return {"ok": false, "code": NUMBER_OUT_OF_RANGE, "detail": "%d outside %d..%d" % [value, low, high]}
			return {"ok": true, "value": int(value)}
		TYPE_FLOAT:
			number = value
		_:
			return {"ok": false, "code": INVALID_SAVE, "detail": "not a number (%s)" % type_string(typeof(value))}
	if not is_finite(number):
		return {"ok": false, "code": NUMBER_OUT_OF_RANGE, "detail": "not finite"}
	if number != floorf(number):
		return {"ok": false, "code": INVALID_SAVE, "detail": "not a whole number (%s)" % number}
	# Compared as floats first: a huge value must not overflow int() before the check.
	if number < float(low) or number > float(high):
		return {"ok": false, "code": NUMBER_OUT_OF_RANGE, "detail": "%s outside %d..%d" % [number, low, high]}
	return {"ok": true, "value": int(number)}


static func _parse(text: String) -> Variant:
	var json: JSON = JSON.new()
	if json.parse(text) != Error.OK:
		return null
	return json.data


static func _has_keys(data: Dictionary, keys: Array) -> bool:
	return _sorted_keys(data) == keys


static func _sorted_keys(data: Dictionary) -> Array:
	var keys: Array = data.keys()
	for key: Variant in keys:
		if typeof(key) != TYPE_STRING:
			return []
	keys.sort()
	return keys


static func _is_sha256_hex(text: String) -> bool:
	if text.length() != 64:
		return false
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


## Strict UTF-8 check done here so damaged bytes are refused quietly instead of being
## replaced (with an engine message) by the decoder.
static func _is_utf8(bytes: PackedByteArray) -> bool:
	var index: int = 0
	var size: int = bytes.size()
	while index < size:
		var lead: int = bytes[index]
		var extra: int = 0
		var minimum: int = 0
		if lead < 0x80:
			index += 1
			continue
		elif lead >= 0xC2 and lead <= 0xDF:
			extra = 1
			minimum = 0x80
		elif lead >= 0xE0 and lead <= 0xEF:
			extra = 2
			minimum = 0x800
		elif lead >= 0xF0 and lead <= 0xF4:
			extra = 3
			minimum = 0x10000
		else:
			return false
		if index + extra >= size:
			return false
		var code: int = lead & (0x3F >> extra)
		for offset: int in range(1, extra + 1):
			var next: int = bytes[index + offset]
			if next & 0xC0 != 0x80:
				return false
			code = (code << 6) | (next & 0x3F)
		if code < minimum or code > 0x10FFFF or (code >= 0xD800 and code <= 0xDFFF):
			return false
		index += extra + 1
	return true
