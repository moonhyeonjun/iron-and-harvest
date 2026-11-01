# IH-111 채집·자원 지점 상세 설계

상태: **Proposed / IH-111 구현·검증(review)**, 2026-11-01. 기준 develop `de0c163`(IH-110 BUG-005/006 독립 재검증 완료). 아래 계약대로 구현했으며 차이는 문서 끝과 [검증 기록](../03-development/IH-111-VALIDATION.md)에 있다. Godot4.7.2 Standard/GDScript/Compatibility 유지. Codex는 설계, Claude Code는 구현·검증한다. [ADR-016](../04-decisions/ADR/ADR-016-atomic-gathering.md), [수락 조건](../03-development/IH-111-ACCEPTANCE.md), [인수인계](../03-development/IH-111-HANDOFF.md)를 함께 따른다.

## 최소 플레이 경험과 범위

걷기 → 자원 행동 안내 → E로 1개 획득 → 잔량/가방 확인 → 가방이 차면 보관함으로 옮김 → 돌아와 남은 자원 수집. 유한한 월드 물자가 실제 개인 재고로 이동한다. 실패하면 양쪽이 보존되고, 마지막 획득 뒤 빈 지점이 세계에 남는다.

| 포함 | 후속 범위 |
|---|---|
| 나뭇가지 줍기→wood, 돌 줍기→stone, 산열매 따기→berry | 나무 베기·광맥 채굴·도구·내구도·기력 |
| E 새 누름당1개, 즉시 동기 명령, 유한 지점 | 누르고 있기·작업 시간·진행 바·작업 애니메이션·확률 보상 |
| 소진 표시·동일 세션의 뷰 재진입·실패 안내 | 자연 재생·달력·계절·다른 맵 이동·파일 저장(IH-112) |
| 기존 가방/검증 보관함과 같은 InventoryService | 제작·드롭·판매·농사·위임·영지 재고 집계 |

수량·좌표·표현은 검증 fixture이며 최종 밸런스가 아니다. 기본 Foundation 진입점과 기존 테스트 맵을 보존한다. 기존 설명용 상자는 아이템을 주지 않는다.

## 정의·상태·뷰

| 모델 | 필드·규칙 | 소유자 |
|---|---|---|
| GatherDef (.tres) | definition_id, display_name, action_label, item_id, initial_quantity | 검증한 스칼라 복사; Resource를 상태로 수정하지 않음 |
| PointBinding | point_id, map_id, definition_id, stock_inventory_id | GatherService의 불변 메타데이터 |
| 숨은 재고 | capacity=1, owner_id=point_id, slot0={item_id, quantity} 또는 null, revision | 기존 InventoryService가 유일한 쓰기 소유자 |
| 파생 조회 | remaining=slot0 수량(빈 슬롯은0), depleted=(remaining==0), stock_revision | 별도 remaining/depleted 상태 없음 |
| GatherTarget | target_id=point_id, Anchor·충돌영역·뷰, 서비스 참조, 임시 준비 명령 | 씬 어댑터; 수량 소유 금지 |

- ID: IH-110과 같은 전체 문자열 ASCII `[a-z][a-z0-9_]*`, 길이1~64. 끝 개행·공백·자동 trim 금지. 표시명은 한국어 가능하다.
- initial_quantity: bool/float가 아닌 정수, `1..ItemCatalog의 해당 stack_limit`. 미등록 품목/초과 수량은 시작 실패. 다중 슬롯/보상은 범위 밖이다.
- stock_inventory_id는 명시 데이터다. 접두사+긴 ID 자동 연결로 길이 제한을 깨지 않는다. point_id는 세션 전체 유일, stock ID는 bag/store 포함 전체 재고에서 유일하다. 두 지점이 stock을 공유하지 않는다.
- 검증 정의: gather_branches(wood,6), gather_stones(stone,4), gather_berries(berry,3). 회당 수량은 계약1이며 별도 설정 필드를 두지 않는다.
- 같은 정의의 두 지점도 각각 다른 숨은 재고를 가진다. 미채집 stock을 영지 소유 물자/식량에 합산하지 않는다. 일반 가방 UI는 bag/store만 조회·전송한다.

