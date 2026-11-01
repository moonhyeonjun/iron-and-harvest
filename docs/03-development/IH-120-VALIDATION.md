# IH-120 달력·계절·하루 경계 검증 — 2026-11-02

## 결론

Claude Code가 [CALENDAR 명세](../02-technical-design/CALENDAR.md)에 따라 다음을 구현했다.
- 정수 달력(CalendarRules·CalendarService)
- 교체 월드 밖의 실시간 어댑터(CalendarController)와 HUD
- 전용 calendar_test 장면
- schema2 필수 calendar와 0→1→2 이관
- 기존 맵의 passive calendar
- SaveCoordinator의 선택 외부 blocker와 보고 중 busy

검증 결과는 다음과 같다.
- 자동 AC-C01~15: **334검사 PASS**. 2회 반복 차이 0, 고아 0, 엔진 오류 0.
- 필수 표적 변이 8종: 모두 검출.
- 별도 프로세스 저장→불러오기: 확인.
- 깨끗한 worktree 공통 CI: **14단계 PASS**. 이동 360·상호작용 333·인벤토리 521·채집 347 그대로, 저장 531(schema2 조정 +2), 달력 334.

AC-C16 GUI 확인은 두 갈래다.
- 사용자 확인: 일부 항목을 실제 창에서 확인했다.
- Claude 조작 확인: 사용자의 "앞으로 GUI 테스트는 니가 직접 조작해서 해줘" 지시에 따라 실제 렌더 창을 스크립트로 조작하고 캡처를 확인했다. 전 절차(1~5)를 확인했다.

사용자가 직접 확인하지 않은 항목은 아래에 구분해 적었다. IH-120은 Codex 후속 검토를 위해 **review**이며, ADR-018은 **Proposed**를 유지한다.

수치(14일×4계절, 36000tick/하루, 60Hz, 06:00 시작, 빠른 프로필 2일·120tick)는 검증용 제안이며 제품 밸런스가 아니다. 농사, 생산 결산, 노화, 수면, 배속, 오프라인 보상, Cloud, 월간 국가는 구현하지 않았다.

## 환경·기준

- macOS 13.4 / Apple M1, Godot 4.7.2 stable official Standard, Compatibility, physics 60Hz.
- 기준 develop `2e62a15`. 게임 코드는 `bb4d6fe` 이후 변경이 없었다.
- 브랜치 `feature/calendar-system`. 커밋:

| 커밋 | 내용 |
|---|---|
| `43dd607` | 규칙/서비스 |
| `5570197` | schema2 |
| `c6febb3` | passive 연결과 hook |
| `8ae36a8` | Controller/HUD/장면 |
| `177ff53` | runner와 CI |
| `b29c6b1` | HUD 레이어 |

- 시험 파일: runner는 `user://tests/ih120/runner_<pid>_<usec>/`만 쓰고 자기가 만든 고정 이름 파일만 지운다. GUI는 `user://tests/ih120/` 아래 전용 경로만 쓴다. 제품 `user://saves`는 없고, 기존 `ih112` GUI 파일(mtime 11-01 20:19/20:24/22:19)은 건드리지 않았다.

## 구현 파일

| 파일 | 내용 |
|---|---|
| `data/calendar/calendar_rules.json` | 두 프로필의 단일 원본 |
| `systems/calendar/calendar_rules.gd` | 정의 검증. 키·신뢰 ID·IH-112 숫자 계약(`SaveCodec.json_int`)·60Hz·계절 순서·한도. 독립 사본 |
| `systems/calendar/calendar_service.gd` | 상태 rule_id/day_index/tick_in_day/revision만 소유. 파생 날짜, 원자 전진(최대 하루), 읽기 전용 day_advanced 1회, 닫힘·정지·busy, restore |
| `scripts/calendar/calendar_controller.gd` | ALWAYS 노드, 물리 스텝당 현재 world 달력 1tick. 정지 사유 합성, P/N 새 누름, N pending, 보고 중 busy, `save_blocker` |
| `ui/calendar/calendar_hud.*` | 표시와 epoch/revision이 붙은 의도. layer 1 |
| `scenes/tests/calendar_test.tscn`, `scripts/tests/calendar_test.gd` | SaveLoadTest를 감싸고 Controller/HUD를 월드 밖에 둔다. `--fixture=calendar-boundary`, `--save-root=user://tests/ih120/...` |
| `tests/test_calendar.gd`, `tests/support/calendar_child.gd`, `tests/fixtures/save/schema3_future.json` | runner, 별도 프로세스, 새 미래 fixture |

