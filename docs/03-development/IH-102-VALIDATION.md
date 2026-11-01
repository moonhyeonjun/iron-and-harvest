# IH-102 상호작용 대상·프롬프트 검증 — 2026-11-01

## 현재 판정 — Codex 후속 검토

2026-11-01, `29b2ed3` 추가 검사에서 BUG-003/004가 재현되어 IH-102를 review로 재개했다. 이후 아래 수정 검증과 [PR #12](https://github.com/moonhyeonjun/iron-and-harvest/pull/12) 통합으로 **done**에 복귀했다. 아래는 Claude Code 구현 당시의 검증 이력이며, 기존 299검사 PASS가 두 경계의 안전성을 입증하지는 않는다. 재현·수정 기준·전달 프롬프트는 [Codex 검토](IH-102-REVIEW.md)를 따른다.

## BUG-003/004 수정 검증 (2026-11-01, Claude Code)

브랜치 `fix/interaction-request-validation` ← develop `dc2a185`. 커밋: `aaac5da` 실패 회귀 추가, `0332b5a` 수정. 환경은 위와 같다(macOS 13.4 / M1, Godot 4.7.2 Standard). 원시 로그는 `build/ih-102-fix/`(Git 무시).

수정 내용:
- **BUG-003**: 중복 ID 규칙을 `_check_target`(`_has_usable_twin`)으로 옮겨 선택·요청 실행·활성 세션 재검증이 같은 정책을 쓴다. 사용 가능한 후보끼리 ID가 겹치면 모두 무효(INVALID_TARGET)다. 활성 세션은 열 때의 ID로 재검증하므로 ID가 바뀌거나 중복되면 다음 틱에 INVALID_TARGET으로 닫는다(end1, 게이트 복구). 검사는 Detector 후보 집합만 순회한다.
- **BUG-004**: `try_begin` 실행 중의 비활성화·포커스 상실·트리 이탈을 첫 취소 사유로 기록한다. 반환 후에는 제거·enabled·포커스·이동 게이트를 다시 보고, 그다음 대상을 재검증한다. 받아들였지만 시작할 수 없게 된 요청은 end(cancelled) 1회, rejected 1회로 끝나고 ACTIVE·패널·게이트 소유가 생기지 않는다. 비활성화 후 같은 호출 안에서 다시 활성화해도 DISABLED다. 전역 잠금·비동기 구조는 추가하지 않았다.

| 명령 | 빌드 | 종료 | 결과 |
|---|---|---:|---|
| Codex 재현 진단(IH-102-REVIEW의 gdscript 블록) | `dc2a185`(수정 전) | 1 | 위반2: 두 경우 모두 ACTIVE·패널·게이트 차단 |
| 같은 재현 | `0332b5a` | 0 | 위반0, 두 요청 모두 열리지 않고 control_effective=true |
| `python3 tools/godot.py --headless --script res://tests/test_interaction.gd` | `aaac5da`(회귀만 추가) | 1 | 새 사례 12종 모두 실패(26검사) |
| 같은 runner | `0332b5a` | 0 | 333검사 PASS, 2회 측정33종 차이0, 고아0, 엔진 오류0 |
| 같은 runner `-- --inject-failure` | `0332b5a` | 1 | 의도한 실패1건만 |
| 표적 변이: `_cancel_resolving(DISABLED)` 제거 | `0332b5a` 변형 | 1 | `disable_enable_in_begin` 실패. 반환 후 상태 재확인만으로는 부족함을 확인 |
| `python3 tools/run_ci.py` (깨끗한 worktree) | `0332b5a` | 0 | 10단계 PASS, IH-101 player 123.9초 PASS·엔진 오류0, interaction 29.6초 |

새 회귀 사례와 결과:

| AC | 사례 | 결과 |
|---|---|---|
| AC-I04 | E 캡처 뒤 같은 ID 후보가 available/visible로 바뀜 | INVALID_TARGET 1회, begin0/0, 열림0, 이후 선택 없음 |
| AC-I08 | try_begin 안에서 disable / disable 후 enable | DISABLED 1회, end(cancelled) 1회, 열림0, 패널 숨김, 다른 대상 begin0, 게이트 유지, 복구 후 새 E는 더 큰 ID로 정상 열림 |
| AC-I10 | 세션 중 활성 대상 ID 중복 / 이름 변경 | 다음 틱 INVALID_TARGET 종료, end1, 쌍둥이 begin0, 게이트 복구 |
| AC-I10 | try_begin 안에서 focus out / 트리 이탈(remove_child) | FOCUS_LOST / REMOVED 1회, end1, 열림0, 복구 후 새 E 정상 |
| AC-I10 | try_begin 안에서 Controller queue_free | REMOVED 1회, journal begin→end, 열림0, 게이트 유지 |

리뷰가 "직접 재현하지 않았다"고 남긴 포커스 상실·트리 이탈 변형도 수정 전 코드에서 같은 방식(ACTIVE·패널)으로 실패했다. 그래서 BUG-004에 포함해 수정했다.

GUI: **사용자**가 빌드 `0332b5a`에서 시작 프롬프트/오른쪽 상자, E 패널과 클릭·Enter·Escape 닫기, 패널 중 E 연타, 걸으며 E와 neutral, 패널 중 Cmd+Tab 복귀, 비16:9 리사이즈를 확인하고 "1~5 모두 정상"으로 응답했다. 이전 `3d99d36` 창은 종료한 뒤 새로 실행했으며 GUI 로그 오류는 0이다. 런타임 중복 ID·try_begin 재진입은 정상 화면 조작으로 만들 수 없어 자동 검사로만 확인했다.

판정: **done**. [PR #12](https://github.com/moonhyeonjun/iron-and-harvest/pull/12): `3225882` → develop, merge `e5d7730f1b858b22a5ba9ead1880fe1fd73a8641`(병합 전 mergeable_state=clean, base `dc2a185`, 보호 우회 없음). [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41269323346/job/124738634090) success: Ubuntu에서 10단계 PASS, 새 회귀 12종 결과가 로컬과 같다. [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41269551599/job/124739307741) success. 통합 tree는 `3225882`와 동일하다. main `64928e5`·v0.1.0은 변경하지 않았다.

## 구현 당시 결론

Claude Code가 [명세](../02-technical-design/INTERACTION.md)에 따라 InteractionController/Target/UI와 테스트 맵을 구현했다. AC-I01~12 자동 검사는 실제 씬·Area2D·물리 질의·UI 입력 경로로 통과했다. GUI 수동 항목은 사용자가 실제 창에서 확인했다. 공통 CI 실행기에 등록했으며 로컬의 깨끗한 worktree에서 전체 10단계 PASS를 확인했다.

IH-102 상태는 **done**이다. [PR #9](https://github.com/moonhyeonjun/iron-and-harvest/pull/9)의 필수 CI checks 성공 후 develop에 병합하고 원격 CI를 확인했다(아래 통합 기록). 거리32·정면 dot0.5·E/Escape·문구·패널 배치는 검증용 제안이며 최종 값이 아니다(ADR-014 Proposed 유지). 아이템 지급·가방·채집·대화 트리·상점·전투·저장·통치는 구현하지 않았다.

## 환경·대상

- macOS 13.4, MacBook Air M1, Godot `4.7.2.stable.official.ed1daf0bf` Standard, Compatibility(OpenGL 4.1 Metal).
- 브랜치 `feature/interaction-system` ← develop `82e2ba2`. 커밋: `95c723e` controller/target, `f89d812` UI/맵, `bcab854` runner, `4f69d80` IH-101 runner 이중 전달 수정(BUG-002), `5062a83` CI 등록, `3d99d36` 패널 여백, `bf8501b` 리뷰 수정(세션 종료 틱에 큐된 E를 BUSY로 보고).
- 원시 로그: git 무시 경로 `build/ih-102/`(runner, 변이, GUI 캡처).

## 실행 명령·결과

| 명령 | 종료 | 결과 |
|---|---:|---|
| `python3 tools/godot.py --headless --import` | 0 | 오류0, `.gd.uid` 6개 생성·추적 |
| `python3 tools/godot.py --headless --script res://tests/test_interaction.gd` | 0 | 299검사 PASS(`bf8501b`), 2회 반복 차이0, 고아 노드0, 엔진 오류0, 약25초 |
| 같은 명령 `-- --inject-failure` (`run_step`으로 판정) | 1 | 실패 사유: nonzero exit, engine error in log, missing completion marker |
| `python3 tools/godot.py --headless --script res://tests/test_player_movement.gd` | 0 | IH-101 회귀 12개 AC PASS(Controller 추가 후) |
| `python3 -m unittest discover -s tests -p 'test_*.py'` | 0 | 19개 OK(신규: suite 등록/마커/실패 출력 판정) |
| `python3 tools/run_ci.py` (깨끗한 worktree, `5062a83`) | 0 | 10단계 PASS. player 124.0초, interaction 24.5초. 최종 head는 PR 필수 CI로 확인 |
| `python3 tools/godot.py res://scenes/tests/interaction_test.tscn` (GUI) | 실행 중 사용자 조작 | 로그 오류0 |

변이 검사: controller에 결함을 하나씩 넣은 5개 worktree로 runner를 실행했다. 중복 ID 필터 제거→AC-I04, 세션 종료 시 게이트 미해제→AC-I04~I11 128건, 가시선 검사 제거→AC-I02/I05/I10, echo 허용→AC-I07 실패(모두 종료1). "누른 시점 캡처 대신 처리 시점 선택 사용"은 통과했다. 현재 처리 순서에서는 선택이 요청 처리 뒤에만 갱신되고 포커스 상실/비활성 경로는 큐를 함께 폐기하므로 두 값이 항상 같은 등가 변이다. 캡처는 처리 순서가 바뀔 때를 위한 방어로 유지한다.

코드 리뷰 수정: 세션이 닫히는 틱에 큐된 E가 결과 없이 지워지던 경계를 BUSY 보고로 고쳤다(`bf8501b`). 새 검사는 수정 전 controller에서 종료1(요청 결과 누락)로 실패하고 수정 후 통과했다.

## AC별 결과

측정 기준: `physics_frame` 재개(틱 시작, Player 0 → Controller 10 이전)에서 키 이벤트를 `Input.parse_input_event`+flush로 넣으면 같은 틱에 처리된다. 거리/각도 허용 오차는 넓히지 않았다.

| ID | 결과 | 측정·관찰 | 확인 주체 |
|---|---|---|---|
| AC-I01 | pass | Import 오류0. Controller는 Player 마지막 자식, Camera2D 인덱스2 유지, priority 10/0. Detector layer0/mask4/monitoring/not monitorable r32, Target layer4(값4)/mask0/monitorable r4·Anchor 원점, override 없음. layer_3 이름, interact=물리E, interaction_cancel=Escape keycode. main_scene Foundation. 시작 시 안내판, 오른쪽을 보면 상자 선택 | 자동·리뷰 |
| AC-I02 | pass | 거리31.9/32.0 선택, 32.1/35.9는 Detector 후보지만 미선택, 36.5는 후보 아님. 거리0은 위를 봐도 선택, 같은 지점 벽 안이면 미선택·E=NO_TARGET, 벽 제거 후 선택. 순간이동 진입2틱/이탈1틱, 걸어서 접근 시 32 이내 진입 틱=프롬프트 틱 | 자동 |
| AC-I03 | pass | 정면만 선택, 뒤/좌/우 미선택. 59°(dot 0.515038908) 선택, 60°(실측 0.500000298) 선택, 61°(0.484808475) 미선택. W+D→RIGHT, S+A→LEFT로 가로 대상 선택 | 자동 |
| AC-I04 | pass | 거리·dot 동률 3배치(생성 순서/좌우 반전) 모두 `tie_a`. 반올림 거리 동률은 정면 대상 우선. 더 가까운 빈 ID·중복 ID 후보를 건너뛰고 `unique` 열기. 맵 검수: EmptyId=EMPTY_ID, SignEntrance·SecondSign=DUPLICATE_ID, 시작 위치 선택 없음. 먼 대상은 후보 아님(전맵 검색 없음, 코드 리뷰도 후보 집합만 순회) | 자동·리뷰 |
| AC-I05 | pass | 사이 벽: 프롬프트 없음, E=NO_TARGET, begin0. 벽 제거 후 선택·열기. 사용 불가 대상의 Area가 사이에 있어도 뒤 대상 선택. Block 안 Anchor는 차단 | 자동 |
| AC-I06 | pass | E 후 같은 틱 처리 전 무효화: 범위 밖=OUT_OF_RANGE, queue_free/free/available=false/숨김=INVALID_TARGET. 대체 대상 begin0, 열림0. 더 가까운 대상이 생겨도 캡처 대상 열기. try_begin false=TARGET_REJECTED(end0), 호출 중 자기 삭제=INVALID_TARGET(end1). 게이트·패널 변화 없음, NULL 접근 오류0 | 자동 |
| AC-I07 | pass | 한 번 누름 begin1·opened1. ACTIVE 중 E=BUSY. 유지+echo8회 요청1, 같은 틱 두 번 누름 요청1, 닫기 버튼과 같은 틱의 E는 BUSY로 보고. 요청 ID 단조 증가. 자원 시스템이 없어 자원 변화 대상 없음 | 자동 + 사용자 키보드 |
| AC-I08 | pass | 포커스 LineEdit가 E를 소비(text 'e')하면 요청0. 외부 이동 차단 중 프롬프트 숨김·E=CONTROL_BLOCKED·패널 없음·외부 잠금 유지. 비활성 시 숨김·E=DISABLED·활성 세션 DISABLED 종료 | 자동 |
| AC-I09 | pass | 걸으며 E: 열린 틱에 velocity0, 20틱 이동0. Enter(닫기 버튼)=COMPLETED, end1(cancelled=false). S 유지 중 10틱 이동0, 해제→재입력 10틱 15.9998. Escape=CANCELLED. 이전 ID의 close/cancel/finish_active/UI close_session은 새 세션에 영향 없음 | 자동 + 사용자 GUI |
| AC-I10 | pass | ACTIVE 중 queue_free/숨김/비활성=INVALID_TARGET, 밀려남=OUT_OF_RANGE, 벽=OCCLUDED: 다음 틱 종료, 패널 숨김, 소유 게이트 해제. focus out=FOCUS_LOST(큐의 E도 FOCUS_LOST로 폐기), focus in 자동 재시작0, 선택 복귀. ready 이전 포커스 알림 오류0, 맵 트리 이탈·재진입 후 선택 정상, Controller 제거=REMOVED·end1·게이트 해제, 세션 중 맵 해제 오류0. 실제 앱 전환은 사용자 확인 | 자동 + 사용자 GUI |
| AC-I11 | pass | 프롬프트 'E 살펴보기 — 마을 안내판'/'… 보급 상자', 제목·설명 일치, 닫기 버튼 포커스, 패널 (190,120) 260×120이 640×360 안, 설명 2/2줄 표시, E→읽기→닫기 완주 후 프롬프트 복귀. UI 코드는 표시와 의도 신호만 가짐. 실제 창·비16:9 가독성은 사용자 확인 | 자동 + GUI·리뷰 |
| AC-I12 | pass | 2회 반복 측정24종 차이0, 고아0, 키·게이트 누수0(모든 case 종료 검사), 엔진 오류0, 실패 주입 종료1, IH-101 회귀·로컬 CI PASS. PR 필수 CI·develop push CI 성공, 원격 반영 확인(통합 기록) | 자동·리뷰 |

## 수동 GUI 확인

- 확인 주체: **사용자**(실제 창·키보드·마우스·육안), 2026-11-01, 빌드 `3d99d36`. 이후 `bf8501b`는 세션 종료 틱의 큐 보고와 트리 이탈 시 정리만 바꿨으며 사용자 수동 조작은 다시 하지 않았다.
- 절차: ① 시작 프롬프트·오른쪽 상자·멀어지면 숨김, ② E 패널·버튼 포커스·클릭/Enter/Escape 닫기·패널 중 E 연타/유지, ③ S 유지 중 E 즉시 정지·닫은 뒤 neutral, ④ 패널 연 채 Cmd+Tab 전환/복귀·자동 재열림 없음, ⑤ 비16:9 리사이즈 가독성.
- 응답: "1~5 모두 정상". 항목별 메모는 없다.
- Claude는 화면 기록/보조 접근 권한이 없어(ENV-003) 엔진 viewport 캡처로 한글 렌더링·패널 여백만 보조 확인했다(`build/ih-102/gui/`). OS 창 표시 증거는 아니다.

## 설계 차이·관찰

1. **headless 입력 경로 정정(BUG-002)**: `Input.parse_input_event`+`flush_buffered_events()`는 headless에서도 Viewport/UI로 이벤트를 동기 전달한다. IH-101 기록의 "전달하지 않는다"는 unicode 없는 이벤트로 오판한 것이다. 그래서 수락 문서가 제안한 `root.push_input` 추가 전달은 이벤트를 두 번 보낸다. 두 runner 모두 한 번만 전달하도록 고쳤다.
2. **패널 노드 경로**: InspectPanel은 PanelContainer이고 Title/Description/CloseButton은 `InspectPanel/Layout`(VBoxContainer) 아래에 있다. 여백 StyleBox를 추가했다.
3. **reason 추가**: 외부 이동 차단은 `CONTROL_BLOCKED`, Controller 제거는 `REMOVED`. 나머지는 명세 목록과 같다.
4. **Escape 처리**: UI는 패널이 보일 때 `_shortcut_input`에서 먼저 처리한다. Controller의 `interaction_cancel`은 취소할 것이 있을 때만 소비하는 예비 경로이며, 그 외 Escape는 다른 기능을 위해 남긴다.
5. **ID 검수 API**: 맵 검수가 `reject_registration(reason)`을 호출하고 Target은 `is_registered()`로 선택 가능 여부를 알린다. 런타임에 추가된 대상은 Controller의 후보 중복 검사가 막는다.
6. **프롬프트와 neutral**: 명세대로 `Player.is_control_effective()`가 거짓이면 프롬프트를 숨긴다. 이동 키를 누른 채 패널을 닫으면 키를 뗄 때까지 프롬프트가 보이지 않고 E는 CONTROL_BLOCKED가 된다.
7. **한글 글꼴**: 별도 글꼴 자산 없이 엔진 기본 글꼴의 시스템 fallback으로 표시된다. 다른 OS/배포 빌드의 글꼴 포함 여부는 IH-006 아트/UI 규격에서 결정한다.
8. **단일 게이트 한계**: 세션 중 외부가 이동을 다시 막으면 Player 게이트는 이미 닫혀 있어 구분되지 않고, 종료 시 Controller가 자신의 해제를 수행한다. 명세대로 다중 모달 조율은 후속 설계이며 이번에 검사하지 않았다.

## 통합 기록

- [PR #9](https://github.com/moonhyeonjun/iron-and-harvest/pull/9): feature/interaction-system(`8c8414c`) → develop, merge `318fcd20911023d57585befce10f5bc153b0a252`. 병합 전 GitHub API mergeable_state=clean, base `82e2ba2`(strict 충족). 보호 규칙 우회·강제 push 없음.
- [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41266988871/job/124731789818): Ubuntu 24.04 / Godot 4.7.2에서 10단계 PASS, `interaction-acceptance`·`player-acceptance` 모두 `RESULT: PASS`, 엔진 오류0. 앞선 head `0737e39`의 실행은 새 push로 cancelled(concurrency 설정).
- [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41267229659/job/124732455905): develop push(`318fcd2`) CI checks success. ls-remote develop=`318fcd2`.
- 통합 tree는 검증한 `8c8414c`와 동일(`git diff --exit-code`). main(`64928e5`)과 v0.1.0 태그는 변경하지 않았다. v0.2.0 태그/릴리스는 별도 검토 대상이다.