## 원자 거래와 최소 API

기존 `InventoryService.transfer(source_id, source_slot, destination_id, quantity, expected_source_revision, expected_destination_revision)`를 **source=지점 stock, slot=0, destination=bag, quantity=1**로 호출한다. 양쪽 상태·revision 설치 후 단일 변경 신호가 발생하는 실제 IH-110 구현을 재사용한다. bag에 add 후 별도 remaining 차감이나 실패 후 rollback을 만들지 않는다.

성공: stock -1, bag +1, 양 revision 각각+1, inventories_changed 1회(변경 ID2개). 다른 품목/재고 불변. stock+bag+store의 품목별 합은 초기 합과 같다. 실패: 슬롯·수량·revision·변경 신호 모두 불변. 기존 스택에 여유가 있으면 빈 슬롯 없이도 성공한다. 소진은 마지막 성공 거래의 결과이며 별도 완료 거래가 아니다.

GatherService는 RefCounted, Node/입력/시간을 참조하지 않고 InventoryService를 주입받는다. 아래 이름은 구현 시 조정 가능하나 계약이 달라지면 문서·테스트를 같이 갱신한다.

| API | 계약 |
|---|---|
| query(point_id) | 독립 값 사본(point/item/remaining/revision) 또는 오류 |
| prepare(point_id, bag_id, request_id) | 두 재고 revision·품목·수량1을 캡처한 단발 GatherCommand 생성. 재고/이벤트 변경 없음 |
| GatherCommand.commit() | 서비스가 발급·보관한 동일 명령인지 검사, 유효 준비 명령을 먼저 소비한 뒤 검증·transfer. 재사용 거부 |
| GatherCommand.cancel() | 미소비 명령 무효화. 소비/commit된 재고에 영향 없음, 여러 번 호출 안전 |
| close() | 이후 준비/실행 거부, 미소비 명령 무효화. 이미 commit된 거래 보존 |

단일 플레이어·동기 실행이므로 서비스당 미소비 명령은 최대1개, 존재하면 새 prepare는 BUSY다. 취소/성공/실패 모두 이를 비우고 전체 요청 이력은 쌓지 않는다. request_id는 양의 정수이며 point/bag ID와 함께 준비 당시 값으로 고정한다. bag ID는 bootstrap이 지정한 플레이어 가방만 허용하고 UI 인수로 임의 목적지를 받지 않는다. 잘못된 타 명령 요청이 기존 유효 준비 명령을 취소하지 않도록 한다. 명령 내부 필드는 외부 변경으로 변조할 수 없어야 한다. 생성 서비스의 수명에만 유효하며 세션 간 재사용할 수 없다. 영속 exactly-once 보상 일지가 아니다.

commit의 명령 검증→소비→stock 내용/owner/capacity·두 revision 검사→transfer 구간에는 await, 사용자 콜백, UI/Target 호출, 사전 신호가 없다. 서비스 busy를 commit 반환까지 유지하여 Inventory 변경 신호의 재진입 prepare/commit은 BUSY다. 읽기는 양쪽 최종 상태를 볼 수 있다. prepare는 공간 예약이 아니다. 준비 후 bag/stock 변경은 STALE_REVISION이며 자동 재시도/다른 지점 선택은 없다.

결과는 `ok, code, request_id, point_id, item_id, applied_quantity, revisions`의 독립 값이다. 성공1/실패0. 성공 revision은 transfer 반환값을 사용한다. 콜백에서 서비스가 닫혀 후속 query가 실패해도 성공을 실패로 바꾸지 않는다.

