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

중세 판타지·픽셀 아트, 생활과 통치의 연결, 주민의 삶과 영지의 성장, 최종 제국 목표는 확정이다. 첫 MVP는 마을1개·주민20~30명·약10건물·자립을 목표로 한다. 정확한 수치·콘텐츠·엔진 버전은 TBD/Proposed를 확인한다.

Godot 루트는 game/이며 res://는 이 디렉터리다. 루트 data/design은 수치 실험, tests/는 Python 검증, game/tests/는 향후 엔진 테스트다. 현재 빈 씬에는 게임 로직이 없다. 미래용 빈 매니저·불필요한 리팩터링·범위 밖 기능을 만들지 않는다.

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
