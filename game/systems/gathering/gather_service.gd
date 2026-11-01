class_name GatherService
extends RefCounted
## Finite resource points (IH-111). Each point owns a hidden 1-slot inventory ("stock") in
## the same InventoryService as the player's bag; gathering is one InventoryService.transfer
## of 1 item stock->bag, so the point's loss and the bag's gain commit together or not at
## all. remaining/depleted are read from the stock, never stored separately. prepare() only
## captures revisions; a single-use command performs the transfer. No Node, input or time.

const OK: StringName = &"OK"
const BUSY: StringName = &"BUSY"
const CLOSED: StringName = &"CLOSED"
const INVALID_ARGUMENT: StringName = &"INVALID_ARGUMENT"
const INVALID_POINT: StringName = &"INVALID_POINT"
const INVALID_COMMAND: StringName = &"INVALID_COMMAND"
const INVALID_STOCK: StringName = &"INVALID_STOCK"
const INVALID_SETUP: StringName = &"INVALID_SETUP"
const DEPLETED: StringName = &"DEPLETED"
const STALE_REVISION: StringName = &"STALE_REVISION"
const NO_SPACE: StringName = &"NO_SPACE"
const BINDING_KEYS: Array = ["definition_id", "map_id", "point_id", "stock_inventory_id"]


## Independent outcome value. `value` carries query data, the prepared command, or the
## services created by build().
class Result extends RefCounted:
	var ok: bool = false
	var code: StringName = &""
	var request_id: int = 0
	var point_id: StringName = &""
	var item_id: StringName = &""
	var applied_quantity: int = 0
	var revisions: Dictionary = {}
	var value: Variant = null
	var detail: String = ""

	static func make(result_code: StringName, result_detail: String = "") -> Result:
		var result: Result = Result.new()
		result.ok = result_code == OK
		result.code = result_code
		result.detail = result_detail
		return result


## Single-use token. The service keeps the authoritative captured values, so editing this
## object cannot change what a commit does; it only routes back to the issuing service.
class GatherCommand extends RefCounted:
	var _service: WeakRef
	var _request_id: int
	var _point_id: StringName

	func _init(service: GatherService, request_id: int, point_id: StringName) -> void:
		_service = weakref(service)
		_request_id = request_id
		_point_id = point_id

	func get_request_id() -> int:
		return _request_id

	func get_point_id() -> StringName:
		return _point_id

	func commit() -> Result:
		var service: GatherService = _service.get_ref() as GatherService
		if service == null:
			return Result.make(INVALID_COMMAND, "service gone")
		return service.execute(self)

	func cancel() -> void:
		var service: GatherService = _service.get_ref() as GatherService
		if service != null:
			service.release(self)


var _inventory: InventoryService
var _bag_id: StringName = &""
var _definitions: Dictionary = {}
## point_id -> {"map_id", "definition_id", "stock_id", "item_id", "initial", "display_name", "action_label"}
var _points: Dictionary = {}
## The one unconsumed command: {"token", "request_id", "point_id", "stock_revision", "bag_revision"}.
var _pending: Dictionary = {}
var _busy: bool = false
var _closed: bool = false


## Validates everything and registers bag/store and every stock in a fresh InventoryService.
## Either both services come back ready (value = {"inventory", "gather"}) or nothing does.
## NEW game path: each stock is created here with its definition's initial quantity.
static func build(item_catalog: ItemCatalog, gather_catalog: GatherCatalog, snapshots: Array,
		bag_id: StringName, bindings: Array) -> Result:
	var used_inventory_ids: Dictionary = {}
	for snapshot: Variant in snapshots:
		if typeof(snapshot) == TYPE_DICTIONARY and ItemCatalog.is_valid_id(snapshot.get("inventory_id")):
			used_inventory_ids[StringName(snapshot.inventory_id)] = "inventory"
	var setup: Array = _setup(item_catalog, gather_catalog, bag_id, bindings, used_inventory_ids)
	var service: GatherService = setup[0]
	var errors: PackedStringArray = setup[1]
	var inventory: InventoryService = service._inventory
	if errors.is_empty():
		for snapshot: Variant in snapshots:
			var registered: InventoryService.Result = inventory.register_snapshot(snapshot)
			if not registered.ok:
				errors.append("snapshot: %s %s" % [registered.code, registered.detail])
		if not ItemCatalog.is_valid_id(bag_id) or not inventory.snapshot(bag_id).ok:
			errors.append("bag '%s' is not a registered inventory" % String(bag_id).c_escape())
		for point_id: StringName in service._points:
			var point: Dictionary = service._points[point_id]
			var stock: Dictionary = {"inventory_id": String(point.stock_id), "owner_id": String(point_id), "capacity": 1,
				"revision": 0, "slots": [{"item_id": String(point.item_id), "quantity": point.initial}]}
			var registered: InventoryService.Result = inventory.register_snapshot(stock)
			if not registered.ok:
				errors.append("stock %s: %s %s" % [point.stock_id, registered.code, registered.detail])
	return _finish_setup(service, errors)


