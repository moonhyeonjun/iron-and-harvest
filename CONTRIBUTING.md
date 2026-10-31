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

기존 브랜치를 먼저 확인하며 같은 이름을 무조건 다시 생성하지 않는다. 정상 작업은 develop에서 분기한다. 현재는 최초 커밋이 없어 `feature/project-foundation`이 unborn 상태다. main/develop의 실체는 아직 없으며 이름과 정책만 정해졌다. **최초 커밋과 브랜치 기준점 구성은 승인 후 수행**한다. 실제 원격 기본 브랜치/보호 규칙은 확인·변경하지 않았다.

최초 커밋 승인 후의 제안 순서: 검토된 파일만 stage → 승인된 최초 커밋 → 그 커밋을 기준으로 main/develop 생성 → 이후 develop 기반 feature 브랜치. 이 최초 기준점 설정은 일반 PR 흐름의 bootstrap 예외다. 원격 push와 설정 변경은 각각 별도 승인 범위다. 현재 diff에 대한 사용자 승인이 미래 커밋·push·merge까지 자동으로 승인하는 것은 아니다.

## 커밋과 PR

Conventional Commits: `type(scope): description`. type은 feat/fix/refactor/perf/docs/test/chore/style. 예: `feat(inventory): add item transfer validation`. 관련 없는 변경은 분리하고 작업 ID는 본문에 연결한다.

작업 후 관련 테스트 → 실제 실행 → 문서 갱신 → `git diff --check`, `git diff`, `git diff --cached` 검토 → PR 초안을 준비한다. 초기 untracked 파일은 일반 diff에 나오지 않으므로 파일별 내용/manifest도 검사한다. **사용자 명시 승인 없이 commit, push, merge, tag, release, 원격 설정 변경을 실행하지 않는다.**

force push, `git reset --hard`, `git clean -fd`, 기존 변경 강제 덮어쓰기는 금지한다. 문제를 숨기기 위한 임의 stash/rebase/amend도 하지 않는다. 원격 PR/Issue 게시 권한을 추정하지 않고, 현재는 TASKS.md와 로컬 PR 초안으로 관리한다.

## 검증과 보고

현재 실행 가능한 검사:

```sh
python3 tools/validate_foundation.py
python3 -m unittest discover -s tests -p 'test_*.py'
python3 tools/check_economy.py
git diff --check
```

엔진 설치/버전 확정 후 `godot --headless --path game --editor --quit`, `godot --headless --path game --quit-after 2`를 실행한다. 현재 빈 기반 씬은 게임 플레이가 아니다. UI/기능 구현 시 실제 창의 수동 검증을 추가한다. 프로젝트 루트와 `res://` 루트를 혼동하지 않는다.

완료 보고는 목적, 구현/변경, 파일, 설계, 실제 테스트 결과, 미해결 문제, 문서 갱신, 추천 커밋 메시지, 다음 작업을 포함한다. 미실행 테스트는 통과로 기록하지 않는다.
