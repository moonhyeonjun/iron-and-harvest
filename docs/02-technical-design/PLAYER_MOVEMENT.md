# IH-101 플레이어 이동·충돌 구현 명세

상태: **Proposed 명세, IH-101 구현·검증 완료(review)**, 2026-10-31. Codex 설계 → Claude Code 구현. 결과와 엔진 관찰은 이 문서 끝과 [검증 기록](../03-development/IH-101-VALIDATION.md)에 있다. 확정 기술은 ADR-011의 Godot4.7.2 Standard/GDScript/Compatibility다. 아래 수치와 조작 정책은 재현 가능한 검증용 기준안이며 최종 게임 밸런스·아트 규격으로 확정하지 않는다. 변경 시 수락 조건도 함께 갱신한다.

관련: [생활 시스템](../01-game-design/LIFE_SYSTEM.md), [아키텍처](ARCHITECTURE.md), [ADR-012](../04-decisions/ADR/ADR-012-player-movement.md), [수락 검사](../03-development/IH-101-ACCEPTANCE.md), [Claude 인수인계](../03-development/IH-101-HANDOFF.md).

## 목적·범위

작은 공간을 자유롭게 걷고 벽과 장애물을 자연스럽게 돌아가는 생활 조작의 기반을 만든다. 통치 모드나 장래의 전투가 플레이어 위치를 별도로 복제하지 않도록 Player가 월드의 실제 위치를 소유한다.

이번 명세의 구현 범위는 키보드 이동·충돌·카메라·idle/walk 표현·임시 테스트 맵·검사다. 상호작용 행동, 채집, 가방, 기력, 달리기, 점프, 공격, 대시, 저장, NPC, 통치 UI, 게임패드 지원은 제외한다. 미래 기능의 빈 매니저/Autoload/전역 이벤트 버스를 만들지 않는다. 아래 파일은 IH-101에서 계획대로 생성했다.

## 예정 Scene 및 파일

```text
MovementTest (Node2D)                         scenes/tests/movement_test.tscn
├── Ground (Polygon2D)                       시각 배경, 충돌 없음
├── WorldCollision (Node2D)
│   ├── BoundaryTop/Bottom/Left/Right (StaticBody2D)
│   │   ├── CollisionShape2D (RectangleShape2D)
│   │   └── Polygon2D                       충돌과 같은 크기의 표시
│   ├── Block (StaticBody2D)                 중앙 장애물
│   └── CorridorTop/Bottom (StaticBody2D)    좁은 길 검사
├── Player (인스턴스)                        scenes/player/player.tscn
└── Instructions (CanvasLayer → Label)       조작 설명, 입력 포커스 없음

Player (CharacterBody2D)                     scripts/player/player_controller.gd
├── BodyCollision (CollisionShape2D)         CircleShape2D, 발 위치
├── Visual (Node2D)                          scripts/player/player_visual.gd
│   ├── Body (Polygon2D)                     임시 몸체
│   └── FacingMarker (Polygon2D)             시선 확인 표식
└── Camera2D                                기본 enabled=false
```

Player 루트의 원점은 발 중심이다. 몸체 표시는 위쪽으로 배치하고 충돌 형상은 발 중심에 둔다. Visual만 바꾸어도 충돌·입력 결과가 변하지 않아야 한다. 테스트 맵은 Player 한 개를 인스턴스화하고 해당 Camera2D만 활성화한다. 다른 맵에서도 사용할 수 있게 카메라 경계/활성화는 맵의 책임이다.

| 예정 파일 | 책임·변경 범위 |
|---|---|
| game/scenes/player/player.tscn | 플레이어 구성·export 기본값·로컬 shape 리소스 |
| game/scripts/player/player_controller.gd | 입력 읽기, 조작 게이트, 물리 이동, facing/locomotion 상태 |
| game/scripts/player/player_visual.gd | 상태를 받아 임시 도형·방향 표시; 입력/자원 변경 금지 |
| game/scenes/tests/movement_test.tscn | 검사 지형·spawn·카메라 경계·설명; 콘텐츠 맵 아님 |
| game/tests/test_player_movement.gd | 실제 Player 씬과 물리 월드를 실행하는 수락 검사 |
| game/project.godot | 구현 때만 InputMap/물리60Hz/검사용 화면·충돌 레이어 이름 추가 |
| game/tests/README.md | 실제 실행 명령과 검증 범위 추가 |

