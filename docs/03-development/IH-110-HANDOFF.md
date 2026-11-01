# Claude Code 인수인계 — IH-110

상태: **상세 설계 완료 / 구현 미시작 / ready**, 2026-11-01. Codex는 문서·검증 기준만 작성했다. IH-101/102와 IH-004 CI는 done, v0.2.0 Character는 원격 발행 완료다. main/v0.2.0을 변경하지 않고 최신 develop에서 구현한다.

## 읽기와 변경 범위

CLAUDE.md/.claude/rules → [TASKS](TASKS.md) → [아이템 기획](../01-game-design/ITEM_SYSTEM.md) → [INVENTORY](../02-technical-design/INVENTORY.md) → [AC-N01~14](IH-110-ACCEPTANCE.md) → [ADR-015](../04-decisions/ADR/ADR-015-inventory-contract.md) → [상호작용 리뷰](IH-102-REVIEW.md)/실제 코드 → [CI 운영](../02-technical-design/CI.md).

신규 파일 후보는 INVENTORY의 씬·모듈 표를 따른다. 수정 후보는 project.godot(가방 입력만), interaction_controller.gd(enabled 읽기 getter 필요 시), tools/run_ci.py/관련 Python CI 테스트, game/tests/README.md, 구현 상태 문서다. Player 이동 정책/기존 Target 지급 동작/기본 Foundation 씬은 변경 대상이 아니다. 공유 원본을 수정하지 않는 카탈로그, 참조 없는 재고 snapshot, 실제 입력 경계가 핵심 리뷰 대상이다.

## 작업 순서

1. 작업 트리/브랜치/원격 확인, 사용자 파일 보존, feature/inventory-system에서 파일 목록·계획 제시.
2. 작은 Resource/JSON 정의 예제 비교와 실패 검증. 기본안 .tres 선택 결과를 ADR/검증 기록에 남기고 하나의 원본만 사용.
3. 카탈로그·상태·원자 명령·snapshot과 AC-N01~09 구현. UI에 앞서 실패 불변식 확인.
4. 최소 조율자·가방 UI·유한 fixture 연결, AC-N10~12 및 기존 이동/상호작용 회귀.
5. runner/CI 등록, AC-N13·실제 GUI AC-N14. 로그와 실패 주입 증거 기록.
6. 코드/문서 리뷰·검증 보고·필수 PR CI 후 develop 통합, 원격 결과 확인. main 승격/태그는 이번 작업 범위 아님.

## 전달용 프롬프트

```text
IH-110 아이템 정의와 인벤토리를 구현하라.
CLAUDE.md/.claude/rules, docs/02-technical-design/INVENTORY.md,
docs/03-development/IH-110-ACCEPTANCE.md, IH-110-HANDOFF.md,
ADR-015와 CI.md 및 기존 InteractionController/Player/UI 코드를 먼저 읽는다.
최신 develop/Git 상태/사용자 변경을 확인하고 feature/inventory-system에서 시작한다.
수정 파일과 계획을 먼저 제시한 뒤 작은 단계로 구현한다.
엔진4.7.2 Standard/GDScript/Compatibility와 기존 Foundation 진입점을 유지한다.
Resource/JSON 작은 예제 비교를 수행하고 .tres 기본안 선택 근거와 검증 결과를 기록한다.
ItemDef·Catalog·고정 슬롯·원자 add/remove/transfer·expected revision·snapshot을 구현한다.
실패는 슬롯/수량/revision/이벤트 모두 불변, transfer는 양쪽 전체 성공만 허용한다.
정의 Resource와 외부 snapshot 변경이 내부 상태를 바꾸지 않게 한다.
UI는 session/선택/revision 의도만 보내고 도메인 상태나 이동 게이트를 직접 수정하지 않는다.
가방과 살펴보기는 배타적이며 입력 큐 취소·포커스·수명·중립키 복구를 검사한다.
기존 try_begin/can_interact에서 아이템 지급하지 않는다. 기존 상자는 살펴보기 전용으로 보존한다.
별도 inventory_test 맵의 유한 보관함으로 양방향 이동을 검증한다.
12슬롯/7품목/스택10은 검증 제안이며 제품 최종 밸런스로 확정하지 않는다.
채집·소비·장비·제작·드롭·예약·실제 저장·통치·범용 전역 잠금은 구현하지 않는다.
AC-N01~14와 기존 이동360/상호작용333 기준의 회귀를 실행한다.
숫자만 맞추지 말고 기존 검증 의도를 보존하며 새 runner를 공통 CI에 등록한다.
실패 주입과 엔진 오류 검출을 확인하고 GUI 확인 주체/빌드 SHA를 기록한다.
구현 차이가 필요하면 이유와 명세·테스트 영향을 먼저 기록한다. 미검증을 완료로 보고하지 않는다.
IH-110-VALIDATION.md 및 TASKS/WEEKLY_LOG/BUGS/CHANGELOG/ADR 상태를 실제 증거로 갱신한다.
Conventional Commits·push·PR의 필수 CI checks 성공 후 develop에 통합하고 원격 결과를 확인한다.
사용자의 미추적 AGENTS.md를 덮어쓰거나 이번 커밋에 포함하지 않는다.
main/태그/릴리스는 만들지 않는다. 파일·설계 차이·AC 결과·미검증·커밋/PR/CI를 보고한다.
```

## 알려진 제약

루트 미추적 AGENTS.md는 없는 .Codex/rules 링크4개를 포함한다. 사용자 파일을 고쳐 검사 통과시키지 말고 실제 루트 검사 결과와 커밋된 깨끗한 worktree 검사를 구분한다. 기존 .claude/rules가 프로젝트 기준이다. DEBT-002 단일 bool 게이트의 제3 작성자 문제와 DEBT-003 배포 한글 글꼴은 남는다. 현재 구현 계약은 두 모달의 배타적 사용만 지원한다. 게임 전체 저장/보상 중복 방지나 새 잠금 작성자 지원으로 확대 해석하지 않는다.