## RESTORE path (IH-112): `snapshots` holds every inventory of the session, stocks included,
## exactly as saved. Each one is registered once; no stock is created or refilled, nothing
## is granted and no change signal is emitted. Every stock must still be capacity 1, owned
## by its point, holding only the point's item and no more than its initial quantity.
## Same all-or-nothing result as build().
static func restore(item_catalog: ItemCatalog, gather_catalog: GatherCatalog, snapshots: Array,
		bag_id: StringName, bindings: Array) -> Result:
	var stock_ids: Dictionary = {}
	for binding: Variant in bindings:
		if typeof(binding) == TYPE_DICTIONARY and ItemCatalog.is_valid_id(binding.get("stock_inventory_id")):
			stock_ids[StringName(binding.stock_inventory_id)] = true
	var used_inventory_ids: Dictionary = {}
	var seen: Dictionary = {}
	var errors: PackedStringArray = []
	for snapshot: Variant in snapshots:
		if typeof(snapshot) != TYPE_DICTIONARY or not ItemCatalog.is_valid_id(snapshot.get("inventory_id")):
			errors.append("snapshot without a valid inventory_id")
			continue
		var inventory_id: StringName = StringName(snapshot.inventory_id)
		seen[inventory_id] = int(seen.get(inventory_id, 0)) + 1
		if not stock_ids.has(inventory_id):
			used_inventory_ids[inventory_id] = "inventory"
	var setup: Array = _setup(item_catalog, gather_catalog, bag_id, bindings, used_inventory_ids)
	var service: GatherService = setup[0]
	errors.append_array(setup[1])
	var inventory: InventoryService = service._inventory
	for stock_id: StringName in stock_ids:
		if int(seen.get(stock_id, 0)) != 1:
			errors.append("stock %s saved %d times" % [stock_id, int(seen.get(stock_id, 0))])
	if stock_ids.has(bag_id):
		errors.append("bag '%s' is a point stock" % bag_id)
	if errors.is_empty():
		for snapshot: Variant in snapshots:
			var registered: InventoryService.Result = inventory.register_snapshot(snapshot)
			if not registered.ok:
				errors.append("snapshot %s: %s %s" % [snapshot.get("inventory_id"), registered.code, registered.detail])
		if not ItemCatalog.is_valid_id(bag_id) or not inventory.snapshot(bag_id).ok:
			errors.append("bag '%s' is not a registered inventory" % String(bag_id).c_escape())
	if errors.is_empty():
		for point_id: StringName in service._points:
			var stock: Dictionary = service._stock_state(point_id)
			if stock.code != OK:
				errors.append("stock of %s: %s %s" % [point_id, stock.code, stock.detail])
	return _finish_setup(service, errors)


## Compiles definitions and checks every binding against the non-stock inventory IDs.
## Returns [service (not yet usable), errors]. Shared by the NEW and RESTORE paths.
static func _setup(item_catalog: ItemCatalog, gather_catalog: GatherCatalog, bag_id: StringName,
		bindings: Array, used_inventory_ids: Dictionary) -> Array:
	var errors: PackedStringArray = []
	var inventory: InventoryService = InventoryService.new(item_catalog)
	if not inventory.is_catalog_valid():
		errors.append_array(inventory.get_catalog_errors())
	var items: Dictionary = {}
	for item_id: StringName in inventory.get_item_ids():
		items[item_id] = inventory.get_item_info(item_id)
	var compiled: Dictionary = gather_catalog.compile(items) if gather_catalog != null else {"ok": false, "errors": ["gather catalog is null"]}
	errors.append_array(compiled.errors)
	var service: GatherService = GatherService.new()
	service._inventory = inventory
	service._bag_id = bag_id
	service._definitions = compiled.get("records", {})
	for index: int in bindings.size():
		var problem: String = service._binding_problem(bindings[index], used_inventory_ids)
		if not problem.is_empty():
			errors.append("bindings[%d]: %s" % [index, problem])
	return [service, errors]


