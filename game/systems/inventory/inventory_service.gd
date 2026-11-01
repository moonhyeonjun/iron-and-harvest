class_name InventoryService
extends RefCounted
## Single writer of registered inventories (IH-110). Every write validates on copies and
## replaces state only when the whole command succeeds; failures change no slot, quantity,
## revision or event. Each success bumps each changed revision by exactly 1 and emits
## inventories_changed once, while the write lock is still held, so a callback can read
## the final state of both sides but any write from it is refused as BUSY.
## Capacities, items and stack limits used by the test map are verification fixtures.

signal inventories_changed(changed_ids: Array[StringName], revisions: Dictionary)

const OK: StringName = &"OK"
const BUSY: StringName = &"BUSY"
const CLOSED: StringName = &"CLOSED"
const INVALID_CATALOG: StringName = &"INVALID_CATALOG"
const INVALID_ARGUMENT: StringName = &"INVALID_ARGUMENT"
const INVENTORY_NOT_FOUND: StringName = &"INVENTORY_NOT_FOUND"
const DUPLICATE_INVENTORY: StringName = &"DUPLICATE_INVENTORY"
const SAME_INVENTORY: StringName = &"SAME_INVENTORY"
const STALE_REVISION: StringName = &"STALE_REVISION"
const INVALID_SLOT: StringName = &"INVALID_SLOT"
const UNKNOWN_ITEM: StringName = &"UNKNOWN_ITEM"
const EMPTY_SLOT: StringName = &"EMPTY_SLOT"
const INSUFFICIENT_QUANTITY: StringName = &"INSUFFICIENT_QUANTITY"
const NO_SPACE: StringName = &"NO_SPACE"
const INVALID_SNAPSHOT: StringName = &"INVALID_SNAPSHOT"

const MIN_CAPACITY: int = 1
const MAX_CAPACITY: int = 256
## Technical request ceiling (256 slots x 9999), checked before any arithmetic.
const MAX_REQUEST: int = MAX_CAPACITY * ItemCatalog.MAX_STACK
const SNAPSHOT_KEYS: Array = ["capacity", "inventory_id", "owner_id", "revision", "slots"]
const STACK_KEYS: Array = ["item_id", "quantity"]


## Typed command outcome. `value` carries read results (snapshot, count, decoded state).
class Result extends RefCounted:
	var ok: bool = false
	var code: StringName = &""
	var applied_quantity: int = 0
	## inventory_id (String) -> new revision, for the inventories a success changed.
	var revisions: Dictionary = {}
	var value: Variant = null
	var detail: String = ""

	static func make(result_code: StringName, result_detail: String = "") -> Result:
		var result: Result = Result.new()
		result.ok = result_code == OK
		result.code = result_code
		result.detail = result_detail
		return result


var _records: Dictionary = {}
var _item_order: Array[StringName] = []
var _catalog_errors: PackedStringArray = []
var _inventories: Dictionary = {}
var _busy: bool = false
var _closed: bool = false


func _init(catalog: ItemCatalog) -> void:
	if catalog == null:
		_catalog_errors = PackedStringArray(["catalog is null"])
		return
	var compiled: Dictionary = catalog.compile()
	_catalog_errors = compiled.errors
	if compiled.ok:
		_records = compiled.records
		_item_order.assign(compiled.order)


func is_catalog_valid() -> bool:
	return _catalog_errors.is_empty()


func get_catalog_errors() -> PackedStringArray:
	return _catalog_errors.duplicate()


## Item IDs in catalog order.
func get_item_ids() -> Array[StringName]:
	return _item_order.duplicate()


## Independent copy of an item's validated scalar record, or an empty Dictionary.
func get_item_info(item_id: StringName) -> Dictionary:
	return (_records[item_id] as Dictionary).duplicate() if _records.has(item_id) else {}


func close() -> void:
	_closed = true


func is_closed() -> bool:
	return _closed


# --- creation --------------------------------------------------------------------

