# Iron & Harvest

중세 판타지 픽셀 아트 생활·영지 경영 성장 시뮬레이션. 가난한 귀족이 주민과 마을을 발전시키고 장기적으로 제국을 건설한다. 목표 플랫폼은 PC / Steam이다.

## 현재 상태

2026-10-31: Foundation 기반·문서·관리 체계 준비. **게임 플레이 기능은 아직 없다.** Godot 4 계열 빈 설정/씬을 만들었지만 엔진을 발견하지 못해 실제 import/실행은 미검증이다. 버전은 Unreleased이며 v0.1.0 태그도 없다.

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
.github/             Issue/PR 템플릿, CI 도입 대기
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
```

엔진 확보/버전 기록 후 Godot에서 `game/project.godot`을 가져온다. 저장소 루트에 두 번째 project.godot을 만들지 않는다. 명령행은 `godot --headless --path game --editor --quit`, 빈 씬 확인은 `godot --headless --path game --quit-after 2`다. 지금의 정적 검사는 엔진 파싱/실행을 대신하지 않는다. Godot의 res://는 project.godot 위치를 기준으로 한다. [공식 파일 시스템 안내](https://docs.godotengine.org/en/stable/tutorials/scripting/filesystem.html)

## 다음 작업

IH-002: 엔진 경로/버전 확인과 빈 프로젝트 검증. 이후 IH-101: 작은 임시 맵의 플레이어 이동·충돌. LICENSE의 배포 조건은 소유자 결정 대기다. Git/GitHub 작업은 별도 승인 없이 수행하되 이력을 보존하고 원격 반영을 검증한다. 파괴적 작업에 안전한 대안이 없으면 사용자에게 확인한다.
