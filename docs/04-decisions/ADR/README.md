# 의사결정 색인

Accepted는 사용자 확정 원칙/현재 구조, Proposed는 검증/결정 대기다. 기술 후보를 확정된 엔진/구현으로 보고하지 않는다. 기존 결정은 삭제하지 않으며 후속 ADR에서 supersedes 관계를 기록한다.

- [ADR-001 게임 엔진 선택](ADR-001-godot-engine.md) — 초기 Proposed; ADR-011로 확정
- [ADR-002 스크립트 언어](ADR-002-gdscript.md) — 초기 Proposed; ADR-011로 확정
- [ADR-003 데이터 관리](ADR-003-data-management.md) — Proposed
- [ADR-004 저장과 마이그레이션](ADR-004-save-system.md) — Proposed
- [ADR-005 시간 처리](ADR-005-time-simulation.md) — Proposed
- [ADR-006 NPC 시뮬레이션](ADR-006-npc-simulation.md) — Proposed
- [ADR-007 이벤트 구조](ADR-007-event-system.md) — Proposed
- [ADR-008 생활과 통치 연결](ADR-008-shared-world.md) — Accepted
- [ADR-009 저장소·Git 운영](ADR-009-repository-layout.md) — Accepted

기존 docs/design/decisions.md는 초기 제안 원문으로 보존한다. 신규 결정은 여기서 추적한다.

- [ADR-010 Git/GitHub 자율 운영](ADR-010-autonomous-git.md) — Accepted. ADR-009의 Git 승인 대기 부분을 대체한다.

- [ADR-011 검증된 Godot 개발 기준](ADR-011-validated-godot-toolchain.md) — Accepted, IH-002 완료.

- [ADR-012 생활 이동의 최소 구현 경계](ADR-012-player-movement.md) — Proposed, IH-101 구현·수락 검증 완료. 최종 조작·수치 결정은 후속이며 v0.2.0 판정과 구분.

- [ADR-013 CI 관문](ADR-013-continuous-integration.md) — Accepted, IH-004 원격 성공/실패·병합 관문 검증 완료.

- [ADR-014 상호작용 경계](ADR-014-interaction-boundary.md) — Proposed, IH-102 구현·BUG-003/004 수정·수락 검증 완료. 최종 제품 결정은 후속.

- [ADR-015 아이템·인벤토리 계약](ADR-015-inventory-contract.md) — Proposed. IH-110 구현·BUG-005/006 수정·Codex 독립 재검증 완료(done). Accepted 전환은 별도 판단. ADR-003 전체를 대체하지 않음.

- [ADR-016 유한 재고 전송과 즉시 채집 경계](ADR-016-atomic-gathering.md) — Proposed. IH-111 구현·BUG-007/008 수정·Codex 독립 재검증 완료(done). Accepted 전환은 별도 판단. [수정 검토](../../03-development/IH-111-REVIEW.md). ADR-014/015의 채집 연결을 구체화하며 전체를 대체하지 않음.
