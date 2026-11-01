# IH-110 — 아이템·인벤토리 상세 설계

상태: **Proposed / IH-110 구현·검증·develop 통합 완료**, 2026-11-01. 기준 develop `2b4b9aa`, Godot4.7.2 Standard/GDScript/Compatibility. 아래 클래스·경로·API는 계획대로 구현했으며, 차이는 문서 끝과 [검증 기록](../03-development/IH-110-VALIDATION.md)에 있다. 수치는 검증 fixture이고 제품 밸런스가 아니다. [아이템 기획](../01-game-design/ITEM_SYSTEM.md), [ADR-015](../04-decisions/ADR/ADR-015-inventory-contract.md), [수락 조건](../03-development/IH-110-ACCEPTANCE.md), [Claude 인수인계](../03-development/IH-110-HANDOFF.md)를 함께 사용한다.

## 1. 경험과 범위

플레이어가 가방 내용과 여유 공간을 확인하고, 시험용 보관함과 물자를 주고받으며 실패 이유를 이해한다. 같은 물자가 가방과 보관함에 중복 존재하지 않는다. 이 경계를 IH-111 채집과 IH-130 건설이 재사용한다.

포함: 아이템 정의 검증, 고정 슬롯, 스택 병합·분산, 전체 성공/전체 실패 명령, 두 재고 간 보존 이동, 읽기 스냅샷, 가방 UI, 유한 재고 fixture, 자동/GUI 검사와 CI 등록.

제외: 채집·드롭·소비·장비 효과·제작·정렬·드래그·슬롯 간 수동 분할·무게·예약·거래·금화 지갑·실제 영지 창고·파일 저장·Autoload. `remove` API는 시험 및 후속 소비 경계용이며 버리기 버튼을 만들지 않는다. 무기·내구도·품질·마법은 미래 필드도 선행 추가하지 않는다.

## 2. 정의 형식과 ID

검증할 기본안은 **typed custom Resource + 개별 .tres + 명시적 catalog**다. 에디터 편집과 타입·리소스 참조를 활용하며 런타임 수량은 Resource에 저장하지 않는다. JSON은 외부 도구 친화성이 있지만 스키마·숫자·참조 검증이 추가로 필요하다. 두 형식의 작고 동등한 wood 예제를 구현 단계에서 로드/오류 검사한 뒤 ADR-015를 판정한다. 비교용 JSON은 game/tests/fixtures/ 아래만 두고 런타임은 선택한 하나만 읽는다. 전체 데이터 시스템의 포맷을 이번에 일괄 확정하지 않는다.