| 실패 코드 | 조건·안내 |
|---|---|
| NO_SPACE | bag 수용 불가. “가방이 가득 찼습니다.”, 지점 보존 |
| DEPLETED | 준비 시 잔량0. 소진 표시·프롬프트 없음 |
| STALE_REVISION | 준비 후 어느 한쪽 변경. “상태가 바뀌었습니다. 다시 시도하세요.” |
| INVALID_POINT / INVALID_ARGUMENT | 미등록·잘못된 ID/인수/결속. 진단 로그, 지급0 |
| INVALID_COMMAND | 미발급·취소·소비된 명령. 지급0 |
| BUSY / CLOSED | 재진입 또는 세션 종료. 지급0 |
| INVALID_STOCK | capacity/owner/품목/수량 결속 불일치. 지점 비활성·명시 오류, 자동 재충전 금지 |

검사 순서: busy/closed → 명령 동일성·소비 → 결속·stock 무결성 → revision → 잔량 → transfer 결과. 준비 후 외부 거래로 소진되면 STALE_REVISION, 새 준비는 DEPLETED다. 예상 밖 Inventory 오류는 원래 code/detail을 진단에 남긴다. InventoryService를 임의로 조작하는 코드에 대한 보안 경계는 아니며, gameplay의 stock 변경은 GatherService로 제한한다.

## Interaction 확장: 살펴보기와 즉시 행동

현재 InteractionController는 try_begin 뒤에도 재검증하고 ACTIVE/모달을 연다. 따라서 **can_interact, try_begin, 프롬프트, session_opened에서 지급하지 않는다**. BUG-003/004의 중복 ID 검증·취소 래치를 보존한다.

기본 Target 실행 종류는 INSPECT(기존 동작), GatherTarget만 INSTANT다. 추가 읽기 계약은 get_execution_kind()와 get_prepared_command(request_id)이며 범용 작업 버스는 만들지 않는다.

1. 기존 E 입력의 target WeakRef/ID 캡처, 틱당1개 규칙 유지. 같은 프레임 누름 합치기, echo/held 반복 무시.
2. IDLE→RESOLVING. 기존 enabled/focus/Player effective/대상/중복ID/거리32/정면dot0.5/LOS 검증.
3. GatherTarget.try_begin은 준비 명령만 만든다. 성공 시 true. 종류·표시 값·RefCounted 명령을 확보한 뒤 **마지막으로** 취소 래치와 대상/제어 조건 재검증. 취소면 cancel/end1회·거부1회·재고 변경0.
4. INSTANT는 RESOLVING→EXECUTING, 중간 신호·사용자 콜백 없이 확보한 명령.commit을 동기 호출한다. Target Node의 보상 함수 안에서 transfer하지 않는다. Inventory 신호에서 Target이 제거돼도 도메인 명령은 살아 있다. INSPECT는 기존 ACTIVE 흐름을 유지한다.
5. Inventory 양쪽 상태 설치가 취소 가능 여부의 경계다. 그 전 취소는 지급0. 그 뒤 Escape/focus-out/disable/Target 제거/service.close는 이미 적용된 지급을 취소하거나 재시도하지 않는다. EXECUTING 취소는 이후 요청만 막고 현재 결과를 덮어쓰지 않는다.
6. 결과 후 내부 요청을1회 정리한다. 살아 있고 같은 요청을 가진 Target에만 end_interaction(성공 cancelled=false, 실패 true)을 호출한다. 제거된 Target은 건너뛴다. 게이트를 획득하지 않았으므로 해제하지도 않는다.
7. 살아 있는 Controller만 성공 신호 instant_completed(request_id,target_id,result)1회 또는 기존 request_rejected1회를 보고한다. UI/Controller 제거로 표시가 생략돼도 거래는 성공이다. 죽은 Node 접근·늦은 UI 요청 없음. 이후 안전한 틱에서 선택/잔량을 재조회한다.

EXECUTING 및 정리/결과 콜백의 재진입 E는 BUSY 거부 또는 소비된 입력으로 버리고 다음 틱 큐에 남기지 않는다. 완료 후 정상 key-up/key-down만 다음 작업이다. 가방 I 요청은 기존 Interaction IDLE 요구로 거부한다. 실제 Viewport 입력 경로를 검사하며 직접 함수 호출만으로 입력 검증을 대체하지 않는다.

