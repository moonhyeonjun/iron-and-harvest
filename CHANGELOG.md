# 변경 이력

완료 조건과 검증을 충족한 버전만 자율적으로 태그/릴리스한다. 현재 엔진 검증이 남아 있어 버전 태그/릴리스는 없다.

## Unreleased — 2026-10-31

### Added

- 요청한 개요·게임 기획·기술 설계·개발 관리·아트 문서 체계.
- Claude 규칙, GitHub Issue/PR 템플릿, Git ignore/줄바꿈 정책.
- `game/` 아래 Godot 4 계열 기반 설정과 기능 없는 빈 씬.
- Foundation 정적 검증 도구와 검증기 회귀 테스트, 로컬 관리 작업 ID.

### Changed

- README/CLAUDE의 문서 진입점을 새 체계로 갱신. 이전 원문은 docs/archive에 보존.
- 이전 상세 기획을 참조 초안으로 구분. 수치·정확한 엔진 버전·라이선스는 미확정으로 관리.

### Not implemented

- 캐릭터 이동·상호작용·채집·경제·저장 등 게임 플레이 기능.
- Godot 실제 import/실행 검증. 최초 구축 당시 Git 실행 여부는 FOUNDATION_REPORT의 역사 기록을 따른다.

## Git 운영 후속 — 2026-10-31

- 최초 Foundation 커밋 957dd3b 생성, main/develop 기준점 구성.
- ADR-010으로 Git/GitHub 자율 운영 정책 수락, 기존 안전 규칙 유지.
- 정책·원격 동기화 결과는 GIT_BOOTSTRAP과 WEEKLY_LOG에서 관리.
