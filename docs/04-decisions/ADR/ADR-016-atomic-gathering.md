# ADR-016: 유한 재고 전송과 즉시 채집 실행 경계

- 상태: **Proposed** — 구현·수락 검증 완료(2026-11-01), Accepted 판정은 별도
- 날짜: 2026-11-01
- 관련: IH-111, [GATHERING](../../02-technical-design/GATHERING.md), [ADR-014](ADR-014-interaction-boundary.md), [ADR-015](ADR-015-inventory-contract.md)

## 배경

IH-110의 InventoryService는 두 재고의 원자 transfer·revision·단일 변경 신호를 제공한다. 현재 Interaction은 살펴보기이며 try_begin 이후 취소/대상 재검증이 있다. 그 훅에서 지급하면 취소된 작업에 보상이 생긴다. UI/Target 제거 시 수명 문제도 고려해야 한다.

## 검토한 대안

1. GatherNode.remaining 감소와 bag.add 분리: 실패·재진입·저장 불일치 위험, rollback 필요.
2. InventoryService에 모든 자원 도메인을 아는 범용 거래 엔진 추가: 현재 규모에서 과한 결합/추상화.
3. 유한 지점을 숨은 재고로 모델링하고 기존 transfer 사용: 기존 원자 경계 재사용, 중복 잔량 제거. **제안 선택**.

## 결정 제안·이유

지점마다 하나의 품목·1슬롯 stock을 둔다. stock→bag 1개 전송으로 소진/지급을 같이 commit한다. 준비 명령은 revision만 캡처하고 지급하지 않는다. 최종 Interaction 재검증 뒤 RefCounted 명령을 실행한다. INSPECT와 INSTANT만 분리하며 instant는 모달/이동 게이트를 소유하지 않는다. 상태 설치 이후 UI 수명 변경은 이미 성공한 거래를 취소하지 않는다.

초기 세 종류의 즉시 줍기로 수집→보관→복귀와 유한 세계 상태를 검증한다. 시간/재생/도구/농사/위임은 별도 작업에서 필요 계약을 추가한다.

## 단점·고려사항

숨은 Inventory 수가 지점 수만큼 증가하고 UI/집계에서 미채집 물자를 제외해야 한다. 현재 모델은 단일 품목·스택 한도 이하에 적합하다. 대형 광맥/다중 산출/노동 시간/예약은 그대로 확장하지 않고 재검토한다. 명령 중복 방지는 세션 내 단발 실행이며 영속 보상 일지가 아니다. Node 수명과 commit 전후 취소 경계는 엔진 회귀로 증명해야 한다.

## 영향·검증 관문

Interaction의 최소 instant 분기, Gather 정의/서비스/Target, 전용 테스트 맵·CI 회귀가 필요하다. IH-112 저장에는 결속과 숨은 stock을 포함하되 remaining을 중복 저장하지 않는다. 기존 ADR-014/015 전체를 대체하지 않고 채집 경계를 구체화한다.

AC-G01~14·기존 회귀·실제 GUI·필수 PR CI를 확인한 후 Accepted 전환을 별도 판단한다. 문서 ready만으로 Accepted나 IH-111 done을 기록하지 않는다.

## 구현 검증 결과 (2026-11-01)

Claude Code가 이 제안대로 구현했다. 숨은 1슬롯 stock과 기존 transfer 재사용, 단발 명령, 최종 재검증 뒤 INSTANT 실행, commit 후 수명 변화 무롤백을 AC-G01~14와 변이 7종 검출로 확인했다([검증 기록](../../03-development/IH-111-VALIDATION.md)). 타입 있는 Resource 필드가 소수/bool을 조용히 정수화하는 엔진 동작을 측정했고, 정의 원본 리터럴 검사로 보완했다. 상태는 Proposed를 유지하며, Accepted 전환과 최종 수치는 별도 판단한다. DEBT-002는 해결되지 않았다. [PR #26](https://github.com/moonhyeonjun/iron-and-harvest/pull/26)로 develop에 통합했다(IH-111 done).