기존 파일 변경:
- SaveCodec: schema2와 이관, `json_int`.
- SaveCoordinator: `is_busy`에 보고 중 포함, `set_external_blocker`와 setup 선택 인자, 후보 calendar close.
- gathering 맵: passive calendar 생성/채택/캡처/manifest/정지/close/save_blocker, `calendar_rules()`/`calendar_profile()`.
- SaveLoadTest: `calendar_rule_id` hook, ih120 접두사.
- 그 밖: `project.godot`의 `calendar_pause`(P)/`calendar_next_day`(N), `run_ci.py`와 Python 등록 테스트, IH-112 runner 예상값 조정.

## 4.7.2 관찰

- 물리 스텝마다 Controller `_physics_process`가 1회 실행된다. max_fps 30/60/144 각각 40스텝에서 tick 40 = 물리 스텝 40.
- 400ms 정지(OS.delay_msec) 뒤에는 처리된 물리 스텝 4개만큼만 진행됐다. 벽시계로 따지면 약 24tick이므로, 보충이 없음을 확인했다.
- `Engine.physics_ticks_per_second = 30`이면 `physics_hz` 사유로 정지하고, 60으로 되돌리면 재개한다.
- SceneTree.paused 중에도 ALWAYS Controller는 처리되지만 tick하지 않는다. 월드 노드는 멈춘다.
- process_mode만으로는 직접·call_deferred 호출이 막히지 않는다. 그래서 서비스의 suspended/busy 검사가 필요하다(AC-C06/C08에서 확인).
- 렌더 창 조작에서 InputEvent와 viewport push_input 클릭이 실제 버튼·패널·키 경로로 동작했다. 창 포커스는 true로 관찰됐다.

## AC별 결과

| ID | 결과 | 측정·관찰 | 주체 |
|---|---|---|---|
| AC-C01 정의 | pass (50) | 두 프로필 값이 정확하다. 반환 프로필과 서비스 사본을 수정해도 원본은 불변이다. 잘못된 정의 17종(키 누락·추가, 중복·비신뢰 ID, bool·1.5·"36000"·0·-1·2^53, 30Hz, 계절 순서·개수, 1440분, 10000년, 빈 목록, 루트 키)과 깨진 텍스트 4종을 거부한다 | 자동 |
| AC-C02 날짜 | pass (46) | 손으로 쓴 날짜 19행(기본·빠른 프로필 경계, 23:59/00:00/05:59/18:00, 9999년 겨울14일)이 일치한다. 23:59→00:00은 같은 day_index이고 이벤트가 없다. 상태 키는 4개뿐이다 | 자동 |
| AC-C03 전진 | pass (44) | 1·500·남은 시간·정확히 하루 전진, revision은 명령당 +1. 잘못된 인수 9종은 INVALID_AMOUNT, 오래된 revision은 STALE. 마지막 날 내부는 진행하고 다음 새벽은 NUMBER_OUT_OF_RANGE. revision 2^53-1, 두 번 close, 잘못된 restore 7종도 확인 | 자동 |
| AC-C04 경계·재진입 | pass (18) | 설치 후 1회 알림: completed 13(봄14) → 여름1, 읽기 전용, 재진입 BUSY, 반환값은 사본, 같은 revision은 STALE. 겨울2 → 2년 봄1. 장면에서는 경계 보고·day_advanced·coordinator 거부 보고 중 F5/F9/N/P가 모두 BUSY이고 파일·epoch 변화 0 | 자동 |
| AC-C05 어댑터 | pass (16) | 위 4.7.2 관찰과 같다. N이 있는 스텝은 다음 새벽만 진행하고 자연 tick을 더하지 않는다(revision +1). 30Hz는 정지 | 자동 |
| AC-C06 정지 합성 | pass (16) | 아래 정리 참조 | 자동 |
| AC-C07 다음새벽 | pass (12) | 아래 정리 참조 | 자동 |
| AC-C08 수명 | pass (14) | 아래 정리 참조 | 자동 |
| AC-C09 schema2 왕복 | pass (14) | 기본·빠른 프로필 모두 비초기 상태(day 2, tick>0)를 저장→다음 날→불러오기 하면 calendar·재고가 같다. P 정지 유지, 이벤트 0, HUD 날짜 일치. 이후 시간과 경계 1회. 별도 프로세스: 저장(day 2) → 종료 → 다른 프로세스 불러오기가 같고 이벤트 0 | 자동 |
| AC-C10 이관 | pass (24) | 아래 정리 참조 | 자동 |
| AC-C11 codec 실패 | pass (44) | 아래 정리 참조 | 자동 |
| AC-C12 세션·복구 | pass (14) | 아래 정리 참조 | 자동 |
| AC-C13 호환·회귀 | pass (10) | gathering_test·save_load_test 맵은 30스텝과 P/N 뒤에도 day0/tick0/rev0이다. 트리를 떠나면 calendar close. 기존 suite 수와 의도 유지(아래 명령) | 자동 |
| AC-C14 반복 | pass (7) | 빠른·기본 프로필 각 4년(32일/224일)을 하루 두 명령으로 진행. 독립 중첩 표와 순서·completed가 일치하고 revision 64/448, 5년 봄1에서 끝난다. 2회 측정 15종 차이 0 | 자동 |
| AC-C15 실패 감지 | pass (5) + 변이 8 | `--inject-failure` exit 1. 고아 0, 엔진 오류 0, 시험 루트 정리. 변이는 아래 | 자동 |
| AC-C16 GUI | **Claude 조작 확인 완료 / 사용자 확인 일부** | 아래 'GUI' | 사용자(일부)·Claude |

