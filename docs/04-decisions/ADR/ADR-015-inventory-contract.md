# ADR-015: 아이템 정의와 원자적 슬롯 인벤토리

- 상태: **Proposed** — 구현·검증 완료(2026-11-01), Accepted 판정은 별도.
- 날짜: 2026-11-01.
- 관련: [ADR-003](ADR-003-data-management.md)의 아이템 포맷 후보를 구체화한다. 아직 supersedes하지 않으며 다른 정의/저장 형식을 확정하지 않는다. [ADR-014](ADR-014-interaction-boundary.md)의 보상 분리와 단일 게이트 제약을 유지한다.

## 배경

v0.2.0은 이동·살펴보기까지 구현했다. 다음 채집에서 가방 포화나 중복 입력이 물자 손실/증식을 만들지 않도록 도메인 경계가 필요하다. 전체 생산·예약 시스템을 먼저 만드는 것은 범위를 넘는다.

## 대안과 제안

| 영역 | 비교 | IH-110 검증 제안 |
|---|---|---|
| 정의 | JSON은 외부 편집/가공이 쉬우나 스키마·숫자/에셋 참조 검증 필요. Resource는 에디터 타입·리소스 참조 활용 가능하나 엔진 의존·공유 캐시 주의 | custom Resource/.tres, 명시 catalog, 검증 후 스칼라 복사; 작은 JSON 비교 실험 후 결정 |
| 재고 | counts map은 간단하지만 슬롯/스택 UI를 나중에 재해석해야 함. 고정 슬롯은 공간 제약을 바로 검증 가능 | 고정 슬롯 + 정수 stack, UI에 내부 상태 미공개 |
| 거래 | 부분 성공은 획득/보관함에서 잔량 처리 복잡. 선차감/후추가는 실패 시 유실 위험 | 복사본 계획 → 전체 commit → 단일 변경 이벤트 |
| 중복 | 전역 영속 명령 장부는 현재 범위 초과. UI의 enable만으로 stale 명령 방지 불가 | expected revision + 모달 session ID, 재진입 BUSY |
| 모달 | 비모달 가방은 이동·UI 동시 입력 정책 필요. 범용 잠금 시스템은 작업 확대 | 가방/살펴보기 상호 배제하는 작은 조율자, 알려진 두 작성자로 제한 |

## 이유·단점·영향

수량 보존과 실패 불변식을 엔진 씬 밖에서도 검사하고, 채집/저장에 명확한 실패 결과를 전달한다. 슬롯 모델은 향후 대규모 창고에 그대로 적합하다고 가정하지 않는다. Resource를 불변으로 강제하는 언어 기능에 기대지 않고 서비스 경계를 통해 외부 수정을 격리한다. revision은 영속 보상 중복 방지 기능을 대체하지 않는다.

별도 InventoryController가 기존 InteractionController와 배타적으로 동작한다. 전투 등 제3 잠금 작성자는 미지원이며 DEBT-002는 유지한다. .tres와 JSON을 동시에 운영 원본으로 보관하지 않는다. 파일 저장·예약·다중재료 소비는 후속 작업이다.

## 수락 관문

[명세](../../02-technical-design/INVENTORY.md)와 [AC-N01~14](../../03-development/IH-110-ACCEPTANCE.md)를 구현·검증하고, 두 형식 작은 예제의 결과/선택 이유를 IH-110-VALIDATION에 기록한다. 타입·공유 Resource 변조 격리·원자 이동·stale/reentrant·모달/GUI 회귀를 확인한 후 기술 결정 Accepted 여부를 판정한다. 최종 밸런스 TBD는 그 판정과 분리한다. 제안과 다른 선택은 근거·API/테스트 영향과 함께 기록한다.

## 구현 검증 결과 (2026-11-01)

Claude Code가 이 제안대로 구현했다. 작은 형식 비교에서 JSON은 stack_limit을 float로 읽고 숫자·키·문법 검사를 별도로 구현해야 했다. 반면 .tres는 타입을 유지했고, 공유 캐시 위험은 스칼라 복사로 막혔다(AC-N02). 그래서 **런타임 원본은 .tres + 명시 catalog.tres** 하나로 정했다. 원자성·stale·재진입·snapshot 격리·모달 배타성은 AC-N01~14와 변이 10종 검출로 확인했다([검증 기록](../../03-development/IH-110-VALIDATION.md)). 상태는 Proposed를 유지하며, Accepted 전환과 최종 수치(TBD)는 별도 판단한다. DEBT-002는 해결되지 않았다. [PR #19](https://github.com/moonhyeonjun/iron-and-harvest/pull/19)로 develop에 통합했다(IH-110 done).

후속 검토(2026-11-01): [Codex 리뷰](../../03-development/IH-110-REVIEW.md)에서 BUG-005/006을 추가 재현해 IH-110은 review로 재개했고, [PR #22](https://github.com/moonhyeonjun/iron-and-harvest/pull/22)로 수정·통합해 done이다(상태는 Proposed 유지). 기존 검증 기록은 보존하며 Accepted 판정은 수정·회귀 확인 뒤로 보류한다.
