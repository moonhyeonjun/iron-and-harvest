# IH-120 달력·계절·하루 경계 상세 명세

상태: **Proposed / 구현됨(review)**(2026-11-02 Claude Code, [검증 기록](../03-development/IH-120-VALIDATION.md), 아래 '구현 결과·차이'). 원래 상태는 구현 ready(2026-11-01)였다. 기준 develop `4d30344`, IH-112 done·ADR-017 Accepted, v0.3.0 확정. 이번 작업은 설계뿐이며 Calendar 코드·신규 runner·GUI는 아직 없다. Codex는 설계·검증, Claude Code는 구현을 맡는다. [수락 조건](../03-development/IH-120-ACCEPTANCE.md), [인수인계](../03-development/IH-120-HANDOFF.md), [ADR-018](../04-decisions/ADR/ADR-018-calendar-day-boundary.md)을 함께 따른다.

## 목적·범위

같은 마을에서 시간과 계절이 흐르고, 저장 후 같은 시점에서 이어가며, 다음 날로 넘어갈 때 정확히 한 번 날짜 경계를 전달한다. 이후 농사·생산은 이 경계를 소비한다. 생활·통치가 별도 달력을 갖지 않는다.

포함: 정수 달력, 실시간→달력 어댑터, 계절/연도 파생, 자연 날짜 전진·시험용 다음 새벽 명령, 시간 정지/포커스/모달/세션 가드, HUD, schema2 저장·v0/1 이관, 기존 회귀와 전용 맵. 제외: 작물/성장/생산·세금 결산, 주민 일정/노화, 날씨·일조 아트, 수면/체력/강제 귀가, 오프라인 보상, 국가 월간/역사 연간 시스템, 다중 날짜 건너뛰기, 시간 배속·되감기, 자동 저장·Cloud. N은 시험 UI의 하루 건너뛰기이며 제품 수면 시스템이 아니다.

## 1. 제안 규칙과 단일 원본

아래는 **구현·검증용 제안값**이다. 제품 밸런스/56일과 인물 수명의 대응은 TBD다. 값은 검증된 정의 하나에 두고 UI/codec에 상수를 중복하지 않는다. 프로필 ID의 의미를 바꾸면 새 ID/이관 계약이 필요하다.

| 정의 | 기본 `calendar_test_v1` | 빠른 시험 `calendar_boundary_fixture_v1` |
|---|---:|---:|
| physics_hz | 60 | 60 |
| ticks_per_day | 36000 | 120 |
| days_per_season | 14 | 2 |
| seasons | spring → summer → autumn → winter | 동일 |
| day_start_minute | 360(06:00) | 동일 |
| max_year | 9999 | 9999 |

물리 스텝1회가 달력 tick1이다. 기본 하루는 실제 시뮬레이션600초(10분), 1년56일이다. 렌더 FPS와 무관하지만 컴퓨터가 느리거나 앱이 멈춘 시간까지 따라잡는 벽시계는 아니다. physics_hz≠60 환경은 시험 초기화 NOT_READY로 명시 거부한다. Engine.time_scale/physics 설정 변경·OS 날짜/Time.get_unix_time·Timer timeout 누적으로 시간을 보정하지 않는다. 이동의 물리 설정도 변경하지 않는다.

`CalendarState = {rule_id: String, day_index: int, tick_in_day: int, revision: int}`만 영속 상태다. day_index는0부터, tick_in_day는0..ticks_per_day-1, revision은0..9007199254740991. 새 게임은 day_index0/tick0/revision0, 즉 1년 봄1일06:00. 정의와 상태는 외부 변경에서 독립된 사본이다.

