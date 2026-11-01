# Iron & Harvest 개발 지침

사용자의 최신 지시가 우선한다. 현재 작업 기준은 새 docs/00-overview~05-art 체계이며 기존 docs/design·production과 archive는 참고 원문이다. 구현되지 않은 기능을 완료로 보고하지 않는다.

## 반드시 읽을 파일

- README.md, docs/03-development/TASKS.md, WEEKLY_LOG.md, BUGS.md.
- 해당 GDD/TDD와 docs/04-decisions/ADR/의 상태.
- [.claude/rules/architecture.md](.claude/rules/architecture.md)
- [.claude/rules/coding-standards.md](.claude/rules/coding-standards.md)
- [.claude/rules/git-workflow.md](.claude/rules/git-workflow.md)
- [.claude/rules/testing.md](.claude/rules/testing.md)

## 제품·구조 원칙

중세 판타지·픽셀 아트, 생활과 통치의 연결, 주민의 삶과 영지의 성장, 최종 제국 목표는 확정이다. 첫 MVP는 마을1개·주민20~30명·약10건물·자립을 목표로 한다. 엔진은 Godot4.7.2 Standard/GDScript/Compatibility로 고정한다. 수치·콘텐츠의 TBD/Proposed는 별도로 확인한다.

Godot 루트는 game/이며 res://는 이 디렉터리다. 루트 data/design은 수치 실험, tests/는 Python 검증, game/tests/에는 엔진 smoke 테스트가 있다. 현재 빈 씬에는 게임 로직이 없다. 미래용 빈 매니저·불필요한 리팩터링·범위 밖 기능을 만들지 않는다.

## 역할 분담

사용자 지시에 따라 Codex는 설계·기술 기반·환경 검증을 맡는다. Claude Code가 향후 실제 게임플레이 기능을 구현한다. Codex는 이동/상호작용을 임의로 구현하지 않고 파일·의존성·인수 조건·테스트를 갖춘 명세를 준비한다.

실행은 `python3 tools/godot.py`를 사용하고 엔진 버전을 임의 변경하지 않는다.

IH-101은 구현·검증·develop 통합 완료다. 후속 작업 전 [이동 명세](docs/02-technical-design/PLAYER_MOVEMENT.md), [수락 검사](docs/03-development/IH-101-ACCEPTANCE.md), [검증 결과](docs/03-development/IH-101-VALIDATION.md)를 읽는다. [인수인계](docs/03-development/IH-101-HANDOFF.md)는 최초 구현 계약으로 보존한다. 수치는 여전히 검증용 제안이다.

## 완료 기능: IH-102

