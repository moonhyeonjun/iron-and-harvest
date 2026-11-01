# Iron & Harvest

중세 판타지 픽셀 아트 생활·영지 경영 성장 시뮬레이션. 가난한 귀족이 주민과 마을을 발전시키고 장기적으로 제국을 건설한다. 목표 플랫폼은 PC / Steam이다.

## 현재 상태

**v0.2.0 Character 확정** — main `8901bac`에 annotated 태그를 생성하고 원격 반영을 검증했다. [판정·발행 기록](docs/03-development/CHARACTER-v0.2.0-VERIFICATION.md). 이동·상호작용 테스트 맵을 갖춘 개발 기준점이며 게임 출시판이 아니다.

2026-11-01: **IH-002 완료. Godot4.7.2 Standard / GDScript / Compatibility**를 검증했다. Import·Headless·GDScript smoke·그래픽 실행을 통과했고, GUI 표시를 사용자가 확인했다. 기본 실행 씬은 빈 Foundation이며, 이동·상호작용은 별도 테스트 맵에서 실행한다. v0.1.0 Foundation은 기술 기반 마일스톤이며 게임 출시판이 아니다. 기존 태그v0.1.0의 대상d176bd7과 원격 일치를 [Foundation 재검증 기록](docs/03-development/FOUNDATION-v0.1.0-VERIFICATION.md)에서 확인했다. IH-101 플레이어 이동·충돌은 Claude Code가 구현하고 AC-01~12를 검증했다([검증 기록](docs/03-development/IH-101-VALIDATION.md)). 테스트 맵은 `python3 tools/godot.py res://scenes/tests/movement_test.tscn`으로 실행하며 기본 진입점은 Foundation 그대로다. IH-102 상호작용은 구현·develop 통합 후 [Codex 리뷰](docs/03-development/IH-102-REVIEW.md)에서 BUG-003/004를 확인해 review로 재개했고, [PR #12](https://github.com/moonhyeonjun/iron-and-harvest/pull/12)로 수정·통합해 done이다. 채집·인벤토리·저장은 아직 없다.

최초 Foundation 커밋 `957dd3b`를 생성하고 `main`·`develop` 기준점을 구성했다. Git/GitHub는 사용자 요청 범위와 검증 조건에 따라 자율 운영한다. 원격 동기화와 실제 반영 기록은 [Git 구축 기록](docs/03-development/GIT_BOOTSTRAP.md)을 따른다. 최초 보고서는 당시 상태를 보존한 기록이다.

## 문서 진입점

| 영역 | 문서 |
|---|---|
| 개요·비전·로드맵 | [개요](docs/00-overview/PROJECT_OVERVIEW.md), [비전](docs/00-overview/GAME_VISION.md), [로드맵](docs/00-overview/ROADMAP.md) |
| 게임 기획 | [GDD](docs/01-game-design/GDD.md)에서 시스템별 문서로 이동 |
| 기술 설계 | [TDD](docs/02-technical-design/TDD.md), [환경](docs/02-technical-design/TOOLCHAIN.md) |
| 개발 관리 | [마일스톤](docs/03-development/MILESTONES.md), [작업](docs/03-development/TASKS.md), [주간 기록](docs/03-development/WEEKLY_LOG.md), [문제](docs/03-development/BUGS.md) |
| 의사결정 | [ADR](docs/04-decisions/ADR/README.md) |
| 아트 | [가이드](docs/05-art/ART_GUIDE.md), [에셋 목록](docs/05-art/ASSET_LIST.md) |
| 기여·에이전트 | [CONTRIBUTING](CONTRIBUTING.md), [CLAUDE](CLAUDE.md) |
| 이번 결과 | [구축 보고서](docs/03-development/FOUNDATION_REPORT.md), [파일 목록](docs/03-development/FILE_MANIFEST.md), [PR 초안](docs/03-development/PR_DRAFT.md) |

사용자 확정 콘셉트와 검증할 Proposed/TBD를 구분한다. 기존 docs/design·production·templates는 참고 원문으로 보존한다. 이전 README/CLAUDE 원문은 [archive 안내](docs/archive/README.md)를 따른다. 새 문서가 현재 기준이다.

## 디렉터리

```text
.github/             Issue/PR 템플릿, 고정 엔진 CI
.claude/rules/       아키텍처·코딩·Git·테스트 규칙
docs/00-overview/    개요·비전·로드맵
docs/01-game-design/ 시스템 기획
docs/02-technical-design/ 기술·환경
docs/03-development/ 작업·검증·주간 관리
docs/04-decisions/ADR/ 의사결정
docs/05-art/         아트 관리
game/               Godot 프로젝트 루트(res://)
  project.godot
  assets/ scenes/ scripts/ systems/ data/ ui/ tests/
art/source/         편집 원본, 게임 출력은 game/assets/
tests/              Python 저장소 검증기 테스트
tools/              관리·설계 검증 도구
data/design/        이전 경제 가정 실험, 런타임 아님
```

## 검사와 프로젝트 열기

```sh
python3 tools/validate_foundation.py
python3 -m unittest discover -s tests -p 'test_*.py'
python3 tools/check_economy.py
python3 tools/godot.py --headless --import
python3 tools/godot.py --headless --script res://tests/smoke_engine.gd
```

Godot 실행은 `python3 tools/godot.py --editor`, 빈 프로젝트 실행은 `python3 tools/godot.py`다. 도구가 `.godot-version`을 확인하고 `game/`을 프로젝트 루트로 지정한다. 설치 위치와 전체 검증 명령은 [TOOLCHAIN](docs/02-technical-design/TOOLCHAIN.md)을 따른다. 다른 설치는 GODOT_BIN으로 명시한다.

Codex는 설계/기술 기반 검증, Claude Code는 이후 게임 기능 구현을 맡는다. 이번 smoke 테스트는 게임 기능이 아니다.

## 다음 작업

IH-004 CI는 정상/실패·통합 검증을 완료했다([검증 기록](docs/03-development/IH-004-VALIDATION.md)). IH-102 상호작용(안내판/상자 살펴보기)은 Claude Code가 구현하고 AC-I01~12를 검증했다([검증 기록](docs/03-development/IH-102-VALIDATION.md)). 테스트 맵은 `python3 tools/godot.py res://scenes/tests/interaction_test.tscn`으로 실행한다. 아이템·채집·저장은 아직 없다. BUG-003/004 수정은 통합됐으며 [검토 기록](docs/03-development/IH-102-REVIEW.md)을 따른다. v0.2.0 마일스톤의 기능 판정을 통과했다. IH-110은 [아이템·인벤토리 상세 명세](docs/02-technical-design/INVENTORY.md)·[수락 조건](docs/03-development/IH-110-ACCEPTANCE.md)·[Claude 전달 프롬프트](docs/03-development/IH-110-HANDOFF.md)에 따라 Claude Code가 구현하고 AC-N01~14를 검증했다([검증 기록](docs/03-development/IH-110-VALIDATION.md), done). 시험 맵은 `python3 tools/godot.py res://scenes/tests/inventory_test.tscn`이다. Codex는 명세·기술 검토를 맡는다. LICENSE의 배포 조건은 소유자 결정 대기다. Git/GitHub 작업은 별도 승인 없이 수행하되 이력을 보존하고 원격 반영을 검증한다. 파괴적 작업에 안전한 대안이 없으면 사용자에게 확인한다.