파생(중복 저장 금지): `year=floor(day_index/(4*days_per_season))+1`, `season_index=floor(day_index/days_per_season)%4`, `day_of_season=day_index%days_per_season+1`, `minute_of_day=(360+floor(tick_in_day*1440/ticks_per_day))%1440`. floor는 정수 나눗셈으로 구현한다. 날짜 경계는 **새벽06:00**다. 23:59→00:00은 같은 플레이 일자이며 날짜/연도 경계가 아니다. HUD에 날짜와 ‘하루 시작06:00’을 표시한다. midnight의 별도 day event를 만들지 않는다.

기본 마지막 day_index는559943(9999년 겨울14일). 마지막 날 내부 tick은 진행 가능하지만 다음 해로 넘어가거나 revision이 넘치는 명령은 전체 NUMBER_OUT_OF_RANGE·상태/알림0이다. 어댑터는 한도 알림을 한 번 표시하고 자동 진행을 멈춘다. 유효 세션 교체 전까지 매 tick 오류를 반복하지 않는다.

## 2. 도메인 API와 데이터

이름은 제안이며 역할/불변식이 기준이다. 새 전역 이벤트 버스·Autoload·범용 스케줄러·미래용 빈 SeasonManager를 만들지 않는다.

| 모듈/경로 후보 | 책임 |
|---|---|
| game/data/calendar/calendar_rules.json | 신뢰된 두 프로필 정의. JSON 원문 수치를 검증한 뒤 내부 int로 정규화 |
| game/systems/calendar/calendar_rules.gd | RefCounted, 순수 값 정의 검증/독립 사본·프로필 조회. Node/파일/I/O/입력 없음 |
| game/systems/calendar/calendar_service.gd | RefCounted, 날짜 상태 유일 쓰기 소유자·원자 전진·snapshot/restore·closed/suspended/busy |
| game/scripts/calendar/calendar_controller.gd | 물리 스텝·키/버튼·정지 사유·pending/epoch·현재 세션 연결. SessionHost/World 밖 |
| game/ui/calendar/calendar_hud.* | snapshot 표시·표시 당시 epoch/revision을 가진 의도만 발행 |
| game/scenes/tests/calendar_test.tscn | 기존 저장/채집 월드를 재사용하는 전용 검증 루트, 밖에 SaveUI/CalendarController/HUD |
| game/tests/test_calendar.gd | AC-C 자동 검사·실제 맵 통합/파일 fixture/결정적 반복 |

상태 snapshot/get_date는 읽기만 하며 반환값 수정이 서비스에 영향을 주지 않는다. get_date는 year/season_id/day_of_season/hour/minute를 파생한다. `restore(snapshot, rules)`는 새 서비스만 만들고 초기화·day event·revision 증가·자원 지급0이다. `close()`는 멱등이며 이후 조회/전진은 CLOSED다. `set_session_suspended(bool)`는 세션 소유자만 사용하고 날짜/게이트/패널은 변경하지 않는다.

`advance_ticks(amount, expected_revision)`는 내부 시험·어댑터 명령이다. 런타임 인수는 실제 TYPE_INT만 허용(bool/float/문자열 거부). 순서: closed → busy/보고 또는 suspended → 인수 타입/범위 → expected revision → 결과 한도 검증 → 새 사본 설치 → 알림 → busy 해제. 실패 시 상태/이벤트0. amount는1..ticks_per_day만 허용하므로 한 명령에 최대 날짜 경계1개다. amount0/음수/하루 초과는 INVALID_AMOUNT. 성공마다 revision+1(경과 tick 수와 다름). 결과는 `{ok, code, before_revision, snapshot, boundary|null}`. STALE_REVISION/BUSY/CLOSED/INVALID_AMOUNT/INVALID_STATE/NUMBER_OUT_OF_RANGE를 구분한다. 반환 snapshot/boundary는 내부 상태와 독립이다.

정의 JSON도 bool·비정수·문자열/음수/중복 ID·미지원 순서/Hz·누락/추가 키·오버플로를 검증한다. 경로·Node를 도메인에 전달하지 않는다. Godot int Resource의 암묵 변환(DEBT-004)을 그대로 물려받지 않는다. 정확한 프로필 허용 목록은 신뢰 manifest에서 제공한다.