static func _finish_setup(service: GatherService, errors: PackedStringArray) -> Result:
	if not errors.is_empty():
		service._inventory.close()
		service._closed = true
		return Result.make(INVALID_SETUP, "\n".join(errors))
	var result: Result = Result.make(OK)
	result.value = {"inventory": service._inventory, "gather": service}
	return result


func get_inventory() -> InventoryService:
	return _inventory


func get_bag_id() -> StringName:
	return _bag_id


func get_point_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_points.keys())
	return ids


## True while an unconsumed command exists (diagnostics and tests).
func has_pending_command() -> bool:
	return not _pending.is_empty()


## True while execute() runs (a commit and its change signal). Read-only, for the save
## coordinator's quiescence check.
func is_busy() -> bool:
	return _busy


## Independent copies of the bindings this service was built from, sorted by point_id.
## Only IDs: no remaining/depleted (they are derived from the stocks).
func export_bindings() -> Array:
	var ids: Array = _points.keys()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	var out: Array = []
	for point_id: StringName in ids:
		var point: Dictionary = _points[point_id]
		out.append({"point_id": String(point_id), "map_id": String(point.map_id),
			"definition_id": String(point.definition_id), "stock_inventory_id": String(point.stock_id)})
	return out


func close() -> void:
	_closed = true
	_pending = {}


func is_closed() -> bool:
	return _closed


## Independent copy of a point's derived state; reads are allowed while a commit runs.
func query(point_id: Variant) -> Result:
	if _closed:
		return Result.make(CLOSED)
	if not ItemCatalog.is_valid_id(point_id):
		return Result.make(INVALID_ARGUMENT, "point_id")
	var point: Dictionary = _points.get(StringName(point_id), {})
	if point.is_empty():
		return Result.make(INVALID_POINT)
	var stock: Dictionary = _stock_state(StringName(point_id))
	var result: Result = Result.make(stock.code)
	result.point_id = StringName(point_id)
	result.item_id = point.item_id
	if stock.code != OK:
		result.detail = stock.detail
		return result
	result.value = {
		"point_id": String(point_id), "map_id": String(point.map_id), "definition_id": String(point.definition_id),
		"item_id": String(point.item_id), "display_name": point.display_name, "action_label": point.action_label,
		"initial": point.initial, "remaining": stock.remaining, "depleted": stock.remaining == 0,
		"revision": stock.revision,
	}
	return result


## Captures both revisions for one future transfer. Changes no inventory and emits nothing.
## Only the bag chosen at build time is accepted as destination.
func prepare(point_id: Variant, bag_id: Variant, request_id: Variant) -> Result:
	var gate: StringName = _gate()
	if gate != OK:
		return _fail(gate, request_id, point_id)
	if not ItemCatalog.is_valid_id(point_id) or not ItemCatalog.is_valid_id(bag_id) \
			or typeof(request_id) != TYPE_INT or request_id < 1:
		return _fail(INVALID_ARGUMENT, request_id, point_id)
	if StringName(bag_id) != _bag_id:
		return _fail(INVALID_ARGUMENT, request_id, point_id, "destination is not the player bag")
	if not _points.has(StringName(point_id)):
		return _fail(INVALID_POINT, request_id, point_id)
	if not _pending.is_empty():
		return _fail(BUSY, request_id, point_id, "a prepared command is outstanding")
	var stock: Dictionary = _stock_state(StringName(point_id))
	if stock.code != OK:
		return _fail(stock.code, request_id, point_id, stock.detail)
	if stock.remaining == 0:
		return _fail(DEPLETED, request_id, point_id)
	var bag: InventoryService.Result = _inventory.snapshot(_bag_id)
	if not bag.ok:
		return _fail(INVALID_ARGUMENT, request_id, point_id, "bag %s" % bag.code)
	var command: GatherCommand = GatherCommand.new(self, request_id, StringName(point_id))
	_pending = {"token": command, "request_id": int(request_id), "point_id": StringName(point_id),
		"stock_revision": stock.revision, "bag_revision": int(bag.value.revision)}
	var result: Result = _fail(OK, request_id, point_id)
	result.ok = true
	result.value = command
	return result


## Runs a command issued by this service exactly once. The command is consumed before any
## other check, so a failure never leaves it reusable. The transfer is the only write.
func execute(command: GatherCommand) -> Result:
	var gate: StringName = _gate()
	if gate != OK:
		return _fail(gate, command.get_request_id() if command != null else 0, command.get_point_id() if command != null else &"")
	if command == null or _pending.is_empty() or _pending.token != command:
		# A foreign, cancelled or used command never disturbs the valid pending one.
		return _fail(INVALID_COMMAND, command.get_request_id() if command != null else 0, command.get_point_id() if command != null else &"")
	var pending: Dictionary = _pending
	_pending = {}
	_busy = true
	var result: Result = _execute_pending(pending)
	_busy = false
	return result