func register_inventory(inventory_id: Variant, owner_id: Variant, capacity: Variant) -> Result:
	var gate: StringName = _write_gate()
	if gate != OK:
		return Result.make(gate)
	if not ItemCatalog.is_valid_id(inventory_id) or not ItemCatalog.is_valid_id(owner_id):
		return Result.make(INVALID_ARGUMENT, "inventory_id/owner_id")
	if typeof(capacity) != TYPE_INT or capacity < MIN_CAPACITY or capacity > MAX_CAPACITY:
		return Result.make(INVALID_ARGUMENT, "capacity")
	if _inventories.has(StringName(inventory_id)):
		return Result.make(DUPLICATE_INVENTORY)
	_inventories[StringName(inventory_id)] = InventoryState.create_empty(StringName(inventory_id), StringName(owner_id), capacity)
	return _success({String(inventory_id): 0}, 0)


## Strictly validates a snapshot value and returns a new, unregistered InventoryState.
func decode_snapshot(data: Variant) -> Result:
	var gate: StringName = _read_gate()
	if gate != OK:
		return Result.make(gate)
	var problem: String = _snapshot_problem(data)
	if not problem.is_empty():
		return Result.make(INVALID_SNAPSHOT, problem)
	var state: InventoryState = InventoryState.new()
	state.inventory_id = StringName(data.inventory_id)
	state.owner_id = StringName(data.owner_id)
	state.capacity = data.capacity
	state.revision = data.revision
	for stack: Variant in data.slots:
		state.slots.append(null if stack == null else {"item_id": StringName(stack.item_id), "quantity": int(stack.quantity)})
	var result: Result = Result.make(OK)
	result.value = state
	return result


## Registers a fresh copy of a valid snapshot. Never replaces an existing inventory.
func register_snapshot(data: Variant) -> Result:
	var gate: StringName = _write_gate()
	if gate != OK:
		return Result.make(gate)
	var decoded: Result = decode_snapshot(data)
	if not decoded.ok:
		return decoded
	var state: InventoryState = decoded.value
	if _inventories.has(state.inventory_id):
		return Result.make(DUPLICATE_INVENTORY)
	_inventories[state.inventory_id] = state
	return _success({String(state.inventory_id): state.revision}, 0)


# --- reads -----------------------------------------------------------------------

func snapshot(inventory_id: Variant) -> Result:
	var gate: StringName = _read_gate()
	if gate != OK:
		return Result.make(gate)
	if not ItemCatalog.is_valid_id(inventory_id):
		return Result.make(INVALID_ARGUMENT, "inventory_id")
	var state: InventoryState = _inventories.get(StringName(inventory_id))
	if state == null:
		return Result.make(INVENTORY_NOT_FOUND)
	var result: Result = Result.make(OK)
	result.value = state.to_snapshot()
	return result


func count(inventory_id: Variant, item_id: Variant) -> Result:
	var gate: StringName = _read_gate()
	if gate != OK:
		return Result.make(gate)
	if not ItemCatalog.is_valid_id(inventory_id) or not ItemCatalog.is_valid_id(item_id):
		return Result.make(INVALID_ARGUMENT, "id")
	var state: InventoryState = _inventories.get(StringName(inventory_id))
	if state == null:
		return Result.make(INVENTORY_NOT_FOUND)
	if not _records.has(StringName(item_id)):
		return Result.make(UNKNOWN_ITEM)
	var result: Result = Result.make(OK)
	result.value = state.count(StringName(item_id))
	return result


# --- writes ----------------------------------------------------------------------

