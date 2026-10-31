# IH-102 상호작용 상세 명세

상태: **Proposed 구현 기준안**, 2026-10-31. IH-004 원격 성공/실패/통합 검사 완료 후 Codex가 설계했다. 기능은 미구현이며 구현 담당은 Claude Code다. 엔진은 ADR-011, 이동은 기존 IH-101을 그대로 사용한다.

관련: [생활 시스템](../01-game-design/LIFE_SYSTEM.md), [이동 명세](PLAYER_MOVEMENT.md), [수락 조건](../03-development/IH-102-ACCEPTANCE.md), [인수인계](../03-development/IH-102-HANDOFF.md), [ADR-014](../04-decisions/ADR/ADR-014-interaction-boundary.md).

## 목적·범위

플레이어가 가까운 물체를 바라보면 가능한 행동과 대상을 알 수 있고, 한 번 눌러 행동을 시작하고 안전하게 닫을 수 있어야 한다. 이 경계를 이후 주민 대화·채집·상점의 공통 진입점으로 사용한다.

IH-102는 대상 탐지·선택·안내·요청 검증·취소와 간단한 살펴보기 패널만 구현한다. 안내판과 상자의 설명을 읽는 임시 대상2종을 제공한다. 아이템 지급/가방/상점 거래/대화 트리/퀘스트/농사/전투/저장/통치 모드는 제외한다. '상자 살펴보기'는 가방을 열거나 보상을 지급하지 않는다. 숫자·조작·UI 배치는 검증용 제안이며 제품 최종값이 아니다.

## 예정 Scene·모듈

```text
Player (기존 CharacterBody2D / controller 유지)
├── BodyCollision, Visual, Camera2D (IH-101 유지)
└── InteractionController (Node2D, 마지막 자식으로 추가)
    └── Detector (Area2D)
        └── CollisionShape2D (CircleShape2D, r32)

InteractionTarget (Area2D / interaction_target.gd)
├── CollisionShape2D (CircleShape2D, r4, 원점)
├── Anchor (Marker2D, 원점)
└── Visual (Polygon2D, 임시 안내판/상자 표현)

InteractionTest (Node2D / interaction_test.gd)
├── World (기존 MovementTest 인스턴스: 바닥/벽/Player 보존)
├── Targets (InteractionTarget 인스턴스들)
└── InteractionUI (CanvasLayer / interaction_ui.gd)
    ├── Prompt (Label, 포커스 없음)
    └── InspectPanel (Control, 기본 숨김)
        ├── Title / Description (Label)
        └── CloseButton (Button)
```

| 예정 경로(game/ 기준) | 책임 |
|---|---|
| scripts/interaction/interaction_controller.gd | 후보/선택, 입력 의도 큐, 거리·방향·가시선 검증, 요청/세션 상태, 소유한 이동 차단 |
| scripts/interaction/interaction_target.gd | 대상 식별·설명·사용 가능 여부, 동기 시작 허용/종료 경계 |
| scenes/interaction/interaction_target.tscn | 비물리 대상·Anchor·표현; 인스턴스별 export 정의 |
| ui/interaction/interaction_ui.tscn 및 .gd | 프롬프트/패널 표시와 닫기 요청 신호; 자원/선택/Player 상태 직접 수정 금지 |
| scenes/tests/interaction_test.tscn 및 scripts/tests/interaction_test.gd | 테스트 대상 배치·ID 검수·씬 간 신호 연결 |
| tests/test_interaction.gd | 실제 씬/물리/입력/수명/세션 수락 검사 |

기존 player.tscn에는 마지막 자식으로 컴포넌트를 추가한다. Camera2D의 기존 인덱스/override와 movement_test fixture를 보존한다. InteractionUI는 맵이 인스턴스화·연결하며 Player가 고정 UI 경로를 찾지 않는다. 기본 main_scene/Foundation smoke는 그대로 두고 interaction_test는 명시 경로로 실행한다. 새로운 Autoload·이벤트 버스·범용 행동 프레임워크는 만들지 않는다.

## 입력과 처리 시점

