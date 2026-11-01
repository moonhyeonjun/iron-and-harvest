class_name GatherDef
extends Resource
## Authored gathering definition (IH-111): which item a resource point yields and how many
## it starts with. Loaded Resources are shared by the engine cache, so GatherCatalog copies
## validated scalars; nothing here is runtime state. Values are verification fixtures.

@export var definition_id: StringName = &""
@export var display_name: String = ""
@export var action_label: String = ""
@export var item_id: StringName = &""
## Default 0 is invalid on purpose so every file must state the quantity.
@export var initial_quantity: int = 0