IH-004 CI 완료 후 [상호작용 인수인계](docs/03-development/IH-102-HANDOFF.md), [명세](docs/02-technical-design/INTERACTION.md), [수락 조건](docs/03-development/IH-102-ACCEPTANCE.md)를 준비했다. 2026-11-01 Claude Code가 구현하고 AC-I01~12와 로컬 CI를 검증했다([검증 기록](docs/03-development/IH-102-VALIDATION.md)). [PR #9](https://github.com/moonhyeonjun/iron-and-harvest/pull/9)로 develop에 통합했다. 이후 Codex 추가 검토에서 BUG-003/004를 재현해 review로 재개했고, BUG-003/004를 [PR #12](https://github.com/moonhyeonjun/iron-and-harvest/pull/12)(merge e5d7730)로 수정·통합하여 done으로 복귀했다([검토](docs/03-development/IH-102-REVIEW.md)). 기존 이동 회귀를 보존하며 test_interaction은 tools/run_ci.py에 등록되어 있다. main/develop은 CI checks가 필수이므로 문서도 PR로 검증한다.

## 완료 기능: IH-110

[인수인계](docs/03-development/IH-110-HANDOFF.md), [명세](docs/02-technical-design/INVENTORY.md), [수락 조건](docs/03-development/IH-110-ACCEPTANCE.md), [ADR-015](docs/04-decisions/ADR/ADR-015-inventory-contract.md)를 따른다. 2026-11-01 Claude Code가 구현하고 AC-N01~14를 검증했다([검증 기록](docs/03-development/IH-110-VALIDATION.md)). [PR #19](https://github.com/moonhyeonjun/iron-and-harvest/pull/19)로 develop에 통합했다. Codex 추가 검토에서 BUG-005/006을 확인해 review로 재개했고, [PR #22](https://github.com/moonhyeonjun/iron-and-harvest/pull/22)로 수정·통합해 done이다([검토](docs/03-development/IH-110-REVIEW.md)). Codex가 설계했다. 정의/수량 분리·전체 성공 거래·stale 요청·가방/살펴보기 배타성을 검증하며 실제 채집/저장은 후속이다. v0.2.0/main은 보존한다.

Codex가 a5cefeb에서 BUG-005/006 원래 재현과 전체 CI를 재검증해 done을 유지했다. 완료된 IH-110 구현/수정 프롬프트를 반복 실행하지 않는다. IH-111 채집·자원 지점은 2026-11-01 Claude Code가 구현·검증했다([검증 기록](docs/03-development/IH-111-VALIDATION.md)). [PR #26](https://github.com/moonhyeonjun/iron-and-harvest/pull/26)로 develop에 통합했다. Codex가 c266d52에서 BUG-007/008을 재현해 review로 재개했다. BUG-007/008은 PR #29로 수정·통합됐고 Codex가 1cb3471에서 원래 진단4종과 전체 CI를 재검증해 resolved·IH-111 done으로 복귀했다. [검토 이력](docs/03-development/IH-111-REVIEW.md)의 수정 프롬프트는 완료됐다. [명세](docs/02-technical-design/GATHERING.md), [수락 조건](docs/03-development/IH-111-ACCEPTANCE.md), [전달 프롬프트](docs/03-development/IH-111-HANDOFF.md)를 준비했다. 최초 구현/수정 프롬프트를 반복 실행하지 않는다. IH-112 초기 저장·복원은 구현 후 Codex 검토에서 BUG-009~011을 재현해 review다. [수정 전달 프롬프트](docs/03-development/IH-112-REVIEW.md)를 사용한다. [상세 명세](docs/02-technical-design/SAVE_LOAD.md), [수락 조건](docs/03-development/IH-112-ACCEPTANCE.md), [전달 프롬프트](docs/03-development/IH-112-HANDOFF.md)를 준비했다. 최초 구현 프롬프트는 완료 이력이다. 추가 사용자 테스트를 재요청하지 않고 GUI 미확인 범위를 보존한다. ADR-017 Proposed다. ADR-016 Proposed다. Codex는 설계, Claude Code는 이 명세에 따라 구현한다.

## 작업 절차

1. 현재 경로·Git 상태·현재 브랜치·기존 변경을 확인한다.
2. 관련 GDD/TDD/ADR와 코드·의존성·테스트를 읽는다.
3. 작업 ID·작업 계획·변경할 파일·완료 조건·테스트를 명시한다.
4. 요청된 작은 기능만 구현하고 기존 사용자 변경을 보존한다.
5. 테스트 작성/실행과 실제 실행을 수행한다. 불가능하면 이유와 미실행 범위를 기록한다.
6. 코드 변경·문서 일치·저장 영향·git diff를 검토한다. untracked는 별도 확인한다.
7. TASKS/WEEKLY_LOG/BUGS와 필요한 ADR을 갱신한다.
8. 검증된 변경을 작은 Conventional Commit으로 기록하고 필요한 push/PR/merge를 자율 수행한다. 원격 반영을 확인하고 커밋 해시·결과·남은 작업을 기록한다.

## Git 필수 규칙

작업 전 `git status --short --branch`, `git branch --show-current`, `git diff`, `git diff --cached`. 작업 후 `git diff --check`와 변경 내용 검토. 초기 커밋 전 파일은 일반 diff에 안 나오므로 파일 내용과 manifest를 확인한다.

main=안정, develop=통합, feature/fix/refactor/docs/experiment 브랜치로 작업한다. 최초 기준점은 생성되었다. 기존 원격/브랜치를 먼저 확인하고 일반 작업은 develop에서 분기해 검증 후 통합한다. 안정화된 변경만 main으로 반영한다.

**Git/GitHub 작업은 별도 승인 없이 자율 실행한다.** stage/commit, 브랜치 생성·전환·병합·삭제, fetch/pull/push, Issue/PR 생성·종료·병합, 원격 설정 변경, 검증된 태그/릴리스가 포함된다. 작업 규모에 필요한 단계만 수행하고 원격 결과를 검증한다.

reset --hard, clean -fd, force/force-with-lease push, 임의 이력 재작성, 사용자 변경 삭제/덮어쓰기는 기본적으로 실행하지 않는다. 복구 가능한 백업·병합 대안을 우선하며 안전한 대안이 없거나 충돌 의도가 불명확하면 확인한다. Git 권한을 Steam 게시·결제·라이선스 결정 권한으로 확대하지 않는다.

## 완료 보고

1. 작업 목적
2. 구현한 기능/변경과 미구현 범위
3. 수정/생성 파일
4. 주요 설계
5. 실제 테스트 명령·결과·미실행
6. 미해결 문제
7. 문서 갱신
8. 실제 커밋 해시·push/merge·태그/릴리스 결과
9. 다음 작업

현재 검증 명령은 CONTRIBUTING.md를 따른다. headless import를 실제 플레이 테스트로 보고하지 않는다. 엔진이 없으면 설치된 것처럼 가정하지 않는다. 사용자 요청이 아키텍처와 충돌하면 문제와 대안을 먼저 설명한다.
