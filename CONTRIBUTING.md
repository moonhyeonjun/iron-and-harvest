# 개발 참여 및 변경 절차

## 작업 시작

1. [현재 작업](docs/03-development/TASKS.md), 관련 GDD/TDD, CLAUDE.md를 읽는다.
2. `git status --short --branch`, `git branch --show-current`, `git diff`, `git diff --cached`로 작업 상태를 확인한다.
3. 기존 수정과 요청 범위를 구분한다. untracked 파일도 사용자 작업이다. 숨기거나 삭제하지 않는다.
4. 작업 ID·계획·변경 예정 파일·완료 조건을 명시하고 해당 브랜치에서 구현한다.

## 브랜치

| 브랜치 | 역할 |
|---|---|
| main | 검증된 안정 버전, 기본 브랜치 정책 |
| develop | 개발 통합, 일반 PR의 대상 |
| feature/* | 신규 기능·기반 기능 |
| fix/* | 버그 수정 |
| refactor/* | 동작을 유지하는 구조 개선 |
| docs/* | 문서 변경 |
| experiment/* | 검증용 기술 실험 |

기존 브랜치를 먼저 확인하며 같은 이름을 무조건 다시 생성하지 않는다. 정상 작업은 develop에서 분기한다. 검증 후 develop에 통합하고 안정화된 변경만 main에 반영한다. 최초 Foundation 커밋과 main/develop 기준점은 구성했다. 자세한 이력·원격 검증은 docs/03-development/GIT_BOOTSTRAP.md에 기록한다.

일반 흐름: 계획/작업 브랜치 → 기능·테스트 → 작은 커밋 → push → 필요한 PR/리뷰/merge → develop 통합 → 안정화 → main 반영 → 조건 충족 시 태그/릴리스. 모든 단계가 항상 필요한 것은 아니다. 빈 원격의 최초 기준점은 PR 대상 이력이 없으므로 로컬 검증 후 초기 push로 구성할 수 있다. 원격에 예상 밖 이력이 있으면 fetch·차이 검토·비파괴 병합으로 보존하며 강제 덮어쓰지 않는다.

## 커밋과 PR

Conventional Commits: `type(scope): description`. type은 feat/fix/refactor/perf/docs/test/chore/style. 예: `feat(inventory): add item transfer validation`. 관련 없는 변경은 분리하고 작업 ID는 본문에 연결한다.

작업 후 관련 테스트 → 실제 실행 → 문서 갱신 → `git diff --check`, `git diff`, `git diff --cached` 검토 → commit/push 및 필요한 PR 통합을 자율 실행한다. untracked 파일도 내용/범위를 검사한다. stage/commit, 로컬·원격 브랜치 생성·전환·병합·삭제, fetch/pull/push, Issue/PR 생성·종료·병합, 원격 설정 변경, 검증된 태그/릴리스에 매번 사용자 승인을 요청하지 않는다. 관련 Issue가 있으면 연결하며 원격 작업 후 실제 ref/PR 상태를 확인한다.

`git reset --hard`, `git clean -fd`, `git push --force`, `git push --force-with-lease`, 임의 rebase/amend와 사용자 변경 삭제/덮어쓰기는 기본적으로 실행하지 않는다. 필요하면 손실 가능성을 분석하고 백업/복구 가능한 대안을 우선한다. 안전한 대안이 없거나 충돌 의도를 판단할 수 없으면 사용자에게 확인한다. 브랜치 삭제 전 미통합 커밋/사용자 작업을 확인한다. Git 권한은 Steam 게시/결제/라이선스 선택까지 포함하지 않는다.

## 검증과 보고

현재 실행 가능한 검사:

```sh
python3 tools/validate_foundation.py
python3 -m unittest discover -s tests -p 'test_*.py'
python3 tools/check_economy.py
git diff --check
```

엔진 설치/버전 확정 후 `godot --headless --path game --editor --quit`, `godot --headless --path game --quit-after 2`를 실행한다. 현재 빈 기반 씬은 게임 플레이가 아니다. UI/기능 구현 시 실제 창의 수동 검증을 추가한다. 프로젝트 루트와 `res://` 루트를 혼동하지 않는다.

완료 보고는 목적, 구현/변경, 파일, 설계, 실제 테스트 결과, 미해결 문제, 문서 갱신, 실제 커밋 해시와 push/merge/태그/릴리스 결과, 다음 작업을 포함한다. 미실행 테스트는 통과로 기록하지 않는다.