생성된 .gd.uid도 추적한다. 외부 아트·플러그인·테스트 프레임워크는 필수가 아니다. Foundation main scene과 smoke_engine.gd는 유지한다. 임시 맵은 명시 경로로 실행하고 기본 진입점 변경은 별도 통합 작업에서 결정한다.

## 입력 액션·정책

| 액션 | 기본 키(검증용 제안) | 목적 |
|---|---|---|
| move_left | 물리 A, Left | x 음수 |
| move_right | 물리 D, Right | x 양수 |
| move_up | 물리 W, Up | y 음수 |
| move_down | 물리 S, Down | y 양수 |

WASD는 physical_keycode, 화살표는 keycode로 등록하고 동일 키를 이중 등록하지 않는다. 기본 ui_* 액션을 이동에 재사용하지 않는다. 네 액션 deadzone 제안값은0.2이며 이번 키보드 입력은0/1이다. 게임패드/키 재설정 화면은 후속이다.

각 물리 틱에 Input.get_vector(move_left, move_right, move_up, move_down)로 의도 벡터를 읽는다. 서로 반대 키는 해당 축에서 상쇄한다. 같은 방향의 두 키를 눌러도 속도가 더해지지 않는다. 입력 길이는1 이하로 제한하며 비영벡터를 무조건 normalized() 하지 않는다(장래 아날로그 크기 보존). 두 축 동시 입력은 대각선 이동을 허용한다. 타일 단위 이동이나 4축 이동 제한은 사용하지 않는 제안이다.

