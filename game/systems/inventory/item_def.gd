class_name ItemDef
extends Resource
## Authored item definition (IH-110). Holds no runtime quantity. Loaded Resources are
## shared by the engine cache, so ItemCatalog copies validated scalars instead of keeping
## this object as live state. Values are verification fixtures, not final balance.

@export var item_id: StringName = &""
@export var name_key: StringName = &""
@export var fallback_name: String = ""
@export var category: StringName = &""
## Default 0 is invalid on purpose: every definition must state its limit explicitly, so a
## changed default can never silently alter saved .tres files.
@export var stack_limit: int = 0
## Optional; the UI falls back to text when null. Not copied into inventory state.
@export var icon: Texture2D = null
