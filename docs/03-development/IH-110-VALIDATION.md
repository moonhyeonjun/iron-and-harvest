# IH-110 아이템 정의와 인벤토리 검증 — 2026-11-01

**후속 판정(2026-11-01): Codex가 14302e5에서 기존 전체 CI 통과를 확인했으나 BUG-005/006을 추가 재현하여 IH-110을 review로 재개했다. 아래 수정 검증과 [PR #22](https://github.com/moonhyeonjun/iron-and-harvest/pull/22) 통합으로 **done**에 복귀했다. [검토·수정 프롬프트](IH-110-REVIEW.md)를 따른다. 아래 Claude의 최초 검증·통합 기록은 당시 증거로 보존한다.**

## BUG-005/006 수정 검증 (2026-11-01, Claude Code)

브랜치 `fix/inventory-lifecycle-and-id-validation` ← develop `65cda09`. 커밋: `5004419` 실패 회귀, `fb5cd0c` 수정, `a714c5a`·`8dfe8bb` 검사 보완. 환경은 macOS 13.4 / M1, Godot 4.7.2 Standard. 로그는 `build/ih-110-fix/`(Git 무시)에 있다.

수정 내용:
- **BUG-005** (`inventory_controller.gd`): `_dependency_lost()`가 조율자·Player·UI(유효·트리 안·삭제 예약 아님)와 서비스(close·카탈로그)를 확인한다. 이 확인은 열기 콜백 직후(`_still_openable`), OPEN 중 매 물리 틱, 보기 전환 전, 이동 요청 전에 수행한다. 열기는 1회 거부(REMOVED/SERVICE_UNAVAILABLE)되고, 열린 가방은 1회 닫히며 자기 게이트 해제와 interaction 복구가 1회씩 일어난다. notice·결과·화면 갱신은 살아 있는 UI에만 보낸다. 닫을 때 트리에서 분리만 된 UI는 초기화하고, 해제/삭제 예약된 UI는 호출하지 않는다.
- **BUG-006** (`item_catalog.gd`): `is_valid_id`가 정규식 `$` 대신 모든 문자를 검사한다. trim·소문자화 없음. 카탈로그 정의, 재고/소유자 등록, add/count/remove/transfer 인자, snapshot ID에 같은 규칙이 적용된다.

| 명령 | 빌드 | 종료 | 결과 |
|---|---|---:|---|
| Codex 재현 진단(IH-110-REVIEW의 gdscript 블록) | `65cda09` | 1 | 위반 3(수명 2, ID 1) |
| 같은 재현 | `fb5cd0c` | 0 | 위반 0. 열기 결과 REMOVED / SERVICE_UNAVAILABLE, state CLOSED, 게이트 미소유, 이동 가능 |
| `test_inventory.gd` | `5004419`(회귀만 추가) | 250 | `free_ui` 열기 사례에서 signal 11 충돌 |
| 같은 runner(`free_ui` 임시 제외, 미커밋) | `5004419` | 1 | 25검사 실패: ID 사례(N01/02/09)와 수명 사례 6종(N12), 트리 밖 UI 엔진 오류 |
| 같은 runner | `8dfe8bb` | 0 | 521검사 PASS(N01 98, N02 156, N09 64, N12 40 등), 2회 측정54종 차이0, 고아0, 엔진 오류0 |
| 같은 runner `-- --inject-failure` (`run_step`) | `8dfe8bb` | 1 | nonzero exit, engine error in log, missing completion marker |
| 표적 변이 5종 | `8dfe8bb` 변형 | 모두 비0 | 열기 재검사 제거→충돌(250), 틱 검사를 Player만→N12, 이동 요청 수명 검사 제거→N12, 유효하기만 한 UI에 notice→N13(엔진 오류), 정규식 `$` 복귀→N01/02/09 |
| `python3 tools/run_ci.py` (깨끗한 worktree) | `8dfe8bb` | 0 | 11단계 PASS. 이동 360(123.9초), 상호작용 333(29.6초), 인벤토리 521(9.8초), 각 엔진 오류0 |

새 회귀:

| AC | 사례 | 결과 |
|---|---|---|
| AC-N01 | 정의 item_id 16종(LF, CRLF, 중간·앞 개행, 앞/뒤/중간 공백, 탭, 비ASCII, 한글, 대문자, 숫자/밑줄 시작, 하이픈, 빈 값, 65자) | 모두 is_valid_id=false, 카탈로그 전체 거부. 1자·64자·`seed_wheat`·`a0_9`는 유효 |
| AC-N02 | 같은 ID로 재고·소유자 등록, add, count | 모두 INVALID_ARGUMENT, 기존 재고·이벤트 불변. `bag\n` 조회도 INVALID_ARGUMENT로 다른 ID와 섞이지 않음 |
| AC-N09 | snapshot의 inventory_id/owner_id/item_id에 개행·공백·비ASCII | INVALID_SNAPSHOT, 활성 재고 불변 |
| AC-N12 | 열기 콜백 중 UI queue_free/remove_child/free, service.close | 거부 1회, opened 0, CLOSED, 게이트 미소유, interaction 복구, Player 이동 가능, 재고·이벤트 불변 |
| AC-N12 | 보관함 OPEN 중 같은 4종 + 같은 프레임 늦은 이동 요청 → 물리 틱 → 보기 전환 | 틱 검사로 1회 닫힘(REMOVED/SERVICE_UNAVAILABLE), 늦은 요청 재고 변경 0, 보기 전환 거부, 게이트 해제 |

검사 보완 기록: 처음에는 OPEN 사례가 가방 보기에서 실행돼, 늦은 요청이 수명 검사보다 먼저 WRONG_VIEW로 막혔다. 또 같은 프레임 보기 전환이 먼저 닫아 버려 틱 검사가 따로 검증되지 않았다. 변이 m2/m3가 통과한 것으로 이를 발견했고, 보관함 보기와 틱 뒤 전환 순서로 고쳤다(`a714c5a`, `8dfe8bb`). 이 과정에서 하나 더 확인했다. 변이로 runner의 의존 스크립트에 파싱 오류가 나면 Godot이 runner를 불러오지 못하고 **종료 0**으로 끝난다. 공통 CI는 `Parse Error`/`ERROR:` 로그와 `RESULT: PASS` 마커 누락으로 이를 실패 처리하므로 CI 판정에는 영향이 없다. 변이 실행 판정에는 마커 확인을 추가했다. 기존 IH-110 변이 10종은 모두 AC 실패와 함께 종료 1이었으므로 이 문제의 영향을 받지 않았다.

GUI: **사용자**가 빌드 `8dfe8bb`, macOS 13.4에서 ① 가방 I 열기/닫기·한글·첫 칸 포커스·닫은 뒤 이동, ② 보관함 1개/스택 양방향 이동·합계 목재 15, ③ 살펴보기 중 I 거부·가방 중 E 무반응·닫은 뒤 E 정상, ④ 포커스된 버튼에서 I/Escape·Cmd+Tab 왕복·이동 키 유지 닫기를 확인하고 "1~4 모두 정상"으로 응답했다. 응답 시점까지 GUI 로그 오류는 0이었다. UI 삭제·서비스 종료·끝 개행 ID는 정상 화면 조작으로 만들 수 없어 자동 검사로만 확인했다.

판정: **done**. [PR #22](https://github.com/moonhyeonjun/iron-and-harvest/pull/22): `5f8bb51` → develop, merge `cbb836b40f37a0f29173e541005529229ff037e4`(병합 전 mergeable_state=clean, base `65cda09`, 보호 우회 없음). [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41278706636/job/124766026102) success: Ubuntu에서 11단계 PASS, 새 회귀 결과가 로컬과 같다. [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41278935113/job/124766685853) success. 통합 tree는 `5f8bb51`과 동일하다. main·태그·릴리스는 변경하지 않았다.

## 결론

Claude Code가 [INVENTORY 명세](../02-technical-design/INVENTORY.md)에 따라 아이템 정의·카탈로그·고정 슬롯 재고·원자 명령·revision·snapshot과 가방/보관함 UI·조율자·유한 시험 맵을 구현했다. AC-N01~13 자동 검사는 375검사 PASS다. 기존 이동 360검사와 상호작용 333검사 회귀도 같은 로컬 CI에서 통과했다. AC-N14 GUI는 사용자가 실제 창에서 확인했다. 변이 10종과 엔진 오류 전용 변이도 모두 검출됐다.

IH-110 상태는 **done**이다. [PR #19](https://github.com/moonhyeonjun/iron-and-harvest/pull/19) 필수 CI 성공 후 develop에 통합하고 원격 CI를 확인했다(아래 통합 기록). 12슬롯·7품목·스택10은 검증용 제안이며 제품 밸런스가 아니다. ADR-015는 **Proposed**를 유지한다. 채집·소비·장비·제작·드롭·예약·파일 저장·통치·범용 전역 잠금은 구현하지 않았다. IH-102 상자는 살펴보기 전용 그대로이고 `try_begin`/`can_interact`는 아무것도 지급하지 않는다.

## 환경·대상

- macOS 13.4, MacBook Air M1, Godot `4.7.2.stable.official.ed1daf0bf` Standard, Compatibility(OpenGL 4.1 Metal).
- 브랜치 `feature/inventory-system` ← develop `3803bc7`. 커밋: `b7efab6` 도메인·정의, `05cd2b3` 조율자·UI·맵, `2a085e2` runner·fixture, `311a742` CI 등록, `025c863` 시험 창 제목.
- 사용자 미추적 `AGENTS.md`는 수정·커밋하지 않았다. 원시 로그는 Git 무시 경로 `build/ih-110/`에 있다.

## 정의 형식 비교와 선택 (AC-N01)

같은 wood 정의를 `res://data/items/wood.tres`(ItemDef)와 `res://tests/fixtures/inventory/wood.json`으로 두고 고정 엔진에서 읽었다.

| 항목 | .tres ItemDef | JSON |
|---|---|---|
| stack_limit 타입 | int(스크립트 타입 유지) | `JSON.parse`가 float 10.0을 돌려줌. 정수 여부를 따로 검사해야 함 |
| 필드 누락/오타 | export 기본값으로 로드됨. 그래서 ItemDef 기본 stack_limit을 무효 값 0으로 두어 카탈로그 검증에서 걸리게 함 | 키 집합을 직접 검사해야 함(`wood_missing_name` 거부) |
| 숫자 형식 오류 | 타입 있는 속성이라 문자열이 int로 저장되지 않음 | `10.5`, `"10"`을 별도 규칙으로 거부해야 함 |
| 문법 오류 | 에디터/로더 오류 | `parse line 1: Expected key`로 거부 |
| 참조/아이콘 | Texture2D 참조 가능(이번엔 null) | 경로 문자열 해석이 따로 필요 |
| 공유 캐시 | `load()`가 같은 객체를 공유함. 카탈로그가 스칼라를 복사해 격리하고 AC-N02로 검증 | 해당 없음 |

엄격 변환을 거친 JSON 레코드는 .tres 레코드와 같았다. 선택은 **typed Resource(.tres) + 명시 catalog.tres**로, 런타임은 이것만 읽는다. JSON은 테스트 fixture에만 있다. 근거는 엔진 타입 보존, 에디터 편집, 리소스 참조 가능성과, JSON이 매번 숫자·키·참조 검증을 별도로 구현해야 한다는 실측이다. 공유 캐시 위험은 스칼라 복사로 막았다.

7종 정의는 ResourceSaver로 생성했다. 처음 생성할 때 `tool_axe.tres`에 stack_limit이 빠졌다. 기본값(당시 1)과 같은 값은 저장되지 않기 때문이다. 이후 기본값을 0으로 바꾸고 다시 생성해 모든 파일이 한도를 명시하는지 검사한다.

## 실행 명령·결과

| 명령 | 빌드 | 종료 | 결과 |
|---|---|---:|---|
| `python3 tools/godot.py --headless --import` | 각 단계 | 0 | 오류/경고 0 |
| `python3 tools/godot.py --headless --script res://tests/test_inventory.gd` | `2a085e2`, `025c863` | 0 | 375검사 PASS, 2회 측정45종 차이0, 고아0, 엔진 오류0, 약8초 |
| 같은 runner `-- --inject-failure` (`run_step` 판정) | `311a742` | 1 | nonzero exit, engine error in log, missing completion marker |
| 변이 10종(아래) | `2a085e2` 변형 | 모두 1 | 각 변이를 해당 AC가 검출 |
| 엔진 오류 전용 변이(UI notice에서 null 호출) | `311a742` 변형 | 1 | 다른 검사는 통과했지만 Logger가 SCRIPT ERROR 8건 수집(AC-N13 실패), `run_step`도 engine error 판정 |
| `python3 -m unittest discover -s tests -p 'test_*.py'` | `311a742` | 0 | 19개 OK(3개 gameplay suite 등록·순서·마커) |
| `python3 tools/run_ci.py` (깨끗한 worktree) | `311a742` | 0 | 11단계 PASS. player 124.1초(360검사), interaction 30.7초(333검사), inventory 7.6초(375검사), 각 엔진 오류 0 |
| `python3 tools/godot.py res://scenes/tests/inventory_test.tscn` (GUI) | `025c863` | 0 | 사용자 조작 후 정상 종료, 로그 오류0 |
| 같은 명령 `-- --fixture=full` (GUI) | `025c863` | 0 | 사용자 조작 후 정상 종료, 로그 오류0 |

변이 검사(결함 1개씩, 모두 종료1):

| 변이 | 검출 AC |
|---|---|
| transfer가 목적지 공간 확인 전에 원본을 차감 | N07, N10, N13 |
| add가 NO_SPACE에서 부분 적재 유지 | N04, N07, N10, N13 |
| transfer가 목적지 revision 무시 | N07, N08 |
| 카탈로그 대신 공유 ItemDef의 limit을 직접 읽음 | N02 |
| 변경 신호 중 쓰기 잠금 없음 | N08 |
| snapshot이 내부 스택 Dictionary를 공유 | N02, N09 |
| decode가 float 수량 허용 | N09 |
| 가방 열림 중 E를 삼키지 않음 | N11 |
| opening 중 취소 래치 무시 | N12 |
| UI 이동 요청의 session 검사 생략 | N10 |

## AC별 결과

| ID | 결과 | 측정·관찰 | 확인 주체 |
|---|---|---|---|
| AC-N01 | pass | catalog 순서 wood·stone·iron·wheat·berry·seed_wheat·tool_axe, 레코드 값 일치, 7개 .tres 모두 stack_limit 명시. JSON 비교는 위 표. 잘못된 카탈로그 11종(null·중복·빈·대문자·숫자 시작·65자 ID, 빈 name_key/fallback, 미지 category, limit 0/10000)이 원인과 함께 전체 거부되고, 그 서비스는 등록·명령 모두 INVALID_CATALOG. null catalog도 차단 | 자동 |
| AC-N02 | pass | 빈 12칸 등록, capacity 0/257/12.0/"12"/true/-1과 잘못된 ID 거부, 중복 ID는 덮어쓰지 않음. snapshot 사본 수정은 내부 불변. 캐시된 wood.tres를 limit 99·이름 변조해도 서비스는 10 단위로 `[wood10, wood8]`을 쌓고 이름은 '목재' 그대로. 두 서비스·두 재고 독립 | 자동 |
| AC-N03 | pass | `[wood8,stone10,-]+wood5 → [wood10,stone10,wood3]`, `[wood4,-,wood9,stone10,-]+wood8 → [wood10,wood1,wood10,stone10,-]`, 도끼2 → 각각 별도 칸, berry25 → 10/10/5 | 자동 |
| AC-N04 | pass | 꽉 참·wood9+2(여유1)=NO_SPACE(부분 적재 없음). 수량 0/음수/상한+1, float/bool/문자열 수량, float revision, 잘못된 ID 형식=INVALID_ARGUMENT, gold=UNKNOWN_ITEM, stale, 없는 재고, 결정 순서 2건, close 후 CLOSED. 16건 모두 슬롯·revision·이벤트 불변 | 자동 |
| AC-N05 | pass | `[wood4,wood3]-5 → [-,wood2]`, 정확히 전량 제거 후 0 스택 없음. 부족 8·미소지 iron=INSUFFICIENT_QUANTITY, gold=UNKNOWN_ITEM은 불변이고 다른 품목도 차감 안 됨 | 자동 |
| AC-N06 | pass | 양방향 3회(부분 슬롯, 목적지 여러 스택 분산, 원본 전량, 도구) 모두 품목별 총합 보존, 양쪽 revision +1, 이벤트 1회(`[bag, store]` 오름차순). 콜백 안에서 두 재고의 최종 상태를 관찰 | 자동 |
| AC-N07 | pass | NO_SPACE·EMPTY_SLOT·INVALID_SLOT(-1/범위 밖)·SAME_INVENTORY·없는 원본/목적지·슬롯 수량 초과(다른 칸엔 충분해도 INSUFFICIENT_QUANTITY)·float 슬롯·원본/목적지 stale·우선순위 2건, 13건 모두 양쪽 불변 | 자동 |
| AC-N08 | pass | 같은 기대 revision 재전송·목적지만 바뀐 경우=STALE_REVISION, 새 revision 명령은 성공. 변경 콜백 안 transfer/add=BUSY, 읽기=OK. 이후 자동 재시도 0 | 자동 |
| AC-N09 | pass | 메모리 왕복에서 배치·수량·revision 동일. 값은 String/int/null/Array/Dictionary만 포함. 손상 14종(키 누락/추가, 길이, capacity, ID, 미지 아이템, 수량 0/한도 초과/float, revision 음수/float, 스택 키 추가, 비Dictionary)은 decode·등록 모두 INVALID_SNAPSHOT이고 활성 상태 불변. 유효 snapshot도 같은 ID 재고를 덮어쓰지 않음 | 자동 |
| AC-N10 | pass | 맵이 fixture를 1회 등록(revision 0). I로 열고 닫기·재열기 후 지급 없음. HUD 버튼(마우스)으로 보관함 열기, 키보드 Enter로 bag 0칸 선택 후 1개 이동(wood7/wood8), 마우스로 보관함 스택 이동(bag `[wood10,stone10,tool_axe1,wood5]`), 합계 HUD '목재 15'. 옛 session=STALE_SESSION, 다른 선택=SELECTION_CHANGED, 옛 revision=STALE_REVISION, 모두 불변·재시도 없음·안내 표시. 꽉 찬 보관함=NO_SPACE 안내, 양쪽 불변. UI 스크립트에 서비스/게이트 접근 없음 | 자동 + 사용자 GUI |
| AC-N11 | pass | 살펴보기 ACTIVE·RESOLVING 중 I=INTERACTION_BUSY(살펴보기 유지). 같은 프레임 E→I는 E를 DISABLED로 폐기하고 가방만 열림. 가방 중 E·I echo 무반응, Escape 1회 닫힘·반복 무해, 게이트·interaction 복구. 포커스된 Button에서 I/Escape 각 1회 닫힘. I 한 번에 열기 1회 | 자동 + 사용자 GUI |
| AC-N12 | pass | 걸으며 I: 즉시 정지, 열린 동안 이동 0, 키 유지 중 닫아도 0, 해제 후 재입력 16.0. A+D 유지 중 닫으면 둘 다 뗄 때까지 차단. focus out=FOCUS_LOST 닫힘, focus in 재열림 없음. ready 전 알림·미연결 조율자=NOT_READY. opening 콜백 중 focus out/close 요청은 열기를 취소(게이트 미획득, interaction 복구). 닫힌 뒤 늦은 요청=STALE_SESSION. 조율자 제거=REMOVED(남은 Player 복구), Player 제거=다음 틱 REMOVED, 열린 채 맵 해제 오류 0 | 자동 + 사용자 GUI |
| AC-N13 | pass | seed 1101, 400명령(OK 133, INSUFFICIENT 161, NO_SPACE 67, STALE 36, EMPTY 3): 매 명령 독립 counts 모델·슬롯 불변식·revision·이벤트 확인, 같은 seed 2회 최종 상태·코드 동일. suite 2회 측정45종 차이0, 고아0, 키 잔류0, 엔진 오류0. 실패 주입 종료1, CI 등록, 기존 회귀 통과 | 자동 |
| AC-N14 | pass | 아래 GUI 확인 | 사용자 |

## AC-N14 실제 GUI 확인

- 확인 주체: **사용자**(실제 창·키보드·마우스·육안), 2026-11-01, 빌드 `025c863`, macOS 13.4 / M1, Godot 4.7.2 Standard.
- 창: 'IH-110 inventory test'(일반)와 'IH-110 inventory test (FULL store fixture)'(`-- --fixture=full`).
- 항목: ① I 가방 표시·첫 칸 포커스·비16:9 리사이즈, ② HUD 버튼/‘보관함 보기’(키보드)로 열고 1개/스택 양방향 이동, 합계 목재 15 유지·재열기 무지급, ③ FULL 창에서 공간 부족 안내·양쪽 보존, ④ 살펴보기 중 I 거부·가방 중 E 무반응·I/Escape 연타·Button 포커스 후 I/Escape, ⑤ 걸으며 I·키 유지 닫기·Cmd+Tab 왕복·종료 후 재실행.
- 응답: "1~5 모두 정상". 항목별 메모는 없다. 두 창 모두 exit 0, 로그 오류 0.
- 보조: Claude는 화면 기록/보조 접근 권한이 없어(ENV-003) 엔진 viewport 캡처로 패널 배치만 확인했다(`build/ih-110/gui/`). 이것은 OS 창 증거가 아니다.

## 구현 차이·결정

명세와 다르거나 명세가 정하지 않은 부분이다. 테스트 영향은 함께 적었다.

1. **ItemDef.stack_limit 기본값 0(무효)**: ResourceSaver가 기본값과 같은 값을 쓰지 않아 `tool_axe.tres`에 한도가 빠진 것을 발견했다. 그래서 모든 정의가 한도를 명시하도록 했고, AC-N01이 각 파일의 명시 여부를 검사한다.
2. **결과 타입**: `InventoryService.Result` 내부 클래스(ok, code, applied_quantity, revisions, value, detail). 명세에 이름이 없던 `DUPLICATE_INVENTORY`(중복 등록), `INVALID_SNAPSHOT`(손상 snapshot) 코드를 추가했다. 결정 순서는 명세와 같으며, 등록 계열은 인자 검사 뒤 중복 검사를 한다.
3. **snapshot API**: `decode_snapshot`(미등록 새 상태 반환)과 `register_snapshot`(검증 후 새 사본 등록, 덮어쓰기 없음). snapshot의 ID는 String, 수량·revision은 int다. 등록은 거래가 아니므로 변경 이벤트를 내지 않는다. close 뒤에는 읽기도 CLOSED로 통일했다.
4. **아이콘**: 카탈로그 레코드에 Texture를 복사하지 않는다(이번 7종은 null). UI는 텍스트로 표시한다.
5. **조율자 위치와 시점**: InventoryController는 맵 루트 자식(Player 자식 아님)이다. 물리 질의가 필요 없어서 입력 콜백에서 바로 열고, 그 과정에서 Interaction을 비활성화해 큐에 있던 E를 폐기한다.
6. **입력 라우팅**: 닫힘 상태의 I는 `_unhandled_input`에서, 열림 상태의 I/Escape/E/interaction_cancel은 `_shortcut_input`(포커스된 GUI 다음)에서 처리한다. 상태에 따라 경로가 하나만 정해져 이중 명령이 없다.
7. **사유 코드**: 열기 거부·닫힘에 NOT_READY, REMOVED, FOCUS_LOST, SERVICE_UNAVAILABLE, INTERACTION_BUSY, INTERACTION_DISABLED, CONTROL_BLOCKED, CLOSED_BY_USER를 쓴다. UI 요청 거부에는 STALE_SESSION, WRONG_VIEW, SELECTION_CHANGED를 쓴다.
8. **보관함 키보드 경로**: HUD 버튼은 키보드 포커스를 빼앗지 않게 마우스 전용으로 두고, 가방 안에 '보관함 보기/가방만 보기' 버튼을 추가했다. 보기 전환은 새 session ID를 발급해 이전 화면의 요청을 무효로 만든다.
9. **꽉 찬 fixture**: `-- --fixture=full`이면 보관함이 `[wood10, stone10×11]`이다. 시험 창 제목으로 두 fixture를 구분한다. 자동 검사는 서비스 add로 같은 상태를 만든다.
10. **이동 키를 누른 채 열기**: Player의 neutral 규칙상 이동이 비활성이면 CONTROL_BLOCKED이고, "이동 키를 놓고 다시 시도하세요"를 안내한다.
11. **DEBT-002 유지**: 이동 게이트 작성자는 상호 배타적인 Interaction과 Inventory 둘뿐이다. 제3 잠금 작성자 지원은 해결로 보고하지 않는다.

## 미검증·남은 범위

- Windows/Linux GUI, 배포 빌드, 한글 글꼴 번들(DEBT-003)은 확인하지 않았다.
- 실제 저장 왕복(IH-112), 채집 지급(IH-111), 다중 재료 거래·예약(IH-130/132)은 범위 밖이다.
- 통합 결과는 아래 기록에 있다.

## 통합 기록

- [PR #19](https://github.com/moonhyeonjun/iron-and-harvest/pull/19): feature/inventory-system(`160ca9e`) → develop, merge `f26a77e66d9d63f9dd9216eae4f82d71fb28bde7`. 병합 전 mergeable_state=clean, base `3803bc7`. 보호 규칙 우회·강제 push 없음.
- [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41276480044/job/124759576975): Ubuntu 24.04 / Godot 4.7.2에서 11단계 PASS, player·interaction·inventory 모두 `RESULT: PASS`, 엔진 오류0.
- [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41276740036/job/124760326722): develop push(`f26a77e`) CI checks success.
- 통합 tree는 검증한 `160ca9e`와 동일(`git diff --exit-code`). main·태그·릴리스는 변경하지 않았다.
