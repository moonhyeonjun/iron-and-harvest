class_name ItemCatalog
extends Resource
## Explicit list of item definitions (IH-110). Order comes from this list, never from a
## directory scan. compile() validates every entry and returns independent scalar records;
## one bad entry rejects the whole catalog so nothing is silently dropped.

const CATEGORIES: Array[StringName] = [&"material", &"crop", &"food", &"seed", &"tool"]
const MIN_STACK: int = 1
const MAX_STACK: int = 9999
const ID_MAX_LENGTH: int = 64

@export var definitions: Array[ItemDef] = []

## True when the whole value is an ASCII lower-case ID `[a-z][a-z0-9_]*` of 1..64
## characters. Every character is checked (a regex `$` would accept a trailing newline,
## BUG-006), and nothing is trimmed or case-folded, so distinct inputs never alias an ID.
static func is_valid_id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		return false
	var text: String = String(value)
	if text.is_empty() or text.length() > ID_MAX_LENGTH:
		return false
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		var lower: bool = code >= 97 and code <= 122
		if index == 0:
			if not lower:
				return false
		elif not (lower or (code >= 48 and code <= 57) or code == 95):
			return false
	return true


## {"ok": bool, "errors": PackedStringArray, "records": {item_id: {...}}, "order": Array}.
## Records are fresh Dictionaries; later edits to the ItemDef objects cannot reach them.
func compile() -> Dictionary:
	var errors: PackedStringArray = []
	var records: Dictionary = {}
	var order: Array[StringName] = []
	for index: int in definitions.size():
		var definition: ItemDef = definitions[index]
		if definition == null:
			errors.append("definitions[%d]: null definition" % index)
			continue
		var label: String = "definitions[%d] '%s'" % [index, definition.item_id]
		if not is_valid_id(definition.item_id):
			errors.append("%s: invalid item_id" % label)
		elif records.has(definition.item_id):
			errors.append("%s: duplicate item_id" % label)
		if String(definition.name_key).is_empty():
			errors.append("%s: empty name_key" % label)
		if definition.fallback_name.strip_edges().is_empty():
			errors.append("%s: empty fallback_name" % label)
		if definition.category not in CATEGORIES:
			errors.append("%s: unknown category '%s'" % [label, definition.category])
		if definition.stack_limit < MIN_STACK or definition.stack_limit > MAX_STACK:
			errors.append("%s: stack_limit %d outside %d..%d" % [label, definition.stack_limit, MIN_STACK, MAX_STACK])
		if is_valid_id(definition.item_id) and not records.has(definition.item_id):
			records[definition.item_id] = {
				"item_id": StringName(definition.item_id),
				"name_key": StringName(definition.name_key),
				"fallback_name": String(definition.fallback_name),
				"category": StringName(definition.category),
				"stack_limit": int(definition.stack_limit),
			}
			order.append(definition.item_id)
	if definitions.is_empty():
		errors.append("catalog has no definitions")
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "records": {}, "order": []}
	return {"ok": true, "errors": errors, "records": records, "order": order}