INSTANT는 inspect session_opened/패널/이동 게이트 소유0이다. 가방이 열리면 기존 Interaction 비활성화로 채집이 막힌다. 토스트는 포커스 없음/mouse_filter IGNORE, 이동/E/I를 소비하지 않는다. DEBT-002의 제3 게이트 작성자 문제를 해결했다고 보고하지 않는다.

일반 Node 제거는 queue_free를 쓴다. 변경 신호 중 Target/UI 즉시 free·queue_free, Controller/맵 트리 이탈·queue_free를 회귀로 검사한다. 실행 중인 Controller 자체의 동기 free는 지원 API로 제공하지 않는다. 종료 중에는 표시를 생략한다. 실제 엔진에서 수명 오류가 나오면 검증 실패로 남기고 어댑터/계약을 보완한다.

## 씬·모듈과 연결

```text
GatheringTest (Node2D; bootstrap/세션 소유)
├── Interaction (기존 interaction_test.tscn)
│   ├── World/Player/InteractionController
│   ├── Targets (기존 살펴보기2개)
│   └── InteractionUI
├── GatheringPoints (교체 가능한 뷰 하위 트리)
│   └── GatherTarget × 3 (Area2D)
│       ├── CollisionShape2D
│       ├── Anchor (Marker2D)
│       └── Visual (가용/소진)
├── InventoryController (기존)
├── InventoryUI (기존; bag/store만)
└── GatheringHUD (잔량·성공/실패; 읽기 전용)
```

GatherTarget은 InteractionTarget 계약을 따른다. 탐지 layer3=값4, 물리 장애물 없음. 기존 world_solid=값1/LOS 재사용. 빈 지점도 뷰/ID가 남고 can_interact=false다. 수량 권위는 숨은 재고뿐이며 위치/물리/애니메이션을 서비스에 넣지 않는다.

