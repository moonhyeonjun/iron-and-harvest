# Godot 기반 검증

저장소 루트에서 실행한다. 모든 검사는 고정 엔진 실행기 `tools/godot.py`를 사용한다.

## smoke_engine.gd — Foundation

타입 있는 GDScript 실행과 configured Foundation PackedScene 로드/인스턴스화를 확인한다. 게임플레이·사용자 데이터 변경 없음. 기본 진입점은 Foundation 그대로다.

```sh
python3 tools/godot.py --headless --script res://tests/smoke_engine.gd
```

## test_player_movement.gd — IH-101 이동·충돌

실제 Player/MovementTest 씬을 SceneTree에 넣고 엔진 물리 루프(60Hz)로 진행한다. 입력은 `Input.parse_input_event`의 실제 InputEventKey로 InputMap을 거친다. 수식 복제 대신 move_and_slide 결과 좌표와 물리 프레임 수를 측정한다. 전체 suite를 한 실행에서 새 맵 인스턴스로2회 반복해 측정값을 비교하고, 실패가 하나라도 있으면 종료코드1이다.

```sh
python3 tools/godot.py --headless --import
python3 tools/godot.py --headless --script res://tests/test_player_movement.gd
python3 tools/godot.py --headless --max-fps 30 --script res://tests/test_player_movement.gd
python3 tools/godot.py --headless --max-fps 60 --script res://tests/test_player_movement.gd
python3 tools/godot.py --headless --max-fps 120 --script res://tests/test_player_movement.gd
# 실패 경로 확인: 의도적 실패 1건을 넣어 종료코드1을 확인한다.
python3 tools/godot.py --headless --script res://tests/test_player_movement.gd -- --inject-failure
```

한 번 실행에 약2분(실시간 물리 약 3,600틱 × 2회)이 걸린다. 자동 검사 범위는 AC-01~08, AC-09의 포커스 알림 경로, AC-10의 카메라 경계 계산, AC-11이다. 실제 앱 전환(AC-09), 창 크기 변경·화면 흔들림(AC-10), 키보드 조작감은 GUI 수동 확인이 필요하며 이 runner의 PASS로 대체하지 않는다. headless DisplayServer는 parse된 이벤트를 Viewport에 전달하지 않으므로 UI 소비 사례는 runner가 같은 이벤트를 `push_input`으로 전달한다.

## 테스트 맵 수동 실행

```sh
python3 tools/godot.py res://scenes/tests/movement_test.tscn
```

테스트 맵은 명시 경로로만 실행한다. export에서 tests 리소스를 제외하는 정책은 배포 단계에서 검증한다.