Resource 캐시는 같은 객체를 공유할 수 있으므로 Catalog는 검증된 스칼라 필드를 내부 레코드로 복사한다. ItemDef 원본이나 외부로 반환한 사본을 변경해도 이미 시작한 카탈로그/재고는 변하지 않아야 한다. 콘텐츠 재로딩은 IH-110에서 지원하지 않는다. [.tres/공유 로드 근거](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html), [JSON 파싱·타입 검증 근거](https://docs.godotengine.org/en/stable/classes/class_json.html). stable 문서는 가변이므로 실제 호환성은 고정 엔진에서 검증한다.

| ItemDef 필드 | 제안 타입·규칙 |
|---|---|
| item_id | StringName; ASCII 소문자 `[a-z][a-z0-9_]*`, 1~64자, 카탈로그 내 유일 |
| name_key | StringName; 비어 있지 않은 번역 키 |
| fallback_name | String; 비어 있지 않은 임시 한글명, 번역 부재 시 사용 |
| category | StringName; 이번 허용값 material, crop, food, seed, tool |
| stack_limit | int; 1~9999, 정수 범위 검증(밸런스 상한 아님) |
| icon | Texture2D 또는 null; null이면 UI 기본 도형/텍스트 |

`effects`/가격은 미포함. 목록은 디렉터리 탐색 순서에 맡기지 않고 catalog.tres의 정의 배열에 명시한다. null 정의·중복/빈 ID·알 수 없는 category·빈 이름·범위 밖 limit은 목록 전체 로드 실패다. 첫 항목만 채택하거나 조용히 제거하지 않는다. 로드 실패 시 조작/재고 생성은 차단하고 정의 ID·원인 로그를 남긴다. 재고 상태에 icon/Resource/NodePath/표시명을 넣지 않는다.

| 검증용 ID | 임시 이름 | category | stack_limit |
|---|---|---|---|
| wood | 목재 | material | 10 |
| stone | 석재 | material | 10 |
| iron | 철 | material | 10 |
| wheat | 밀 | crop | 10 |
| berry | 산열매 | food | 10 |
| seed_wheat | 밀 씨앗 | seed | 10 |
| tool_axe | 도끼 | tool | 1 |

7종은 형태 검사용 콘텐츠이며 도끼는 소지 확인만 가능하다. 철광석/철 구분, 먹기/심기/벌목은 후속 설계다. 금화와 추상적인 ‘식량’ 총량을 별도 아이템으로 중복 집계하지 않는다.

## 3. 상태와 소유권

- InventoryState: inventory_id, owner_id(각 안정 StringName), capacity(int), revision(int, 0부터), slots(고정 길이).
- ItemStack: item_id, quantity(int). 빈 슬롯은 null 하나로 표현한다. 수량0 스택/빈 ID 스택은 금지한다.
- capacity는 생성 시 1~256, 이번 bag/test_store 각각12. 슬롯 인덱스는0부터, occupied는1~stack_limit. 같은 아이템의 여러 스택을 허용한다.
- inventory_id/owner_id는 item_id와 같은 ASCII 형식·길이 규칙을 사용하며 inventory_id는 서비스 내 유일. owner_id는 `player_01`/`fixture_store_01` 등 데이터 ID로서 노드 이름과 무관하다. 같은 소유자의 복수 가방 가능성을 막지 않는다.
- InventoryService(RefCounted) 한 인스턴스가 등록된 재고 상태의 유일한 쓰기 소유자다. UI·Player·Target은 상태 참조를 보유하거나 slots를 직접 수정하지 않는다.
- 각 시험 맵이 별도 서비스를 소유하고 종료 시 해제한다. 맵 간 보존과 실제 월드 소유권은 IH-112에서 설계한다. 종료 후 인스턴스 참조가 있어도 close된 서비스의 명령은 거부한다.
- capacity 변경·아이템 정의 변경·예약은 미지원이다. 수량 계산은 int; 외부 데이터 bool/float를 int로 암묵 변환하지 않는다. 요청 수량의 기술 상한은 2,559,744(256×9999), 연산 전 검증한다.

## 4. 명령 계약

아래는 논리 시그니처다. typed 결과 객체의 파일 분할은 구현 때 최소로 유지한다. 배열/Dictionary 반환값은 깊은 사본이어야 한다.

| API | 계약 |
|---|---|
| register_inventory(id, owner_id, capacity) | 유효한 빈 재고 생성; 중복 ID 거부, revision0 |
| snapshot(id) | ID·capacity·revision·전체 슬롯의 독립된 읽기 사본; 없는 ID는 명시 실패 |
| count(id, item_id) | 해당 재고 전체 수량; 정의에 없는 ID는 실패, 유효하지만 미소지이면0 |
| add(id, item_id, quantity, expected_revision) | 전체 수량 적재 가능할 때만 적용 |
| remove(id, item_id, quantity, expected_revision) | 전체 수량 보유 시에만 낮은 인덱스부터 차감 |
| transfer(source_id, source_slot, destination_id, quantity, expected_source_revision, expected_destination_revision) | 선택한 단일 원본 슬롯에서 수량을 이동; 목적지의 여러 슬롯으로 분산 가능 |
| close() | 새 명령 차단; 중복 close 무해, 읽기/변경 정책은 종료 실패로 통일 |

Result 제안: ok, code(StringName), applied_quantity(실패0), 변경된 재고의 새 revisions. 실패는 상태·revision·변경 이벤트를 모두 보존한다. 원본 슬롯 부족 시 다른 슬롯에서 자동으로 가져오지 않는다. source==destination은 SAME_INVENTORY로 거부하며 정렬 명령으로 해석하지 않는다.

결정 순서: BUSY(재진입) → CLOSED → 카탈로그 유효성(INVALID_CATALOG) → 인자 타입/범위(INVALID_ARGUMENT) → 재고 존재(INVENTORY_NOT_FOUND) → 동일 재고(SAME_INVENTORY) → 기대 revision(STALE_REVISION) → 슬롯 범위(INVALID_SLOT)/아이템 정의(UNKNOWN_ITEM) → 빈 원본(EMPTY_SLOT)/수량부족(INSUFFICIENT_QUANTITY) → 목적지 공간(NO_SPACE). 해당 명령에 없는 검사는 건너뛴다. 테스트는 실패 조건을 하나씩 분리하고, 복수 실패 시 이 우선순위를 따른다. 임의 예외/엔진 오류 대신 결과를 반환한다.

외부 Variant/Dictionary를 받는 경계에서 typeof를 먼저 검사하고 내부 typed 명령으로 넘긴다. typed int 매개변수의 자동 변환을 실패 검증으로 오인하지 않는다. 정수 요청 q는1~상한, revision은0 이상이어야 한다. `remove`가 정의에 있는 미소지 아이템을 요청하면 INSUFFICIENT_QUANTITY다. 정의에 없는 아이템은0으로 취급하지 않는다. add/remove/transfer는 성공마다 각 변경 재고의 revision을 정확히1 증가시킨다. 기대 revision을 생략하는 편의 쓰기 API를 UI에 노출하지 않는다.

### 결정적 적재와 원자성

1. 모든 인자/현재 상태/revision을 검증한다. 원본과 목적지의 복사본에서 계획을 만든다.
2. add는 같은 ID의 덜 찬 스택을 낮은 인덱스부터 채우고, 다음으로 빈 슬롯을 낮은 인덱스부터 채운다. 다른 아이템은 이동시키지 않는다.
3. transfer는 원본 슬롯 차감과 목적지 add 계획을 모두 검증한다. remove는 해당 ID의 낮은 인덱스부터 차감하고0이 된 슬롯을 null로 만든다. 자동 압축하지 않는다.
4. 전체 성공할 때만 교체한다. await·사용자 콜백·signal을 두 재고 반영 사이에 호출하지 않는다. transfer의 모든 아이템별 원본+목적지 총합이 보존된다.
5. 두 상태와 revision을 반영한 뒤 서비스 `inventories_changed(changed_ids, revisions)`를 거래당1회 발행한다. changed_ids는 ID 오름차순이다. 읽기 콜백은 두 재고의 최종 상태만 관찰한다.
6. 검증~신호 발행 종료까지 쓰기 잠금을 유지한다. 신호 콜백이 다시 쓰기를 요청하면 BUSY, 나중에 큐잉해 자동 실행하지 않는다. 읽기는 허용한다. 종료 요청이 콜백 중 오면 이미 완료된 거래를 되돌리지 않고 이후 쓰기만 막는다.

예: bag `[wood8, stone10, null]`에 wood5를 더하면 `[wood10, stone10, wood3]`. 빈 슬롯 없는 `[wood9, stone10]`에 wood2 추가는 NO_SPACE이며 wood1만 넣지 않는다. `[wood4, wood3]`에서 wood5 remove는 `[null, wood2]`. 실패 시 수량뿐 아니라 슬롯 배치도 동일해야 한다.

revision은 같은 상태를 대상으로 한 오래된 UI 명령/동일 요청 재전송을 거부한다. **보상 ID의 영구 중복 방지 장부는 아니다.** 같은 기대 revision으로 transfer를 두 번 보내면 두 번째는 STALE_REVISION이다. 새 revision으로 사용자가 다시 클릭한 이동은 새 명령이며 정상이다. IH-111에서 채집 지점 소진과 지급의 단일 완료 경계를 별도로 설계한다.

## 5. 스냅샷과 저장 경계

IH-110은 메모리 값 변환만 제공한다. 제안 스냅샷:

```json
{"inventory_id":"player_bag","owner_id":"player_01","capacity":3,"revision":2,"slots":[{"item_id":"wood","quantity":10},null,{"item_id":"tool_axe","quantity":1}]}
```

이는 구조 설명이며 파일 저장 포맷 확정이 아니다. encode→독립 복사→validate/decode로 **새 미등록 상태**를 생성하는 왕복을 검사한다. decode는 필수/알 수 없는 키, 타입, 배열 길이, capacity, ID, 정의 존재, 스택 제한, 음수 revision을 엄격 검사하며 손상 데이터를 자동 잘라내지 않는다. 실패는 현재 서비스 상태를 바꾸지 않는다. 성공 상태의 서비스 등록은 ID 중복 검사와 함께 전체 적용한다. 빈 재고 생성과 검증된 snapshot 등록 외 임의 setter를 두지 않는다.

서비스 내 활성 세션에서 같은 ID를 덮어쓰거나 revision을 되감는 restore는 제공하지 않는다. IH-112에서 세이브 envelope/migration/원자적 파일 쓰기와 새 세션 전체 교체를 설계한다. JSON 왕복에서 float로 읽힌 숫자를 어떻게 엄격 정수로 변환할지는 저장 어댑터 책임이다. 현재 도메인 스냅샷은 int를 요구한다. [저장 설계](SAVE_SYSTEM.md).

## 6. UI·입력·기존 상호작용

가방은 모달이며 세계 시뮬레이션 전체를 pause하지 않는다. 검증용 640×360에서 제목·슬롯(4열×3행)·선택 이름/수량·오류/닫기 버튼을 보여준다. 보관함 fixture는 같은 패널에 두 재고를 나란히 보여주고 선택 슬롯에서 `1개 옮기기`/`스택 옮기기`만 제공한다. 표시 이름·수량은 필수이고 아이콘은 도형 대체 가능하다. 탭/방향키/Enter와 마우스로 선택·버튼 조작 가능하게 한다. 고정 좌표보다 Container/anchors를 쓰고 창 크기/비16:9에서도 가려지지 않게 한다.

| 입력 | 정책 |
|---|---|
| inventory_toggle | 물리 I, echo 무시. 닫힘에서 가방 열기, 열림에서 닫기 |
| inventory_cancel | Escape, 열려 있을 때만 닫기; 같은 이벤트를 기존 interaction_cancel에 전달하지 않음 |
| E/interact | 가방이 열리면 무시, 상호작용 큐에도 남기지 않음 |
| 기존 ui_* | 패널 안 선택/버튼 전용; 이동키를 새로 덮어쓰지 않음 |
| fixture HUD 버튼 | ‘검증용 보관함’ 열기, 실제 월드 상자 행동은 아님 |

GUI가 사용한 키는 월드 입력으로 전파하지 않는다. 닫힌 상태 I는 `_unhandled_input`, 열린 모달의 I/Escape는 포커스된 Button에서도 처리되도록 단일 라우팅을 정한다. 한 event를 `_input`/`_shortcut_input`/`_unhandled_input`에서 중복 명령으로 보내지 않는다. 입력 훅 선택은 [공식 전파 순서](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html)와 실제 엔진 검사를 근거로 한다. Player가 Input을 폴링하므로 GUI 소비만으로 이동은 멈추지 않는다.

### 최소 조율자 계약

새 InventoryController(씬 어댑터)가 가방 UI/서비스와 기존 Player/InteractionController 사이를 조율한다. UI는 이동 게이트를 직접 만지지 않는다. 기존 InteractionController의 단일 bool 게이트를 범용 잠금 시스템으로 확대하지 않는다.

- 맵은 InventoryController를 **재고 패널의 유일한 소유자**로 연결한다. 이 fixture에서 이동 잠금 작성자는 기존 InteractionController와 InventoryController뿐이다. 외부 전투/대화 잠금의 동시 추가는 미지원이며 DEBT-002가 해결됐다고 기록하지 않는다.
- 가방 열기는 Player `is_control_effective()==true`, Interaction `IDLE`, Interaction enabled, 포커스 있음, 조율자 closed일 때만 가능하다. ACTIVE/RESOLVING이면 거부하고 ‘살펴보기를 먼저 닫으세요’를 표시한다. 기존 세션을 강제로 닫거나 그 잠금을 해제하지 않는다.
- enabled 조회가 필요하면 `is_interaction_enabled()` 읽기 API만 추가할 수 있다. 내부 `_enabled` 접근/추측은 금지한다.
- 열기 시 opening 플래그 설정 → `set_interaction_enabled(false)`로 미처리 E 큐 폐기 → callback 후 씬·포커스·Player 유효성/제어·Interaction IDLE 재검사 → 성공할 때만 자기 이동 게이트 획득/패널 표시. 재진입은 거부한다. 실패/취소 시 자신이 바꾼 enable만 복구한다. opening 중 close/focus-out은 래치하고 뒤늦게 패널을 열지 않는다.
- 같은 프레임 E/I는 먼저 확정된 모달만 유지한다. E가 아직 큐 상태라면 가방 열기가 이를 폐기하고, E가 이미 RESOLVING/ACTIVE면 가방은 거부된다. 트리 탐색 순서에 기대어 두 패널이 잠깐 겹치게 하지 않는다.
- 정상 닫기/포커스 상실은 입력·선택·보류 명령을 비우고, 자신의 게이트를 정확히1회 해제한 뒤 자신이 비활성화한 Interaction을 복구한다. Player의 기존 neutral-required 규칙을 유지한다. 이동키를 계속 누르면 재이동하지 않는다.
- `_ready` 이전 알림과 `_exit_tree`/Player 제거에서는 유효성 확인 후 정리하며, 제거된 노드를 호출하지 않는다. 독립 조율자 제거로 Player만 남는 경우에도 자신이 보유한 잠금을 복구한다. 서비스의 수명은 맵이 소유하므로 단순 UI 닫기는 재고를 지우지 않는다.
- 패널마다 단조 session_id를 부여한다. UI 요청에는 session_id와 표시 시 source_slot/item_id/두 revision을 캡처한다. 닫힌/옛 세션, 다른 선택의 명령, 트리 이탈 후 명령은 거부한다. 서비스 실행 전 캡처된 item_id와 원본 슬롯을 확인한다. NO_SPACE/STALE_REVISION은 안내 후 최신 화면을 읽되 자동 재시도하지 않는다.
- 한 입력 동작에 하나의 명령만 보낸다. 변경 이벤트는 화면만 갱신하며 다시 transfer를 호출하지 않는다. 드래그/hold 반복은 없다.

기존 `InteractionTarget.try_begin()`은 승인 후 Controller가 재검증하여 취소할 수 있다. 여기나 `can_interact()`에서 아이템 지급·차감을 하지 않는다. IH-102 상자는 계속 설명 전용이다. 실제 창고/채집 Target과 도메인 명령 연결은 IH-111 이후 해당 작업에서 설계한다.

## 7. 씬·모듈·유한 시험 맵

제안 경로(아직 미생성):

| 위치 | 책임 |
|---|---|
| game/systems/inventory/item_def.gd, item_catalog.gd | 정의 Resource와 검증된 카탈로그 |
| game/systems/inventory/inventory_state.gd, inventory_service.gd | 슬롯/스냅샷·원자 명령·revision·읽기 사본 |
| game/data/items/*.tres, catalog.tres | 7종 정의, 단일 런타임 원본 |
| game/scripts/inventory/inventory_controller.gd | 입력·모달 수명·명령 조율 |
| game/ui/inventory/inventory_ui.tscn/.gd | 읽기 표시·선택·의도 신호 |
| game/scenes/tests/inventory_test.tscn | 기존 interaction_test 인스턴스 + InventoryController + InventoryUI |
| game/scripts/tests/inventory_test.gd | 두 재고 초기화·fixture HUD·의존성 연결·종료 |
| game/tests/test_inventory.gd, fixtures/inventory/ | 자동 runner·작은 형식 비교/실패 fixture |

기존 Player/World/카메라/Target의 실제 경로는 구현 시 읽고 연결한다. 기존 맵을 복사해 분기된 Player를 만들지 않는다. Foundation main_scene와 이동/상호작용 맵의 독립 실행을 보존한다. 서비스는 Player 자식이 아니며 Node/입력/카메라를 참조하지 않는다. Player는 인벤토리 계산을 모른다.

검증 맵 시작 재고: bag12의 slot0 wood8, slot1 stone10, slot2 tool_axe1; store12의 slot0 wood7, slot1 seed_wheat4. 나머지는 null. 초기화는 검증된 상태 등록을 사용하며 revision0이다. 재시작할 때만 재설정하고 매번 UI 열기에 물품을 지급하지 않는다. 총 wood15/stone10/tool_axe1/seed_wheat4를 표시해 보존을 관찰한다. 만원/오류 시나리오는 별도 테스트 상태로 구성한다. UI에 무한 생성/삭제 버튼을 두지 않는다.

## 8. 확장과 완료 경계

- IH-111: 재고 NO_SPACE면 지점 소진 없음, 지급 성공과 지점 감소를 하나의 유효 행동으로 묶는 계약 추가. 사전 공간 조회만 믿고 나중에 지급하지 않는다.
- IH-112: 메모리 snapshot을 버전 있는 월드 저장에 연결한다. definition 파일/Node를 저장하지 않고 콘텐츠 ID migration을 다룬다.
- IH-130/132: 건설 비용·다중 재료·예약은 별도 batch transaction 설계가 필요하다. remove 여러 번 호출해 부분 차감하는 방식은 금지한다.
- 전투/장비: stack_limit1은 고유 장비 인스턴스 모델이 아니다. 품질/내구도 도입 시 instance_id와 저장 migration을 별도 결정한다.

구현 완료는 [AC-N01~14](../03-development/IH-110-ACCEPTANCE.md)와 기존 회귀·필수 CI·GUI 증거·develop 통합으로 판정한다. 2026-11-01 AC-N01~14 pass(자동 375검사, 사용자 GUI). [PR #19](https://github.com/moonhyeonjun/iron-and-harvest/pull/19)로 develop 통합, done. 최종 가방 크기/아이템 품목·스택/조작키·아트·글꼴·저장 형식은 TBD다.

## 9. 구현 결과·차이 (2026-11-01)

- 정의 형식: .tres + catalog.tres를 선택했다(근거는 [검증 기록](../03-development/IH-110-VALIDATION.md)의 형식 비교). JSON은 `game/tests/fixtures/inventory/`에만 있다. ItemDef 기본 stack_limit은 무효 값 0이므로 모든 정의가 한도를 명시해야 한다.
- 결과 타입은 `InventoryService.Result`이다. 코드 `DUPLICATE_INVENTORY`, `INVALID_SNAPSHOT`을 추가했다. snapshot은 `decode_snapshot`/`register_snapshot`, ID는 String, 등록은 변경 이벤트 없음, close 후 읽기도 CLOSED다.
- 조율자는 맵 루트의 InventoryController이며 입력 콜백에서 바로 연다. 입력은 닫힘 I=`_unhandled_input`, 열림 I/Escape/E=`_shortcut_input`의 단일 경로다. 보기 전환은 새 session ID를 발급한다. 가방 안 '보관함 보기' 버튼으로 키보드 경로를 제공하며, HUD 버튼은 마우스 전용이다.
- 꽉 찬 보관함 GUI fixture는 `-- --fixture=full`이다. 이동 키를 누른 채라 Player가 neutral 대기이면 CONTROL_BLOCKED로 안내한다. DEBT-002는 그대로이며, 두 작성자의 배타적 사용만 지원한다.
