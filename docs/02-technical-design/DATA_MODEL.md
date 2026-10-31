# 데이터 모델

상태: Proposed. 현재 런타임 데이터 클래스/정의 파일은 없다. `data/design/economy-baseline.json`만 기존 실험 자료로 보존한다.

## 분리 원칙

Definition(불변 콘텐츠) / State(세이브되는 세계) / View(표현) / SaveEnvelope(버전 포함 직렬화)를 나눈다. JSON과 Godot Resource를 비교하되 같은 값을 두 원본에 중복 저장하지 않는다. 공유 Resource를 개별 NPC/건물 상태로 직접 수정하지 않는다.

| 모델 | 최소 필드 초안 | 연결 |
|---|---|---|
| PlayerState | position, map_id, inventory_id, equipment | 지도/아이템 |
| ItemDef / InventoryState | id, stack_limit / owner_id, items, reserved | 자원/거래 |
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