공식 Input 문서는 폴링이 UI의 accept_event와 무관함을 명시한다. 그러므로 UI 소비만으로 이동 차단을 해결하지 않는다. [Input API](https://docs.godotengine.org/en/stable/classes/class_input.html).

## 물리 이동·상태

검증 기본값: move_speed=96.0 월드 단위/초, physics_ticks_per_second=60. move_speed는 Player의 타입 있는 export 값이며 최종 밸런스는 TBD다. 1월드 단위는 임시 아트1px로 취급한다. 가속/감속 없이 즉시 출발·정지한다.

1. 조작 가능 여부와 입력을 읽는다. 차단되면 의도0.
2. 비영 의도일 때 facing을 갱신한다.
3. velocity = 의도 × move_speed. 속도에 delta를 곱하지 않는다.
4. _physics_process에서 move_and_slide()를 한 틱에 한 번 호출한다. position 직접 가산은 금지한다.
5. 충돌 처리 뒤 실제 이동 속도를 읽어 idle/walk를 선택하고 Visual에 전달한다.

CharacterBody2D.motion_mode는 MOTION_MODE_FLOATING, 중력·점프·바닥 판정은 없다. 플랫폼 레이어는0, 루트 rotation=0·scale=(1,1)을 유지한다. safe_margin은 기본0.08을 시작점으로 사용한다. 벽 미끄러짐을 허용하되 외곽 밖 이동을 좌표 clamp로 숨기지 않는다. 검증 속도에서의 물리 충돌로 경계를 지켜야 한다. [CharacterBody2D API](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html).

이동 거리는 물리 시간의 함수다. 렌더30/60/120fps에서도 동일한 물리 틱 수에는 같은 거리가 나와야 한다. 부하로 실제 시간이 늘어나는 현상은 따로 기록하고 물리 틱 수를 wall-clock 시간과 혼동하지 않는다. 이동 결과는 부동소수점으로 유지하며 Player 위치를 픽셀 정수로 반올림하지 않는다.

## 조작 게이트와 포커스

공개 경계 제안: set_control_enabled(enabled: bool) -> void. 현재 맵/세션 소유자 한 곳만 호출한다. controller는 control_enabled, window_focused, neutral_required를 별도로 소유한다. effective_enabled는 앞 두 조건이 참이고 neutral_required가 거짓일 때만 참이다.

차단 또는 창 포커스 상실 시 즉시 velocity=0, 상태idle로 전환한다. 재활성화/포커스 복귀 뒤 네 이동 액션이 모두 해제된 틱을 한 번 확인할 때까지 neutral_required를 유지한다. 좌우 동시 입력의 결과0을 '모두 해제'로 오인하지 않는다. 그 다음 새 키 입력으로 이동한다. 창 포커스가 없어도 테스트 입력을 넣는 headless 검사는 이 경계를 명시적으로 설정하며 테스트 종료 때 입력을 모두 해제한다.

트리 pause 시 Player는 pausable 프로세스 모드를 사용한다. pause를 여는 소유자는 먼저 control을 끄고, unpause 후 다시 켠다. IH-101에서는 pause 메뉴를 만들지 않고 게이트 API를 테스트한다. 향후 여러 차단 사유가 생기면 상위 소유자가 집계하고 Player에는 단일 결과를 전달한다. 지금 토큰/전역 잠금 관리자를 선행 구현하지 않는다.

## 애니메이션·방향

논리 상태는 Locomotion {IDLE, WALK}와 Facing {UP, DOWN, LEFT, RIGHT}의 조합이다. 초기idle/down. facing은 마지막 비영 의도로 결정하고 정지할 때 보존한다. 대각선은 절댓값이 큰 축을 선택하고 같은 값이면 가로축을 우선한다. 완전히 벽에 막혀도 의도 방향으로 바라본다.

walk 여부는 충돌 후 실제 속도 길이 > 0.5 단위/초로 제안한다. 벽을 계속 누르지만 움직이지 않으면 idle, 벽을 따라 이동하면 walk다. 입력 벡터만으로 걷기 애니메이션을 판정하지 않는다.

IH-101 Visual은 방향 표식과 idle/walk 구분(색 또는 작은 흔들림)을 제공한다. 표식은 BodyCollision을 움직이지 않는다. 향후 AnimatedSprite2D 교체 시 idle_up/down/left/right, walk_up/down/left/right의8개 이름 계약을 제안한다. 실제 프레임 수·fps·텍스처 규격은 IH-006 TBD이며 현재 SpriteFrames/AnimationTree나 빈 attack 상태를 만들 필요가 없다. Visual의 set_presentation(locomotion, facing)는 상태를 읽기만 하고 controller는 Visual 자식의 개별 도형을 직접 조작하지 않는다.

## 카메라·화면 검증 기준안

Camera2D는 Player 발 위치를 추적한다. 중심 anchor, zoom=(1,1), offset=(0,0), ignore_rotation=true, position/rotation smoothing=false, drag=false, physics callback을 시작값으로 한다. 물리 보간은 이 검사 기준에서는 끄고 흔들림/잔상을 실제 GUI로 검토한다. 보간·픽셀 스냅은 IH-006에서 별도 비교하며 매끄러움이 검증되었다고 가정하지 않는다.

검사용 논리 viewport640×360, 초기 창1280×720, viewport stretch/keep aspect/정수 배율을 제안한다. 제품 해상도 결정이 아니다. 창 크기/비율 변경 시 검은 여백은 허용하되 월드 비율은 유지한다. 맵이 논리 viewport보다 크도록 하고 카메라 limit=(left0, top0, right1280, bottom720)을 적용한다. 경계 근처에서 플레이어가 화면 중심에서 벗어나는 것은 정상이다. 카메라가 월드 밖 빈 공간을 보여주거나 collider를 대신해서 플레이어를 막아서는 안 된다.

카메라 노드 위치 대신 get_screen_center_position()과 viewport/zoom으로 실제 화면 영역을 검사한다. [Camera2D API](https://docs.godotengine.org/en/stable/classes/class_camera2d.html). 다른 지역 이동/다중 카메라 전환은 후속이며 이번 맵에서는 활성 카메라1개다.

## 테스트 맵·충돌

월드1280×720. 좌표는 좌상단(0,0), +x 오른쪽, +y 아래. 맵/형상 수치는 검사 fixture다. Player 발 원점 spawn=(128,360), CircleShape2D 반지름6. 임시 몸체16×24, 중심은 발보다 위로10. 최종 인물/타일 크기는 확정하지 않는다.

| 지형 | Rect2(position, size) | 확인 목적 |
|---|---|---|
| 위 경계 | (0,0), (1280,16) | 위쪽 이탈 방지 |
| 아래 경계 | (0,704), (1280,16) | 아래쪽 이탈 방지 |
| 왼쪽 경계 | (0,16), (16,688) | 왼쪽 이탈 방지 |
| 오른쪽 경계 | (1264,16), (16,688) | 오른쪽 이탈 방지 |
| 중앙 Block | (600,280), (64,160) | 정면 충돌·벽 따라가기·모서리 |
| CorridorTop | (900,200), (160,32) | 통로 윗벽 |
| CorridorBottom | (900,252), (160,32) | 폭20 통로, 지름12 플레이어 통과 |

RectangleShape2D.size는 표의 size, StaticBody2D.position은 rect 중심이다. 표시 도형과 shape의 외곽이 일치해야 한다. 검사 runner는 경우마다 Player만 안전한 빈 좌표로 옮기고 속도/입력/상태를 초기화한다. 게임 중 위치 강제 이동 API를 새로 만들지 않는다.

충돌 레이어 제안: 1=world_solid(값1), 2=player_body(값2). Player layer2/mask1, 정적 벽 layer1/mask2. 이름과 비트값을 혼동하지 않는다. 장식·설명·Camera는 충돌 없음. IH-102의 탐지 Area2D와 향후 hit/hurt 레이어는 그 작업에서 추가하고 물리 몸체와 별도로 둔다. 아직 NPC 간 막힘·밀기·경로 탐색을 구현하지 않는다. TileMapLayer/타일셋은 아트 파이프라인 확정 후 고려하며 이 fixture에는 필요 없다.

## 모듈 경계·확장 계약

controller가 transform, velocity, facing, locomotion과 이동 허용 상태의 권위자다. 속도는 export 정의값, 위치/방향은 런타임 상태다. 이 단계에서는 저장 데이터 형식이나 도메인 PlayerState 클래스를 만들지 않는다.

- IH-102: 별도 Interaction 컴포넌트가 발 위치/읽기 전용 facing을 참고해 대상을 찾고 행동을 요청한다. controller에 대상 검색이나 대화 코드를 넣지 않는다.
- IH-110/111: Inventory/Gathering 명령이 획득을 검증한다. 이동 틱과 Visual은 자원을 지급하지 않는다.
- 전투: 추후 ActionController가 행동 가능 여부와 이동 정책을 조율한다. 공격·넉백·장비 속도 보정은 이번 API에 추측으로 추가하지 않는다.
- 저장: 이후 map_id/position/facing을 별도 DTO에 복사한다. NodePath/카메라 위치를 영속 ID로 쓰지 않는다.
- 월드/UI: 맵이 Player 생성·카메라 경계를 소유한다. 모달/통치 전환의 소유자가 조작 게이트를 호출한다. 통치 모드가 별도 플레이어 위치를 갖지 않는다.

입력과 물리 처리는 짧은 private 메서드로 나누되 지금 별도 입력 매니저/MovementSystem/상태머신 라이브러리는 만들지 않는다. 실제 기능이 두 곳 이상 재사용될 때 분리 이유를 기록한다.

## 완료 관문·미확정

세부 수락 조건은 IH-101-ACCEPTANCE의 AC-01~12다. 실제 물리 검사와 GUI 조작 확인을 모두 통과해야 IH-101을done으로 바꾼다. 명세 작성만으로 v0.2.0을 완료하거나 태그하지 않는다.

TBD: 최종 속도/가감속/달리기, 아트·해상도·카메라 보간, 게임패드/재매핑, NPC 충돌, 게임 진입점 전환. 이번 검증 기준안은 이 TBD들의 제품 결정을 대신하지 않는다. 공식 stable 문서는 이동할 수 있으므로 구현 시 고정4.7.2 바이너리에서도 API와 씬 속성을 검증한다.

## 구현 결과·엔진 관찰 (2026-10-31)

위 계약대로 구현했다. 파일·노드 구성·공개 API(`set_control_enabled`, `is_control_effective`, `get_facing`, `get_locomotion`, Visual의 `set_presentation`)는 명세와 같다. 검증용 수치는 바꾸지 않았다. 고정4.7.2에서 확인한 차이와 보완은 다음과 같다.

- 벽 미끄러짐: floating 모드는 첫 slide에서 남은 이동 길이를 유지한다. →+↑로 Block을 밀면 투영값67.9가 아니라 약96 u/s로 벽을 따라 간다. "벽을 따라 y감소"는 충족한다. 이 감각을 유지할지는 ADR-012 검토 항목이다.
- 포커스: macOS GUI 시작 시 APPLICATION_FOCUS_IN→OUT이 트리 진입 전에 도착한다. controller는 상태만 기록하고 Visual 갱신은 `_ready` 이후로 미룬다(BUG-001). 포커스 판단은 APPLICATION_FOCUS 알림을 사용한다.
- 테스트 맵 중심 (640,360)은 Block 내부다. 카메라 중심 추적은 빈 바닥에서 검사한다. AC-06의 x≤594는 평평한 옆면(y≥280)에 적용하고 모서리 구간은 관통 검사로 확인한다.
- 카메라는 Player 자식 + physics callback이라 같은 틱에 갱신되어 측정 지연이 0이다.
- headless DisplayServer는 parse된 입력을 Viewport로 전달하지 않는다. UI 소비 검사는 runner가 `push_input`으로 전달한다.