| 신규 후보(game/ 기준) | 책임 |
|---|---|
| systems/gathering/gather_def.gd | 정의 Resource |
| systems/gathering/gather_service.gd | 스칼라 복사·결속·조회·단발 명령; 작은 Command/Result는 내부 클래스 가능 |
| scripts/gathering/gather_target.gd | Target 어댑터·뷰 갱신 |
| scenes/gathering/gather_target.tscn | 감지·Anchor·시각 |
| data/gathering/*.tres | 세 정의 및 명시 목록, 디렉터리 스캔 의존 금지 |
| scripts/tests/gathering_test.gd, scenes/tests/gathering_test.tscn | 단일 서비스 구성·fixture·전체 대상 검수 |
| ui/gathering/* | 최소 비모달 표시, 불필요한 위젯 분리 금지 |
| tests/test_gathering.gd, tests/fixtures/gathering/* | 도메인·입력·수명·보존 회귀 |

수정 후보: interaction_target/controller.gd의 실행 분기, tools/run_ci.py와 Python CI 등록 검사, game/tests/README.md, 관련 문서. InventoryService.transfer/Player 정책은 원칙적으로 유지한다. 부족한 읽기 API가 필요하면 이유와 영향 기록. 새 입력 액션·Autoload·플러그인·범용 잠금은 필요 없다.

inventory_test는 자체 서비스를 생성하는 독립 fixture이므로 그대로 중첩하고 두 번째 서비스를 만들지 않는다. gathering_test 루트가 **하나의** InventoryService와 GatherService를 만들고 기존 InventoryController/UI에 같은 인스턴스를 주입한다.

## 초기화·재진입·저장 경계

입력 비활성 → 정의/모든 point·stock·target ID 및 bag/store 결속 검증 → 별도 후보 서비스에 bag/store/stock snapshot 등록 → 전부 성공할 때 뷰 연결·입력 활성. 오류면 후보 컨텍스트 폐기·명시 오류, 부분 등록된 세계로 진행하지 않는다. 초기 재고는 register_snapshot으로 넣으며 live add 이벤트로 초기 지급을 흉내내지 않는다.

기존 interaction_test의 `$Targets` 검사만으로 새 지점을 검수할 수 없다. 상위 bootstrap이 안내판/상자와 모든 지점(비가용·소진 포함)의 ID를 검수한다. 같은 point의 활성 뷰는 하나만 허용한다. 뷰 이탈은 신호/바인딩/준비 명령만 해제한다.

GatheringPoints 제거·재인스턴스는 같은 point에 기존 stock을 연결한다. `_ready`에서 재등록/초기 수량 재지급 금지. 세션 루트는 살아 있으므로 수량/소진/revision 유지. 전체 테스트 씬 재시작은 새 세션이며 초기 fixture로 돌아간다. 이를 디스크 저장/지역 스트리밍 구현으로 보고하지 않는다.

IH-112에는 PointBinding과 숨은 stock을 포함한 Inventory snapshot을 넘긴다. 별도 remaining/reset_at, 뷰/WeakRef/준비 명령/request_id는 저장하지 않는다. 복원은 초기 지급 없이 새 컨텍스트에 모든 참조/정의/stock을 검증한 후 교체하는 방향. 파일 형식·스키마·migration은 IH-112에서 확정한다.

## Fixture·완료 기준

일반: bag12=wood8/stone10/tool_axe1(나머지 빈 슬롯), store12 비움, 지점 wood6/stone4/berry3. 품목별 초기 합 wood14/stone14/berry3/tool_axe1. 세 지점은 실제 충돌을 확인해 접근 가능한 곳에 배치하고 기존 시작 안내판 선택을 유지한다. 정확한 좌표는 구현 검증 기록에 남긴다.

`--fixture=full`: bag wood10+stone10×11, store 빈12슬롯. E 실패→bag의 wood10을 store로 전송→E 성공. `--fixture=rebind`: 최초 성공 후 GatheringPoints만1회 제거/복원하고 HUD에 전후 수량 표시. 새 제품 단축키/재생 버튼은 만들지 않는다.

[AC-G01~14](../03-development/IH-111-ACCEPTANCE.md), 기존 회귀, 실패 주입, GUI, 필수 PR CI로 구현 완료를 판정한다. 2026-11-01 AC-G01~14 pass(자동 309검사, 사용자 GUI). PR 필수 CI·develop 통합 전 review다. 최종 감각·아트·밸런스, 도구/시간/재생/위임/다중 보상·영속 중복 방지는 TBD다.

## 구현 결과·차이 (2026-11-01)

- 측정 결과, 엔진은 타입 있는 int 필드에 `.tres`의 `2.5`/`true`/`"3"`을 오류 없이 정수화한다. 그래서 GatherCatalog가 원본 텍스트의 `initial_quantity` 정수 리터럴을 확인한다. 명시 목록용 `gather_catalog.gd`를 추가했다.
- `GatherService.build(...)`는 정의·결속·bag/store/stock 등록을 모두 성공할 때만 서비스를 반환한다(실패 시 INVALID_SETUP). `GatherCommand.commit/cancel`은 서비스의 `execute/release`로 위임한다. 캡처 값은 서비스가 보관하고, 명령은 서비스를 WeakRef로 참조한다. stock에 다른 품목이나 초기보다 많은 수량이 있으면 INVALID_STOCK이다.
- Interaction은 EXECUTING 상태와 `instant_completed`를 추가했다. 실행·보고 중 E는 조용히 소비한다. RESOLVING 중 Escape는 취소이며 INSPECT에도 적용된다. 콜백으로 트리에서 빠지면 그 틱의 선택 갱신을 생략한다.
- GatherTarget은 `_process`에서 잔량을 조회해 표시만 갱신한다. 지점 뷰는 `scenes/gathering/gathering_points.tscn`로 분리했다(좌표: 나뭇가지 (250,360), 돌 (250,470), 산열매 (360,300)). HUD 합계는 가방+보관함+지점이다.
