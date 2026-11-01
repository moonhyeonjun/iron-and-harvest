# IH-101 수락 검사 계획

상태: **AC-01~12 실행 완료, 모두 pass**(2026-10-31, Claude Code 구현·자동 검사, GUI 수동 항목은 사용자 확인). AC-12의 develop 원격 반영은 [PR #4](https://github.com/moonhyeonjun/iron-and-harvest/pull/4)(merge 6575a17)로 확인했다. 측정값·명령·확인 주체는 [IH-101 검증 기록](IH-101-VALIDATION.md)에 있다. 아래 표의 기준은 Codex가 작성한 원래 계획이며, 판정은 그 기준을 넓히지 않고 적용했다.

기준: [구현 명세](../02-technical-design/PLAYER_MOVEMENT.md), [인수인계](IH-101-HANDOFF.md). 숫자는 임시 fixture/속도96/물리60Hz 기준이다. 게임 최종 밸런스와 다르다.

## 자동·수동 수락 조건

| ID | 절차·입력 | 통과 기준 | 방식 / 현재 |
|---|---|---|---|
| AC-01 | 고정 엔진 Import, Player와 MovementTest 로드·인스턴스화 | 파싱/리소스 오류0, Player는 CharacterBody2D, shape/Visual 존재, 카메라1개 활성, 기본 Foundation 진입점 유지 | 엔진 / pass |
| AC-02 | 네 방향 각각120물리 틱; 각 case 빈 공간에서 독립 시작 | 거리192±0.25, 비이동 축 오차≤0.25, 키 해제 다음 틱 속도0 | 물리 / pass |
| AC-03 | 대각선 네 조합 각각120틱; 반대 키·W와Up 등 중복키 | 대각 총거리192±0.25(축별 약135.765), 길이≤96.01, 양 반대 축0, 같은 방향 키 중복 가속 없음 | 물리+키보드 / pass |
| AC-04 | 동일120물리 틱을 렌더 cap30/60/120에서 수행 | 각 거리 차≤0.25, 렌더/실제물리 프레임 수 기록; 벽시계2초만으로 판단하지 않음 | 물리 / pass |
| AC-05 | 네 외곽에 직각으로 충분히 이동 후120틱 계속 누름 | 발 중심 x≥22−0.25, x≤1258+0.25, y≥22−0.25, y≤698+0.25; 접촉 후 이동≤0.25, 벽 내부/맵 밖 진입 없음 | 물리 / pass |
| AC-06 | Block 왼쪽(560,360)에서 오른쪽60틱, 이어 오른쪽+위60틱; 모서리/폭20통로 반복 | 정면 정지 x≤594+0.25, 벽을 따라 y감소, 모서리에서 벽 관통·영구고착 없음; 통로 중심y242에서 x860→1100 통과 | 물리+GUI / pass |
| AC-07 | 정지/이동/방향전환/대각선/벽누르기 | 최초idle/down, 정지 facing 보존, 동률 대각선 가로 우선, 막히면idle·미끄러지면walk; 표현 변경이 shape를 움직이지 않음 | 자동 상태+GUI / pass |
| AC-08 | 이동 중 control off, 키 유지한 채 on, 모두 해제 뒤 새 입력; 반대키 동시 유지도 검사 | 차단 즉시 속도0, 해제 전 재이동 없음, neutral 한 틱 뒤 새 입력 이동; UI가 이벤트를 소비해도 게이트가 이동 차단 | 경계 API / pass |
| AC-09 | 실제 창에서 키 유지→다른 앱으로 전환→키 해제→복귀; 키 유지 복귀도 검사 | 백그라운드 이동/복귀 급이동 없음, 새 입력으로 정상 복귀; 자동 입력 검사로 이 증거 대체 불가 | 수동 / pass(사용자) |
| AC-10 | 맵 중앙/네 모서리·경계 이동,1280×720과 비16:9창에서 확인 | 실제 camera view가0..1280/0..720 안, 내부는 중심 추적, 경계에서는limit, 확대/찌그러짐/원치 않는 줌 없음; 깜빡임/흔들림 관찰 기록 | 자동 경계+GUI / pass |
| AC-11 | 테스트 전체를 같은 실행에서2회 및 새 실행에서 반복 | 동일 허용 오차, 입력/노드/속도 누수 없음, 실패는 nonzero, pending 때문에 성공 처리하지 않음 | 자동 / pass |
| AC-12 | 정적/기존 회귀/코드·변경 범위 검토 | 기존 검사 통과, 외부 의존/채집·저장·전투 미추가, 문서/로그 갱신, Godot 오류0, 원격 반영 확인 | 리뷰 / pass |

## runner 작성 계약

game/tests/test_player_movement.gd는 SceneTree 기반 또는 동일하게 재현 가능한 최소 runner로 작성한다. 외부 프레임워크 선행 도입 없이 실제 Player 씬과 StaticBody2D fixture를 SceneTree에 넣고 물리 step을 실행한다. 수식만 복제한 테스트는 실제 move_and_slide 검사를 대신하지 않는다.

각 case는 shape가 겹치지 않는 시작 좌표와 방향, 입력, velocity, 게이트를 초기화한다. 입력 해제→한 틱 정착→측정 시작, 정확히N회 controller 물리 업데이트가 끝난 뒤 측정한다. physics_frame 신호의 처리 순서 때문에 첫/마지막 틱을 중복/누락하지 않도록 실제 step count를 기록한다. 물리 서버 반영을 기다린 뒤 좌표를 검사하고 테스트가 Player 이동을 두 번 호출하지 않게 한다.

AC-02/03은 (320,360)에서 시작하면192거리 이동이 fixture와 충돌하지 않는다. AC-04는 표시 cap와 physics60Hz를 분리한다. CI headless의 cap 비교는 물리 독립성 증거이며 실제 화면 부드러움 증거가 아니다. GUI30/60/120 실제 fps가 하드웨어 제한으로 나오지 않으면 요청 cap/관측 fps를 구분하고 미검증 구간을 기록한다.

스모크와 자동 회귀는 핵심 불변식·거리·경계·게이트·상태를 검사한다. 키보드 physical binding, 포커스, 실제 가독성은 GUI 수동 확인이 별도로 필요하다. GUI 접근이 없으면 해당 항목을pending으로 남기며 IH-101 done 처리하지 않는다.

## 구현 이후 실행 명령

모든 명령을 2026-10-31에 실행했다. 결과는 [검증 기록](IH-101-VALIDATION.md)에 있다. 실패 경로는 `-- --inject-failure`로 종료1을 확인한다.

```sh
python3 tools/validate_foundation.py
python3 -m unittest discover -s tests -p 'test_*.py'
python3 tools/check_economy.py
python3 tools/godot.py --headless --import
python3 tools/godot.py --headless --script res://tests/smoke_engine.gd
python3 tools/godot.py --headless --script res://tests/test_player_movement.gd
python3 tools/godot.py --headless --max-fps 30 --script res://tests/test_player_movement.gd
python3 tools/godot.py --headless --max-fps 60 --script res://tests/test_player_movement.gd
python3 tools/godot.py --headless --max-fps 120 --script res://tests/test_player_movement.gd
python3 tools/godot.py res://scenes/tests/movement_test.tscn
git diff --check
```

## 결과 양식·완료 판정

각 AC에 커밋/엔진·OS, 명령, 종료코드, 입력/틱·거리·오차 또는 관찰, 증거 경로, pass/fail/pending을 기록한다. raw 로그는 무시되는 build/ih-101/에 둘 수 있지만 핵심 측정값은 저장소의 검증 기록에 남긴다. screenshot 없이 육안 확인했다면 확인 주체를 명시한다.

AC-01~12 모두pass, 오류/회귀 해결, 코드 리뷰와 문서 일치 확인 후 IH-101 done. IH-102 상호작용은 별도이며 IH-101만으로 v0.2.0을 태그하지 않는다.
