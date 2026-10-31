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
