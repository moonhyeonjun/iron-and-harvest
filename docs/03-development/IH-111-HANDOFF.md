# Claude Code 인수인계 — IH-111

**현재 상태: 구현·수정·독립 검증 완료(done).** BUG-007/008은 PR #29로 수정·통합됐고 Codex가 1cb3471에서 원래 진단4종과 전체 CI를 재검증했다([결과](IH-111-VALIDATION.md#codex-독립-수정-재검증)). 아래 최초 구현 프롬프트와 리뷰의 수정 프롬프트는 완료 이력이며 반복 실행하지 않는다. 다음 구현에는 새 작업 명세를 사용한다.

상태: 상세 설계 완료 → **2026-11-01 Claude Code 구현·검증·통합(done)**, [IH-111 검증 기록](IH-111-VALIDATION.md). 아래는 원래 인수인계 내용이다. 2026-11-01. Codex가 문서와 검증 계약만 작성했다. 기능/새 runner/GUI는 아직 없다. IH-110 done(버그 수정·독립 검증 포함), ADR-016 Proposed. 아래 프롬프트가 이번 작업의 전달용이다.

## 읽기·파일·작업 순서

CLAUDE.md/.claude/rules → [TASKS](TASKS.md) → [생활](../01-game-design/LIFE_SYSTEM.md) → [GATHERING](../02-technical-design/GATHERING.md) → [AC-G01~14](IH-111-ACCEPTANCE.md) → [ADR-016](../04-decisions/ADR/ADR-016-atomic-gathering.md) → 기존 Interaction/Inventory 실제 코드·테스트·리뷰 → [CI](../02-technical-design/CI.md).

신규/수정 후보는 GATHERING의 모듈 표를 따른다. 전역 매니저/이동 정책/기본 진입점은 변경하지 않는다. 구현 중 필수 API 차이를 발견하면 근거와 계약 영향을 기록하고 작은 수정으로 해결한다.

1. 최신 develop/작업 트리 확인, feature/gathering-system 분기, 파일 목록·계획 제시.
2. 세 정의·PointBinding·숨은 재고·서비스/단발 명령 구현. 원자성/공간/stale/중복/오염 검사를 UI보다 먼저 검증.
3. 기존 INSPECT 보존, INSTANT 실행 경계와 취소/재진입/Node 수명 회귀 추가.
4. 단일 서비스의 일반/full/rebind 테스트 맵과 비모달 표시 연결. 초기화 검수·부분 실패·소진/재진입 확인.
5. runner/공통 CI 등록, 실패 주입/변이·기존 회귀·실제 GUI 검증.
6. 검증 문서와 작업 상태 갱신, 필수 PR CI 후 develop 통합·원격 확인. main/태그는 이번 범위가 아니다.

## 전달용 프롬프트

```text
IH-111 채집·자원 지점을 구현하라.
CLAUDE.md/.claude/rules, docs/02-technical-design/GATHERING.md,
docs/03-development/IH-111-ACCEPTANCE.md, IH-111-HANDOFF.md,
ADR-016과 기존 InteractionController/Target, InventoryService/Controller/UI 및 테스트를 읽는다.
Git 상태·최신 develop·사용자 변경을 확인하고 feature/gathering-system에서 시작한다.
수정 파일과 계획을 먼저 제시한 뒤 작은 단계로 구현한다.
Godot4.7.2 Standard/GDScript/Compatibility, 기존 Foundation 진입점과 테스트 맵을 유지한다.
나뭇가지/돌/산열매 세 종류를 E 새 누름당1개 즉시 채집한다.
지점별 숨은1슬롯 재고를 같은 InventoryService에 두고 transfer로 stock→bag을 원자 적용한다.
remaining/depleted는 파생값이다. add 후 별도 차감/rollback/재진입 시 초기 재지급을 만들지 않는다.
정의는 검증한 스칼라 복사, stable ID와 결속은 전체 맵·bag/store까지 검사한다.
prepare는 지급 없이 두 revision을 캡처한다. 단발 명령은 소비/취소/실패 후 재사용할 수 없다.
try_begin/can_interact/프롬프트/session_opened에서 지급하지 않는다.
기존 INSPECT는 보존하고 마지막 재검증 뒤 INSTANT/EXECUTING에서 RefCounted 명령을 호출한다.
commit 전 취소는 지급0, commit 후 UI/Target 제거·서비스 종료는 이미 성공한 거래를 되돌리지 않는다.
변경 신호·정리 콜백의 재진입 E를 다음 틱 작업으로 남기지 않는다.
instant는 모달/이동 게이트를 소유하지 않는다. 가방과 기존 살펴보기의 배타성을 보존한다.
기존 inventory_test를 중첩해 서비스를 이중 생성하지 말고 단일 서비스 테스트 맵을 구성한다.
일반/full/rebind fixture, 소진 표시, 실패 안내, 숨은 재고 UI 비노출을 구현한다.
도구/기력/작업시간/재생/파일 저장/농사/전투/위임/범용 잠금은 구현하지 않는다.
AC-G01~14, 기존 이동360/상호작용333/인벤토리521 회귀 의도를 보존한다.
새 runner를 공통 CI에 등록하고 실패 주입·표적 변이·반복 결과·엔진 오류0을 검증한다.
GUI 확인 주체/빌드 SHA/절차를 기록하며 미실행을 pass로 보고하지 않는다.
IH-111-VALIDATION.md를 생성하고 TASKS/WEEKLY_LOG/BUGS/CHANGELOG와 설계 차이/ADR 상태를 갱신한다.
Conventional Commits, push, PR 필수 CI 성공 후 develop 통합·원격 결과를 검증한다.
사용자 미추적 AGENTS.md를 변경하거나 커밋하지 않는다.
main/태그/릴리스는 만들지 않는다. 파일·AC 결과·미검증·설계 차이·커밋/PR/CI를 보고한다.
```

## 알려진 제약

사용자 미추적 AGENTS.md에 없는 .Codex/rules 링크4개가 있다. 사용자 파일을 고쳐 검사를 통과시키지 말고 원래 루트 검사와 커밋된 깨끗한 worktree 검사를 구분한다. 실제 규칙은 .claude/rules다. DEBT-002(제3 게이트 작성자), DEBT-003(배포 한글 글꼴), 라이선스 결정은 이번에 해결하지 않는다. v0.2.0은 기존 개발 기준점이며 IH-111 ready는 구현 완료를 뜻하지 않는다.
