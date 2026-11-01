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

한 번 실행에 약2분(실시간 물리 약 3,600틱 × 2회)이 걸린다. 자동 검사 범위는 AC-01~08, AC-09의 포커스 알림 경로, AC-10의 카메라 경계 계산, AC-11이다. 실제 앱 전환(AC-09), 창 크기 변경·화면 흔들림(AC-10), 키보드 조작감은 GUI 수동 확인이 필요하며 이 runner의 PASS로 대체하지 않는다. `Input.parse_input_event` 후 `Input.flush_buffered_events()`가 headless에서도 이벤트를 Viewport로 동기 전달하므로 UI 소비도 같은 경로로 검사한다(2026-11-01 정정, BUG-002).

## test_interaction.gd — IH-102 상호작용

실제 InteractionTest 맵(이동 맵 인스턴스 + 안내판/상자 + UI)을 사용한다. Area2D 후보, 물리 질의, Control 입력 소비를 그대로 거친다. `support/probe_target.gd`는 begin/end 호출만 계측하는 테스트용 Target이며 아무것도 지급하지 않는다. suite를 새 맵으로 2회 반복하고 각 case 뒤 세션·이동 게이트·패널·키 잔류를 검사한다. 엔진/스크립트 오류가 하나라도 있으면 실패한다. 약25초.

```sh
python3 tools/godot.py --headless --script res://tests/test_interaction.gd
python3 tools/godot.py --headless --script res://tests/test_interaction.gd -- --inject-failure
```

실제 앱 전환, 키보드 감각, 비16:9 창 가독성은 GUI 수동 확인 대상이다.

## test_inventory.gd — IH-110 아이템·인벤토리

도메인 사례(AC-N01~09, N13)는 InventoryService를 직접 호출한다. 모든 실패 전후로 전체 snapshot·revision·이벤트 수를 비교하고, seed 1101의 400명령 수열을 독립 counts 모델로 확인한다. 장면 사례(AC-N10~12)는 실제 inventory_test 맵에서 키(Input parse+flush)와 마우스(viewport)를 사용한다. `fixtures/inventory/`의 JSON은 형식 비교용이며 런타임 원본이 아니다. 약8초.

```sh
python3 tools/godot.py --headless --script res://tests/test_inventory.gd
python3 tools/godot.py --headless --script res://tests/test_inventory.gd -- --inject-failure
```

실제 창 조작·가독성(AC-N14)은 GUI 수동 확인 대상이다.

## test_gathering.gd — IH-111 채집·자원 지점

도메인 사례는 GatherService/InventoryService로 모든 재고(가방·보관함·지점 stock) snapshot, revision, 변경 이벤트, 독립 합계를 비교한다. 장면 사례는 gathering_test 맵에서 실제 E/I/Escape 입력과 `support/gather_probe_target.gd`(try_begin 안 콜백)로 재검증·취소·commit 후 수명·재진입·rebind를 확인한다. `fixtures/gathering/`은 엔진이 조용히 정수화하는 수량 리터럴 거부를 확인하는 fixture다. 약19초.

```sh
python3 tools/godot.py --headless --script res://tests/test_gathering.gd
python3 tools/godot.py --headless --script res://tests/test_gathering.gd -- --inject-failure
```

## test_save_load.gd — IH-112 저장·복원

실제 파일을 사용한다. 실행마다 고유한 시험 전용 루트(`user://tests/ih112/runner_<pid>_<usec>/`)를 쓰고, 끝나면 자신이 만든 고정 이름 파일과 빈 폴더만 지운다. 제품 `user://saves`와 GUI 시험 루트(`user://tests/ih112/gui`)는 건드리지 않는다.
- codec 사례: 파일 전체 바이트를 decode한다.
- store 사례: 실제 SaveFileAdapter를 쓰거나, 같은 실제 파일에 읽기/쓰기/flush/rename 실패와 짧은 쓰기를 주입하는 하위 클래스를 쓴다.
- 장면 사례: SaveLoadTest에서 실제 F5/F9/E/I/이동 입력을 넣는다.
- AC-S13: `support/save_child.gd`로 별도 Godot 프로세스를 실행한다. 저장→종료→다른 프로세스 불러오기와, 저장 단계별 SIGKILL을 검증한다.

`fixtures/save/`는 정상 v1, 시험 v0, 미래 schema, content 2 파일이다. 약25초.

```sh
python3 tools/godot.py --headless --script res://tests/test_save_load.gd
python3 tools/godot.py --headless --script res://tests/test_save_load.gd -- --inject-failure
```

## 테스트 맵 수동 실행

```sh
python3 tools/godot.py res://scenes/tests/movement_test.tscn
python3 tools/godot.py res://scenes/tests/interaction_test.tscn
python3 tools/godot.py res://scenes/tests/inventory_test.tscn
python3 tools/godot.py res://scenes/tests/inventory_test.tscn -- --fixture=full
python3 tools/godot.py res://scenes/tests/gathering_test.tscn -- --fixture=full
python3 tools/godot.py res://scenes/tests/gathering_test.tscn -- --fixture=rebind
python3 tools/godot.py res://scenes/tests/save_load_test.tscn
python3 tools/godot.py res://scenes/tests/save_load_test.tscn -- --fixture=corrupt-latest
```

테스트 맵은 명시 경로로만 실행한다. export에서 tests 리소스를 제외하는 정책은 배포 단계에서 검증한다.
