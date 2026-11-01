extends Node2D
## IH-102 verification map: audits its own targets once and wires the player's
## interaction controller to the UI. Content and coordinates are test fixtures.

const EMPTY_ID: StringName = &"EMPTY_ID"
const DUPLICATE_ID: StringName = &"DUPLICATE_ID"

## target node name -> rejection reason, kept for verification output.
var audit_rejections: Dictionary = {}

@onready var controller: InteractionController = $World/Player/InteractionController
@onready var ui: InteractionUI = $InteractionUI


func _ready() -> void:
	_audit_targets()
	controller.target_changed.connect(ui.show_target)
	controller.session_opened.connect(ui.open_session)
	controller.session_closed.connect(ui.close_session)
	ui.close_requested.connect(func(request_id: int) -> void:
		controller.finish_active(request_id, InteractionController.COMPLETED))
	ui.cancel_requested.connect(func(request_id: int) -> void:
		controller.finish_active(request_id, InteractionController.CANCELLED))


## Empty or repeated authored IDs are never registered as selectable targets.
func _audit_targets() -> void:
	var holders: Dictionary = {}
	for node: Node in $Targets.find_children("*", "InteractionTarget", true, false):
		var target: InteractionTarget = node as InteractionTarget
		if target.target_id.is_empty():
			target.reject_registration(EMPTY_ID)
			audit_rejections[String(target.name)] = EMPTY_ID
			continue
		if not holders.has(target.target_id):
			holders[target.target_id] = []
		(holders[target.target_id] as Array).append(target)
	for target_id: StringName in holders:
		var group: Array = holders[target_id]
		if group.size() < 2:
			continue
		for target: InteractionTarget in group:
			target.reject_registration(DUPLICATE_ID)
			audit_rejections[String(target.name)] = DUPLICATE_ID