**AC-C06 정지 합성**
- P: 시간이 정지하고 걷기(x -48)와 채집(+1)은 된다. 게이트는 그대로다.
- P + 가방: 가방을 닫아도 P 정지가 유지된다.
- 가방만 열면 정지하고, 닫으면 재개한다. 강제 닫기는 없다.
- 포커스 out+P → 복귀 시 neutral → P만 남는다.
- suspended: 직접·deferred advance 모두 BUSY이고 tick 0.
- tree pause + P → tree를 재개해도 P가 남는다. tree pause만 있어도 tick 0.
- P만 걸린 상태에서 F5는 성공한다.

**AC-C07 다음새벽**
- N 누름 + echo 4는 경계 1. 한 스텝에 두 번 누르면 [BUSY, OK].
- pending 중 F5/F9는 BUSY이고 파일 불변.
- P 취소는 CANCELLED, 포커스 왕복은 FOCUS_LOST, 이전 epoch는 STALE_SESSION, 이전 revision은 STALE_REVISION. 날짜 변화 0.
- 불러오기 뒤 이전 epoch HUD 버튼은 STALE_SESSION이고, 새로 누르면 정상이다.

**AC-C08 수명**
- HUD free/queue_free/remove_child 각각 뒤에도 시간·P·N·F5·F9가 동작한다.
- 보고 중 HUD를 해제해도 다음 N이 정상이다.
- staging 중에는 이전 달력 tick 0, 후보는 suspended(직접 advance BUSY). publish 뒤 이전 달력은 CLOSED.
- coordinator 제거 뒤에는 tick 0, 키 무시, 오류 0.

**AC-C10 이관**
- v1 → 2: calendar 기본값(rule calendar_test_v1/0/0/0), migrated_from 1. generation 3, 재고·revision·facing이 v1 원문과 같다.
- v0 → 1 → 2: facing down, generation 2.
- v1 결함은 먼저 거부한다: 키 누락, facing, 맵 ID, 수량, calendar가 들어 있는 v1·v0.
- 빠른 프로필 manifest에서 v1은 CONTENT_MISMATCH(암묵 이관 없음).
- 불러오기는 파일 바이트를 쓰지 않는다. 다음 저장은 b4 schema2이고 v1 은행은 보존된다.
- 장면: v1 불러오기 → '1년 봄 1일 06:00'과 재고, 이벤트 0.

