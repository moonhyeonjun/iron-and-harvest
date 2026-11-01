# 작업 목록

GitHub Issue를 원격 생성하지 않았다. 이 문서가 현재 작업 관리 기준이다. 최초 커밋 957dd3b가 생성되었고 이후 Git 기록은 GIT_BOOTSTRAP/WEEKLY_LOG를 따른다. 원격 PR 번호는 만들지 않은 링크로 기록하지 않는다.

유형: feature, bug, refactor, tech-debt, design, balance, art, documentation.
우선순위: priority:critical/high/medium/low.
상태: status:backlog → ready → in-progress → review → done, 진행 불가 시 blocked와 원인 기록. ready는 의존 작업 완료와 인수 조건이 준비되었을 때만 사용한다. blocked가 일정 지연을 숨기는 상태가 되어서는 안 된다.

현재 IH-001은 파일/정적검사 리뷰를 완료했고, IH-002도 Godot4.7.2 Import/Headless/GUI와 GDScript smoke 검증을 완료했다. Foundation 기술 관문은 충족했다. v0.1.0 원격 태그와 대상d176bd7을 재확인했다. [Foundation 확정 기록](FOUNDATION-v0.1.0-VERIFICATION.md)을 따른다. IH-101은 Claude Code가 구현하고 AC-01~12를 검증했으며 [PR #4](https://github.com/moonhyeonjun/iron-and-harvest/pull/4)로 develop에 통합했다(done). main 반영·v0.2.0 태그는 하지 않았다.

v0.2.0 Character: IH-101/102 done과 회귀·GUI 증거를 근거로 [기능 마일스톤 PASS](CHARACTER-v0.2.0-VERIFICATION.md). main 승격(PR #16)·CI 성공 후 v0.2.0 태그를8901bac에 발행·검증했다. IH-110은 Claude Code가 구현하고 AC-N01~14를 검증했다([IH-110 검증 기록](IH-110-VALIDATION.md)). [PR #19](https://github.com/moonhyeonjun/iron-and-harvest/pull/19)로 develop에 통합했다. 이후 Codex가 BUG-005/006을 재현하여 review로 재개했다([검토·수정 프롬프트](IH-110-REVIEW.md)). BUG-005/006은 [PR #22](https://github.com/moonhyeonjun/iron-and-harvest/pull/22)로 수정·통합해 done이다.

| ID | 제목 | 유형 | 우선순위 | 상태 | 의존성 |
|---|---|---|---|---|---|
| IH-001 | 기반·문서·관리 체계 | documentation | priority:high | status:done | 없음 |
| IH-002 | Godot 환경 고정과 빈 프로젝트 실행 | tech-debt | priority:critical | status:done | 없음 |
| IH-003 | 라이선스·권리 정책 결정 | design | priority:high | status:backlog | 없음 |
| IH-004 | CI 검사 도입 | tech-debt | priority:medium | status:done | IH-002 |
| IH-005 | 실제 개발 일정 재산정 | design | priority:medium | status:backlog | 없음 |
| IH-006 | 픽셀 규격과 제작 흐름 결정 | art | priority:medium | status:backlog | IH-002 |
| IH-007 | Git 자율 운영 정책·최초 동기화 | documentation | priority:high | status:done | IH-001 |
| IH-101 | 플레이어 이동·충돌 | feature | priority:high | status:done | IH-002 |
| IH-102 | 상호작용 대상·프롬프트 | feature | priority:high | status:done | IH-101, IH-004 |
| IH-110 | 아이템 정의와 인벤토리 | feature | priority:high | status:done | IH-102 |
| IH-111 | 채집과 자원 지점 | feature | priority:high | status:ready | IH-110 |
| IH-112 | 초기 저장과 복원 | feature | priority:critical | status:backlog | IH-110, IH-111 |
| IH-120 | 달력·계절·하루 경계 | feature | priority:high | status:backlog | IH-112 |
| IH-121 | 심기·성장·수확 | feature | priority:high | status:backlog | IH-120 |
| IH-130 | 건설·수리 프로젝트 | feature | priority:high | status:backlog | IH-120, IH-110 |
| IH-131 | 기초 노동 배치와 위임 | feature | priority:high | status:backlog | IH-130 |
| IH-132 | 생산 체인과 소비 | feature | priority:high | status:backlog | IH-131 |
| IH-140 | 장부·세금·재정 | feature | priority:high | status:backlog | IH-132 |
| IH-141 | 수동 거래 | feature | priority:medium | status:backlog | IH-140 |
| IH-150 | 주민20~30명·주요 인물 | feature | priority:high | status:backlog | IH-140 |
| IH-151 | 관계·의뢰·기록 | feature | priority:high | status:backlog | IH-150 |
| IH-160 | 경제·시간·저장 통합 | feature | priority:critical | status:backlog | IH-151, IH-132, IH-140 |
| IH-161 | 경제 밸런스 검증 | balance | priority:high | status:backlog | IH-160 |
| IH-170 | 자립 Alpha 플레이 검증 | feature | priority:high | status:backlog | IH-161 |
| IH-180 | 성능·회귀·배포 검증 | tech-debt | priority:critical | status:backlog | IH-170 |
| IH-190 | Steam 출시 준비 | documentation | priority:high | status:backlog | IH-180, IH-003 |
| IH-200 | 전투·탐험 출시 범위 판단 | design | priority:low | status:backlog | IH-170 |

## IH-001 — 기반·문서·관리 체계

- 목적: 기반·문서·관리 체계을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 요청 구조·규칙·템플릿과 기존 파일 보존.
- 관련 문서: [설계](../00-overview/PROJECT_OVERVIEW.md).
- 예상 영향 범위: 문서/설정/도구.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 정적 검사·보존 비교·Git 검토.
- 현재 증거/미확정: 파일 구축/정적 검사·테스트·보존·diff 리뷰 완료, 최초 커밋957dd3b; 엔진 검증은 IH-002로 분리.

## IH-002 — Godot 환경 고정과 빈 프로젝트 실행

- 목적: Godot 환경 고정과 빈 프로젝트 실행을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 실행 파일 식별·버전 기록·import/빈 씬 실행.
- 관련 문서: [설계](../02-technical-design/TOOLCHAIN.md).
- 예상 영향 범위: 엔진/game/ADR.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: --version·headless import·빈 씬·실제 창.
- 현재 증거/미확정: Downloads에서4.7.2를 발견해 버전별 사용자 Applications에 설치. 모든 실행 검사0, GUI 사용자 확인, ADR-011 수락. IH-002-VALIDATION 참조.

## IH-003 — 라이선스·권리 정책 결정

- 목적: 라이선스·권리 정책 결정을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 소유자 승인 라이선스와 타사 에셋 규칙.
- 관련 문서: [설계](../05-art/ASSET_LIST.md).
- 예상 영향 범위: LICENSE/에셋 관리.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 선택된 조건·표기·배포 범위 검토.
- 현재 증거/미확정: 소유자/정책 TBD, 임의 오픈소스 선택 금지.

## IH-004 — CI 검사 도입

- 목적: CI 검사 도입을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 엔진 버전/실행기 고정 후 PR 검사.
- 관련 문서: [설계](../02-technical-design/TDD.md).
- 예상 영향 범위: .github/workflows.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 로컬 재현·권한·실패 차단.
- 현재 증거/미확정: 547b117, PR #6 merge e50a8a2. 로컬/PR/통합 push 성공, 실패 PR #7 blocked 후미병합closed, 두브랜치 required CI 보호 확인. [CI 검증](IH-004-VALIDATION.md), [운영](../02-technical-design/CI.md), ADR-013 Accepted.

## IH-005 — 실제 개발 일정 재산정

- 목적: 실제 개발 일정 재산정을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 주간 가용시간·아트 조달·버전별 관문 계획.
- 관련 문서: [설계](../00-overview/ROADMAP.md).
- 예상 영향 범위: 로드맵/리소스.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 예산/의존성 검토.
- 현재 증거/미확정: 이전 12개월 계획은 참고 가정.

## IH-006 — 픽셀 규격과 제작 흐름 결정

- 목적: 픽셀 규격과 제작 흐름 결정을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 타일·인물·스케일·원본/출력 규칙 검증.
- 관련 문서: [설계](../05-art/ART_GUIDE.md).
- 예상 영향 범위: 아트/카메라/UI.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 화면 가독성·import·권리 확인.
- 현재 증거/미확정: 이미지 제작은 별도 작업.

## IH-101 — 플레이어 이동·충돌

- 목적: 생활 조작의 기반인 자유 이동과 장애물 회피를 검증한다.
- 요구사항: CharacterBody2D 이동·4개입력·대각선 속도·조작 게이트·카메라·idle/walk·임시 충돌 맵.
- 관련 문서: [상세 명세](../02-technical-design/PLAYER_MOVEMENT.md), [수락 검사](IH-101-ACCEPTANCE.md), [인수인계](IH-101-HANDOFF.md), [검증 기록](IH-101-VALIDATION.md).
- 영향 범위: game/scenes/player·scenes/tests·scripts/player·tests 및 project.godot(입력·화면·물리·레이어).
- 완료 조건: AC-01~12 실제pass, 코드 리뷰/문서 갱신/검증된 develop 통합. 명세만으로done 금지.
- 테스트 항목: 실제 물리 이동 거리·대각선·반대키·30/60/120fps·벽/통로·게이트·포커스·표현·카메라·회귀.
- 현재 증거/미확정: feature/player-movement에서 구현(e9a0e03, 7cd97c1, 571c1e9). 자동 runner 4변형 PASS·실패 주입 종료1, GUI 수동 항목 사용자 확인. BUG-001 수정. [PR #4](https://github.com/moonhyeonjun/iron-and-harvest/pull/4) merge 6575a17로 develop 통합·원격 확인, done. 속도/아트/조작 정책은 검증용 Proposed 기준안(ADR-012).

## IH-102 — 상호작용 대상·프롬프트

- 목적: 표시된 가까운 대상에 한 번 요청하고 안전하게 종료하는 생활 행동 경계를 만든다.
- 요구사항: Area 후보·거리/정면/가시선·안정 선택·프롬프트·입력 큐/재검증·살펴보기 패널·취소/게이트 복구.
- 관련 문서: [상세 명세](../02-technical-design/INTERACTION.md), [수락 검사](IH-102-ACCEPTANCE.md), [인수인계](IH-102-HANDOFF.md), ADR-014 Proposed.
- 영향 범위: game/scripts/interaction·tests, scenes/interaction·tests, ui/interaction, game/tests(runner·probe), player.tscn 마지막 자식, InputMap/layer_3, tools/run_ci.py 등록.
- 완료 조건: AC-I01~12 pass·실제 GUI·기존 이동 회귀·CI checks·리뷰·develop 통합. 명세만으로 done 금지.
- 테스트 항목: 범위/방향/동률/벽, 삭제/거부/연타/중복 종료, UI 소비/포커스/이동 복구/씬 수명·CI.
- 현재 증거/미확정: feature/interaction-system에서 구현(95c723e, f89d812, bcab854, 4f69d80, 5062a83, 3d99d36, bf8501b). AC-I01~12 자동 299검사 PASS, 사용자 GUI "1~5 모두 정상", 로컬 CI 10단계 PASS. [검증 기록](IH-102-VALIDATION.md). [PR #9](https://github.com/moonhyeonjun/iron-and-harvest/pull/9) 필수 CI 성공 후 merge 318fcd2로 develop 통합, develop push CI 성공, done. 반경/정면각/키/UI는 검증용 제안(ADR-014 Proposed).
- 후속 판정(2026-11-01): Codex가 `29b2ed3`에서 BUG-003/004를 재현하여 review로 재개. [검토·Claude 수정 프롬프트](IH-102-REVIEW.md)의 실행 시 중복 ID/RESOLVING 취소 회귀를 보완해야 done으로 복귀한다. 기존 통합 이력은 보존한다.
- BUG-003/004 수정(2026-11-01): fix/interaction-request-validation `aaac5da`(실패 회귀)·`0332b5a`(수정). runner 333검사 PASS, Codex 재현 종료0, 로컬 CI 10단계 PASS, 사용자 GUI "1~5 모두 정상"(0332b5a). [PR #12](https://github.com/moonhyeonjun/iron-and-harvest/pull/12) 필수 CI 성공, merge e5d7730, develop CI 성공 → done.
- Codex 재검증(2026-11-01): `69561ca`에서 원래 재현 위반0, 전체 CI 10단계/상호작용333검사 PASS 및 원격 CI 성공 확인. BUG-003/004 resolved·IH-102 done 유지. [검증 기록](IH-102-VALIDATION.md).
- 의존성 메모: IH-101은 기능 의존, IH-004는 사용자 지정 개발 순서와 PR 검증 기반이다.

## IH-110 — 아이템 정의와 인벤토리

- 목적: 가방 확인·유한 보관함 이동을 통해 이후 채집/소비의 수량 보존 경계를 만든다.
- 요구사항: 정의 검증·포맷 비교, 고정 슬롯·스택, 원자 add/remove/transfer, revision·독립 snapshot, 배타적인 가방 UI.
- 관련 문서: [아이템 기획](../01-game-design/ITEM_SYSTEM.md), [상세 계약](../02-technical-design/INVENTORY.md), [AC-N01~14](IH-110-ACCEPTANCE.md), [Claude 인수인계](IH-110-HANDOFF.md), [ADR-015](../04-decisions/ADR/ADR-015-inventory-contract.md).
- 예상 영향 범위: game/systems/inventory, data/items, scripts/inventory, ui/inventory, 테스트 맵/runner, CI 등록. 기존 Player/상호작용 회귀 보존.
- 완료 조건: AC-N01~14·기존 회귀·GUI 확인·필수 PR CI 통과, 검증 기록과 ADR 판정, develop 통합/원격 확인.
- 테스트 항목: 정의/별칭 격리·포화·부족·양방향 보존·stale/reentrant·snapshot 손상·모달 입력/수명·실제 GUI.
- 현재 증거: feature/inventory-system(b7efab6, 05cd2b3, 2a085e2, 311a742, 025c863). AC-N01~13 자동 375검사 PASS, 변이 10종·엔진 오류 변이 검출, 로컬 CI 11단계 PASS(이동 360·상호작용 333 회귀 포함), AC-N14 사용자 GUI "1~5 모두 정상"(025c863). [IH-110 검증 기록](IH-110-VALIDATION.md). 12슬롯/7품목/스택10은 검증용 제안이며 ADR-015 Proposed. [PR #19](https://github.com/moonhyeonjun/iron-and-harvest/pull/19) 필수 CI 성공, merge f26a77e, develop CI 성공 → done.
- Codex 후속 검토: 14302e5의 CI 11단계 PASS, 추가 진단은 수명2·ID1 위반으로 종료1. BUG-005/006 open, review로 재개. [수정 수락 조건](IH-110-REVIEW.md)을 충족한 후 done 복귀를 판정한다.
- BUG-005/006 수정(2026-11-01): fix/inventory-lifecycle-and-id-validation `5004419`(실패 회귀)·`fb5cd0c`(수정)·`a714c5a`/`8dfe8bb`(검사 보완). 재현 진단 종료1→0, runner 수정 전 충돌·25실패 → 수정 후 PASS, 표적 변이 5종 검출, 깨끗한 worktree CI 11단계 PASS(이동 360·상호작용 333·인벤토리 521), 사용자 GUI "1~4 모두 정상"(8dfe8bb). [PR #22](https://github.com/moonhyeonjun/iron-and-harvest/pull/22) 필수 CI 성공, merge cbb836b, develop CI 성공 → done.
- Codex 수정 재검증(2026-11-01): a5cefeb의 원래 재현 종료0/위반0, 전체 CI 11단계/인벤토리521검사 PASS. BUG-005/006 resolved·IH-110 done 유지. [독립 검증](IH-110-VALIDATION.md).
- 제외: 실제 채집/저장/예약/장비 효과/정렬/실제 영지 창고. 후속 IH-111은 상세 설계 ready, IH-112는 backlog다.

## IH-111 — 채집과 자원 지점

- 목적: 유한 월드 물자를 직접 채집해 가방으로 옮기는 수집 루프를 검증한다.
- 유형/우선순위/상태: feature / priority:high / status:ready. 의존 IH-110 done.
- 요구사항: 나뭇가지·돌·산열매, 새 E당1개, 숨은 stock→bag 원자 transfer, 소진 표시, full/stale/취소 보존, 같은 세션 뷰 재진입 보존.
- 관련 문서: [생활](../01-game-design/LIFE_SYSTEM.md), [상세 설계](../02-technical-design/GATHERING.md), [수락 조건](IH-111-ACCEPTANCE.md), [Claude 전달 프롬프트](IH-111-HANDOFF.md), [ADR-016](../04-decisions/ADR/ADR-016-atomic-gathering.md).
- 예상 영향: GatherDef/GatherService/GatherTarget, Interaction의 INSTANT 분기, 별도 GatheringTest/표시, 신규 runner/공통 CI 등록. Inventory transfer와 Player 정책 유지.
- 완료 조건: AC-G01~14 자동·GUI, 기존 회귀, 실패 주입/변이, 검증 기록, 필수 CI/리뷰/develop 통합. 아직 구현·새 검사 없음.
- 미포함: 도구/시간/재생/파일 저장/위임/농사/범용 잠금. 수량·표현은 검증용 Proposed, 제품 밸런스 TBD.
- 현재 증거: 2026-11-01 Codex 상세 설계 완료. 실제 구현 완료와 구분하며 다음 담당은 Claude Code.

## IH-112 — 초기 저장과 복원

- 목적: 초기 저장과 복원을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 위치·재고·지점 snapshot/복원.
- 관련 문서: [설계](../02-technical-design/SAVE_SYSTEM.md).
- 예상 영향 범위: Save/fixtures.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 손상·쓰기 실패·왕복·미래 버전.
- 현재 증거/미확정: 스키마는 구현 때 확정.

## IH-120 — 달력·계절·하루 경계

- 목적: 달력·계절·하루 경계을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 날짜 전진·경계 이벤트·일시 정지.
- 관련 문서: [설계](../01-game-design/WORLD_SYSTEM.md).
- 예상 영향 범위: Calendar/Season.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 중복 결산·로드·계절/연도 경계.
- 현재 증거/미확정: 계절 길이/일시 정지 범위 TBD.

## IH-121 — 심기·성장·수확

- 목적: 심기·성장·수확을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 씨앗 소비·날짜 성장·수확.
- 관련 문서: [설계](../01-game-design/LIFE_SYSTEM.md).
- 예상 영향 범위: Crop/Inventory.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 중복 파종/수확·계절·저장.
- 현재 증거/미확정: 성장 수치 TBD.

## IH-130 — 건설·수리 프로젝트

- 목적: 건설·수리 프로젝트을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 재료 예약·작업·완료·취소.
- 관련 문서: [설계](../01-game-design/ESTATE_MANAGEMENT.md).
- 예상 영향 범위: Building/Project.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 재료 부족·환급·완료 중복.
- 현재 증거/미확정: 배치 방식 TBD.

## IH-131 — 기초 노동 배치와 위임

- 목적: 기초 노동 배치와 위임을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 한 인물 한 노동·직접/위임 동일 결과.
- 관련 문서: [설계](../01-game-design/CHARACTER_SYSTEM.md).
- 예상 영향 범위: Assignment/Project.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 이중 배치·기여 중첩·취소.
- 현재 증거/미확정: 상세 NPC AI는 IH-150.

## IH-132 — 생산 체인과 소비

- 목적: 생산 체인과 소비을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 원료→가공→식량, 병목 표시.
- 관련 문서: [설계](../01-game-design/ECONOMY_SYSTEM.md).
- 예상 영향 범위: Production/Resource.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 원료/인력/공간 부족·정수/보존.
- 현재 증거/미확정: 정확한 레시피는 설계 검증 후.

## IH-140 — 장부·세금·재정

- 목적: 장부·세금·재정을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 수입/지출·세율 결과·주민 영향.
- 관련 문서: [설계](../01-game-design/ESTATE_MANAGEMENT.md).
- 예상 영향 범위: Ledger/Tax.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 잔액·미납·현장/장부 일치.
- 현재 증거/미확정: 세율/미납 정책 TBD.

## IH-141 — 수동 거래

- 목적: 수동 거래을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 상인 가격/재고/수량 확인 후 거래.
- 관련 문서: [설계](../01-game-design/ECONOMY_SYSTEM.md).
- 예상 영향 범위: Trade/Inventory.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 왕복 차익·예약 재고·취소 보존.
- 현재 증거/미확정: MVP 편입·가격/한도 TBD.

## IH-150 — 주민20~30명·주요 인물

- 목적: 주민20~30명·주요 인물을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 이름·거처·직무·단순 일정.
- 관련 문서: [설계](../01-game-design/CHARACTER_SYSTEM.md).
- 예상 영향 범위: Population/Character.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 화면 밖 상태·노동 일치·ID 복원.
- 현재 증거/미확정: 정확한 주민/고유 인물 수 TBD.

## IH-151 — 관계·의뢰·기록

- 목적: 관계·의뢰·기록을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 행위에 따른 관계/대사/기록.
- 관련 문서: [설계](../01-game-design/GAME_LOOP.md).
- 예상 영향 범위: Relationship/Event/Chronicle.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 중복 보상·조건·로드.
- 현재 증거/미확정: 고유 서사 규모 TBD.

## IH-160 — 경제·시간·저장 통합

- 목적: 경제·시간·저장 통합을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 장기 반복 상태 보존·복구.
- 관련 문서: [설계](../02-technical-design/TDD.md).
- 예상 영향 범위: Simulation/Save.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 여러 연도·migration·중복 tick.
- 현재 증거/미확정: 초기 식량 모델 검사만으로 대체 불가.

## IH-161 — 경제 밸런스 검증

- 목적: 경제 밸런스 검증을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 직접/위임 모두 의미, 자립 가능.
- 관련 문서: [설계](../01-game-design/ECONOMY_SYSTEM.md).
- 예상 영향 범위: 수치/테스트/기획.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 대표 전략·실패 회복·실제 플레이.
- 현재 증거/미확정: 측정 전 수치 확정 금지.

## IH-170 — 자립 Alpha 플레이 검증

- 목적: 자립 Alpha 플레이 검증을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 새 게임에서 자립·결과 인식.
- 관련 문서: [설계](../01-game-design/GAME_LOOP.md).
- 예상 영향 범위: 튜토리얼/목표/전체.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 실제 플레이·세이브 재개·완주.
- 현재 증거/미확정: 목표 시간/테스터 수 TBD.

## IH-180 — 성능·회귀·배포 검증

- 목적: 성능·회귀·배포 검증을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 지원 환경 품질·버그 해소.
- 관련 문서: [설계](../02-technical-design/PERFORMANCE.md).
- 예상 영향 범위: QA/export/문서.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 장기 메모리·실행·업데이트·복구.
- 현재 증거/미확정: 장비/최소 사양 TBD.

## IH-190 — Steam 출시 준비

- 목적: Steam 출시 준비을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: 심사·기능 일치·출시 승인.
- 관련 문서: [설계](../00-overview/ROADMAP.md).
- 예상 영향 범위: 스토어/빌드/권리.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 설치/실행·심사 자료·최종 QA.
- 현재 증거/미확정: Steam 게시/결제 권한은 별도. GitHub 릴리스는 검증 후 자율 실행.

## IH-200 — 전투·탐험 출시 범위 판단

- 목적: 전투·탐험 출시 범위 판단을 통해 해당 마일스톤의 검증 가능한 결과를 만든다.
- 요구사항: MVP 후 직접/위임 전투 범위 결정.
- 관련 문서: [설계](../01-game-design/COMBAT_SYSTEM.md).
- 예상 영향 범위: GDD/후속 작업.
- 완료 조건: 요구 동작/산출물 확인, 아래 테스트 결과와 문서 갱신, 리뷰 완료.
- 테스트 항목: 비용·재미·보급 연결 검토.
- 현재 증거/미확정: 기능 구현 의존에 선행시키지 않음.

## IH-007 — Git 자율 운영 정책·최초 동기화

- 목적: 새 운영 권한을 지침에 반영하고 Foundation 이력을 안전하게 원격에 보존.
- 요구사항: 기존80파일 검증, 지정 메시지 최초 commit, main/develop 구성, 원격 확인/동기화.
- 관련 문서: [ADR-010](../04-decisions/ADR/ADR-010-autonomous-git.md), [Git 기록](GIT_BOOTSTRAP.md).
- 예상 영향 범위: Git refs·운영 규칙·개발 기록. 게임 기능 변경 없음.
- 완료 조건: 테스트 통과, 기존 이력 보존, 원격 SHA와 로컬 비교, 실제 해시/결과 기록.
- 테스트 항목: 정적 구조, 기존 unittest/경제 가정, diff, ref 일치, 작업 트리.
- 현재 증거: 최초 커밋957dd3b·정책 커밋8ce8d1d, main/develop/작업 브랜치 push 성공·원격 SHA 일치. 상세는 GIT_BOOTSTRAP.
