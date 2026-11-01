# 주간 개발 기록

## 2026-10-31 — Foundation 구축

- 작업: IH-001, 환경 확인 IH-002.
- 목표: 관리 체계·문서·Git 규칙·빈 Godot 기반, 게임 기능 제외.
- 관찰: 기존14파일 보존 대상, Git 최초 커밋 전 main, origin 기설정.
- 변경: feature/project-foundation으로 작업 HEAD 전환. main/develop ref는 아직 없음.
- 산출물: 새 문서 체계, 규칙4개, GitHub 템플릿4개, ADR9개, 로컬 작업26개, 정적 검증기와 회귀 테스트, 빈 Node 씬.
- 신규 게임 콘텐츠/기능: 없음.
- 커밋/원격 Issue/PR: 없음. 로컬 TASKS와 PR_DRAFT로 관리.
- 테스트: 최종 실행 결과를 아래에 기록한다.
- 미완료: 엔진 실행/버전 고정, LICENSE 선택, 실제 브랜치 기준점/릴리스.
- 기술 부채: 이전 초안과 새 문서 공존; 현재 기준/참고 원문을 명시.
- 다음 목표: IH-002 엔진 검증 후 IH-101 이동·충돌.

## 다음 주 기록 양식

목표(기능/버그/콘텐츠/기술 개선), 작업ID, 빌드·브랜치·실제 커밋 또는 없음, 구현 완료, 신규 콘텐츠, 테스트 명령/환경/결과, 버그/부채, 미완료, 다음 목표를 적는다. 실행하지 않은 항목은 미실행으로 남긴다.

## 실제 실행 결과

- 환경: Git2.39.3 (Apple Git-145), Python3.9.6, 엔진 버전 미확인.
- 정적 Foundation 검사: 필수42파일/경로/문서/의존성/ignore 통과, 종료0.
- unittest: 6개 통과, 종료0.
- 기존 경제 설계 검사: 7개 통과, 종료0.
- 파일 보존: 기존12파일 불변, README/CLAUDE 원문 archive 동일.
- git diff --check: 종료0. untracked 파일은 별도 내용/whitespace 검토.
- 엔진 실행/게임 플레이/성능: 미실행, IH-002 blocked.
- IH-001: review 유지. v0.1.0 전체는 엔진 검증 전이며 done/tag 처리하지 않음.
- 상세 결과와 전체 파일 목록: [구축 보고](FOUNDATION_REPORT.md), [manifest](FILE_MANIFEST.md).

## 2026-10-31 — Git 자율 운영 후속

- IH-007: 최신 사용자 정책으로 Git/GitHub 작업의 반복 승인 절차 제거, 안전 규칙 유지.
- 기존80파일 목록 일치, 정적 검사/6개 회귀/7개 경제 가정 검사 통과.
- 최초 커밋: 957dd3bbdf564c04636b7be082d800f89a458524 — chore(foundation): establish project structure and development workflow.
- 최초 원격 refs0개, fetch 성공. main/develop 기준점 로컬 생성.
- IH-001 문서/관리 리뷰 완료; IH-002 엔진 검증 blocked 유지.
- 정책 문서 수정 중 작업 표 행 손상을 정적 검사가 검출하여 커밋 전에 수정했다. 최종 재검사 결과로 통합 여부를 판단한다.
- 원격 반영 결과는 GIT_BOOTSTRAP과 후속 기록으로 남긴다.

### 원격 동기화 확인

- 정책 커밋: 8ce8d1d50518d7d229eb25b51a1ffd135453de20 — chore(git): adopt autonomous repository workflow.
- feature/project-foundation → develop → main fast-forward 통합, 충돌 없음.
- main/develop/feature/project-foundation atomic 비강제 push 성공, 세 upstream 설정.
- ls-remote 재조회: 원격 HEAD=main, 세 브랜치 SHA=8ce8d1d50518d7d229eb25b51a1ffd135453de20, 로컬과 일치.
- IH-007 완료. 원격 초기 이력이 없어 PR은 생략. 태그/릴리스 없음; 엔진 미검증 상태 유지.
- 최종 검증 결과를 문서 커밋으로 별도 기록하고 원격에 반영한다. 이 문서 기록 커밋의 해시는 작업 완료 보고와 Git 이력에서 확인한다.

## 2026-10-31 — IH-002 엔진 환경 검증

- 목표/범위: 엔진 버전·Import·Headless·GUI 검증, 게임플레이 제외.
- 설치: Downloads의4.7.2 서명/버전 확인 후 ~/Applications/Godot-4.7.2.app에 복사, 기존4.4.1/4.7.2 보존.
- 결과: 4.7.2.stable.official.ed1daf0bf, Compatibility/Apple M1, Import/Headless/GDScript smoke/GUI editor+project 모두0.
- GUI: CUA 도구 서비스 오류. 사용자가 “두 창 모두 정상 표시됨” 확인. 자동 스크린샷 검증은 없음.
- 기반: 고정 버전 실행기·타입 GDScript smoke·.uid 추가. Python11개 통과, 문서/정적 검사 통과.
- IH-002 done, ENV-001 resolved, IH-004 ready. Codex 설계/기술·Claude Code 기능 구현 역할 명시.
- 다음: Claude Code 인수인계용 IH-101 명세, 또는 IH-004 CI. Windows/export/성능은 미검증.
- 상세 명령/증거: [IH-002 검증](IH-002-VALIDATION.md). Git 반영은 후속 기록.

### IH-002 통합·Foundation 기준점

- 작업 커밋5cadb74de45c2c3d1f8faeb8e3c5be00b69d2ec7 원격 push 완료.
- PR #1 병합: develop=87b6a19bce9c61225bdc1eb15044618645694cab.
- PR #2 병합: main=fd376d22b2e5a1566d9e97ef3caa231394eb6977. 두 병합 모두 GitHub API에서 성공 확인 후 fetch.
- 통합 tree와 검증한 작업 branch의 내용 일치, 충돌/강제 push/기존 이력 재작성 없음.
- 결과 기록 문서를 docs/ih-002-results에서 정리. Foundation 완료 태그 v0.1.0 생성 대상으로 판단하며 코드 변경 없이 최종 문서 commit을 포함한다. 실제 ref/원격 SHA 확인은 완료 보고와 Git 이력에 남긴다.
- CUA 화면 서비스 실패는 사용자 정상 표시 확인으로 보완. Python API TLS는 시스템 CA 사용으로 해결. 엔진 오류는 발견되지 않음.
- 게임플레이/Windows/export/제품 릴리스는 미구현 또는 미검증. 다음 Codex 작업은 IH-101 구현 명세 또는 IH-004 CI.

## 2026-10-31 — Foundation 확정 및 IH-101 설계

- 시작: develop clean, origin fetch, main/develop 모두d176bd7094db783c2aaf43b2ee227936a5137758.
- Foundation: 기존 annotated v0.1.0 객체7488fc92e681e1695d9cad0fb793e33afebd6a27, peeled target=d176bd7, ls-remote 일치. 중복 생성/이동 없음.
- 브랜치: docs/ih-101-player-design. Codex는 문서만 변경, 게임플레이·project.godot 변경 없음.
- 재실행: 정적42파일 검사, unittest11개, 경제 설계7개, Godot4.7.2 version/import/headless/smoke 모두종료0. GUI는 재실행하지 않고 IH-002 사용자 확인 증거 유지.
- 산출물: Player 씬/모듈/키/8방향 이동·4방향표현/물리/게이트/카메라/충돌 fixture/확장 명세, 수락12항목, Claude 인수인계, ADR-012 Proposed.
- 상태: IH-001/002 done 유지, IH-101 ready(설계 준비·미구현). AC-01~12 모두미실행. IH-102는 backlog 유지.
- 버그/기술 부채: 새 결함 없음. ENV-003 자동 화면 도구 문제는 기존 documented, Windows/Export/게임 성능은 미검증.
- 다음: Claude Code IH-101 구현·실제 물리/GUI 검사. Codex IH-004 CI 또는 구현 리뷰.
- Git commit/통합·원격 검증은 후속 기록으로 남긴다.

