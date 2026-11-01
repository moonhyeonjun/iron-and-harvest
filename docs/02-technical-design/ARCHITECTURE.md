# 아키텍처

## 실제 경로와 경계

저장소 루트는 Git/문서/관리 도구, Godot 루트는 `game/`다. `res://scripts/...`는 `game/scripts/...`이고 `res://game/...`가 아니다. 게임에서 루트 docs/data/tools를 읽지 않는다. 원본 아트는 `art/source/`, 게임용 출력 에셋은 `game/assets/`, 배포 빌드는 무시되는 build/dist/exports에 둔다.

| 경로 | 책임 |
|---|---|
| game/scripts | 씬 어댑터·입력·애플리케이션 작업 흐름 |
| game/systems | 도메인 상태·게임 규칙·명령 처리 |
| game/scenes | 월드/오브젝트 씬 |
| game/ui | UI 씬/스크립트, 읽기 모델과 입력 |
| game/data | 런타임 정의/시작 시나리오 |
| game/tests | smoke_engine.gd로 엔진/씬 smoke 검증, 게임 테스트는 기능별 추가 |
| tests | Python 저장소 검증기 회귀 테스트 |
| data/design | 기존 수치 가정 자료, 런타임 사용 금지 |

## Proposed 책임과 의존성

입력/장부 → 명령 검증 → 공유 상태 반영 → 이벤트 → 월드/UI/연대기. 정의 데이터는 읽기 전용, 상태는 인스턴스별로 소유한다. UI가 생산 계산·저장 파일 조작을 맡지 않는다.

| 모듈 | 책임 | 주요 의존/단계 |
|---|---|---|
| Player, Interaction | 이동·대상 탐지·행동 요청 | 입력/월드, v0.2 |
| Inventory, Resource | 수량·예약·이동 원자성 | ItemDef, v0.3 |
| Calendar, Season | 날짜·경계·주기 이벤트 | 저장 상태, v0.4 |
| Building, Production | 건설 진행·입출력·노동 | 자원/시간, v0.5 |
| Trade, Tax | 거래 검증·세금/재정 | 자원/가구, v0.6 이후 |
| Population, Character, Relationship | 노동 자격·인물·관계 | 안정 ID/시간, v0.6~0.7 |
| Event | 조건·결과·중복 방지 | 상태/날짜, 필요 기능부터 |
| Dynasty, Diplomacy, Faction, Law | 계승·계약·파벌·정책 | MVP 이후, 세부 의존 TBD |
| Army, Combat, Siege | 병력·전투·공성·보급 | 경제/영토, MVP 이후 검토 |
| WorldMap, Territory | 지역 연결·소유·접근 | 세계 상태, 확장 단계 |

모든 모듈은 예정 책임이며 클래스 파일이 존재한다는 뜻이 아니다. God Object/과도한 Autoload/ECS/범용 이벤트 프레임워크를 선행 도입하지 않는다.

## IH-101의 최소 분리 제안

[Player 상세 명세](PLAYER_MOVEMENT.md)에 controller/Visual/맵의 책임과 향후 Interaction·Inventory·Combat 연결 경계를 정의했다. IH-101에서 game/scripts/player(controller·Visual), game/scenes/player, game/scenes/tests로 구현했다. 새 매니저/Autoload는 만들지 않았다. 물리 위치는 Player, 카메라 경계는 맵, 표현은 Visual이 소유한다. AC 검증은 통과했고 ADR-012는 Proposed를 유지한다.

## 시간·이벤트 제안

이동/표현은 프레임, 영지 생산은 하루, 국가 정책은 월, 역사 집계는 연 단위를 검토한다. 일일 파이프라인 제안은 원료→가공→식사→재정→프로젝트→사건→날짜→검증/저장이다. 월/년 빠른 진행도 일일 효과를 보존해야 한다. 정확한 순서는 IH-120에서 검증 후 확정한다.

Event는 event_id/type/date/actor_ids/target_ids/payload_version을 갖고 상태 반영 후 발행한다. 동일 완료 이벤트를 재수신해도 보상/기록을 중복 적용하지 않는다. 화면 이벤트가 도메인 상태를 재귀 변경하지 않는다.

## 완료 조건·TBD

같은 행동이 생활/장부 어디서 들어와도 동일 검증을 통과하고 동일 상태를 만든다. 재고·인력·하루 진행의 불변식을 테스트한다. 서비스 수/폴더 세분화/이벤트 타입/주기 구현은 실제 기능 시 확정한다.