**AC-C11 codec 실패**
- 정상 schema2가 통과한다.
- calendar 결함 13종을 기대 코드로 거부한다: 없음, 키 오타, 추가 필드, 1.5, bool, 문자열, tick 36000, 마지막 날 초과, 음수, 2^53, 빠른·미지 rule, 비객체.
- schema3은 UNSUPPORTED, content 2는 CONTENT_MISMATCH.
- fixture: schema3_future는 UNSUPPORTED, IH-112 schema2_future는 INVALID_SAVE, content2는 CONTENT_MISMATCH.
- 해시를 유지한 채 바꾼 calendar는 CHECKSUM_MISMATCH(구조 오류와 구분).

**AC-C12 세션·복구**
- A v1(3세대)/B v2(4세대, day5)에서 최신은 B(day5), 명시 복구는 A(이관, day0).
- 실패 4종(잘못된 calendar 파일 CORRUPT_SAVE, 막힌 위치 INVALID_POSITION, 포커스 out-in FOCUS_LOST, 후보 제거 REMOVED)에서 같은 calendar 인스턴스·상태·재고·epoch를 유지하고 정지가 해제된다.
- 성공하면 inventory·gather·calendar가 함께 새로 바뀌고 이전 것은 닫힌다.

## IH-112 runner 예상값 변경(schema2)

검사 의도는 유지하고 예상값만 바꿨다. 529 → 531검사(+2는 schema2_future 경계 검사).

| 위치 | 이전 | 변경 |
|---|---|---|
| AC-S02 | "schema 1.0 → OK" | "schema 2.0 → OK" |
| AC-S06 미래 은행 행, AC-S07 미래 사례 | schema2_future | schema3_future. 보존된 schema2_future는 INVALID_SAVE 사례로 별도 추가 |
| AC-S07 v0 이관 | schema 1 | schema 2와 기본 calendar |
| AC-S07 다음 저장 | v1 | schema 2 |

## 명령·결과

| 명령 | 결과 |
|---|---|
| `python3 tools/godot.py --headless --import` | exit 0, 오류 0. 새 `.uid` 커밋 |
| `python3 tools/godot.py --headless --script res://tests/test_calendar.gd` | exit 0, RESULT: PASS, 334검사, 약 28초. 최종 코드 `b29c6b1`에서도 334 PASS |
| 같은 명령 `-- --inject-failure` | exit 1, RESULT: FAIL (1) |
| `python3 tools/godot.py --headless --script res://tests/test_save_load.gd` | exit 0, 531검사 |
| 깨끗한 worktree `python3 tools/run_ci.py`(`177ff53`) | exit 0, 14단계 PASS. 이동 360(124.0초), 상호작용 333(29.7초), 인벤토리 521(9.9초), 채집 347(22.7초), 저장 531(31.2초), 달력 334(27.5초), 누수 경고 0 |

로그는 `build/ih-120/`(Git 무시)에 있다: run1/run2/run_final, inject, save_*, mutations, ci, gui.

## 표적 변이

각 변이 뒤 runner를 실행하고 원복했다. 구문 오류는 모두 0이다.

| 변이 | 결과 |
|---|---|
| m1 경계를 한 tick 늦게(`>`) | FAIL 17(C03/C04/C05/C14/C15) |
| m2 서비스 busy 가드 제거 | FAIL 4(C04 재진입) |
| m3 modal 정지 사유 제거 | FAIL 2(C06) |
| m4 pending N과 자연 tick을 같은 스텝에 모두 실행 | FAIL 2(C05) |
| m5 restore 대신 새 게임 달력 | FAIL 8(C09/C12) |
| m6 v0 → 최신 schema 바로(중간 v1 검증 생략) | FAIL 2(C10) |
| m7 schema2 calendar 선택 허용 | FAIL 6(C10/C11) |
| m8 서비스 suspended 가드 제거 | FAIL 4(C06/C08) |

## AC-C16 GUI

### 사용자 직접 확인(빌드 `177ff53`, 일부)

- 창 1(기본, `user://tests/ih120/gui`): 1)·2)·4) "정상".
  - 시작 06:00과 진행, P 정지 중 이동, 가방·살펴보기 정지, P + 가방 유지, Cmd+Tab 왕복에 날짜 점프 없음.
  - P → F5 → N → P → F9 복원과 정지 유지, 재개 뒤 N 1회, 이동·채집·전송.
  - 로그: 저장 1세대, 불러오기, 경계 로그 정상, 오류 0, exit 0.