## Adds the whole quantity or nothing: fills partial stacks of the item from the lowest
## index, then empty slots from the lowest index. Other items never move.
func add(inventory_id: Variant, item_id: Variant, quantity: Variant, expected_revision: Variant) -> Result:
	var gate: StringName = _write_gate()
	if gate != OK:
		return Result.make(gate)
	if not ItemCatalog.is_valid_id(inventory_id) or not ItemCatalog.is_valid_id(item_id):
		return Result.make(INVALID_ARGUMENT, "id")
	if not _is_quantity(quantity) or not _is_revision(expected_revision):
		return Result.make(INVALID_ARGUMENT, "quantity/revision")
	var state: InventoryState = _inventories.get(StringName(inventory_id))
	if state == null:
		return Result.make(INVENTORY_NOT_FOUND)
	if state.revision != expected_revision:
		return Result.make(STALE_REVISION)
	if not _records.has(StringName(item_id)):
		return Result.make(UNKNOWN_ITEM)
	var planned: Array = _plan_add(state.copy_slots(), StringName(item_id), quantity)
	if planned.is_empty():
		return Result.make(NO_SPACE)
	return _commit({state.inventory_id: planned}, quantity)


## Removes the whole quantity or nothing, from the lowest index; emptied slots become null.
func remove(inventory_id: Variant, item_id: Variant, quantity: Variant, expected_revision: Variant) -> Result:
	var gate: StringName = _write_gate()
	if gate != OK:
		return Result.make(gate)
	if not ItemCatalog.is_valid_id(inventory_id) or not ItemCatalog.is_valid_id(item_id):
		return Result.make(INVALID_ARGUMENT, "id")
	if not _is_quantity(quantity) or not _is_revision(expected_revision):
		return Result.make(INVALID_ARGUMENT, "quantity/revision")
	var state: InventoryState = _inventories.get(StringName(inventory_id))
	if state == null:
		return Result.make(INVENTORY_NOT_FOUND)
	if state.revision != expected_revision:
		return Result.make(STALE_REVISION)
	if not _records.has(StringName(item_id)):
		return Result.make(UNKNOWN_ITEM)
	if state.count(StringName(item_id)) < quantity:
		return Result.make(INSUFFICIENT_QUANTITY)
	var planned: Array = state.copy_slots()
	var remaining: int = quantity
	for index: int in planned.size():
		var stack: Variant = planned[index]
		if remaining == 0 or stack == null or stack.item_id != StringName(item_id):
			continue
		var taken: int = mini(remaining, stack.quantity)
		stack.quantity -= taken
		remaining -= taken
		if stack.quantity == 0:
			planned[index] = null
	return _commit({state.inventory_id: planned}, quantity)


## Moves quantity from one chosen source slot (never other slots) into the destination,
## which may spread over several stacks. Both sides change together or not at all.
func transfer(source_id: Variant, source_slot: Variant, destination_id: Variant, quantity: Variant,
		expected_source_revision: Variant, expected_destination_revision: Variant) -> Result:
	var gate: StringName = _write_gate()
	if gate != OK:
		return Result.make(gate)
	if not ItemCatalog.is_valid_id(source_id) or not ItemCatalog.is_valid_id(destination_id):
		return Result.make(INVALID_ARGUMENT, "id")
	if typeof(source_slot) != TYPE_INT or not _is_quantity(quantity) \
			or not _is_revision(expected_source_revision) or not _is_revision(expected_destination_revision):
		return Result.make(INVALID_ARGUMENT, "slot/quantity/revision")
	var source: InventoryState = _inventories.get(StringName(source_id))
	var destination: InventoryState = _inventories.get(StringName(destination_id))
	if source == null or destination == null:
		return Result.make(INVENTORY_NOT_FOUND)
	if source == destination:
		return Result.make(SAME_INVENTORY)
	if source.revision != expected_source_revision or destination.revision != expected_destination_revision:
		return Result.make(STALE_REVISION)
	if source_slot < 0 or source_slot >= source.capacity:
		return Result.make(INVALID_SLOT)
	var source_slots: Array = source.copy_slots()
	var stack: Variant = source_slots[source_slot]
	if stack == null:
		return Result.make(EMPTY_SLOT)
	if stack.quantity < quantity:
		return Result.make(INSUFFICIENT_QUANTITY)
	var destination_slots: Array = _plan_add(destination.copy_slots(), stack.item_id, quantity)
	if destination_slots.is_empty():
		return Result.make(NO_SPACE)
	stack.quantity -= quantity
	if stack.quantity == 0:
		source_slots[source_slot] = null
	return _commit({source.inventory_id: source_slots, destination.inventory_id: destination_slots}, quantity)