경로 근거: [Godot 파일 시스템](https://docs.godotengine.org/en/stable/tutorials/scripting/filesystem.html). 기존 루트 src 구조는 참조 초안으로 대체되었다.

## IH-102 상호작용 경계 제안

[상세 명세](INTERACTION.md)는 기존 Player 아래 별도 InteractionController의 탐지·선택·재검증·세션과 Target의 행동 허용, UI의 표시 책임을 구분한다. 채집/재고/보상은 후속 도메인 책임이다. 입력 시 대상과 실행 시 대상이 다르거나 소멸하면 거부하며 다른 대상으로 자동 전환하지 않는다. IH-102에서 game/scripts/interaction(controller·target), game/scenes/interaction, game/ui/interaction, game/scenes/tests/interaction_test로 구현했다. Autoload·이벤트 버스·범용 행동 프레임워크는 만들지 않았다. 맵이 Controller와 UI를 연결한다.

## IH-110 인벤토리 경계 제안

[상세 명세](INVENTORY.md): Catalog는 검증된 정의의 스칼라 사본, InventoryService는 상태의 유일한 쓰기 소유자다. UI → InventoryController → 도메인 명령 → 양쪽 상태 commit → 단일 변경 신호 → UI 재조회 순서를 따른다. Node/입력/시간과 도메인을 분리하며 Autoload/범용 이벤트 버스를 추가하지 않는다. 가방/살펴보기의 배타성은 작은 씬 조율자가 맡고 DEBT-002의 일반 다중 잠금 문제는 해결로 표기하지 않는다. 채집 소진+지급, 건설 다중 재료, 저장 복원은 별도 거래 경계를 요구한다. IH-110에서 game/systems/inventory(ItemDef·ItemCatalog·InventoryState·InventoryService), game/data/items, game/scripts/inventory(InventoryController), game/ui/inventory, game/scenes/tests/inventory_test로 구현했다. 서비스는 Node·입력을 참조하지 않는다.

## IH-111 채집 경계 제안

IH-111에서 game/systems/gathering(GatherDef·GatherCatalog·GatherService), game/data/gathering, game/scripts/gathering(GatherTarget), game/scenes/gathering, game/ui/gathering, game/scenes/tests/gathering_test로 구현했다. 서비스는 Node·입력·시간을 참조하지 않는다([검증 기록](../03-development/IH-111-VALIDATION.md)).

[상세 명세](GATHERING.md): 입력/Target 준비 → Interaction 최종 재검증 → RefCounted 단발 명령 → 기존 InventoryService.transfer → 양쪽 상태 설치 → UI/뷰 갱신. 지점별 숨은 재고를 원본으로 사용하여 별도 remaining과 재고의 이중 쓰기를 없앤다. INSTANT는 모달/게이트를 소유하지 않는다. 서비스는 세션 루트가 소유하고 지점 뷰 이탈은 재고를 초기화하지 않는다. IH-111 구현·수정·독립 재검증은 완료했고 ADR-016 Proposed를 유지한다.

## IH-112 저장·세션 경계 제안

[SAVE_LOAD](SAVE_LOAD.md): Codec은 순수 값·버전/검증, Store는 고정 A/B 파일 I/O, Coordinator/작은 bootstrap은 안정 snapshot과 후보 세션 검증/publish를 맡는다. 상태 복원은 새 서비스에만 하며 UI/월드의 live 값을 하나씩 덮어쓰지 않는다. 파일 commit과 세션 publish는 서로 다른 경계다. epoch는 파일에 저장하지 않고 이전 UI/명령의 새 세션 접근을 거부한다. 기존 Player bool 게이트에 제3 소유자를 추가하지 않는다. SaveCodec/Store/Coordinator·Gather restore·맵 훅으로 구현·검증했으며 IH-112 done, ADR-017 Accepted다. bootstrap은 별도 빈 모듈 대신 gathering 맵의 최소 훅을 사용한다. process_mode와 별개로 InventoryController의 직접/지연 명령도 세션 정지 가드를 확인한다.

## IH-120 시간 경계 제안 (미구현)

[CALENDAR](CALENDAR.md): 월드마다 CalendarService가 날짜 상태를 소유하고 season/year/시각은 파생한다. 교체 World 밖 CalendarController가 현재 SaveCoordinator world/epoch만 진행하며 후보·이전 세션을 tick하지 않는다. 기존 맵은 passive, 전용 calendar_test만 자동 진행한다. pending/보고와 파일 요청은 선택적 외부 blocker 하나로 직렬화한다. 시간 정지는 이동 bool 게이트/전역 pause를 작성하지 않고 사유를 합성한다. 날짜 알림에 미래 보상 리스너를 붙여 원자 결산으로 간주하지 않는다. schema2와 세션 전체 snapshot/restore가 필요하며 ADR-018 Proposed다.
