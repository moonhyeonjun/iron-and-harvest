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
