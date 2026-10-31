# Git 규칙

- 시작: `git status --short --branch`, `git branch --show-current`, `git diff`, `git diff --cached` 확인.
- untracked 파일도 보존한다. 기존 브랜치/원격/사용자 수정은 확인 없이 재생성·교체하지 않는다.
- main은 안정, develop은 통합, 작업은 feature/fix/refactor/docs/experiment 브랜치. 최초 커밋 전에는 실제 브랜치 ref가 없을 수 있다.
- 현재 foundation 브랜치는 feature/project-foundation이며 최초 커밋 승인 전이다. main/develop 기준점 생성 절차는 CONTRIBUTING.md를 따른다.
- Conventional Commits: `type(scope): description`; 한 논리적 변경 단위로 나눈다.
- 종료: 테스트·문서·diff/whitespace 확인 후 로컬 PR 초안과 추천 커밋 메시지 제시.
- **명시 승인 전 commit, push, merge, tag, release, remote 변경 금지.**
- force push, `git reset --hard`, `git clean -fd`, 사용자 수정 삭제/덮어쓰기 금지.
- 임의 amend/rebase/stash로 변경을 숨기지 않는다. 충돌은 영향과 대안을 보고하고 현재 작업을 보존한다.
- 승인은 지정된 작업/변경에만 적용한다. 로컬 준비 권한을 원격 게시 승인으로 확대하지 않는다.