- interact: 물리 E. interaction_cancel: Escape keycode. 이동의 ui_* 분리 원칙을 유지한다. 키 재매핑/게임패드는 후속이다.
- Controller의 _unhandled_input에서 새 press만 받아 의도를 큐에 넣는다. echo/키 유지 반복은 무시한다. 처리한 입력은 handled 처리한다. UI가 소비한 E는 전달되지 않아야 한다.
- 입력 콜백에서 물리 공간을 조회하거나 행동을 직접 실행하지 않는다. 다음 _physics_process에서 처리한다. Controller의 process_physics_priority=10, 기존 Player는0으로 두어 이동 후 위치를 사용한다.
- 한 틱에 요청은 최대1개. 같은 틱에 취소와 요청이 있으면 취소 우선, 요청 폐기. 키 연타가 여러 행동을 예약하는 큐가 되어서는 안 된다.
- E를 누른 시점의 화면에 표시된 대상 참조/ID를 캡처한다. 다음 틱에 그 대상이 무효가 되었으면 거부하며 다른 대상으로 요청을 바꿔 보내지 않는다.

[Node 입력 처리 문서](https://docs.godotengine.org/en/stable/classes/class_node.html)에 따라 UI 소비 후의 입력을 사용한다. IH-101의 이동은 Input 폴링이므로 패널 열기는 별도의 이동 게이트도 필요하다.

## 탐지·선택 규칙

검증 기본값: interaction_range=32 월드 단위, facing dot≥0.5(정면±60도). Player 발 위치와 대상 Anchor 사이를 측정한다. IH-101의4방향 facing을 단위 벡터로 변환하며 대각 이동 때도 기존 가로 우선 정책을 사용한다. 거리가0이면 방향 조건만 면제한다.

충돌 레이어: 기존1=world_solid(값1),2=player_body(값2); 신규3=interaction_target(값4). Detector layer0/mask4, monitoring=true/monitorable=false. Target layer4/mask0, monitoring=false/monitorable=true. 둘 다 중력 등 space override 없음. 대상 Area는 몸체를 막지 않으며 발 반지름6/벽 레이어를 변경하지 않는다.

Area2D enter/exit는 후보 집합을 관리하고 초기 overlapping_areas로 동기화한다. overlap 갱신은 즉시가 아니므로 진입/이탈 프롬프트는 물리2틱 이내 반영을 목표로 한다. 매 프레임 모든 월드 대상을 검색하지 않는다. InteractionTarget 타입의 Area만 후보로 삼는다. 후보라도 Anchor 거리가32를 초과하면 선택 불가다. 검출 원과 target r4가 겹친다는 것만으로 거리36을 허용하지 않는다. [Area2D 문서](https://docs.godotengine.org/en/stable/classes/class_area2d.html).

매 물리 틱에 유효 인스턴스·트리 소속·queue_free 여부·visible·available·ID·거리·방향·가시선을 필터링한다. 선택은 다음 순서의 tuple 오름차순이다: round(distance×1000), −round(dot×1000000), target_id의 사전순. 작은 float 동률을 비추이적 epsilon 비교로 정렬하지 않는다. 후보/신호 도착 순서와 무관한 결과가 나와야 한다.

target_id는 맵에서 유일한 authored StringName이며 표시명/NodePath로 만들지 않는다. Target은 interaction_target 그룹에 속한다. 테스트 맵 초기화 스크립트가 자기 하위 대상들을 한 번 검수한다. 빈 ID/중복 ID 대상은 선택 가능 대상으로 등록하지 않고 이유를 검증 결과에 남긴다. 후보 중 동일 ID가 다시 발견되어도 모두 선택에서 제외한다. 런타임 ID 생성·저장 스키마는 IH-112 이후다.

## 벽 너머 동작 차단

발→Anchor 가시선은 _physics_process 안에서 PhysicsDirectSpaceState2D.intersect_ray로 검사한다. query collision_mask=1, collide_with_bodies=true, collide_with_areas=false, exclude에 Player RID, hit_from_inside=true. world_solid hit가 있으면 OCCLUDED. Target의 몸체가 아니라 사용 가능한 바닥 지점에 Anchor를 배치한다.

거리0은 ray 길이0을 만들지 않고 같은 지점의 PhysicsPointQueryParameters2D(collision_mask=1, collide_with_bodies=true, collide_with_areas=false)와 intersect_point로 벽 내부 여부를 검사한다. 후보가 가깝더라도 벽 안/너머면 안내와 행동 모두 거부한다. ray 결과만으로 대상의 유효성/거리 검증을 생략하지 않는다. [Ray query 설정](https://docs.godotengine.org/en/stable/classes/class_physicsrayqueryparameters2d.html).

## 최소 데이터와 API 계약

Target export: target_id:StringName, display_name:String, action_label:String(초기 '살펴보기'), description:String, available:bool. 정의는 scene 인스턴스 export로 충분하며 JSON/Resource 전역 포맷을 이 기능 때문에 확정하지 않는다.

Controller 런타임: 후보 WeakRef 집합, selected_target/selected_id, queued_request, next_request_id:int, active_request_id/active_target, state, owns_movement_gate:bool. 참조·request_id는 현재 씬 세션용이며 세이브하지 않는다. request_id는 해당 Controller 수명 동안 단조 증가하며 의도를 큐에 수락할 때 발급한다. 대상이 없거나 이후 거부되어도 해당 ID로 결과를 남긴다. 같은 틱의 중복 press는 새 ID를 만들지 않는다.

예정 typed 경계:

| 경계 | 계약 |
|---|---|
| Target.can_interact() -> bool | 현재 사용 가능 여부, 부작용 없음 |
| Target.try_begin(request_id:int) -> bool | 동기 최종 허용, false면 상태/보상 변경 없음; IH-102는 읽기 패널만 |
| Target.end_interaction(request_id:int, cancelled:bool) -> void | 유효한 활성 세션 종료 통지; 보상 로직 없음 |
| Controller.finish_active(request_id:int, reason:StringName) -> void | 현재 ID와 일치할 때만 정리; 중복/이전 ID는 무시 |
| Controller.set_interaction_enabled(enabled:bool) -> void | 탐지/요청 중지, false 전환 시 현재 세션 취소; 외부 이동 차단을 해제하지 않음 |
| Controller.target_changed(target_id, action_label, display_name) | 뷰용 값만 발행, 없으면 빈 ID; 변경된 경우만 |
| Controller.session_opened(request_id, title, description) | 허용된 세션만 패널 표시 |
| Controller.session_closed(request_id, reason) | 정리 완료 후 한 번 발행 |
| Controller.request_rejected(request_id, reason) | 테스트/로그·임시 안내용, 게임 자원 변화 없음 |
| UI.close_requested(request_id) / cancel_requested(request_id) | 버튼 완료/Escape 취소 의도만 전달 |

실제 구현에서 신호 인자도 타입을 명시한다. reason 값은 NO_TARGET/INVALID_TARGET/DISABLED/OUT_OF_RANGE/NOT_FACING/OCCLUDED/BUSY/TARGET_REJECTED/CANCELLED/COMPLETED/FOCUS_LOST 등의 StringName 상수로 모아 오타를 막는다. 성공/실패 의미는 API 문서와 검사에서 일치시킨다.

## 요청·세션 상태

IDLE(후보 없음 또는 선택됨) → RESOLVING → ACTIVE → IDLE. RESOLVING은 한 물리 틱의 동기 처리 상태이며 비동기 작업/애니메이션 타이머는 도입하지 않는다.

1. IDLE, enabled, 포커스 있음, Player.is_control_effective() 조건을 확인한다.
2. 큐에 캡처한 대상과 ID를 재확인하고 현재 거리/방향/가시선/available을 다시 검사한다.
3. RESOLVING으로 바꾸고 큐의 request_id를 사용한다. try_begin은 이 요청에 한 번만 호출한다. 재진입/연타는 BUSY로 거부한다.
4. false 또는 호출 중 대상 삭제이면 정리하고 거부한다. 선택 표시 때 가능했어도 실행 시 불가능하면 실행하지 않는다.
5. true와 대상 유효성이 확인되면 ACTIVE로 저장하고 set_control_enabled(false)로 이동을 즉시 멈춘 뒤 session_opened 발행. 활성 프롬프트는 숨긴다.
6. CloseButton은 COMPLETED, Escape는 CANCELLED, focus out은 FOCUS_LOST로 종료한다. 상태/참조/요청 큐를 먼저 비워 재진입을 막고, 유효한 Target에 종료 통지·자신이 소유한 이동 게이트 해제·session_closed를 각각 한 번 처리한다.

ACTIVE 동안 E는 새 행동을 만들지 않는다. 대상 삭제/숨김/available=false/외부 강제 이동으로 범위 밖/LOS 차단이 되면 다음 물리 틱에 취소한다. 맵 종료 시 참조를 정리하며 유효한 Player가 남아 있을 때만 소유한 게이트를 해제한다. Controller 자체가 제거되는 경우도 같은 규칙이다.

애플리케이션 focus out은 큐 폐기·활성 세션 취소·표시 숨김이다. focus in에 자동 재시작하지 않는다. 이동은 IH-101의 neutral-required 규칙을 따른다. _ready 이전 포커스 알림에서도 null 하위 노드/UI를 호출하지 않는다(BUG-001 회귀 적용). _ready 순서상 자식이 부모보다 먼저 준비된다는 점도 고려한다.

현재 IH-102에서는 Controller가 상호작용 패널의 이동 게이트를 소유한다. 시작 전 이미 외부에서 이동이 차단되어 있으면 IDLE 프롬프트를 숨기고 요청을 거부하며 타인의 잠금을 풀지 않는다. 여러 모달/전투가 동시에 이동을 제어할 때는 상위 조율자를 별도 설계한다. 이번 단계에서 전역 잠금 시스템을 선행 구현하지 않는다.

## UI 경험

후보가 있을 때만 하단 고정 Prompt에 'E 살펴보기 — 마을 안내판'처럼 동작과 대상을 함께 표시한다. 처음부터 target ID, 엔진 클래스, 실패 stack을 제품 화면에 노출하지 않는다. InspectPanel은 제목·짧은 설명·닫기 버튼만 가진다. 버튼에 초기 포커스를 주고 Escape 닫기도 제공한다. 예시 설명은 '마을 입구의 낡은 안내판이다.'처럼 세계 안의 문장으로 작성한다.

패널/버튼은 입력을 소비한다. 패널이 보일 때 UI가 Escape를 처리해 cancel_requested를 발행하고 handled 처리한다. 버튼은 close_requested를 발행한다. Controller는 두 신호의 request_id를 검증한다. UI가 Player.velocity나 target 상태를 직접 변경하지 않는다. 패널 닫기 후 이동 키를 계속 누르고 있었다면 완전히 해제 후 새로 눌러야 이동한다. 지연된 이전 패널 닫기 이벤트가 새 세션을 종료하지 않아야 한다.

## 테스트 맵과 확장

기존 MovementTest를 인스턴스로 포함하고 기본 검증 대상2개를 배치한다: sign_entrance=(128,388), crate_supplies=(156,360). 초기 발(128,360), facing down에서는 안내판 선택. 오른쪽을 바라보면 상자 선택 가능하다. 둘 다 설명을 읽는 대상이며 아이템 지급 없음. 자동 테스트는 별도 fixture 또는 같은 맵의 임시 노드를 이용해 거리 경계·동률·벽 너머·거부/삭제/취소를 만든다. 기존 movement fixture 자체를 바꾸지 않는다.

후속 IH-110/111에서는 Target이 Inventory/Gathering 도메인 명령을 요청하고 결과를 표시한다. 선택/프롬프트/이동 틱이 자원을 직접 지급하지 않는다. 비용·중복 보상·저장은 해당 도메인의 원자적 처리와 영속 요청 정책에서 해결한다. IH-102의 세션 ID를 영구 exactly-once 보상 키로 재사용하지 않는다.

## 완료·TBD

[AC-I01~12](../03-development/IH-102-ACCEPTANCE.md)의 실제 자동·GUI 결과와 필수 CI를 통과해야 IH-102 done이다. 현재는 명세만 작성했으며 테스트/게임플레이 구현은 없다. 최종 범위/정면각/키/UI/대상 전환 감각은 Proposed, 마우스 선택·다중 행동 메뉴·누르고 있기·NPC 이동·예약/비동기 작업은 후속이다. v0.2.0 태그는 IH-102 이후 별도 마일스톤 검토에서 판단한다.
