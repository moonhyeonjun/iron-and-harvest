# 변경 이력

완료 조건과 검증을 충족한 버전만 자율적으로 태그/릴리스한다. Foundation 기술 관문을 충족했으며 태그/원격 반영 여부는 IH-002 검증 기록을 따른다.

## Unreleased — 2026-10-31

- Foundation 재검증 완료, 기존 annotated v0.1.0 → d176bd7 및 원격 일치 확인; 태그 유지.
- IH-101 이동/입력/카메라/충돌/표현 상세 명세, AC-01~12 검사 계획, Claude Code 전달 프롬프트 추가.
- ADR-012 Proposed 기록, IH-101은 ready(기능 미구현·검사 미실행). 게임플레이 파일 변경 없음.

## 초기 Foundation 구축 기록 — 2026-10-31 (당시 상태)

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

## v0.1.0 Foundation — 2026-10-31

- IH-002 완료: Godot4.7.2 Standard / GDScript / Compatibility 검증.
- .godot-version과 버전 검증 실행 도구, 기반 GDScript smoke, Python 실행기 회귀 검사 추가.
- Import/Headless/GUI 종료0 및 사용자 GUI 정상 표시 확인. 엔진 자동 project.godot 포맷 변경 검토.
- Codex 설계·기술/Claude Code 구현 역할을 명시하고 TDD/ADR/작업 상태 갱신.
- 게임플레이는 미구현. Windows/export/성능/Steam 검증은 포함하지 않음.