## Drops the pending command if it is this one; safe to call any number of times.
func release(command: GatherCommand) -> void:
	if not _pending.is_empty() and _pending.token == command:
		_pending = {}


func _execute_pending(pending: Dictionary) -> Result:
	var point_id: StringName = pending.point_id
	var stock: Dictionary = _stock_state(point_id)
	if stock.code != OK:
		return _fail(stock.code, pending.request_id, point_id, stock.detail)
	var bag: InventoryService.Result = _inventory.snapshot(_bag_id)
	if not bag.ok or stock.revision != pending.stock_revision or int(bag.value.revision) != pending.bag_revision:
		return _fail(STALE_REVISION, pending.request_id, point_id)
	if stock.remaining == 0:
		return _fail(DEPLETED, pending.request_id, point_id)
	var point: Dictionary = _points[point_id]
	var moved: InventoryService.Result = _inventory.transfer(point.stock_id, 0, _bag_id, 1,
		pending.stock_revision, pending.bag_revision)
	var result: Result = _fail(moved.code, pending.request_id, point_id, moved.detail)
	if moved.ok:
		result.ok = true
		result.code = OK
		result.applied_quantity = 1
		# From the transfer itself: a callback may already have closed the services.
		result.revisions = moved.revisions.duplicate()
	return result


## Stock integrity and derived remaining: capacity 1, owned by the point, holding only the
## point's item and never more than it started with. Anything else is INVALID_STOCK.
func _stock_state(point_id: StringName) -> Dictionary:
	var point: Dictionary = _points[point_id]
	var snap: InventoryService.Result = _inventory.snapshot(point.stock_id)
	if not snap.ok:
		return {"code": INVALID_STOCK if snap.code != InventoryService.CLOSED else CLOSED, "detail": String(snap.code)}
	var data: Dictionary = snap.value
	if data.capacity != 1 or StringName(data.owner_id) != point_id:
		return {"code": INVALID_STOCK, "detail": "capacity/owner"}
	var stack: Variant = data.slots[0]
	var remaining: int = 0
	if stack != null:
		if StringName(stack.item_id) != point.item_id or stack.quantity > point.initial:
			return {"code": INVALID_STOCK, "detail": "item/quantity"}
		remaining = stack.quantity
	return {"code": OK, "remaining": remaining, "revision": int(data.revision), "detail": ""}


func _binding_problem(binding: Variant, used_inventory_ids: Dictionary) -> String:
	if typeof(binding) != TYPE_DICTIONARY:
		return "not a Dictionary"
	var keys: Array = (binding as Dictionary).keys()
	keys.sort()
	if keys != BINDING_KEYS:
		return "keys %s" % [keys]
	for key: String in BINDING_KEYS:
		if not ItemCatalog.is_valid_id(binding[key]):
			return "%s '%s' is not a valid ID" % [key, str(binding[key]).c_escape()]
	var point_id: StringName = StringName(binding.point_id)
	var stock_id: StringName = StringName(binding.stock_inventory_id)
	if _points.has(point_id):
		return "duplicate point_id %s" % point_id
	if used_inventory_ids.has(stock_id):
		return "stock_inventory_id %s already used by %s" % [stock_id, used_inventory_ids[stock_id]]
	var definition: Dictionary = _definitions.get(StringName(binding.definition_id), {})
	if definition.is_empty():
		return "unknown definition_id %s" % binding.definition_id
	used_inventory_ids[stock_id] = "point " + String(point_id)
	_points[point_id] = {"map_id": StringName(binding.map_id), "definition_id": StringName(binding.definition_id),
		"stock_id": stock_id, "item_id": definition.item_id, "initial": int(definition.initial_quantity),
		"display_name": definition.display_name, "action_label": definition.action_label}
	return ""


func _gate() -> StringName:
	if _busy:
		return BUSY
	if _closed:
		return CLOSED
	return OK


func _fail(code: StringName, request_id: Variant, point_id: Variant, detail: String = "") -> Result:
	var result: Result = Result.make(code, detail)
	result.request_id = int(request_id) if typeof(request_id) == TYPE_INT else 0
	result.point_id = StringName(point_id) if ItemCatalog.is_valid_id(point_id) else &""
	if _points.has(result.point_id):
		result.item_id = _points[result.point_id].item_id
	return result
