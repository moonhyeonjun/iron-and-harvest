class_name InventoryState
extends RefCounted
## Plain inventory data (IH-110): fixed slots of null or {"item_id": StringName,
## "quantity": int}. Only InventoryService writes registered states; everyone else gets
## independent snapshots. No Resource, Node or display text is stored here.

var inventory_id: StringName = &""
var owner_id: StringName = &""
var capacity: int = 0
var revision: int = 0
var slots: Array = []


static func create_empty(id: StringName, owner: StringName, size: int) -> InventoryState:
	var state: InventoryState = InventoryState.new()
	state.inventory_id = id
	state.owner_id = owner
	state.capacity = size
	state.slots.resize(size)
	return state


func duplicate_state() -> InventoryState:
	var copy: InventoryState = InventoryState.new()
	copy.inventory_id = inventory_id
	copy.owner_id = owner_id
	copy.capacity = capacity
	copy.revision = revision
	copy.slots = copy_slots()
	return copy


func copy_slots() -> Array:
	var copy: Array = []
	for stack: Variant in slots:
		copy.append(null if stack == null else {"item_id": stack.item_id, "quantity": stack.quantity})
	return copy


## Total quantity of item_id across all slots.
func count(item_id: StringName) -> int:
	var total: int = 0
	for stack: Variant in slots:
		if stack != null and stack.item_id == item_id:
			total += int(stack.quantity)
	return total


## Read-only value with String IDs and int numbers only, safe to hand out and to JSON.
func to_snapshot() -> Dictionary:
	var out_slots: Array = []
	for stack: Variant in slots:
		out_slots.append(null if stack == null else {"item_id": String(stack.item_id), "quantity": int(stack.quantity)})
	return {
		"inventory_id": String(inventory_id),
		"owner_id": String(owner_id),
		"capacity": capacity,
		"revision": revision,
		"slots": out_slots,
	}
