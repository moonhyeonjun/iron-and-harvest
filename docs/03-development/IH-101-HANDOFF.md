# Claude Code 인수인계 — IH-101

상태: 명세 준비 완료 → **2026-10-31 Claude Code 구현·검증 완료**([검증 기록](IH-101-VALIDATION.md)). 아래는 원래 인수인계 내용이다. 2026-10-31. Codex는 이번 작업에서 게임플레이 파일이나 입력 설정을 변경하지 않았다. TASKS의 IH-101 ready는 설계/의존성이 준비됐다는 뜻이며 구현 완료가 아니다.

## 읽기 순서

1. 루트 CLAUDE.md와 .claude/rules, Git 상태/현재 브랜치/기존 diff.
2. [TDD](../02-technical-design/TDD.md), [고정 환경](../02-technical-design/TOOLCHAIN.md), [ADR-011](../04-decisions/ADR/ADR-011-validated-godot-toolchain.md).
3. [이동 상세 명세](../02-technical-design/PLAYER_MOVEMENT.md), [ADR-012 Proposed](../04-decisions/ADR/ADR-012-player-movement.md).
4. [수락 조건 AC-01~12](IH-101-ACCEPTANCE.md), [작업 현황](TASKS.md), [버그](BUGS.md).

Foundation 기준은 v0.1.0 → d176bd7094db783c2aaf43b2ee227936a5137758이다. 구현은 그 태그로 강제 checkout하지 않고 최신 develop을 fetch/검토한 뒤 feature/player-movement에서 시작한다. 태그는 보존한다.

## 구현 작업 단위

| 순서 | 내용 | 검증·커밋 경계 |
|---|---|---|
| 1 | 입력4액션·Player/물리 이동·fixture·기본 물리 검사 | AC-01~06; 플레이 가능한 최소 수직 단위 |
| 2 | 조작 게이트/포커스·Visual 상태·Camera 검증 완성 | AC-07~10; 씬/컨트롤러 범위만 |
| 3 | 회귀·GUI·문서·통합 | AC-11~12, 실제 결과 기록·PR develop |

한 번에 생성할 파일과 의존성을 먼저 제시한다. 구현/테스트를 같은 의미 단위로 커밋한다. 단위별 실패는 다음 단계에서 숨기지 않는다. branch/commit 이름은 기존 충돌 여부를 먼저 확인한다.

## 전달용 작업 프롬프트

```text
IH-101 플레이어 이동·충돌을 구현하라. 먼저 CLAUDE.md, 관련 TDD,
PLAYER_MOVEMENT.md, ADR-011/012, IH-101-ACCEPTANCE.md를 읽고 Git 상태를 확인한다.
Godot4.7.2 Standard/GDScript/Compatibility를 유지하고 tools/godot.py를 사용한다.
최신 develop에서 feature/player-movement 작업 브랜치를 구성한다.
기존 사용자 변경을 보호하고 수정 예정 파일·작업 순서를 제시한 뒤 작은 단위로 구현한다.
명세의 수치는 임시 검증 기준이며 제품의 최종 밸런스/아트 결정으로 기록하지 않는다.
CharacterBody2D 기반8방향 이동,4방향 상태,충돌,조작 차단,카메라,임시 맵을 구현한다.
상호작용·채집·가방·전투·저장·NPC·통치 UI는 구현하지 않는다.
기본 Foundation 씬과 기존 smoke는 유지하고 테스트 맵은 명시 경로로 실행한다.
실제 물리 동작 테스트와 수동 GUI 확인을 수행하고 AC-01~12 결과를 각각 기록한다.
검증 불가/실패는 pending/fail로 남기며 실제 구현·검증된 항목만 완료 보고한다.
TASKS/WEEKLY_LOG/BUGS/CHANGELOG와 필요한 명세 변경을 함께 갱신한다.
검증된 변경을 Conventional Commits로 기록하고 자율 Git 정책에 따라 develop PR로 통합한다.
IH-101만으로 v0.2.0 태그나 제품 릴리스를 생성하지 않는다.
최종 보고에는 파일,테스트 명령·결과,수동 확인 주체,미해결 항목,커밋/PR/원격 결과를 포함한다.
```

## 판단이 필요한 경우

속도·충돌·카메라에 문제가 드러나면 측정 결과와 대안을 기록하고 fixture/수락 기준을 함께 변경한다. 수락 오차를 넓혀 결함을 숨기지 않는다. 아트가 없어도 임시 도형으로 진행 가능하다. 엔진 변경·미정 라이선스 선택·범위 확대를 문제 해결 수단으로 임의 실행하지 않는다.

현재 API 호환성은 공식 문서에 근거한 설계 검토이며 Player 코드의 엔진 검증은 아직 없다. 구현 중 명세와4.7.2 실제 API가 다르면 코드를 맞추고 차이를 ADR/로그에 기록한다. GUI 확인 권한/도구가 없으면 수동 항목은 보류하고 사용자 확인을 받을 수 있는 구체적인 창과 절차를 제공한다.
