class_name CalendarHUD
extends CanvasLayer
## Calendar display of the IH-120 test scene: date and time, running/stopped with reasons,
## profile and test root. Emits intents with the epoch (and revision) it was showing; it
## never touches the calendar. Labels are rewritten only when the visible minute, day or
## reasons change; the epoch/revision sent by the buttons are refreshed on every view.
## Layer 1: below the modal panels (bag 3, inspect 2), so an open panel is never covered.

signal pause_requested(epoch: int)
signal next_day_requested(epoch: int, revision: int)

const SEASON_NAMES: Dictionary = {"spring": "봄", "summer": "여름", "autumn": "가을", "winter": "겨울"}
const REASON_NAMES: Dictionary = {
	"user_paused": "시간 정지", "focus": "창 비활성", "neutral": "키를 놓아 주세요", "tree_paused": "게임 일시 정지",
	"removed": "세계 없음", "save_load": "저장/불러오기 중", "no_service": "달력 없음", "suspended": "세션 교체 중",
	"busy": "처리 중", "modal": "창/행동 진행 중", "not_ready": "준비 안 됨", "physics_hz": "물리 60Hz 아님",
	"limit": "달력 마지막 날",
}
const RESULT_NAMES: Dictionary = {
	&"OK": "완료", &"QUEUED": "다음 새벽 예약", &"BUSY": "지금은 할 수 없습니다", &"STALE_SESSION": "이전 화면의 요청",
	&"STALE_REVISION": "시간이 이미 바뀌었습니다. 다시 누르세요", &"CANCELLED": "취소됨", &"FOCUS_LOST": "창이 비활성이라 취소",
	&"REMOVED": "세계가 없습니다", &"NOT_READY": "준비되지 않음(키를 놓았다가 다시)",
}

var _epoch: int = -1
var _revision: int = -1

@onready var _date: Label = $Panel/Layout/Date
@onready var _status: Label = $Panel/Layout/Status
@onready var _info: Label = $Panel/Layout/Info
@onready var _message: Label = $Panel/Layout/Message
@onready var _pause: Button = $Panel/Layout/Buttons/Pause
@onready var _next: Button = $Panel/Layout/Buttons/Next


func _ready() -> void:
	_pause.pressed.connect(func() -> void: pause_requested.emit(_epoch))
	_next.pressed.connect(func() -> void: next_day_requested.emit(_epoch, _revision))


func show_info(text: String) -> void:
	_info.text = text


func show_view(view: Dictionary) -> void:
	_epoch = int(view.get("epoch", -1))
	_revision = int((view.get("snapshot", {}) as Dictionary).get("revision", -1))
	if not view.get("changed", true):
		return
	var date: Dictionary = view.get("date", {})
	if date.is_empty():
		_date.text = "달력 없음"
	else:
		_date.text = "%d년 %s %d일 %02d:%02d" % [date.year, SEASON_NAMES.get(date.season_id, date.season_id), date.day_of_season, date.hour, date.minute]
	var reasons: PackedStringArray = view.get("reasons", PackedStringArray())
	if reasons.is_empty():
		_status.text = "시간 진행 중"
	else:
		var names: PackedStringArray = []
		for reason: String in reasons:
			names.append(REASON_NAMES.get(reason, reason))
		_status.text = "정지: " + ", ".join(names)
	_pause.text = "시간 재개 (P)" if view.get("user_paused", false) else "시간 정지 (P)"


func show_result(result: Dictionary) -> void:
	var code: StringName = StringName(result.get("code", ""))
	var label: String = "시간" if result.get("command") == "pause" else "다음 새벽"
	_message.text = "%s: %s" % [label, RESULT_NAMES.get(code, String(code))]


func show_boundary(event: Dictionary) -> void:
	_message.text = "새 날이 밝았습니다 (지난 날 #%d → #%d)" % [event.completed_day_index, event.to_day_index]


func get_date_text() -> String:
	return _date.text
