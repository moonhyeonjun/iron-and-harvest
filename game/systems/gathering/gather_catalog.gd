class_name GatherCatalog
extends Resource
## Explicit list of gathering definitions (IH-111); order comes from this list, never from
## a directory scan. compile() validates every entry against the item records and returns
## independent scalar records. One bad entry rejects the whole list.
##
## Source policy (BUG-008): the engine silently turns 2.5/true/"3" into ints when loading a
## typed field, so a definition is only trusted when its authored text can be checked.
## - External .tres file: initial_quantity must be written as an integer literal.
## - Definition embedded in another resource ("::" path): always refused, valid or not.
## - No source file (built in code): refused unless the catalog opts in below.

@export var definitions: Array[GatherDef] = []
## Accept definitions that have no source file at all (tests/tools building them in code).
## Not exported, so a saved catalog can never turn it on; their typed int value is taken as is.
var allow_unsourced_definitions: bool = false


## {"ok", "errors", "records": {definition_id: {...}}, "order"}. `items` maps item_id to the
## validated InventoryService item record (for existence and stack limits).
func compile(items: Dictionary) -> Dictionary:
	var errors: PackedStringArray = []
	var records: Dictionary = {}
	var order: Array[StringName] = []
	for index: int in definitions.size():
		var definition: GatherDef = definitions[index]
		if definition == null:
			errors.append("definitions[%d]: null definition" % index)
			continue
		var label: String = "definitions[%d] '%s'" % [index, String(definition.definition_id).c_escape()]
		var id_ok: bool = ItemCatalog.is_valid_id(definition.definition_id)
		if not id_ok:
			errors.append("%s: invalid definition_id" % label)
		elif records.has(definition.definition_id):
			errors.append("%s: duplicate definition_id" % label)
		if definition.display_name.strip_edges().is_empty() or definition.action_label.strip_edges().is_empty():
			errors.append("%s: empty display_name/action_label" % label)
		var item: Dictionary = items.get(definition.item_id, {}) if ItemCatalog.is_valid_id(definition.item_id) else {}
		if item.is_empty():
			errors.append("%s: unknown item_id '%s'" % [label, String(definition.item_id).c_escape()])
		elif definition.initial_quantity < 1 or definition.initial_quantity > int(item.stack_limit):
			errors.append("%s: initial_quantity %d outside 1..%d" % [label, definition.initial_quantity, item.stack_limit])
		var source_problem: String = _source_problem(definition)
		if not source_problem.is_empty():
			errors.append("%s: %s" % [label, source_problem])
		if id_ok and not records.has(definition.definition_id):
			records[definition.definition_id] = {
				"definition_id": StringName(definition.definition_id),
				"display_name": String(definition.display_name),
				"action_label": String(definition.action_label),
				"item_id": StringName(definition.item_id),
				"initial_quantity": int(definition.initial_quantity),
			}
			order.append(definition.definition_id)
	if definitions.is_empty():
		errors.append("no gathering definitions")
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "records": {}, "order": []}
	return {"ok": true, "errors": errors, "records": records, "order": order}


## "" when the definition's authored quantity can be trusted under the source policy above.
func _source_problem(definition: GatherDef) -> String:
	var path: String = definition.resource_path
	if path.is_empty():
		return "" if allow_unsourced_definitions else "definition has no source file (use an external .tres)"
	if path.contains("::"):
		return "embedded definitions are not supported (use an external .tres)"
	if not FileAccess.file_exists(path):
		return "source file %s not found" % path
	var literal: String = _authored_literal(path, "initial_quantity")
	if not literal.is_valid_int():
		return "initial_quantity is not an integer literal (%s)" % literal
	return ""


## The value text written for `property` in an external .tres file, or "<missing>".
static func _authored_literal(path: String, property: String) -> String:
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with(property + " = "):
			return line.substr(property.length() + 3).strip_edges()
	return "<missing>"