## 3. 하루 경계 commit·알림

`total=tick_in_day+amount`. total<ticks_per_day이면 같은 일자의 tick만 설치한다. 그 외 day_index+1, tick=total-ticks_per_day를 함께 설치한다. 다음 새벽은 amount=ticks_per_day-tick_in_day(이미06:00이면 정확히 하루)로 같은 API를 이용한다. 별도 날짜 setter나 ‘N용’ 결산 경로를 만들지 않는다.

날짜가 바뀐 경우 단일 `day_advanced` 알림을 **상태 설치 뒤** 한 번 발행한다. event는 값만 있는 읽기 전용 평면 Dictionary: `{from_day_index,to_day_index,completed_day_index,from_season_id,to_season_id,from_year,to_year,revision}`. completed_day_index=from_day_index이며 경계 후 날짜가 아니다. 발행용 사본은 make_read_only, 중첩 가변 객체 없음. season_changed/year_changed는 필드 비교로 파생하며 별도의 재진입 경로/알림 순서를 늘리지 않는다. UI는 일자 경계 또는 표시 분 변경 때만 갱신한다.

알림 중에도 서비스 busy 유지: 보고가 끝나기 전 직접/동기 재진입 전진은 BUSY, save/load는 세계/외부 clock blocker로 BUSY다. 정상 UI 표시를 위해 snapshot 읽기는 허용한다. 보고가 끝난 뒤 실행되는 deferred는 캡처한 epoch/revision과 현재 정지 상태로 다시 검증한다. 모든 deferred를 영구 금지하는 계약은 아니다. 읽기 전용/닫힘 뒤 동작 계약을 구분한다. 알림 리스너는 현재는 UI/검증 관찰자뿐이며 자원을 변경하지 않는다. 리스너 오류를 rollback 가능한 경제 결산이라고 부르지 않는다.

**중복 방지의 범위**: 같은 expected_revision 재요청은 STALE_REVISION, 보고 중 요청은 BUSY, 한 실행의 한 경계는 알림1회. 파일 복원은 과거 날짜 경계를 재발행하지 않으며 디스크 원본도 쓰지 않는다. 같은 저장을 다시 로드하면 그 뒤 미래 날짜를 다시 플레이할 수 있다. 서로 다른 세션까지 영구 exactly-once 보상이나 오프라인 정산을 보장하지 않는다.

IH-121/Production은 이후 completed_day_index별 성장/소비 계획→전체 검증→달력/대상 상태 동시 commit·snapshot을 별도 설계해야 한다. 현재 `day_advanced`에 보상 리스너를 임의 연결해서 부분 결산 상태를 저장하지 않는다. IH-120은 경제 결산/last_settled_day를 빈 필드로 선행 구현하지 않는다. 향후 상태를 추가할 때 schema와 원자 결산 계약을 함께 확장한다.

## 4. 실시간 어댑터·명령 순서

CalendarController는 SaveCoordinator/SaveUI와 함께 교체 World 밖에 둔다. 각 물리 스텝에 coordinator의 **현재 world/epoch**에서 CalendarService를 확인하고 허용될 때만 advance_ticks(1,current_revision) 한 번 호출한다. 이전 서비스 참조를 무조건 재사용하거나 staged 후보를 tick하지 않는다. 이전 서비스는 월드 이탈 시 close, 후보는 suspended 상태, publish 후에만 사용한다. 주기/입력의 직접·deferred 진입에도 수명·epoch·pending/보고 가드를 검사한다.

