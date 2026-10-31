# 생활 시스템

## 목적·경험

플레이어가 직접 마을을 걷고 일하고 탐험하며 영지와 주민에게 애착을 가진다. 국가가 커져도 생활을 선택할 수 있다.

## 주요 기능

MVP: 캐릭터 이동·충돌, 대상 상호작용, 채집/벌목, 개인 인벤토리, 심기/성장/수확, NPC 대화, 수리/납품. 낚시·사냥·던전·제작·장비 다양화는 후속 검증으로 둔다.

## 데이터와 연결

PlayerState(position, map_id, equipment), InteractionTarget(id, actions, range), GatherNode(id, remaining, reset_at), CropState(plot_id, crop_id, stage, planted_day). 획득은 [아이템](ITEM_SYSTEM.md), 성장은 [세계 시간](WORLD_SYSTEM.md), 대화는 [인물](CHARACTER_SYSTEM.md)에 연결한다. 도구를 눌렀다는 이유만으로 별도 숨은 자원을 생성하지 않는다.

## 우선순위·완료 조건

v0.2 이동/상호작용 → v0.3 수집/가방 → v0.4 농사. 벽 관통 없음, 범위 밖 작업 거부, 가방 포화 시 재료 유실 없음, 저장 후 채집/농사 상태 복원, 계절 경계 성장 검증이 필요하다.

## TBD

이동 속도·조작 키·픽셀 크기·기력·개인 농장 크기·성장일수·재생량·쓰러짐 페널티. 이전 3×3/3일/기력100은 확정 수치가 아니다.