# --- internals -------------------------------------------------------------------

## Returns the planned slots, or [] when the whole quantity does not fit.
func _plan_add(slots: Array, item_id: StringName, quantity: int) -> Array:
	var limit: int = _records[item_id].stack_limit
	var remaining: int = quantity
	for stack: Variant in slots:
		if remaining == 0:
			break
		if stack != null and stack.item_id == item_id and stack.quantity < limit:
			var added: int = mini(remaining, limit - stack.quantity)
			stack.quantity += added
			remaining -= added
	for index: int in slots.size():
		if remaining == 0:
			break
		if slots[index] == null:
			var placed: int = mini(remaining, limit)
			slots[index] = {"item_id": item_id, "quantity": placed}
			remaining -= placed
	return slots if remaining == 0 else []


## Applies every planned slot array, bumps each revision once and reports once.
func _commit(planned: Dictionary, applied: int) -> Result:
	_busy = true
	var revisions: Dictionary = {}
	for inventory_id: StringName in planned:
		var state: InventoryState = _inventories[inventory_id]
		state.slots = planned[inventory_id]
		state.revision += 1
		revisions[String(inventory_id)] = state.revision
	var changed: Array[StringName] = []
	changed.assign(planned.keys())
	changed.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	inventories_changed.emit(changed, revisions.duplicate())
	_busy = false
	return _success(revisions, applied)


func _success(revisions: Dictionary, applied: int) -> Result:
	var result: Result = Result.make(OK)
	result.revisions = revisions
	result.applied_quantity = applied
	return result


func _write_gate() -> StringName:
	if _busy:
		return BUSY
	return _read_gate()


func _read_gate() -> StringName:
	if _closed:
		return CLOSED
	if not is_catalog_valid():
		return INVALID_CATALOG
	return OK


func _is_quantity(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 1 and value <= MAX_REQUEST


func _is_revision(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0


## Empty when the snapshot is valid, otherwise the first problem found. Nothing is
## trimmed or coerced: wrong keys, types, lengths, IDs or limits reject the whole value.
func _snapshot_problem(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "not a Dictionary"
	var keys: Array = []
	for key: Variant in data.keys():
		if typeof(key) != TYPE_STRING:
			return "non-String key"
		keys.append(key)
	keys.sort()
	if keys != SNAPSHOT_KEYS:
		return "keys %s" % [keys]
	if not ItemCatalog.is_valid_id(data.inventory_id) or not ItemCatalog.is_valid_id(data.owner_id):
		return "inventory_id/owner_id"
	if typeof(data.capacity) != TYPE_INT or data.capacity < MIN_CAPACITY or data.capacity > MAX_CAPACITY:
		return "capacity"
	if typeof(data.revision) != TYPE_INT or data.revision < 0:
		return "revision"
	if typeof(data.slots) != TYPE_ARRAY or (data.slots as Array).size() != data.capacity:
		return "slots length"
	for index: int in (data.slots as Array).size():
		var stack: Variant = data.slots[index]
		if stack == null:
			continue
		if typeof(stack) != TYPE_DICTIONARY:
			return "slot %d type" % index
		var stack_keys: Array = (stack as Dictionary).keys()
		stack_keys.sort()
		if stack_keys != STACK_KEYS:
			return "slot %d keys" % index
		if not ItemCatalog.is_valid_id(stack.item_id) or not _records.has(StringName(stack.item_id)):
			return "slot %d item_id" % index
		if typeof(stack.quantity) != TYPE_INT or stack.quantity < 1 \
				or stack.quantity > _records[StringName(stack.item_id)].stack_limit:
			return "slot %d quantity" % index
	return ""
