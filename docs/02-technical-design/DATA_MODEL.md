# 데이터 모델

상태: Proposed. 현재 런타임 데이터 클래스/정의 파일은 없다. `data/design/economy-baseline.json`만 기존 실험 자료로 보존한다.

## 분리 원칙

Definition(불변 콘텐츠) / State(세이브되는 세계) / View(표현) / SaveEnvelope(버전 포함 직렬화)를 나눈다. JSON과 Godot Resource를 비교하되 같은 값을 두 원본에 중복 저장하지 않는다. 공유 Resource를 개별 NPC/건물 상태로 직접 수정하지 않는다.

| 모델 | 최소 필드 초안 | 연결 |
|---|---|---|
| PlayerState | position, map_id, inventory_id, equipment | 지도/아이템 |
| ItemDef / InventoryState | item_id, stack_limit / inventory_id, owner_id, capacity, revision, slots | IH-110 상세 계약; reserved는 후속 |
| BuildingDef / BuildingState | id, cost, recipe / instance_id, state, workers | 건설/생산 |
| RecipeDef | id, inputs, outputs, duration | 경제/시간 |
| CharacterState | id, role, skills, traits, loyalty, household | 주민/임명 |
| RelationshipState | from_id, to_id, value, memories | 인물/사건 |
| EstateState | id, treasury, storage, policies, assignments | 통치 |
| CalendarState | day_index, season, year, time_of_day | 전체 |
| ProjectState | id, target, work, reservation, status, rewarded | 직접/위임 |
| DynastyState | family_id, members, succession | 확장; 초기 미구현 |
| WorldState | map_ids, territories, flags, journal | 전체/저장 |

## 무결성과 인수 조건

안정 ID를 사용하며 표시명·씬 경로를 영속 ID로 쓰지 않는다. 참조 없음·중복 ID·음수 비용·잘못된 생산 순환을 로드 시 거부한다. 보유≥예약≥0, 인물당 동시 노동≤1, 완료 보상≤1회. 정수/소수·반올림 규칙은 경제 설계와 일치시킨다.

## TBD

정확한 스키마, JSON/Resource, 수정 버전, ID 이관 정책, RNG 직렬화, 가구/인물 지갑 범위. 구현 전 작은 예시와 실패 사례를 먼저 작성한다. 저장 호환은 [SAVE_SYSTEM](SAVE_SYSTEM.md)이 소유한다.

## IH-110 구체화

[상세 계약](INVENTORY.md)은 .tres 정의 카탈로그와 별도 슬롯 상태, 검증된 스칼라 복사, 안정 ID·expected revision·원자 거래·독립 snapshot을 제안한다. 실제 구현은 아직 없고 [ADR-015](../04-decisions/ADR/ADR-015-inventory-contract.md)는 Proposed다. JSON/Resource 비교는 작은 샘플로 검증하며 다른 도메인의 포맷을 일괄 확정하지 않는다. 동일 콘텐츠의 JSON과 Resource를 이중 운영 원본으로 두지 않는다. 금화/식량 지표와 실제 품목 집계의 중복 소유를 피하고 예약·고유 장비 인스턴스는 별도 확장한다.
