class_name SaveUI
extends CanvasLayer
## Save/load panel of the IH-112 test scene: shows the test-only save root, the slot's two
## generations and the last result, and emits intents tagged with the epoch it was showing.
## It never reads files or touches the world; F5/F9 are routed by the scene. Buttons take
## no keyboard focus, so E/I/movement keys never land on them.

signal save_requested(epoch: int)
signal load_requested(epoch: int, source: StringName)

const MESSAGES: Dictionary = {
	&"OK": "완료",
	&"BUSY": "지금은 할 수 없습니다. 열린 창을 닫거나 진행 중인 행동이 끝난 뒤 다시 시도하세요.",
	&"NO_SAVE": "저장된 게임이 없습니다.",
	&"NO_RECOVERY": "복구할 이전 세대가 없습니다.",
	&"RECOVERY_AVAILABLE": "최신 저장이 손상되었습니다. 현재 게임은 그대로입니다. '이전 세대로 복구'로 이전 진행을 불러올 수 있습니다.",
	&"CORRUPT_SAVE": "저장 파일이 손상되어 불러오거나 덮어쓸 수 없습니다. 현재 게임은 그대로입니다.",
	&"INCOMPATIBLE_SAVE": "다른 버전의 저장이라 불러오거나 덮어쓰지 않습니다. 현재 게임은 그대로입니다.",
	&"AMBIGUOUS_SAVE": "같은 세대의 서로 다른 저장이 있어 판단할 수 없습니다. 현재 게임은 그대로입니다.",
	&"IO_ERROR": "파일을 읽거나 쓸 수 없습니다. 현재 게임과 기존 저장은 그대로입니다.",
	&"FILE_CHANGED": "저장 중 파일이 바뀌어 중단했습니다. 기존 저장은 그대로입니다.",
	&"INVALID_POSITION": "저장된 위치가 막혀 있어 불러오지 않았습니다. 현재 게임은 그대로입니다.",
	&"FOCUS_LOST": "창이 비활성이 되어 중단했습니다. 현재 게임은 그대로입니다.",
	&"CANCELLED": "취소했습니다. 현재 게임은 그대로입니다.",
	&"STALE_SESSION": "이전 화면의 요청이라 무시했습니다.",
	&"COMMIT_UNCERTAIN": "저장 결과를 확정할 수 없습니다. 다시 불러와 확인하세요.",
}

var _epoch: int = 1

@onready var _root_label: Label = $Panel/Layout/Root
@onready var _slot_label: Label = $Panel/Layout/Slot
@onready var _message: Label = $Panel/Layout/Message
@onready var _save: Button = $Panel/Layout/Buttons/Save
@onready var _load: Button = $Panel/Layout/Buttons/Load
@onready var _recover: Button = $Panel/Layout/Recover


func _ready() -> void:
	_save.pressed.connect(func() -> void: save_requested.emit(_epoch))
	_load.pressed.connect(func() -> void: load_requested.emit(_epoch, &"latest"))
	_recover.pressed.connect(func() -> void: load_requested.emit(_epoch, &"recovery"))
	_recover.disabled = true


func set_epoch(epoch: int) -> void:
	_epoch = epoch


func get_epoch() -> int:
	return _epoch


func show_root(text: String) -> void:
	_root_label.text = text


## `status` is a summary {code, latest_generation, recovery_generation, recovery_bank}.
func show_slot(status: Dictionary) -> void:
	var parts: PackedStringArray = []
	if int(status.get("latest_generation", 0)) > 0:
		parts.append("최신 %d세대" % status.latest_generation)
	if int(status.get("recovery_generation", 0)) > 0:
		parts.append("이전 %d세대(복구 가능)" % status.recovery_generation)
	if parts.is_empty():
		parts.append(String(status.get("code", "")))
	_slot_label.text = "슬롯: " + " · ".join(parts)
	_recover.disabled = int(status.get("recovery_generation", 0)) <= 0
	_recover.text = "이전 %d세대로 복구" % status.recovery_generation if not _recover.disabled else "이전 세대로 복구"


func set_busy(busy: bool) -> void:
	_save.disabled = busy
	_load.disabled = busy


func show_result(result: Dictionary) -> void:
	var code: StringName = StringName(result.get("code", ""))
	var text: String = MESSAGES.get(code, "실패: %s" % code)
	if result.get("ok", false):
		if result.kind == "save":
			text = "%d세대로 저장했습니다." % result.generation
		else:
			text = "%d세대를 불러왔습니다%s." % [result.generation, " (이전 세대 복구)" if result.recovered else ""]
	elif result.get("cause", code) != code:
		text += " (%s)" % result.cause
	_message.text = text


func get_message() -> String:
	return _message.text