입력 제안: `calendar_pause` 물리P, `calendar_next_day` 물리N. 새 press만, echo/hold 무시. 기존 E/I/Escape/F5/F9 의미를 변경하지 않는다. P는 ‘시간 정지’를 토글하며 게임 전체 pause 메뉴가 아니다. N은 ‘다음 새벽’ 시험 버튼과 같은 명령이다. 버튼은 화면에 표시된 epoch/revision을 함께 보낸다. 키는 현재 coordinator epoch/revision을 쓰며 HUD가 free/queue_free/remove_child여도 죽은 HUD를 읽지 않는다. UI가 없어도 유효 키/자동 시간은 동작하고 표시만 생략한다. coordinator/host가 없으면 파일·상태 작업 없이 거부한다.

`request_next_day(epoch, revision)`는 검증 후 pending 한 건만 받아 QUEUED를 반환한다. 중복은 BUSY. 입력 콜백에서 달력을 바로 바꾸지 않는다. 다음 `_physics_process`에서 pending을 먼저 꺼내 epoch/서비스/revision/모달/포커스/정지/수명을 다시 검증하고 다음 새벽 amount로 호출한다. 해당 스텝의 자동+1은 성공/실패 모두 생략한다. 자연 tick보다 수동 의도가 먼저이므로 예약 뒤 자동 tick 때문에 의도가 임의 stale 되지 않는다. 같은 키 press/버튼 중복으로 두 날을 넘기지 않는다. 완료는 한 번만 보고하며 보고 중 새 시간/save/load 요청은 BUSY다.

P의 요청은 epoch를 검증하되 calendar revision에 묶지 않는다. 수명/포커스/키 중립·save/load/보고 가드는 유지하고 user pause와 모달 자체는 P 토글을 막지 않는다. 따라서 모달 중 시간 정지를 추가해도 모달을 닫은 뒤 정지가 남는다. P로 정지하면 pending N은 취소한다. N 버튼의 epoch/revision 메타데이터는 매 성공 tick/publish 뒤 최신 값으로 갱신하고, Label 문자열 갱신만 표시 분 단위로 줄인다. 화면에 보이는 분이 같다는 이유로 오래된 revision을 계속 보내 정상 클릭이 항상 STALE_REVISION이 되면 안 된다. 오래된 버튼 의도는 명시 거부하고 자동 재시도하지 않는다.

pending/보고는 비영속 상태다. SaveCoordinator.setup에 기본 비어 있는 선택적 외부 blocker Callable 등 **작은 hook 하나**로 CalendarController의 pending/보고를 save/load 진입에서 확인한다(기존 맵은 빈 hook). hook은 coordinator에 재귀 호출하지 않는다. 현재 `SaveCoordinator.is_busy()`는 state만 확인하므로 Clock이 거부 결과 보고 중을 놓치지 않도록 `_emitting`도 포함하는 읽기 API를 제공한다(is_busy 확장 또는 동등한 API). 기존 보고 중 BUSY 가드를 유지하고 거부 callback 안의 시간 요청도 검사한다. world.save_blocker는 CalendarService의 busy/유효성도 확인한다. F5/F9가 pending/보고를 임의 flush/취소해서 저장하지 않는다. 저장이 먼저 시작되면 시간 요청을 받지 않는다.

포커스 상실·수명 상실·사용자 시간 정지·외부 SceneTree pause는 pending을 취소하고 CANCELLED/FOCUS_LOST/STALE_SESSION 등 명시 결과 한 번, 날짜 변경0이다. 취소 intent를 복귀 때 재생하지 않는다. old epoch pending/버튼은 publish 후 새 세계를 건드리지 않는다. 새 서비스 bind 때 오래된 신호 연결을 해제하며 누수/중복 알림0. 명령 순서(입력→pending 소비→원자 설치/보고→다음 step)는 테스트로 측정한다.

## 5. 정지 정책

정지 사유는 Controller 한 곳이 합성한다. 어떤 사유 하나라도 남으면 자동 tick과 N을 차단하며 정지 기간을 누적·보충하지 않는다. user_paused와 window_focused는 독립 필드, 나머지는 현재 상태에서 읽는다. 단일 bool을 여러 작성자가 덮어쓰거나 사유 하나가 해제됐다고 전부 재개하지 않는다.

