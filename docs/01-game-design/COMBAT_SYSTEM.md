# 탐험·전투 시스템

## 목적·경험

위험을 감수해 재료/유물/새 지역을 발견하고, 영지의 안전을 직접 또는 조직을 통해 개선한다.

## 단계별 범위

이번 Foundation에는 전투가 없다. 초기 MVP 필수 범위에 명시되지 않은 직접 전투는 별도 설계 작업 후 편입 여부를 결정한다. 이전 늑대/도적2종·검/회피·야영지 제안은 확정하지 않는다.

장기에는 도적 토벌→국경 분쟁→공성/반란→왕국 전쟁으로 확장하며 군대는 식량·장비·금화·정치 결과와 연결한다. 전투 방식은 실시간 소규모/자동 해결 등을 비교한다.

## 데이터와 관계

ThreatState(id, location, severity, resolved), Expedition(assignments, supplies, progress), CombatResult(casualties, loot, territory_effects). 직접/위임 결과는 같은 위협 ID를 종료하고 보상을 한 번 지급한다. [영지](ESTATE_MANAGEMENT.md), [경제](ECONOMY_SYSTEM.md), [세계](WORLD_SYSTEM.md)와 연결한다.

## 완료 조건·우선순위

현재 design backlog. 구현 전 취소/패배/귀환/보상/저장 규칙을 확정한다. 채택 시 직접/위임 결과 일치, 비용 보존, 중복 전리품 방지, 실패 후 진행 가능성을 검증한다.

## TBD

전투 조작/난이도/적 수/죽음 페널티/랜덤 판정, 첫 출시 포함 여부, 공성 규모. 제국 전쟁을 초기 의존성으로 만들지 않는다.
