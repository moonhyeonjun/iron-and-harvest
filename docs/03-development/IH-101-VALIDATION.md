# IH-101 플레이어 이동·충돌 검증 — 2026-10-31

## 결론

Claude Code가 [명세](../02-technical-design/PLAYER_MOVEMENT.md)대로 구현했고 AC-01~12 자동/수동 항목을 모두 실제 실행했다. 자동 runner는 4개 실행 변형에서 모두 PASS(종료0)였고, 실패 주입 시 종료1을 확인했다. GUI 수동 항목은 사용자가 실제 창과 키보드로 확인했다. 실행 중 발견한 macOS 시작 시 SCRIPT ERROR(BUG-001)는 수정했고 회귀 검사를 추가했다.

IH-101 상태는 **done**이다. [PR #4](https://github.com/moonhyeonjun/iron-and-harvest/pull/4)로 develop에 통합하고 원격 반영을 확인했다(아래 통합 기록). 속도96·물리60Hz·640×360·반지름6 등은 검증용 임시값이며 최종 밸런스·아트·해상도 결정이 아니다(ADR-012 Proposed 유지).

## 환경·대상

- macOS 13.4, MacBook Air M1(arm64), Godot `4.7.2.stable.official.ed1daf0bf` Standard, Compatibility(OpenGL 4.1 Metal).
- 브랜치 `feature/player-movement` ← develop `64928e5`. 커밋: `e9a0e03` 구현, `7cd97c1` runner, `571c1e9` BUG-001 수정+회귀 검사.
- 최종 자동 검사는 `571c1e9`과 같은 작업 트리에서 실행했다. 원시 로그는 git 무시 경로 `build/ih-101/clean/`에 있다.

## 실행 명령·결과

| 명령 | 종료 | 결과 |
|---|---:|---|
| `python3 tools/godot.py --headless --import` | 0 | 오류/경고0, project.godot 재작성 없음, `.gd.uid` 3개 생성 |
| `python3 tools/godot.py --headless --script res://tests/test_player_movement.gd` | 0 | AC-01~12 자동 330검사 PASS, 약2분5초 |
| 같은 명령 + `--max-fps 30` / `60` / `120` | 0 / 0 / 0 | 모두 PASS, 측정값 동일 |
| 같은 명령 + `-- --inject-failure` | 1 | 의도한 AC-11 실패1건만 보고(실패 경로 확인) |
| BUG-001 수정 전 controller로 같은 runner | 1 | AC-12 엔진 오류2건 검출(회귀 검사 유효성 확인) |
| `python3 tools/godot.py --headless --script res://tests/smoke_engine.gd` | 0 | Foundation smoke PASS |
| `python3 tools/godot.py --headless --quit-after 10` | 0 | 기본 Foundation 진입점 유지 |
| `python3 tools/godot.py --headless --quit-after 120 res://scenes/tests/movement_test.tscn` | 0 | 오류/경고0 |
| `python3 tools/godot.py res://scenes/tests/movement_test.tscn` (GUI) | 신호 종료 | 수정 후 시작 로그 SCRIPT ERROR0 |
| `python3 tools/validate_foundation.py` | 0 | 정적 계약 PASS |
| `python3 -m unittest discover -s tests -p 'test_*.py'` | 0 | 11개 OK |
| `python3 tools/check_economy.py` | 0 | 설계 검사7개 PASS |
| `git diff --check` | 0 | 공백 오류 없음 |

## AC별 결과

측정 기준: 시작 틱의 `physics_frame`에서 키를 누르고 N틱 뒤 좌표를 읽는다. 기록된 물리 프레임 수가 N과 일치했다. 허용 오차는 0.25다.

| ID | 결과 | 측정·관찰 | 확인 주체 |
|---|---|---|---|
| AC-01 | pass | Import 오류0. Player=CharacterBody2D(floating, layer2/mask1, platform layer0, pausable), 원점 원형 shape r6, Visual, 비활성 Camera2D. 맵에서 활성 카메라1, limit 0/0/1280/720, fixture 7개 rect·layer·표시 외곽이 명세표와 일치. 4액션 WASD physical·화살표 keycode·deadzone0.2. main_scene=Foundation | 자동 |
| AC-02 | pass | 4방향 120틱 거리 192.0007/192.0007/192.0007/191.9999, 비이동 축0, 해제 다음 틱 속도0·이동0 | 자동 |
| AC-03 | pass | 대각 4조합 길이192.0012(축별135.7654), 최대 속도96.0000. A+D/W+S/4키/←+→ 이동0, A+D+W는 위로48.0. W+↑, D+→, 4키 중복 모두 속도96 이하·거리 동일 | 자동 + 사용자 키보드 |
| AC-04 | pass | 같은 실행 안에서 cap 30/60/120: 물리120틱, process 프레임 61~62/121/243~244, 거리 모두192.0007(차0). CLI `--max-fps` 30/60/120 실행도 동일. headless 비교이므로 화면 부드러움 증거는 아님 | 자동 |
| AC-05 | pass | 접촉 좌표 x 22.0042 / 1257.9958, y 22.0042 / 697.9958. 이후 120틱 계속 눌러도 이동0, 관통0, 120틱 모두 idle | 자동 |
| AC-06 | pass | (560,360)→ 정면 정지 x593.9958. →+↑에서 Block 옆면(y≥280) 동안 x≤593.934, 미끄러짐 약96 u/s(아래 관찰), 60틱 뒤 모서리 통과 (602.73,268.70), 다음 60틱 (670.61,200.82). 모서리 대각 접근 이동 (33.9,175.8)로 고착 없음. 통로 860↔1100 양방향 y242 유지. 관통0 | 자동 + 사용자 GUI |
| AC-07 | pass | 시작 idle/down. 8개 입력에서 walk 30/30, 정지 후 facing 유지, 대각 동률은 좌/우. 표식 위치·회전 일치. 걷기 중 Body y −11.0~−10.0 흔들림, BodyCollision은 원점 고정. 벽을 밀면 idle, 미끄러지면 walk | 자동 + 사용자 GUI |
| AC-08 | pass | 이동 중 차단 즉시 속도0, 키 유지 20틱 이동0. 키 유지 재활성 이동0, neutral 1틱 뒤 새 입력 20틱=32.0. A+D 유지 재활성·A만 해제해도 이동0. 포커스 LineEdit가 키를 소비해도 Input 폴링은 pressed, 게이트 없으면 16.0 이동, 게이트 있으면0 | 자동 |
| AC-09 | pass | 자동: 알림 경로에서 포커스 아웃 이동0, 키 유지 복귀 이동0, 새 입력 16.0. 트리 진입 전 FOCUS_IN→OUT 순서 재현(BUG-001) 통과. 수동: 실제 Cmd+Tab 전환/복귀 정상 | 자동 + 사용자 GUI |
| AC-10 | pass | 논리 viewport 640×360. 내부 (400,360)에서 화면 중심=발 위치, 이동 중 틱별 차이0. 네 모서리·가장자리에서 view가 0..1280/0..720 안. 수동: 비16:9 리사이즈 시 왜곡 없이 여백만 생기고 깜빡임/떨림 문제 없음 | 자동 + 사용자 GUI |
| AC-11 | pass | 한 실행에서 새 맵 인스턴스로 suite 2회, 측정 17종 차이 0.000000. 고아 노드0, 이동 액션 잔류 없음. 새 프로세스 5개(기본·cap30/60/120·실패 주입)의 물리 측정 행이 모두 같다(렌더 의존인 process 프레임 수·흔들림 값 제외). 실패 주입 시 종료1. 중단된 case list는 실패로 집계 | 자동 |
| AC-12 | pass | 기존 검사 전부 통과, 외부 의존·채집·가방·저장·전투·NPC·UI 미추가. runner가 엔진/스크립트 오류를 Logger로 수집해 0건. 코드·문서 diff 검토 완료. develop 원격 반영 확인 완료(통합 기록) | 자동 + Claude 리뷰 |

## 수동 GUI 확인

- 확인 주체: **사용자**(실제 창·실제 키보드·육안). 2026-10-31. Claude는 화면 기록/보조 접근 권한이 없어 창을 직접 보거나 조작하지 못했다(ENV-003).
- 절차: 테스트 맵 창(1280×720)에서 ① WASD/화살표/W+↑/대각선/몸체 색·흔들림·표식, ② Block 정면·벽 따라 미끄러짐·모서리·통로·외곽, ③ D 유지 Cmd+Tab 전환→해제→복귀 및 유지 복귀, ④ 카메라 추적·모서리 limit·비16:9 리사이즈·깜빡임/떨림.
- 응답: "1~4 모두 정상". 항목별 메모는 없다.
- 이 확인은 `7cd97c1` 빌드에서 수행했다. 이후 `571c1e9`는 `_ready` 이전 Visual 갱신만 건너뛰며 ready 이후 동작은 같다. 수정 후 GUI 시작 로그 오류0은 Claude가 확인했지만 사용자 수동 조작은 다시 하지 않았다.
- 보조 증거: GUI 모드에서 엔진 viewport 프레임버퍼를 캡처했다(`build/ih-101/cap_*.png`). 스폰, 걷기 중 색·표식, 우하단 limit을 확인했다. OS 창 표시 증거는 아니다.

## 엔진 관찰·명세 차이

1. **벽 미끄러짐 속도**: Godot floating 모드는 첫 slide에서 남은 이동 길이를 유지한다. 그래서 Block을 →+↑로 밀면 투영 속도67.9가 아니라 약96 u/s로 벽을 따라 이동한다. 명세는 "벽을 따라 y감소"만 요구하므로 위반은 아니다. 이 조작감을 유지할지는 ADR-012 검토 항목으로 남긴다.
2. **macOS 포커스 알림 순서**: GUI 시작 시 APPLICATION_FOCUS_IN→OUT이 Player의 트리 진입 전에 오고, 약7프레임 뒤 FOCUS_IN이 다시 온다. 상태는 기록하고 Visual 갱신만 `_ready` 이후로 미룬다(BUG-001).
3. **headless 입력 전달**: `Input.parse_input_event`는 InputMap/폴링 상태를 갱신하지만 headless DisplayServer는 Viewport/UI로 이벤트를 전달하지 않는다. UI 소비 사례는 runner가 같은 이벤트를 `push_input`으로 전달한다.
4. **맵 중심**: (640,360)은 Block 내부이고 물리 엔진이 벽 밖으로 밀어낸다. 카메라 중심 추적 검사는 빈 바닥 (400,360)을 사용한다.
5. **AC-06 x≤594 범위**: 평평한 옆면(y≥280)에만 적용한다. y 274~280에서는 원형 발이 모서리를 돌며 x≈600까지 갈 수 있고, 이 구간은 관통 검사로 확인한다.
6. **카메라 지연**: Camera2D가 Player의 자식이고 physics callback을 쓰므로 같은 틱에 갱신된다. 측정 지연은 0이었다.

## 통합 기록

- [PR #4](https://github.com/moonhyeonjun/iron-and-harvest/pull/4): feature/player-movement(f7d2104) → develop, merge `6575a17636bf1449620e880813c0eaa99d1e904c`. GitHub API에서 merged=true, mergeable_state=clean, CI check 0개(IH-004 미도입) 확인.
- fetch 후 로컬 develop fast-forward, `git diff --exit-code f7d2104 6575a17` 동일 → 검증한 tree가 그대로 통합됨. 같은 tree라 물리 runner는 재실행하지 않았다.
- main은 변경하지 않았다(안정화 판단은 별도). v0.1.0 태그 유지, 새 태그/릴리스 없음.