| 사유 | 자동 시간 / N | 기타 계약 |
|---|---|---|
| 사용자 시간 정지(P) | 정지 / BUSY | 이동/채집은 기존 규칙대로 가능. HUD ‘시간 정지’ 명시. P로만 해제 |
| 가방/보관·살펴보기·상호작용/채집 준비·도메인 commit | 정지 / BUSY | 강제로 패널 닫기·거래 취소 없음. 원래 입력/게이트 소유권 유지 |
| save/load busy·session_suspended·후보 World | 정지 / BUSY | CalendarService 직접/deferred 전진도 suspended/busy 검사 |
| focus out / 키 중립 대기 | 정지 / FOCUS_LOST 또는 NOT_READY | 복귀 때 P/N을 놓아야 새 press 수락. 이동의 기존 neutral 처리 유지 |
| SceneTree.paused | 정지 / BUSY | Controller가 ALWAYS여도 명령 진입에서 차단. 자체적으로 tree.pause 설정하지 않음 |
| host/world/service 제거·queue_free·setup 실패 | 정지 / REMOVED 또는 NOT_READY | 오래된 참조 호출0, 파일/날짜 변경0 |
| 임시 프레임 지연·앱 휴면 | 처리된 물리 step만 진행 | wall-clock 보충/오프라인 계산0 |

여기서 ‘정지’는 달력 시뮬레이션 정지다. Player의 bool 이동 게이트에 세 번째 작성자를 추가하지 않는다. user_paused는 화면 루트의 비영속 환경 상태라 성공/실패 load 뒤에도 현재 값을 유지한다. 저장 파일이 실행 중인 pause/포커스/GUI 상태를 덮어쓰지 않는다. 새 프로세스는 user_paused=false지만 실제 focus/neutral 확인 전에는 tick/입력을 받지 않는다. 포커스/모달/정지 중 load를 허용하는 기존 save/load 정책은 유지한다(예: 모달 load BUSY, 순수 user_paused 상태의 F5/F9 허용).

## 6. 저장 schema2와 구버전 이관

현재 SaveCodec은 schema1의 정확한7개 payload 키만 허용하고 v0의 facing 보충만 지원한다. 달력은 선택 키가 아니라 **schema2 필수 `calendar` 객체**로 추가한다. envelope/checksum/A/B generation/rename/명시 복구·content_version1은 유지한다. 품목/맵을 바꾸지 않으므로 content를 임의 증가시키지 않는다. rule_id는 manifest의 신뢰 프로필과 정확히 일치해야 하며 다르면 CONTENT_MISMATCH/INCOMPATIBLE_SAVE로 보존한다. 파일이 ticks_per_day/season 길이를 임의 지정하지 못한다.

```json
{"schema_version":2,"content_version":1,"generation":7,
 "map_id":"gathering_test","player":"기존 구조 유지",
 "inventories":"기존 구조 유지","points":"기존 구조 유지",
 "calendar":{"rule_id":"calendar_test_v1","day_index":13,"tick_in_day":35999,"revision":42}}
```

위는 구조 설명이며 player/inventories/points 문자열을 실제 fixture로 쓰지 않는다. 정상 fixture는 기존 전체 유효 payload에 calendar를 추가한다. day_index13/tick35999는 봄14일 다음 새벽 직전이다. 다음+1은 여름1일06:00/day_index14/revision43/event1이다. 계절/연도/시각은 저장하지 않는다.

