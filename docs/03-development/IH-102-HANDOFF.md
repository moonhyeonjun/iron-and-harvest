# Claude Code 인수인계 — IH-102

상태: **명세 준비 완료 / 기능 미구현**, 2026-10-31. IH-004 CI 검증을 완료한 뒤 작성했다. Codex는 이번에 게임 기능/입력/씬을 변경하지 않았다.

## 읽기 순서와 기준

CLAUDE.md/.claude/rules → [TASKS](TASKS.md) → [CI 운영](../02-technical-design/CI.md) → [이동 구현·검증](IH-101-VALIDATION.md) → [상호작용 명세](../02-technical-design/INTERACTION.md) → [수락 조건](IH-102-ACCEPTANCE.md) → [ADR-014](../04-decisions/ADR/ADR-014-interaction-boundary.md).

엔진4.7.2 Standard/GDScript/Compatibility를 유지한다. 최신 develop을 fetch·검토한 후 feature/interaction-system에서 작업한다. main/develop은 CI checks가 필수이므로 문서도 PR로 통합한다. v0.1.0 및 main을 초기 상태로 되돌리지 않는다.

## 구현 순서

1. Target/Detector의 typed 계약과 거리·방향·가시선·동률 검사를 구현한다. 기존 Player 이동은 보존한다.
2. 입력 의도 큐·재검증·세션/취소·이동 게이트·포커스/삭제 경계를 구현한다.
3. 임시 안내판/상자와 프롬프트·설명 패널을 연결하고 자동·GUI 검사를 완료한다.
4. test_interaction을 tools/run_ci.py에 추가하고 기존 이동 회귀와 함께 PR CI를 통과시킨다.
5. TASKS/WEEKLY_LOG/BUGS/CHANGELOG/검증 보고를 갱신하고 develop 통합 후 원격 검사를 확인한다.

## 전달용 프롬프트

```text
IH-102 상호작용 대상·프롬프트를 구현하라.
CLAUDE.md와 INTERACTION.md, IH-102-ACCEPTANCE.md, ADR-014, CI.md를 먼저 읽는다.
현재 Git/브랜치/사용자 변경을 확인하고 최신 develop에서 작업 브랜치를 구성한다.
수정 예정 파일과 작업 순서를 제시한 뒤 작은 단위로 구현·테스트한다.
별도 InteractionController/Target/UI로 탐지·선택·입력 큐·재검증·살펴보기·취소를 만든다.
32거리/정면각/키/UI는 검증용 제안이며 제품 최종 수치로 확정하지 않는다.
이동·카메라·기존 fixture·Foundation 진입점과 IH-101 테스트를 보존한다.
아이템 지급·가방·채집·대화 트리·상점·전투·저장·통치 기능은 구현하지 않는다.
AC-I01~12를 실제 검사하고 엔진 오류·대상 소멸·중복 요청·게이트 복구를 검증한다.
실제 GUI 확인을 자동 테스트로 대체하지 말고 확인 주체와 빌드를 기록한다.
정상 test_interaction을 공통 CI 실행기에 등록하고 실패 마커/종료 경로도 검사한다.
새 기능을 미검증 상태에서 done으로 기록하지 않는다.
코드/문서 리뷰 후 Conventional Commits, push, PR CI checks 성공, develop 병합을 수행한다.
보호 규칙을 우회하지 않고 원격 결과를 확인한다. v0.2.0 태그/릴리스는 별도 검토다.
완료 보고에 파일·설계 차이·AC 결과·미검증·커밋/PR/CI 링크·다음 작업을 포함한다.
```

## 인수인계 주의점

- _unhandled_input과 물리 처리를 분리한다. Enter/Exit 후보만 믿고 실행하지 않는다.
- 시작 입력의 대상이 사라져도 다른 대상으로 바꾸어 실행하지 않는다.
- UI가 이동/자원을 직접 수정하지 않고 예전 session ID의 닫기가 새 세션에 영향을 주지 않게 한다.
- 포커스 알림은 _ready보다 먼저 올 수 있다. BUG-001을 새 컴포넌트에 재도입하지 않는다.
- 현재 컨트롤 게이트는 단일 소유자 전제다. 다중 모달/전투/비동기 작업을 필요 없이 선행 구현하지 않는다.
- 명세 변경이 필요하면 실제 측정·이유와 수락 기준 변경을 함께 남긴다. 실패를 숨기기 위해 테스트를 제거하지 않는다.
