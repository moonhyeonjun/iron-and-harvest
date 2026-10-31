# Foundation 파일 변경 목록

> 최초 구축 당시 상태를 보존한 역사 기록이다. 이후 Git 정책·커밋·원격 상태는 [GIT_BOOTSTRAP](GIT_BOOTSTRAP.md)과 ADR-010을 따른다.

기준: 작업 시작 당시 로컬14파일과 비교. Git은 최초 커밋 전이라 아래 파일은 모두 Git 관점에서 untracked다. 생성/수정 구분은 로컬 snapshot 대비다. 캐시/무시 파일 제외.

- 신규 66파일
- 갱신 2파일: 이전 원문은 archive에 보존
- 변경 없이 보존 12파일
- 검토 대상 전체 80파일

## 신규 파일

- `.claude/rules/architecture.md`
- `.claude/rules/coding-standards.md`
- `.claude/rules/git-workflow.md`
- `.claude/rules/testing.md`
- `.gitattributes`
- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `.github/ISSUE_TEMPLATE/tech_task.md`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/workflows/README.md`
- `.gitignore`
- `CHANGELOG.md`
- `CONTRIBUTING.md`
- `LICENSE`
- `art/source/README.md`
- `docs/00-overview/GAME_VISION.md`
- `docs/00-overview/PROJECT_OVERVIEW.md`
- `docs/00-overview/ROADMAP.md`
- `docs/01-game-design/CHARACTER_SYSTEM.md`
- `docs/01-game-design/COMBAT_SYSTEM.md`
- `docs/01-game-design/ECONOMY_SYSTEM.md`
- `docs/01-game-design/ESTATE_MANAGEMENT.md`
- `docs/01-game-design/GAME_LOOP.md`
- `docs/01-game-design/GDD.md`
- `docs/01-game-design/ITEM_SYSTEM.md`
- `docs/01-game-design/LIFE_SYSTEM.md`
- `docs/01-game-design/WORLD_SYSTEM.md`
- `docs/02-technical-design/ARCHITECTURE.md`
- `docs/02-technical-design/DATA_MODEL.md`
- `docs/02-technical-design/PERFORMANCE.md`
- `docs/02-technical-design/SAVE_SYSTEM.md`
- `docs/02-technical-design/TDD.md`
- `docs/02-technical-design/TOOLCHAIN.md`
- `docs/03-development/BUGS.md`
- `docs/03-development/FILE_MANIFEST.md`
- `docs/03-development/FOUNDATION_REPORT.md`
- `docs/03-development/MILESTONES.md`
- `docs/03-development/PR_DRAFT.md`
- `docs/03-development/TASKS.md`
- `docs/03-development/WEEKLY_LOG.md`
- `docs/04-decisions/ADR/ADR-001-godot-engine.md`
- `docs/04-decisions/ADR/ADR-002-gdscript.md`
- `docs/04-decisions/ADR/ADR-003-data-management.md`
- `docs/04-decisions/ADR/ADR-004-save-system.md`
- `docs/04-decisions/ADR/ADR-005-time-simulation.md`
- `docs/04-decisions/ADR/ADR-006-npc-simulation.md`
- `docs/04-decisions/ADR/ADR-007-event-system.md`
- `docs/04-decisions/ADR/ADR-008-shared-world.md`
- `docs/04-decisions/ADR/ADR-009-repository-layout.md`
- `docs/04-decisions/ADR/README.md`
- `docs/05-art/ART_GUIDE.md`
- `docs/05-art/ASSET_LIST.md`
- `docs/archive/2026-10-31-initial-design/CLAUDE.md`
- `docs/archive/2026-10-31-initial-design/README.md`
- `docs/archive/README.md`
- `game/assets/README.md`
- `game/data/README.md`
- `game/project.godot`
- `game/scenes/foundation.tscn`
- `game/scripts/README.md`
- `game/systems/README.md`
- `game/tests/README.md`
- `game/ui/README.md`
- `tests/README.md`
- `tests/test_foundation_validation.py`
- `tools/validate_foundation.py`

## 갱신 파일

- `README.md`
- `CLAUDE.md`

## 변경 없이 보존한 기존 파일

- `data/design/economy-baseline.json`
- `docs/design/01-core-experience.md`
- `docs/design/02-gdd.md`
- `docs/design/03-mvp.md`
- `docs/design/04-architecture.md`
- `docs/design/decisions.md`
- `docs/design/sources.md`
- `docs/production/12-month-roadmap.md`
- `docs/production/2026-10-31-handoff.md`
- `docs/production/work-prompts.md`
- `docs/templates/weekly-report.md`
- `tools/check_economy.py`