### IH-101 명세 통합 결과

- 설계 커밋: e4b6f3144cc1f33feebad3e764a5e2caab273cea — docs(player): specify IH-101 and verify foundation baseline.
- [PR #3](https://github.com/moonhyeonjun/iron-and-harvest/pull/3): docs/ih-101-player-design → develop, merge1043f9e0e3a4834118fa4b66aebe684433794e14. GitHub API merged=true 확인.
- main은 검증된 develop로 fast-forward 반영 후 push. ls-remote에서 두 브랜치1043f9e 일치 확인.
- 통합 tree는 검증한 명세 커밋과 동일. game/tools/tests/.godot-version은 v0.1.0과 변경 없음.
- v0.1.0 객체7488fc9/대상d176bd7 원격 재확인, 태그 변경 없음. 새 태그/제품 릴리스 없음.
- 결과 기록은 docs/ih-101-results의 별도 문서 커밋으로 통합한다. 해당 기록 커밋 자체의 최종 SHA는 Git 이력과 완료 보고에서 확인한다.

## 2026-10-31 — IH-101 플레이어 이동·충돌 구현 (Claude Code)

- 시작: develop clean, origin/develop=64928e5. `feature/player-movement` 신규 분기(로컬/원격 기존 브랜치 없음). 사용자 변경 없음.
- 환경: macOS 13.4 / M1, Godot 4.7.2.stable.official.ed1daf0bf Standard, Compatibility(OpenGL 4.1 Metal).
- 구현: Player(controller·Visual·Camera2D), 테스트 맵, InputMap/화면/물리/레이어 설정, 물리 수락 runner. 빈 매니저·Autoload·외부 의존 없음.
- 커밋: e9a0e03 feat, 7cd97c1 test, 571c1e9 fix(BUG-001).
- 자동: runner 기본/`--max-fps` 30/60/120 모두 종료0(각 330검사, 약2분), `-- --inject-failure` 종료1, 수정 전 controller에 대한 runner 종료1. 5개 프로세스 물리 측정 동일, 한 실행 2회 차이0.
- 회귀: import·smoke·`--quit-after 10`·테스트 맵 headless·validate_foundation·unittest11·check_economy7·`git diff --check` 모두 종료0, 로그 오류/경고0.
- 수동 GUI: 사용자가 실제 창·키보드로 키 입력/충돌/포커스 전환/카메라·리사이즈를 확인하고 "1~4 모두 정상"으로 응답(7cd97c1 빌드). Claude는 화면 기록·보조 접근 권한이 없어(ENV-003) 엔진 viewport 캡처로 렌더링만 보조 확인.
- 관찰: floating 벽 미끄러짐 약96 u/s(투영67.9 아님), macOS 포커스 알림이 `_ready` 전에 도착(BUG-001), headless는 입력을 Viewport로 전달하지 않음. 측정 중 runner 자체 오류 2건(투영 속도 가정, process 프레임 시점 입력)을 발견해 판정 기준을 넓히지 않고 측정 시점·구간을 바로잡음.
- 결과: AC-01~12 pass, IH-101 review. 상세: [IH-101 검증](IH-101-VALIDATION.md). develop PR 통합·원격 확인은 후속 기록. v0.2.0 태그/릴리스 없음.

### IH-101 통합 결과

- [PR #4](https://github.com/moonhyeonjun/iron-and-harvest/pull/4) feature/player-movement → develop, merge 6575a17636bf1449620e880813c0eaa99d1e904c. API merged=true, CI check 없음(IH-004 미도입).
- 로컬 develop fast-forward, 통합 tree = 검증 커밋 f7d2104 tree. IH-101 done, AC-12 원격 반영 확인.
- 앱 PR 추적 연결은 `gh` CLI 부재로 실패(기능 영향 없음). main 미변경, v0.1.0 유지, v0.2.0 태그/릴리스 없음.
- 다음: Codex의 IH-102 상호작용 명세 또는 IH-004 CI. ADR-012 Accepted 여부와 벽 미끄러짐 속도는 설계 검토 항목.

## 2026-10-31 — IH-101 Codex 기술 재검토

- 대상 develop48aee7e, clean/원격 일치. 구현 branch f7d2104와 game/ 동일.
- 코드/씬/AC 검사 후 기능 수정을 요구할 결함 없음. 정적검사·Python11개·Godot Import·Foundation smoke·물리 runner 재실행 모두종료0.
- runner 출력은360검사/실패0/엔진오류0, 반복2회 측정17종 차이0. 앞선 Claude 기록330개와 달라 검증 보고서의 집계를 정정했다.
- GUI 재실행 없음. 사용자 확인은 기존7cd97c1 빌드의 기록으로 구분. ready 이전 포커스 수정은 자동 회귀 통과.
- 문서만 수정: 검증보고/주간기록과 LIFE_SYSTEM/CLAUDE/ADR-012의 현재 상태. 게임 기능/밸런스/ADR 상태 변경 없음.
- IH-101 done 유지. 다음 Codex 설계 후보는 IH-102; IH-004 CI도 후속. main/v0.1.0 유지, 새 태그/릴리스 없음.
- 검토 기록은 docs/ih-101-technical-review에서 커밋하고 검증 후 develop에 통합한다. 기록 커밋 해시와 원격 결과는 Git 이력/완료 보고를 따른다.

## 2026-10-31 — IH-004 CI 완료

- 시작 develop cd06f94 clean. feature/ci-foundation commit547b117, PR #6 merge e50a8a283310b54be6eeaa81cd25da1b8c033a86. 게임 코드 변경 없음.
- 구현: 공식 Action SHA·엔진 ZIP SHA-256 고정, 읽기 전용 CI checks, 공통 실행기/오류·timeout 판정, 실패 로그7일보존.
- 로컬9단계/Python17개/경제설계7개/물리360개 통과. 원격 PR run41210930155와 통합 push run41211192044 success.
- 실패 검증: 별도 PR #7 run41210992257은 의도한 unittest1개 실패, artifact 확인. required CI 적용 후 mergeable_state=blocked. PR은 미병합closed. 실험 이력 보존.
- develop/main 보호: CI checks(GitHub Actions app15368), strict/admins 적용, force/deletion 금지 확인. 기본 main 파일/태그는 미변경, 수동 workflow_dispatch는 다음 main 승격 후 사용.
- IH-004 done, ADR-013 Accepted. 상세 [검증 기록](IH-004-VALIDATION.md). 기존 GUI/Windows/Export/Steam 범위는 그대로 별도.
- 순서: CI 완료를 확인했으므로 이후 IH-102 상호작용 명세를 Codex가 작성한다. 구현은 Claude Code 담당.

## 2026-10-31 — IH-102 상세 설계

- IH-004의 PR/실패 차단/develop push 성공 확인 후 시작. 구현 순서는 사용자 요청을 따른다.
- 산출물: INTERACTION.md, IH-102-ACCEPTANCE/HANDOFF, ADR-014 Proposed, TDD/아키텍처/생활/작업 진입점 갱신.
- 설계: 대상 후보/정면각/가시선/동률, 입력 큐와 실행 시 재검증, 프롬프트/살펴보기, 취소·수명·이동 게이트, 향후 보상 도메인 경계.
- IH-102 ready. AC-I01~12는 모두미실행. 게임플레이 코드/씬/InputMap 미변경, 기존 IH-101 보존.
- 문서 링크·구조·diff 검사를 수행하고 필수 CI를 거쳐 PR로 통합한다. 신규 기능 테스트 통과로 기록하지 않는다.
- 다음: Claude Code가 인수인계 프롬프트에 따라 IH-102 구현·자동/GUI검증. v0.2.0 태그는 구현 완료 후 별도 판정.

## 2026-11-01 — IH-102 상호작용 구현 (Claude Code)

- 시작: develop clean(82e2ba2, origin 일치), untracked `AGENTS.md`(사용자 Codex 지침)는 보존·미커밋. `feature/interaction-system` 신규 분기.
- 환경: macOS 13.4 / M1, Godot 4.7.2.stable.official.ed1daf0bf Standard, Compatibility.
- 구현: InteractionController/Target/UI, 테스트 맵·ID 검수, InputMap/layer_3, runner·probe target, CI 등록. Autoload·이벤트 버스·보상 로직 없음.
- 커밋: 95c723e, f89d812, bcab854, 4f69d80(BUG-002), 5062a83(ci), 3d99d36(style), bf8501b(리뷰: 종료 틱 큐 요청 BUSY 보고).
- 자동: test_interaction 종료0(최종 299검사, 2회 차이0, 고아0, 엔진 오류0, 약25초). 실패 주입 종료1, `run_step` 실패 사유 3종. IH-101 runner 종료0. unittest 19개 OK. 깨끗한 worktree의 `run_ci.py` 10단계 PASS(첫 시도는 worktree 안의 출력 파일 때문에 source-tree-clean 실패, 출력 위치 변경 후 재실행).
- 변이 5종: 4종 검출(AC-I04/I02·I05·I10/I07/전반), 캡처 대체 변이는 현재 처리 순서상 등가로 통과(이유는 검증 기록).
- 발견: headless 입력이 Viewport로 전달됨(BUG-002, IH-101 기록 정정). 맵 해제 중 트리 밖 버튼 release_focus 엔진 오류는 커밋 전에 수정. probe 탐침의 `_initialize` 직후 @onready nil·자기 셸을 끈 pkill 패턴은 제 스크립트 오류.
- 수동 GUI: 사용자가 3d99d36에서 프롬프트/전환/패널/Enter·Escape/E 연타/걷는 중 E/neutral/Cmd+Tab/비16:9를 확인하고 "1~5 모두 정상". Claude는 엔진 viewport 캡처로 한글 렌더링과 패널 여백만 보조 확인(ENV-003).
- 결과: AC-I01~12 pass, IH-102 review. PR 필수 CI·develop 통합은 후속 기록. v0.2.0 태그/릴리스 없음.

### IH-102 통합 결과

- [PR #9](https://github.com/moonhyeonjun/iron-and-harvest/pull/9) 8c8414c → develop, merge 318fcd20911023d57585befce10f5bc153b0a252. 병합 전 mergeable_state=clean.
- [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41266988871/job/124731789818) success(10단계 PASS, interaction/player 모두 RESULT: PASS). 이전 head 0737e39 실행은 cancelled. [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41267229659/job/124732455905) success.
- 통합 tree = 검증 커밋 8c8414c. IH-102 done. main·v0.1.0 미변경, v0.2.0 태그/릴리스 없음(별도 검토).
- 앱 PR 추적 연결은 `gh` CLI 부재로 사용하지 않고 GitHub API로 CI를 확인했다.
- 다음: v0.2.0 마일스톤 판정 검토(Codex), ADR-012/014 Accepted 여부, IH-110 아이템/인벤토리 명세.

## 2026-11-01 — IH-102 Codex 기술 재검토

- 대상 develop/origin `29b2ed3`, 추적 변경 없음. 사용자 미추적 AGENTS.md는 보존·미커밋.
- 기존 전체 CI 재실행: clean detached worktree, `python3 tools/run_ci.py` 10단계 PASS/종료0. Python19, 이동360, 상호작용299검사. Import/smoke/runtime 오류0, 반복2회 측정24종 차이0·고아0. 원격 동일 SHA run41267694674 success 확인.
- 추가 실제 입력·씬·물리 진단에서 BUG-003(실행 시 중복 ID), BUG-004(RESOLVING 중 disable) 재현: 종료1, 두 경우 모두 ACTIVE/패널=true. 엔진 오류 없음. 기존 suite에 없는 경계이며 기존 PASS로 덮지 않는다.
- IH-102 done→review 재개, v0.2.0/ADR Accepted 판단 보류. Codex는 게임 코드/씬/CI를 바꾸지 않았고 [검토·수정 프롬프트](IH-102-REVIEW.md)를 작성했다. Claude의 다음 작업은 두 결함 수정과 기존 runner에 회귀 편입이다.
- GUI 새 실행/조작 없음. 과거 사용자 확인(3d99d36)과 이번 자동 재검증을 구분한다.
- 문서: 리뷰/수락/인수인계/검증/TASKS/BUGS/CHANGELOG 및 README·TDD·생활·ADR 상태 표기 정리.
- 현재 사용자 작업 트리 정적 검사에는 AGENTS.md의 없는 .Codex/rules 링크4개가 실패한다. 사용자 파일은 그대로 두고 커밋된 clean worktree의 검사 결과와 구분했다.
- 로그: build/ih-102-codex-review/ (Git 무시). docs/ih-102-technical-review에서 문서 커밋·필수 PR CI 후 develop 통합 예정. 실제 SHA/PR 결과는 Git 이력 및 최종 보고를 따른다. main/v0.1.0 보존, 태그/릴리스 없음.

## 2026-11-01 — IH-102 BUG-003/004 수정 (Claude Code)

- 시작: develop clean(dc2a185, origin 일치), 사용자 untracked AGENTS.md 보존·미커밋. `fix/interaction-request-validation` 분기.
- 재현: Codex 진단 종료1(위반2) 확인 후 runner에 회귀 12종 추가. `aaac5da`에서 종료1, 26검사 실패.
- 수정 `0332b5a`: 중복 ID 규칙 일원화(선택·실행·활성), 활성 세션 ID 고정 재검증, try_begin 중 취소 사유 기록과 반환 후 제어기 상태 재검사.
- 검증: 재현 종료0, runner 333검사 PASS(2회 차이0, 고아0, 엔진 오류0), 실패 주입 종료1, 표적 변이(disable 기록 제거) 검출, 깨끗한 worktree run_ci 10단계 PASS(IH-101 포함).
- GUI: 사용자, 빌드 0332b5a, "1~5 모두 정상". 이전 3d99d36 창 종료 후 재실행. 런타임 중복 ID·재진입은 화면 조작으로 만들 수 없어 자동 검사로만 확인.
- 범위: 전역 잠금·새 게임플레이·아이템/인벤토리/채집 미추가. main·v0.1.0 미변경, v0.2.0·ADR Accepted는 별도 판단.
- 다음: PR 필수 CI와 develop 통합 후 IH-102 done 기록.

### BUG-003/004 통합 결과

- [PR #12](https://github.com/moonhyeonjun/iron-and-harvest/pull/12) 3225882 → develop, merge e5d7730f1b858b22a5ba9ead1880fe1fd73a8641(mergeable_state=clean). [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41269323346/job/124738634090) success(10단계, 새 회귀 12종 로컬과 동일). [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41269551599/job/124739307741) success.
- 통합 tree = 3225882. BUG-003/004 resolved, IH-102 done 복귀. main·v0.1.0 미변경, v0.2.0·ADR-014 Accepted는 별도 판단.

## 2026-11-01 — BUG-003/004 Codex 수정 재검증

- 대상 develop/origin `69561ca`. 추적 변경 없음, 사용자 미추적 AGENTS.md 보존. game/tools/tests/.github는 수정 빌드0332b5a와 동일.
- 원래 재현 스크립트 종료0/위반0: 두 요청 모두 패널·ACTIVE=false, 이동 가능=true. 수정 코드와 추가 회귀를 검토했고 추가 수정이 필요한 결함 없음.
- clean worktree `python3 tools/run_ci.py` 종료0/10단계 PASS: Python19, 이동360, 상호작용333. 반복2회 측정33종 차이0·고아0·엔진 오류0. 로그 build/ih-102-fix-codex-review/ci/.
- PR #12/#13 merged, develop run41270032260 success 확인. GUI 새 조작 없음; 0332b5a 사용자 확인 기록을 구분해 사용했다. 실패 주입/변이는 Claude 기록으로 유지, 재실행하지 않음.
- BUG-003/004 resolved와 IH-102 done 유지. 게임 코드/씬/엔진/CI는 변경하지 않고 리뷰/검증/작업/버그/주간 기록 및 README·HANDOFF의 완료된 수정 안내를 정리했다.
- docs/ih-102-fix-verification에서 문서 커밋·필수 PR CI 후 develop 통합. 실제 SHA와 PR 결과는 Git 이력 및 최종 보고를 따른다.
- 다음 설계 후보: v0.2.0 마일스톤 판정, IH-110 아이템·인벤토리 명세. main/v0.1.0·ADR Proposed 유지, 새 태그/릴리스 없음.

## 2026-11-01 — v0.2.0 Character 판정

- 시작 develop/origin35c70dd, 사용자 미추적 AGENTS.md 보존. main64928e5는 develop의 조상이고 기존 이력을 덮어쓸 필요가 없다. local/remote v0.2.0 없음, v0.1.0 보존 확인.
- 기존 마일스톤의 작은 맵 이동/대상 조작, IH-101/102 수락 조건을 대조해 기능 판정 PASS. BUG-001~004 resolved.
- 기존 독립 검사(Python19·이동360·상호작용333·전체10단계) 이후 실행 코드 변경 없음을 git diff로 확인했다. 같은 로컬 전체 검사는 반복하지 않고 문서 정적 검사 및 보호 규칙의 PR/main CI를 수행한다.
- GUI는 기존 사용자0332b5a 확인 기록을 사용한다. 단일 게이트·배포 글꼴·라이선스·최종 조작값은 판정표에서 후속 범위로 구분했다. ADR-012/014 Proposed 유지.
- 변경 문서: Character 판정표, MILESTONES/TASKS/README/CHANGELOG/ROADMAP/ADR 색인/주간 기록. 게임 코드·씬·CI 설정 미변경.
- Git 계획: 문서 PR→develop→main PR, main CI 성공 후 annotated v0.2.0 태그와 원격 검증. 이후 main 이력/발행 기록을 develop에 동기화한다. 실제 SHA/PR/CI는 실행 후 기록한다.
- 다음: IH-110 상세 설계. 제품 실행파일·GitHub Release·Steam 게시 없음.

### v0.2.0 발행 결과

- 문서66aa9b7 → PR #15(필수 CI run41272503689 success) → develop61b2813. develop push run41272701901 success.
- PR #16(develop→main) CI run41272706472 success, main merge `8901bac890393defbfdf438bc2e5b36d7c94b2a3`. 원본61b2813과 tree 동일. main push run41272930692 success.
- annotated `v0.2.0`: 객체 `6a322acfa3b5f825f1877b9ebe0ac82eda39b2c6`, 대상 `8901bac890393defbfdf438bc2e5b36d7c94b2a3`. 생성·push 후 ls-remote의 객체/peeled ref와 로컬 tag 타입/대상을 대조해 일치 확인. 기존 v0.1.0 보존.
- main의 workflow 반영에 맞춰 CI 운영 문서를 갱신했다. workflow_dispatch 정의는 있지만 수동 실행 검증을 주장하지 않는다.
- docs/v0.2.0-publication에서 실제 발행 기록과 main 이력을 develop에 PR로 동기화한다. 태그 이후 문서 기록을 위해 태그를 이동하지 않는다.
- 게임 코드/씬 변경 없음, 제품 실행파일·GitHub Release/Steam 게시 없음. IH-110 상세 설계가 다음 작업이며 아직 backlog다.

## 2026-11-01 — IH-110 상세 설계 (Codex)

- 시작 develop/origin `2b4b9aa`, 이전 develop push CI run41273410068 success 확인. 사용자 미추적 AGENTS.md 보존, 추적 변경 없음.
- docs/ih-110-inventory-design에서 명세·AC-N01~14·Claude 인수인계·ADR-015 Proposed 및 기획/기술/작업 진입점을 작성했다. IH-110 ready, 기능 구현/신규 AC는 미실행.
- 계약: Resource 기본안/JSON 샘플 비교, 고정 슬롯·원자 add/remove/transfer·revision·독립 snapshot, 가방/살펴보기 배타적 조율, 유한 fixture. 최종 품목/슬롯/수치는 TBD. 채집·파일 저장·범용 잠금은 범위 밖이다.
- 기존 코드의 try_begin 이후 취소 가능성과 단일 bool 이동 게이트를 확인하여 지급 분리/모달 배타성/콜백 취소 관문을 명세에 포함했다. DEBT-002는 해결로 바꾸지 않는다.
- 문서 정적 검사·diff 검토 후 보호된 PR CI를 통과하여 develop에 통합한다. 실제 검증/커밋/PR 결과는 후속 기록과 Git 이력으로 확인한다. main/v0.2.0/게임 코드·씬·CI 설정은 변경하지 않는다.
- 다음: Claude Code가 IH-110-HANDOFF의 프롬프트로 구현하고 신규 검증 보고에 자동/GUI 결과를 남긴다.

### IH-110 설계 검증

- 사용자 작업 트리 `python3 tools/validate_foundation.py`: 종료1, 미추적 AGENTS.md의 기존 .Codex/rules 링크4개만 실패. 사용자 파일은 변경/커밋하지 않는다.
- 동일16개 문서 변경을 반영한 별도 detached worktree에서 정적 검사 종료0: 필수42파일·디렉터리·Markdown 링크/펜스·리소스 경로·작업 그래프·ignore 규칙 PASS. `git diff --check` 통과.
- 게임/도구/테스트/CI 파일 변경 없음. 신규 인벤토리 검사와 GUI는 미실행이며 기존 회귀는 필수 PR CI에서 확인한다.

## 2026-11-01 — IH-110 아이템·인벤토리 구현 (Claude Code)

- 시작: develop clean(3803bc7, origin 일치), 사용자 untracked AGENTS.md 보존·미커밋. `feature/inventory-system` 분기. 게임 코드는 IH-102 수정 이후 변경 없음.
- 구현: 정의/카탈로그·상태·서비스(b7efab6), 조율자·UI·맵(05cd2b3), runner·fixture(2a085e2), CI 등록(311a742), 시험 창 제목(025c863).
- 형식 비교: JSON은 stack_limit을 float로 읽고 키·숫자·문법 검사를 따로 구현해야 함. .tres는 int 유지. .tres + catalog.tres를 런타임 원본으로 선택. ResourceSaver가 기본값과 같은 stack_limit을 생략하는 것을 발견해 기본값을 0(무효)으로 바꿈.
- 자동: test_inventory 375검사 PASS(2회 차이0, 고아0, 엔진 오류0, 약8초). 실패 주입 종료1. 변이 10종과 엔진 오류 전용 변이 모두 검출. unittest 19. 깨끗한 worktree run_ci 11단계 PASS(이동 360, 상호작용 333 회귀 포함).
- GUI: 사용자, 빌드 025c863, 일반·FULL 두 창, "1~5 모두 정상", 두 창 exit0·로그 오류0. Claude는 viewport 캡처로 배치만 보조 확인(ENV-003).
- 결과: AC-N01~14 pass, IH-110 review. ADR-015 Proposed 유지(형식 선택 근거 기록). 제품 결함 없음. DEBT-002/003 유지. PR 필수 CI·develop 통합은 후속 기록. main/태그/릴리스 없음.

### IH-110 통합 결과

- [PR #19](https://github.com/moonhyeonjun/iron-and-harvest/pull/19) 160ca9e → develop, merge f26a77e66d9d63f9dd9216eae4f82d71fb28bde7(mergeable_state=clean). [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41276480044/job/124759576975) success(11단계, 세 suite RESULT: PASS·엔진 오류0). [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41276740036/job/124760326722) success.
- 통합 tree = 160ca9e. IH-110 done. ADR-015 Proposed 유지(Accepted 판단은 별도). main·태그·릴리스 미변경.
- 다음: IH-111 채집과 자원 지점(재고 NO_SPACE와 지점 소진의 단일 완료 경계), ADR-015 Accepted 판단.

## 2026-11-01 — IH-110 Codex 기술 검토

- 대상 develop/origin14302e5, 사용자 미추적 AGENTS.md 보존. 원격 run41277180799 success 확인.
- clean detached worktree에서 공통 CI 종료0/11단계 PASS: Python19·경제7·이동360·상호작용333·인벤토리375. 인벤토리 반복45종 차이0·고아0·엔진 오류0.
- 추가 경계 진단 종료1/위반3: UI.queue_free 및 service.close 콜백 뒤에도 OPEN/게이트 소유(BUG-005), 끝 개행 ID가 유효하고 catalog/register 성공(BUG-006). 즉시 UI.free 진단은 _show에서 엔진 signal11 충돌을 기록했다. 혼합 스택 키는 정상 INVALID_SNAPSHOT. 세부 및 진단 종료 경고는 [리뷰](IH-110-REVIEW.md).
- IH-110 done→review, BUG-005/006 open, ADR-015 Proposed 유지. 기존 PASS/통합 기록은 보존한다. GUI 새 조작/변이 재실행 없음; 이전025c863 사용자 GUI 확인과 구분한다.
- docs/ih-110-technical-review에서 리뷰·재현·Claude 수정 프롬프트와 작업/검증 진입점만 갱신한다. 게임 코드·씬·테스트·CI 설정·main/태그는 변경하지 않는다. PR 검증 후 develop 통합, 실제 커밋/원격 결과는 PR 이력·완료 보고로 기록한다.
- 다음: Claude Code의 두 결함 수정·실패 회귀 편입·GUI 확인·필수 CI. 이후 Codex 재검증 및 IH-111 상세 설계 판단.

- 리뷰 문서 변경을 별도 worktree에 반영해 정적 검사 PASS(필수42파일/링크/경로/작업/ignore)를 확인했고 diff --check도 통과했다. 원래 사용자 트리 검사는 AGENTS.md의 기존 링크4개 때문에 종료1이며 해당 파일을 변경하지 않았다.

## 2026-11-01 — IH-110 BUG-005/006 수정 (Claude Code)

- 시작: develop clean(65cda09, origin 일치), 사용자 untracked AGENTS.md 보존·미커밋. `fix/inventory-lifecycle-and-id-validation` 분기.
- 재현: Codex 진단 종료1(위반3). 회귀 추가(5004419) 후 runner는 free_ui에서 signal 11 충돌, free_ui를 임시로 빼면 25실패.
- 수정 fb5cd0c: 조율자의 UI/서비스 수명 재검사(열기 콜백 뒤·틱마다·전환/요청 전), 죽은 UI 호출 방지. ID는 문자 단위 전체 검사.
- 검사 보완 a714c5a/8dfe8bb: 변이 m2/m3가 통과해 OPEN 사례의 경로 공백을 발견하고 보완. 변이 파싱 오류 시 Godot 종료0을 확인(공통 CI는 마커·로그로 실패 처리), 변이 판정에 마커 확인 추가.
- 검증: 재현 종료0, runner 521검사 PASS, 실패 주입 종료1, 표적 변이 5종 검출, 깨끗한 worktree CI 11단계 PASS(360/333/521).
- GUI: 사용자, 빌드 8dfe8bb, "1~4 모두 정상", 로그 오류0. UI 삭제·서비스 종료·개행 ID는 자동 검사로만 확인.
- 다음: PR 필수 CI·develop 통합 후 IH-110 done 기록. main/태그/릴리스 미변경.

### BUG-005/006 통합 결과

- [PR #22](https://github.com/moonhyeonjun/iron-and-harvest/pull/22) 5f8bb51 → develop, merge cbb836b40f37a0f29173e541005529229ff037e4(mergeable_state=clean). [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41278706636/job/124766026102) success(11단계, 새 회귀 로컬과 동일). [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41278935113/job/124766685853) success.
- 통합 tree = 5f8bb51. BUG-005/006 resolved, IH-110 done 복귀. ADR-015 Proposed 유지. main·태그·릴리스 미변경.

## 2026-11-01 — BUG-005/006 Codex 수정 재검증

- 대상 develop/origin a5cefeb, 사용자 미추적 AGENTS.md 보존. game/tools/tests/.github는 사용자 GUI 확인 빌드8dfe8bb와 동일.
- 리뷰의 원래 재현을 그대로 실행해 종료0/위반0. UI 삭제·서비스 종료 모두 열기 거부/CLOSED/게이트 미소유/Player 이동 가능. 개행 ID는 validator·catalog 거부, register INVALID_ARGUMENT.
- clean detached worktree `python3 tools/run_ci.py`: 종료0, 11단계 PASS. Python19·경제7·이동360·상호작용333·인벤토리521. 반복54종 차이0·고아0·엔진 오류0. 로그 build/ih-110-fix-codex-review/.
- 수정 코드와 새 회귀 검토: 추가 수정 요청 없음. BUG-005/006 resolved·IH-110 done 유지. GUI/변이는 새로 실행하지 않고 Claude의8dfe8bb 사용자 확인·표적 변이 기록과 구분했다.
- docs/ih-110-fix-verification에서 검증·리뷰·수락·인수인계·작업·문제 기록과 현재 안내를 갱신한다. 게임 코드/씬/테스트/CI/main/태그는 변경하지 않는다. PR 필수 CI 후 develop 통합, 실제 SHA/원격 결과는 PR 이력과 완료 보고로 기록한다.
- 다음 설계 후보: IH-111 채집·자원 지점. ADR-015 Proposed 및 기존 부채 유지.

- 재검증 문서12개를 별도 worktree에 반영해 정적 검사 PASS, diff --check PASS를 확인했다. 사용자 AGENTS.md는 수정/커밋하지 않았다.

## 2026-11-01 — IH-111 채집·자원 지점 상세 설계(Codex)

- 기준 develop/origin de0c163, develop CI41280063347 success. 사용자 미추적 AGENTS.md 보존. docs/ih-111-gathering-design에서 설계 문서만 변경한다.
- 기존 Interaction 실행/취소와 Inventory 원자 transfer·수명 수정 코드를 검토했다. 지점 숨은 재고→bag 전송, 단발 준비 명령, commit 전후 취소 경계, 뷰 재진입 보존을 제안한다.
- 신규 GATHERING/AC-G01~14/HANDOFF/ADR-016과 관련 진입점 갱신. 세 종류 즉시 채집으로 범위를 제한하고 도구/시간/재생/파일 저장은 후속으로 남긴다.
- IH-111 backlog→ready(상세 설계 완료), 구현·신규 검사·GUI 미실행. ADR-016 Proposed, IH-110 done 유지. 게임/씬/테스트/CI 설정/main/태그 변경 없음.
- 검증은 문서 정적 검사·diff 검토와 필수 PR CI로 진행한다. 실제 결과는 아래 후속 기록 및 PR 이력에서 확인한다.
- 다음: Claude Code가 IH-111-HANDOFF 전달용 프롬프트로 구현·AC 검증 후 인계. 이후 Codex 리뷰, IH-112 저장 상세 설계는 별도 작업이다.

### IH-111 설계 검증

- 사용자 루트 정적 검사 종료1: 미추적 AGENTS.md의 기존 .Codex/rules 링크4개만 실패. 해당 파일은 보존·미커밋한다.
- 변경18파일만 복사한 detached worktree 정적 검사 종료0: 필수42파일/디렉터리/링크·펜스/리소스 경로/작업 그래프/ignore PASS. git diff --check PASS.
- 게임/도구/테스트/CI 설정 변경 없음. 신규 채집 검사·GUI는 미실행. 기존 회귀는 보호된 PR CI에서 확인하며 실제 커밋/PR/CI 결과는 PR 이력과 완료 보고에 기록한다.

## 2026-11-01 — IH-111 채집·자원 지점 구현 (Claude Code)

- 시작: develop clean(fe6a293, origin 일치), 사용자 untracked AGENTS.md 보존·미커밋. `feature/gathering-system` 분기. 게임 코드는 IH-110 수정 이후 변경 없음.
- 사전 측정: int 타입 Resource 필드가 .tres의 2.5/true/"3"을 조용히 2/1/3으로 로드 → GatherCatalog 원본 리터럴 검사, IH-110 영향은 DEBT-004로 기록.
- 구현: 14a2687(정의·서비스), 24bf870(Interaction INSTANT), 5a5f5f5(Target·맵·HUD), 03c6a65(runner), a56ab1d(CI), 7787c26(테스트 순환 수정).
- 개발 중 발견: runner 정리 코드가 해제된 Controller를 타입 변수에 대입해 G09 코루틴이 중단 → 남은 맵이 같은 물리 공간에서 중복 ID를 만들어 이후 사례가 연쇄 실패. 정리 코드 수정과 남은 맵 가드 추가. 공통 CI가 종료 시 ObjectDB 146 누수로 실패 → 테스트 lambda의 자기 서비스 캡처 순환을 해제로 고침(제품 코드는 탐침으로 누수 0 확인).
- 검증: test_gathering 309검사 PASS(2회 차이0, 고아0, 엔진 오류0, 누수 경고0). 실패 주입 종료1. 표적 변이 7종 검출. 깨끗한 worktree CI 12단계 PASS(360/333/521/309).
- GUI: 사용자, 빌드 7787c26, normal/full/rebind 창, "1~5 모두 정상", full·rebind exit0·오류0.
- 결과: AC-G01~14 pass, IH-111 review. ADR-016 Proposed 유지. PR 필수 CI·develop 통합은 후속 기록. main/태그/릴리스 없음.

### IH-111 통합 결과

- [PR #26](https://github.com/moonhyeonjun/iron-and-harvest/pull/26) c036f90 → develop, merge 42e3f4b230bd901a6fdab1122e592ed809822ccf(mergeable_state=clean). [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41283403152/job/124779743066) success(12단계, 네 suite RESULT: PASS·엔진 오류0·누수 경고 없음). [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41283663628/job/124780504085) success.
- 통합 tree = c036f90. IH-111 done. ADR-016 Proposed 유지. main·태그·릴리스 미변경.
- 다음: IH-112 초기 저장과 복원(지점 결속·숨은 stock 포함 snapshot), DEBT-004 결정, ADR-015/016 Accepted 판단.

## 2026-11-01 — IH-111 Codex 기술 검토

- 기준 develop/origin c266d52, 원격 CI41284249678 success. 미추적 사용자 AGENTS.md 보존. docs/ih-111-technical-review에서 문서만 변경한다.
- 추가 진단: GatheringHUD.free 시 gathering_test146행 signal11/launcher250. queue_free는 첫 거래 bag9/stock5 성공·오류0, 다음 E에서 같은 충돌(BUG-007).
- 내장 GatherDef의 initial_quantity 2.5/true/"3"은 각각2/1/3으로 로드·compile=true/build=OK. 분리 진단 종료1/위반3/엔진 오류0(BUG-008).
- 원시 진단/로그 build/ih-111-codex-review/. GUI·표적 변이는 새로 실행하지 않았다. 기존7787c26 사용자 GUI 확인과 구분한다.
- IH-111 done→review, BUG-007/008 open, ADR-016 Proposed 유지. 리뷰·수정 프롬프트·작업/수락/검증/인수인계 진입점을 갱신한다. 게임/씬/테스트/CI 설정/main/태그는 변경하지 않는다.
- 다음: Claude Code 수정·실패 회귀 편입·표적 변이·GUI·필수 PR CI, 이후 Codex 재검증. IH-112 상세 설계는 별도 작업이다.

- 독립 공통 CI 종료0/12단계 PASS: Python19·경제7·이동360·상호작용333·인벤토리521·채집309, 반복22종 차이0·고아0·엔진 오류0. 기존 suite 통과와 새 재현 실패를 구분한다.
- 리뷰 문서13개를 반영한 별도 worktree 정적 검사 PASS, diff --check PASS. 사용자 루트는 AGENTS.md의 기존 링크4개만 실패하며 사용자 파일은 보존한다. 필수 PR CI 후 문서만 develop에 통합하고 실제 SHA/CI/원격 결과는 PR 이력과 완료 보고에 기록한다.

## 2026-11-01 — IH-111 BUG-007/008 수정 (Claude Code)

- 시작: develop f51ede5(origin 일치), 사용자 미추적 AGENTS.md 보존·미커밋. `fix/gathering-hud-and-definition-validation` 분기.
- 재현(수정 전): Codex 진단 4종을 그대로 실행(`build/ih-111-fix/before_*.log`).
  - HUD.free 후 E: exit 250(signal 11)
  - queue_free 첫 E: bag 9/stock 5 성공(FAIL 1)
  - 다음 E: exit 250
  - 내장 2.5/true/"3": compile/build 성공(FAIL 3)
- 실패 회귀 28e5a80: runner가 AC-G01 내장·경로 없음에서 실패하고, AC-G09 HUD 사례에서 exit 250으로 충돌.
- 수정:
  - 56b7d5b: HUD 수명 가드, 외부 .tres 전용 원본 정책
  - b5afd93: HUD fixture 이름 표시
- 검증:
  - `python3 tools/godot.py --headless --script res://tests/test_gathering.gd`: exit 0, 347검사 PASS, 2회 차이 0·고아 0·엔진 오류 0
  - `--inject-failure`: exit 1
  - 진단 4종: 수정 후 exit 0
  - 변이 5종 검출(가드 3곳 제거는 exit 250, 내장/경로 없음 허용은 AC-G01 FAIL). 구문 오류 0
  - 깨끗한 worktree CI: 56b7d5b 12단계 PASS(360/333/521/347), b5afd93 12단계 PASS(360/333/521/347, 누수 경고 0)
- GUI: 사용자, b5afd93, normal/full/rebind.
  - 첫 시도(56b7d5b)에서 "다 normal로만 3개창이 떴다"는 보고가 있었다. 인자·제목·full 합계(목재 16·석재 114)는 정상이었으나 화면 구분 표시가 부족해 HUD fixture 표시를 추가했다.
  - 재확인 결과 "1~5 모두 정상", 세 창 exit 0·오류 0.
- 결과: BUG-007/008 fixed(통합·Codex 재검증 대기), IH-111 review 유지, ADR-016 Proposed. DEBT-004 미변경. main/태그/릴리스 없음. PR/CI/merge 결과는 PR 이력과 후속 기록에 남긴다.

### BUG-007/008 통합 결과

- [PR #29](https://github.com/moonhyeonjun/iron-and-harvest/pull/29) 1010bde → develop, merge ed554c59a56581f6dc3e76a2bbaa9b684df7918f(mergeable_state=clean).
- [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41293472692/job/124809362090) success: 12단계, 360/333/521/347, 네 suite RESULT: PASS, 누수 경고 없음.
- [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41293774055/job/124810245717) success.
- 통합 tree = 1010bde. main(8901bac)·태그·릴리스 미변경.
- 다음: Codex 독립 재검증(BUG-007/008 resolved, IH-111 done 판정), 이후 IH-112 초기 저장과 복원.

## 2026-11-01 — BUG-007/008 Codex 수정 재검증

- 대상 develop/origin1cb3471, 동일 SHA 원격 CI41294351856 success. 사용자 미추적 AGENTS.md 보존. game/tools/tests/.github는 사용자 GUI 확인 빌드b5afd93과 동일하다.
- 원래 진단4종을 수정 없이 재실행해 모두 종료0/RESULT: PASS. HUD free/queue_free/다음 E 충돌0·bag9/stock5 보존, 내장3종 compile=false/build=INVALID_SETUP, 엔진 오류0.
- clean detached worktree `python3 tools/run_ci.py`: 공통 CI 종료0/12단계 PASS: Python19·경제7·이동360·상호작용333·인벤토리521·채집347. 채집 반복2회 측정26종 차이0·고아0·엔진 오류0. 로그 build/ih-111-fix-codex-review/.
- 코드·회귀 검토: 추가 수정 요청 없음. BUG-007/008 resolved·IH-111 done 복귀. GUI/변이는 새로 실행하지 않고 Claude의b5afd93 사용자 확인·변이5종 기록과 구분했다.
- docs/ih-111-fix-verification에서 검증/리뷰/수락/인수인계/작업/문제 기록과 현재 안내만 갱신한다. 게임 코드·씬·테스트·CI 설정/main/태그는 변경하지 않는다. 필수 PR CI 후 develop 통합, 실제 SHA/CI/원격 결과는 PR 이력과 완료 보고에 기록한다.
- 다음 설계 후보: IH-112 초기 저장·복원. ADR-016 Proposed와 기존 부채는 유지한다.

- 검증 문서14개를 별도 worktree에 반영해 정적 검사 PASS, diff --check PASS를 확인했다. 사용자 루트 검사는 AGENTS.md의 기존 링크4개만 실패하며 해당 파일을 수정/커밋하지 않았다.

## 2026-11-01 — IH-112 초기 저장·복원 상세 설계(Codex)

- 기준 develop/origin8913c0d, 원격 CI41295810029 success. 기존 tracked/staged 변경 없음, 사용자 미추적 AGENTS.md 보존. docs/ih-112-save-load-design에서 문서만 변경한다.
- 기존 Player/모달·Interaction 실행 수명, Inventory snapshot/정수 검사, Gather build/stock 초기 지급을 검토했다. JSON/FileAccess/DirAccess 공식 API를 확인하고 실제4.7.2/OS 측정을 구현 관문으로 둔다.
- SAVE_LOAD·AC-S01~16·HANDOFF·ADR-017 작성. 단일 수동 슬롯 A/B 두 세대, 버전/정규화/checksum, 손상 시 명시 복구, 초기 지급 없는 restore·후보 세션 publish·epoch를 제안한다.
- TASKS IH-112 backlog→ready(상세 설계), IH-110/111 done 유지. 게임/씬/테스트/CI/main/태그 변경 없음. 신규 저장 기능·검사·GUI는 미구현/미실행이다.
- 문서 정적/diff와 필수 PR CI로 검증한다. 실제 결과는 아래 후속 기록과 PR 이력에 남긴다.
- 다음: Claude Code가 IH-112-HANDOFF 프롬프트로 구현·AC 검증, 이후 Codex 기술 검토. v0.3.0 판정은 구현·통합 이후 별도 작업이다.

### IH-112 설계 검증

- 사용자 루트 정적 검사: 기존 미추적 AGENTS.md의 .Codex/rules 링크4개만 실패(종료1). 사용자 파일은 수정/커밋하지 않는다.
- 변경16문서만 복사한 detached worktree 정적 검사 종료0: 필수42파일/디렉터리/Markdown 링크·펜스/리소스 경로/작업 그래프/ignore PASS. git diff --check PASS.
- 게임 코드/씬/도구/테스트/CI 설정 변경 없음. 신규 저장 자동/GUI는 미실행이며 기존 회귀는 필수 PR CI로 확인한다. 실제 커밋/CI/merge/원격 결과는 PR 이력과 완료 보고에 기록한다.

## 2026-11-01 — IH-112 초기 저장·복원 구현 (Claude Code)

- **시작**: develop 4b31ed4(origin 일치), 사용자 미추적 AGENTS.md 보존·미커밋. `feature/save-load-system` 분기.
- **4.7.2 탐침**
  - JSON 숫자 float, 2^53 정밀도, 1e400→inf+경고, trailing comma 허용, 중복 키는 마지막 값.
  - 실수 왕복 시 마지막 자리 변동, Vector2 float32.
  - SHA-256(UTF-8), rename 교체, get_buffer 정확 길이, 잘못된 UTF-8 메시지.
  - PAUSABLE Player는 DISABLED 부모 아래에서도 처리됨. 비활성 body/area는 물리에서 제거. 비활성 Button은 클릭 없음. Camera2D 비탈취.
- **구현 커밋**:
  - 9fce058: restore와 읽기 전용 검사
  - e213eff: codec과 store
  - 9985a63: 조율자, 시험 장면, UI
  - 09e5273: runner와 CI 등록
  - 438ef89: fixture 창 표시
- **개발 중 발견·수정**(커밋 전)
  - 해제된 후보를 타입 변수에 대입해 오류가 남.
  - 완료 신호 리스너가 거부를 받으면 다시 보고되어 무한 재귀가 남 → 보고 중 거부는 반환만 한다.
  - 같은 프레임 suspend/resume 뒤 Detector 후보가 한 틱 비어 E가 NO_TARGET이 됨 → live 월드 물리를 KEEP_ACTIVE로 유지하고, 물리 모드를 process보다 먼저 바꾼다.
  - 이미 waitpid된 자식에 `is_process_running`을 불러 오류가 남.
- **검증**
  - runner: exit 0, 425검사, 2회 차이 0, 고아 0, 엔진 오류 0(INF 기대 경고 4). `--inject-failure`는 exit 1.
  - 변이 7종 모두 검출(구문 오류 0).
  - 기존 suite 360/333/521/347 PASS. Python 19 OK.
  - 깨끗한 worktree CI(438ef89): 13단계 PASS, 저장 suite 23.4초, 누수 경고 0.
- **GUI**: 사용자, 438ef89, `user://tests/ih112/gui`.
  - 창 1(저장 1~5세대, F9 복원, BUSY, 복구 버튼)과 창 2(재시작 뒤 F9 5세대)는 로그·응답으로 확인했다.
  - 창 3(corrupt-latest) 첫 인스턴스는 약 90초간 fixture를 적용하지 못했다(원인 미확인, 재실행 시 정상).
  - 사용자가 "앞으로는 사용자 테스트는 진행하지 않는다"고 답해 절차 6은 미실행이다.
- **결과**: AC-S01~15 pass, AC-S16 부분, IH-112 review, ADR-017 Proposed. main/태그/릴리스 없음. PR/CI/merge 결과는 후속 기록에 남긴다.

### IH-112 통합 결과

- [PR #33](https://github.com/moonhyeonjun/iron-and-harvest/pull/33) 81214e4 → develop, merge 3ab4795723344d162e74e91657920b7127e9068a(mergeable_state=clean).
- [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41302107156/job/124835042247) success: Linux 13단계 360/333/521/347/425. 저장 suite의 rename·SIGKILL·재시작 검사가 ext4에서도 PASS, 누수 경고 없음.
- [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41302454648/job/124836057429) success.
- 통합 tree = 81214e4. IH-112 review 유지(AC-S16 절차 6 미실행). ADR-017 Proposed. main(8901bac)·태그·릴리스 미변경.
- 다음:
  - IH-112 review 해소: AC-S16 절차 6 확인 방법 결정(사용자 GUI 중단 지시 반영).
  - Codex 기술 검토.
  - v0.3.0 판정은 별도로 한다.

## 2026-11-01 — IH-112 Codex 기술 검토

- 대상 develop/origin b13292b, 원격 CI41303127354 success, 미추적 AGENTS.md 보존. docs/ih-112-technical-review에서 문서만 변경한다.
- clean detached worktree 공통 CI 종료0/13단계 PASS: Python19·경제7·이동360·상호작용333·인벤토리521·채집347·저장425. 저장 반복15종 차이0·고아0·엔진 오류0. INF fixture 예정 경고4건은 기존 정책대로 별도 계수.
- 추가 진단: SaveUI free/queue_free 뒤 F5 signal11/exit250(BUG-009). 거부 보고 중 nested save OK·A1 생성(exit1, BUG-010). STAGING의 지연 request_open 뒤 FOCUS_LOST 복귀 시 OPEN/게이트 소유(exit1, BUG-011). 후자 엔진 오류0.
- 진단/로그 build/ih-112-codex-review/. 고유 시험 루트만 접근, 제품 saves/사용자 GUI 파일 미접근. 새 GUI/변이는 미실행이며 기존 사용자 부분 확인과 구분한다. 추가 사용자 테스트 중단 기록을 존중한다.
- 세 결함 open·IH-112 review·ADR-017 Proposed 유지. 리뷰·수정 프롬프트·수락/검증/작업 진입점을 갱신한다. 게임/씬/테스트/CI 설정/main/태그 변경 없음.
- 다음: Claude Code의 실패 회귀·최소 수정·자동 검증·필수 PR CI, 이후 Codex 재검증. AC-S16 손상복구 GUI 미확인을 자동 통과로 바꾸지 않는다. v0.3.0 판정은 별도다.

- 리뷰 문서14개를 별도 worktree에 반영해 정적 검사 PASS, diff --check PASS. 사용자 루트는 AGENTS.md의 기존 링크4개만 실패하며 해당 파일은 보존·미커밋한다. 필수 PR CI 후 문서만 develop에 통합하며 실제 SHA/CI/원격 결과는 PR 이력·완료 보고에 기록한다.

## 2026-11-01 — IH-112 BUG-009~011 수정 (Claude Code)

- **시작**: develop f98da4d(origin 일치), 사용자 미추적 AGENTS.md 보존·미커밋. `fix/save-input-and-session-boundaries` 분기.
- **재현(수정 전)**: Codex 진단 5종(`build/ih-112-fix/before_*.log`).
  - ui_free/ui_queue: exit 250
  - reject: 중첩 OK, A1 생성
  - suspend/suspend_position: CLOSED였던 컨트롤러가 OPEN, 게이트 소유
- **실패 회귀 450a988**: BUG-010 6건, BUG-011 7건 FAIL. 이어 BUG-009 사례에서 runner exit 250.
- **수정 8e18a75**:
  - 키는 coordinator epoch를 쓰고 coordinator가 없으면 무시한다.
  - `_request_blocker`가 `_emitting`이면 BUSY다.
  - 세션 정지 표시(coordinator → 맵 → InventoryController)로 open/view는 BUSY, 전송은 STALE_SESSION/BUSY다.
- **bc0d44f**: 열린 패널 직접 정지 검사를 추가하고, BUG-010 가방 사례가 중립 틱을 기다리게 했다.
- **검증**
  - runner exit 0, 529검사. `--inject-failure` exit 1.
  - 진단 5종 모두 exit 0.
  - 변이 5종 검출(m8 exit 250, m9~m12 FAIL), 구문 오류 0.
  - 깨끗한 worktree CI 13단계 PASS(360/333/521/347/529, 누수 경고 0).
  - 제품 saves·GUI 시험 파일 미접촉. crash 실행이 남긴 runner 폴더 2개는 정리했다.
- **GUI**: 새 GUI는 미실행이다(사용자 테스트 중단 존중, 재요청 안 함). AC-S16 손상복구 GUI 미확인을 유지한다.
- **결과**: BUG-009~011 fixed(통합·Codex 재검증 대기), IH-112 review, ADR-017 Proposed. main/태그/릴리스 없음. PR/CI/merge 결과는 후속 기록에 남긴다.

### BUG-009~011 통합 결과

- [PR #36](https://github.com/moonhyeonjun/iron-and-harvest/pull/36) bb4d6fe → develop, merge 5070bd8f2701f40bae3e59653c345be686a08d42(mergeable_state=clean).
- [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41307243315/job/124850039990) success: Linux 13단계 360/333/521/347/529, 누수 경고 없음. [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41307597804/job/124851080300) success.
- 통합 tree = bb4d6fe. main(8901bac)·태그·릴리스 미변경.
- 다음: Codex 재검증(BUG-009~011 resolved 판정). IH-112 done은 AC-S16 손상복구 GUI 조건의 처리 결정 뒤에 판정한다.

## 2026-11-01 — IH-112 Codex 독립 수정 재검증

Codex가 develop `d2e1c88`에서 수정 코드를 검토하고 원래 진단 5종(exit 0)과 깨끗한 worktree 공통 CI 13단계(저장 529검사)를 독립 재실행했다. **BUG-009~011 resolved, IH-112 review 유지**. AC-S16 손상 최신본의 명시 복구 GUI는 미확인이며 추가 사용자 테스트를 재요청하지 않는다. ADR-017 Proposed, main·태그·릴리스는 변경하지 않는다.

- 원래 진단5종 PASS: UI free/queue_free, 거부 보고, focus 취소, 실제 충돌 위치 실패. 진단 engine error0. 공통 CI exit0, Python19·경제7·360/333/521/347/529 PASS. 새 GUI/변이는 미실행이며 Claude 결과와 구분한다.
- 문서: 리뷰·검증·수락·인수인계·BUGS/TASKS/CHANGELOG·README/CLAUDE·기술 진입점/ADR 목록 갱신. 게임 코드/씬/테스트/CI 변경 없음. 로그 build/ih-112-fix-codex-review/.
- AGENTS.md와 기존 링크4개 문제 보존·미커밋, 별도 worktree 검증. 문서 변경의 커밋/PR/CI/merge 실제 결과는 PR 이력 및 완료 보고로 연결한다.
- 다음: 남은 AC-S16 처리 방침에 따른 IH-112 완료/마일스톤 판정. 사용자 테스트 재요청이나 자동 통과 전환은 하지 않는다.

## 2026-11-01 — IH-112 AC-S16 손상복구 GUI 재개 확인 (Claude Code)

- **방침**: 사용자가 사용자 테스트 재개를 명시했다. 앞서 기록한 중단 지시는 이력으로 남기고, 재개를 최신 방침으로 따른다. 범위는 미확인 1항목(최신 손상 → 명시 복구본)이다.
- **기준**: develop 3d248d0(develop CI success, 게임 코드는 bb4d6fe와 동일). 사용자 미추적 AGENTS.md 보존. 문서 브랜치 `docs/ih-112-gui-recovery`.
- **준비**: 새 시험 경로 `user://tests/ih112/gui_recovery_20261101`(기존 gui/·제품 saves 미접촉).
  - 1세대 A: (300,410) 왼쪽, 가방 목재 9, 보관함 비어 있음, 지점 5/4/3.
  - 2세대 B: (520,560) 오른쪽, 보관함 목재 4, 산열매 소진.
- **fixture**: corrupt-latest가 B만 손상(checksum 불일치)시켰고, A는 SHA 그대로 유효함을 창 사용자 조작 전에 확인했다.
- **사용자 GUI 결과** "1~4 모두 정상":
  - 손상 안내와 세계 보존
  - 복구 표시
  - 명시 복구로 1세대 복원, 기준 일치
  - 복원 뒤 이동·채집·전송
- **로그**: RECOVERY_AVAILABLE(a=valid, b=CHECKSUM_MISMATCH) → load OK gen=1 recovered=true. 오류 0. 파일은 변하지 않았다. 창이 열려 있어 종료 코드는 미수집이다.
- **결과**: AC-S16 미확인 항목 해소. IH-112 review 유지(done·v0.3.0은 Codex 후속 검토). main/태그/릴리스 없음.

## 2026-11-01 — IH-112 최종 검토와 v0.3.0 Gathering 판정

- 기준 develop36d86f6, PR #39 및 develop CI41311509122 success 확인. game/tools/tests/.github는 d2e1c88 독립 검증과 동일(diff0). 같은 코드의 전체 로컬 CI를 반복하지 않는다.
- GUI는 사용자438ef89 기존 절차와3d248d0 손상복구 확인 “1~4 모두 정상”을 근거로 사용한다. Codex 신규 GUI/프로세스 종료 확인으로 주장하지 않는다. 사용자 테스트 재개 지시를 최신 방침으로 반영한다.
- IH-112 done, ADR-017 Accepted(초기 저장 범위). v0.3.0 기능 완료 조건 PASS. 판정·수락/인수인계/기술 진입점·마일스톤·로드맵 갱신. 게임/씬/테스트/CI 변경 없음.
- 문서 정적 검사·diff 검토 뒤 필수 PR CI로 develop 통합, develop→main 승격 PR과 main push CI, tree/ref 확인 후 annotated v0.3.0 생성·push한다. 실제 SHA/CI/태그는 PR 이력과 후속 발행 기록에 남긴다. GitHub Release/Export/Steam 게시는 만들지 않는다.
- 사용자 AGENTS.md는 미추적 그대로 보존. 기존 링크4개 오류와 clean worktree 정적 검사를 구분한다. Windows·전원 차단·Cloud·다중 writer·DEBT-002/003/004·라이선스 한계를 보존한다. 다음은 IH-120 상세 설계다.