- 창 2(재시작): "정상". 로그상으로는 새 게임 상태를 F5(2세대)로 먼저 저장한 뒤 복구 버튼으로 창 1의 1세대를 불러왔다(F9로 1세대를 바로 불러온 것은 아니다). 오류 0.
- 창 3: **무효**. 실행 명령 오류로 빠른 프로필이 아니라 기본 프로필로 열렸다(아래 관찰). 다시 띄운 창 A(빠른 프로필, `gui_boundary`)에서 사용자가 "정상"이라고 답했다. 로그상 경계 28회(120tick 간격), 오류 0.
- 창 B(v1 이관)와 C(손상 복구): 사용자가 "정상"이라고 답했지만 창이 약 8초·5초만 열려 있었고 불러오기 로그가 없다. 그래서 **사용자 확인으로 기록하지 않는다.** 다시 띄운 창 B에서 사용자가 "앞으로 GUI 테스트는 니가 직접 조작해서 해줘"라고 지시해 창을 닫았다.

### Claude 조작 확인(빌드 `b29c6b1`, 사용자 지시)

방법: 렌더링되는 실제 창(헤드리스 아님)에서 임시 driver(`game/build/review/gui_driver.gd`, 제품 소스 아님)를 실행했다.
- 키: Input.parse_input_event + flush.
- 버튼: viewport 마우스 클릭.
- 각 단계에서 렌더된 화면 캡처(`build/ih-120/gui/claude/*.png`)와 관찰 JSON을 남기고, Claude가 캡처를 열어 확인했다.

OS 키보드·실제 Cmd+Tab·조작감은 이 방법으로 대체되지 않는다. 사용자 육안 확인과 구분한다. 창 포커스는 모든 단계에서 true였다.

| 절차 | 결과 |
|---|---|
| 1 기본 시작·진행·P | 06:01 → 3초 뒤 06:08. P 정지 중 걷기 +48, revision 변화 0. HUD에 프로필·`claude_gui_final` 경로·'하루는 06:00에 바뀝니다' 표시 |
| 2 가방·P 조합 | 가방 열림: 사유 modal, tick 0. 닫으면 재개. P 상태에서 가방 열고 닫아도 user_paused 유지. HUD layer 수정 뒤 가방 패널이 HUD에 가려지지 않음(캡처 d09) |
| 3 빠른 프로필 | 자연 경계로 '1년 여름 1일 06:00'(day 2)과 '2년 봄 1일 06:00'(day 8) 캡처, 경계 9회. P 정지 중 tick 0. N을 30프레임 눌러도(echo) 하루, 경계 1회 |
| 4 저장·불러오기 | P → F5(1세대, 06:11, x 176) → 재개·N·이동 → P → F9: calendar·날짜 문자열 동일, 위치 오차 0, P 유지. 재개 뒤 N 경계 1회. 채집 +1. 보관함 버튼·슬롯·'1개 옮기기' 실제 클릭으로 보관함 목재 +1. 2세대 저장 뒤 **새 프로세스**에서 P → F9: 2세대(1년 봄 2일 06:00) 복원 |
| 5a v1 이관(`gui_migration`) | F9 → 3세대, '1년 봄 1일 06:00', 위치 (228.12, 360) 오른쪽, 가방 목재 6·산열매 3, 보관함 목재 3, 나뭇가지 5, 산열매 0(소진). 파일 SHA 앞부분 `73fb9a63…` 그대로 |
| 5b 손상 복구(`gui_recovery`) | 준비 기준은 다음과 같다(창 열기 전 SHA 기록, 사전 손상은 같은 corrupt-latest fixture를 헤드리스로 적용). F9 → RECOVERY_AVAILABLE(a=valid, b=CHECKSUM_MISMATCH). 같은 세계·달력·위치(오차 0). '이전 1세대로 복구' 실제 클릭 → 1년 봄 4일 06:00, (300,410) 왼쪽, 가방 목재 9, 보관함 0. 파일 SHA 불변 |