- schema0(시험전용)→1: 기존 규칙대로 facing=down. **중간 schema는1로 고정**, 최신 SCHEMA_VERSION=2를 잘못 써서 v1 구조 검증을 우회하지 않는다.
- schema1→2: 먼저 기존 v1 전체 키/숫자/ID/결속/수량 검증. 독립 사본에 기본 프로필 day_index0/tick0/revision0을 추가하고 schema만2. 구세이브에 없던 시간을 추정하지 않는다. fast fixture의 다른 rule_id로 암묵 이관하지 않는다.
- 외부 migrated_from은 최초 원본 버전0/1을 보고한다. 새 schema2는-1. 원본 바이트/세대/재고/revision/위치·방향(0의 보충 제외)은 보존한다. load/migration 자체 이벤트0, 파일 쓰기0. 다음 명시 F5만 schema2·다음 generation으로 저장한다.
- schema2의 누락 calendar/필드·추가 키·범위/형식 오류를 거부한다. schema3+는 UNSUPPORTED_SCHEMA, 손상으로 오인해 은행을 덮어쓰지 않는다. JSON bool/비정수/NaN/INF/문자열/안전 범위 초과는 IH-112 숫자 계약대로 검사 후 int로 정규화한다. day_index와 rule별 max_year/tick 범위를 검증한다.
- A v1/B v2의 최신/직전 선택은 검증된 generation 기준이며 v1은 메모리 이관 후 유효본이다. 새 버전도 기존 두 은행을 즉시 업그레이드하지 않는다. 기존 v0.3.0 실행파일로 schema2를 읽으면 미지원으로 보존되는 것이 정상이다. 하위 버전으로 읽기를 지원하지 않는다.
- `schema2_future.json`는 IH-112 당시 미래 버전 증거로 보존한다. 신규 미래 검사는 실제3+ 또는 `SCHEMA_VERSION+1`로 만들고, 기존 schema2 fixture의 calendar 누락은 INVALID_SAVE 경계로 구분한다. 기존 v0/v1 fixture도 덮어써 미래 호환 검사를 가짜 통과시키지 않는다.

모든 World는 수동 tick이 가능한 CalendarService를 가진다. 기존 gathering/save_load 독립 맵에는 실시간 Controller를 붙이지 않아 날짜가 자동 진행하지 않는다. capture_payload/restore_context/save_manifest/set_session_suspended/_exit_tree에 calendar를 최소 연결한다. 별도 CalendarController를 둔 새 calendar_test만 자연 시간을 진행한다. 같은 새/복원 bootstrap에서 프로필을 명시 주입하고 staged 후보도 같은 정의로 검증한다. SaveLoadTest의 하드코딩된 manifest/restorer는 작은 설정 hook으로 확장하되 기본 동작은 유지하고 wrapper를 통째로 복제하지 않는다.

파일 실패/호스트 제거/후보 위치 실패/포커스 취소 시 원래 calendar 인스턴스·day/tick/revision도 그대로 복귀한다. 성공은 inventory/gather/calendar가 함께 들어간 새 컨텍스트로 교체한다. 중간 초기화가 실패하면 이미 만든 새 서비스도 모두 close한다. 기본/빠른 프로필은 별도 시험 루트를 쓰며 사용자 파일은 건드리지 않는다.

## 7. UI·검증 흐름

Calendar HUD: ‘1년 봄 1일 06:00’, 실행/정지와 사유, ‘시간 정지/재개(P)’, ‘다음 새벽(N, 시험용)’, 현재 프로필/시험 저장 루트. SaveUI의 세대·복구 안내는 유지하고 겹치지 않는다. 도움말은 midnight와06:00 경계를 구분한다. 매 프레임 Label 쓰기 대신 표시 분·일자·정지 사유 변경 때 갱신한다. staged/old world 신호가 새 HUD의 날짜를 덮어쓰지 않는다.

기본 fixture는 정상 속도, `--fixture=calendar-boundary` 같은 별도 옵션(정확한 이름은 구현 기록)만 빠른 프로필/다른 user://tests/ih120/ 경로를 선택한다. 사용자 전용 기존 ih112 GUI 파일을 재사용·손상시키지 않는다. main_scene/제품 배포 설정은 변경하지 않는다. 기존 save_load_test의 corrupt-latest 옵션과 N을 충돌시키지 않는다.