5b 준비 기준:
- 1세대 A: 봄 4일 06:00 tick 1 rev 16, (300,410) 왼쪽, 목재 9, SHA `326a6a50…`
- 2세대 B: 봄 11일, (520,560) 오른쪽, 보관함 목재 4, 산열매 3, 손상 후 `1c25ded8…`

로그(`build/ih-120/gui/claude/*.log`): 다섯 실행 모두 exit 0, 엔진 오류 0.

### 관찰: 사용자 창 3과 이전 '창이 normal로만' 현상의 원인

Claude가 창을 연속으로 띄울 때 `args="-- --fixture=..."`를 따옴표 없이 `$args`로 넘겼다. zsh는 이를 단어로 나누지 않아 Godot가 한 개의 인자로 받았고, 사용자 인자로 인식되지 않았다. 그 결과 fixture가 적용되지 않았다. 같은 명령을 직접 실행하면 정상 적용됨을 재현했다(GUI·헤드리스 모두).

다음 현상도 같은 원인으로 설명된다. 게임 결함이 아니라 시험 실행 절차 문제이며, 이후에는 인자를 직접 적는다.
- IH-111 GUI의 "다 normal로만 3개창이 떴다"
- IH-112 GUI 첫 창 3의 fixture 미적용

### 발견 사항

- **BUG-012(IH-112, P3, open)**: SaveUI(layer 4)가 가방·보관함 패널(layer 3) 오른쪽 위를 가린다(캡처 d09의 보관함 열 일부). IH-120 범위 밖이라 수정하지 않았다. 달력 HUD는 같은 문제를 layer 1로 고쳤다.

## 구현 차이·결정

1. **N 결과 보고**: request_next_day는 QUEUED를 반환만 하고 보고하지 않는다. 실행 결과(OK/거부)는 다음 스텝에서 한 번 보고한다. 즉시 거부(BUSY 등)는 즉시 한 번 보고한다.
2. **정지 사유 코드**: N 거부 코드는 다음과 같다.
   - removed/no_service: REMOVED
   - focus: FOCUS_LOST
   - neutral/not_ready/physics_hz: NOT_READY
   - user_paused: CANCELLED
   - 그 밖: BUSY
3. **새 프로세스**: neutral 대기로 시작하고, 첫 스텝에 P/N이 눌려 있지 않으면 해제한다. 실제 OS 포커스는 알림으로만 갱신한다(기본 true).
4. **보고 중 busy**: 컨트롤러 보고는 중첩돼도 바깥 보고가 끝날 때까지 busy다. 처음 구현에서 중첩 보고가 플래그를 풀어 P가 통과하는 결함을 runner가 잡았고, 커밋 전에 고쳤다.
5. **한도**: 마지막 날 다음 새벽은 NUMBER_OUT_OF_RANGE다. 컨트롤러는 그 서비스에 대해 'limit' 사유로 한 번 표시하고 멈춘다.
6. **schema2 이관 규칙 ID**: 이관은 항상 `calendar_test_v1`(MIGRATION_RULE_ID)이다. 빠른 프로필 루트에서는 v1 파일이 CONTENT_MISMATCH다.
7. **SaveCoordinator**: `is_busy()`가 보고 중(`_emitting`)을 포함한다. 외부 blocker는 `set_external_blocker`와 setup 선택 인자로 둔다. 기본은 비어 있다.
8. **HUD layer 1**: 모달 패널보다 아래에 그린다. 실제 창 캡처로 발견해 `b29c6b1`에서 고쳤다.
9. **정의 형식**: JSON을 쓴다(int Resource 암묵 변환 DEBT-004를 피하기 위함). 파일 경로는 맵 adapter가 읽고 도메인은 텍스트만 받는다.

## 미검증·남은 범위

- 사용자가 직접 실행하지 않은 GUI 항목(5a/5b 등)은 Claude 조작 확인만 있다. OS 키보드·실제 앱 전환·조작감은 사용자 창 1의 확인뿐이다.
- Windows/Linux GUI, 전원 차단은 미확인이다. 제품 밸런스와 월간·노화는 TBD다.
- IH-120 done, ADR-018 Accepted, v0.4.0 판정은 Codex 후속 검토 대상이다.

## 통합 기록

PR·CI·merge 결과는 PR 이력과 후속 기록에 남긴다.