구현 후 실행 후보(현재 없음):

```sh
python3 tools/godot.py --headless --import
python3 tools/godot.py --headless --script res://tests/test_calendar.gd
python3 tools/godot.py res://scenes/tests/calendar_test.tscn
python3 tools/run_ci.py
```

기존 CI13단계에 calendar suite1개를 추가해14단계 예상(실제 등록/마커 검증). 기존 이동360·상호작용333·인벤토리521·채집347·저장529의 검증 의도를 보존한다. 스키마 변경에 따른 fixture/예상값 조정과 추가 검사를 구분해 기록한다. 임의 assertion 제거/이관 기본값으로 모든 날짜를 리셋해서 왕복을 통과시키지 않는다.

## 8. 후속 확장·TBD·자료

일일 소비/생산·작물 계획의 실패/원자 commit·독립 cursor는 IH-121/131/Simulation에서 명세를 확장한다. 월 정의, 배속, 수면/밤길이, 농사 계절 반응, 생애/왕조 연령과 압축 연도의 관계, 제품 지원 연수/수치는 TBD다. 일자·연도 표시가 곧 인물 나이 변경이라는 전제를 넣지 않는다.

Godot 공식 설명상 물리는 기본60Hz의 고정 주기이고 렌더 `_process`와 다르다. pause/process_mode가 멈춰도 signal 호출은 가능하므로 이번 설계는 명령 진입의 별도 가드를 요구한다. [물리/idle 처리](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html), [정지와 process mode](https://docs.godotengine.org/en/stable/tutorials/scripting/pausing_games.html). 공식 stable 문서와 실제4.7.2의 호출 순서/설정은 구현 때 측정한다. 이번에 새 엔진 동작을 검증했다고 보고하지 않는다.

## 구현 결과·차이 (2026-11-02, Claude Code)

- **모듈**:
  - `data/calendar/calendar_rules.json`(JSON 단일 원본), `systems/calendar/calendar_rules.gd`·`calendar_service.gd`
  - `scripts/calendar/calendar_controller.gd`, `ui/calendar/calendar_hud.*`(layer 1, 모달 아래)
  - `scenes/tests/calendar_test.tscn`(SaveLoadTest를 감싸는 장면), `tests/test_calendar.gd`·`support/calendar_child.gd`
- **SaveCoordinator**: `is_busy()`가 보고 중을 포함한다. `set_external_blocker`(setup 선택 인자 포함, 기본은 빈 값)를 둔다.
- **gathering 맵**: passive calendar와 `calendar_rules()`·`calendar_profile()`, `save_manifest(rule_id)`의 `calendar_profile`. SaveLoadTest는 `calendar_rule_id` hook과 `user://tests/ih120/` 접두사를 허용한다.
- **schema2 이관**: 항상 `calendar_test_v1`로 한다(`SaveCodec.MIGRATION_RULE_ID`). 빠른 프로필 manifest에서 v1은 CONTENT_MISMATCH다. 중간 v1 검증을 거친 뒤 calendar를 추가한다.
- **N 처리**: 요청은 QUEUED만 반환한다. 실행 결과는 다음 스텝에 한 번 보고한다. 거부 코드 대응은 검증 기록에 있다. 새 프로세스는 neutral 대기로 시작한다.
- **4.7.2 측정**:
  - max_fps 30/60/144에서 tick = 물리 스텝이다.
  - 400ms 정지 뒤에는 처리된 스텝만 진행하고 보충하지 않는다.
  - physics 30Hz에서는 정지한다.
  - tree pause 중 ALWAYS Controller는 tick하지 않는다.
  - process_mode는 deferred 호출을 막지 않으므로 서비스 가드가 필요하다.
- **수치**: 프로필 값은 검증용 제안이다. 농사, 생산 결산, 노화, 수면, 배속, 오프라인은 없다.
