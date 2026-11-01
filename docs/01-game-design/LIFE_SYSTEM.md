# 생활 시스템

## 목적·경험

플레이어가 직접 마을을 걷고 일하고 탐험하며 영지와 주민에게 애착을 가진다. 국가가 커져도 생활을 선택할 수 있다.

## 주요 기능

MVP: 캐릭터 이동·충돌, 대상 상호작용, 채집/벌목, 개인 인벤토리, 심기/성장/수확, NPC 대화, 수리/납품. 낚시·사냥·던전·제작·장비 다양화는 후속 검증으로 둔다.

## 데이터와 연결

PlayerState(position, map_id, equipment), InteractionTarget(id, actions, range), GatherNode(id, remaining, reset_at), CropState(plot_id, crop_id, stage, planted_day). 획득은 [아이템](ITEM_SYSTEM.md), 성장은 [세계 시간](WORLD_SYSTEM.md), 대화는 [인물](CHARACTER_SYSTEM.md)에 연결한다. 도구를 눌렀다는 이유만으로 별도 숨은 자원을 생성하지 않는다.

## 우선순위·완료 조건

v0.2 이동/상호작용 → v0.3 수집/가방 → v0.4 농사. 벽 관통 없음, 범위 밖 작업 거부, 가방 포화 시 재료 유실 없음, 저장 후 채집/농사 상태 복원, 계절 경계 성장 검증이 필요하다.

## 첫 구현 준비

IH-101의 이동·충돌·카메라와 임시 조작 기준은 [구현 명세](../02-technical-design/PLAYER_MOVEMENT.md)에 있다. Claude Code가 구현·수락 검증을 완료하고 develop에 통합했다. 결과는 [IH-101 검증 기록](../03-development/IH-101-VALIDATION.md)을 따른다. 임시 속도/키/화면 값은 최종 제품 결정을 대신하지 않는다.

## 상호작용 구현 준비

IH-004 CI 완료 후 [IH-102 명세](../02-technical-design/INTERACTION.md)를 작성했다. 가까운 정면 대상의 행동 안내→E로 살펴보기→설명 읽기→닫기를 최소 경험으로 검증한다. 벽 너머/범위 밖 행동, 삭제된 대상 실행, 중복 요청은 거부한다. 아이템/채집 보상은 이 단계에 포함하지 않는다. Claude Code가 구현·GUI 수락 검사를 완료하고 develop에 통합했다. 이후 [Codex 검토](../03-development/IH-102-REVIEW.md)에서 BUG-003/004를 재현해 review로 재개했고 [PR #12](https://github.com/moonhyeonjun/iron-and-harvest/pull/12)로 수정·통합해 done이다. 수정·회귀 검사가 다음 작업이다.

## TBD

이동 속도·조작 키·픽셀 크기·기력·개인 농장 크기·성장일수·재생량·쓰러짐 페널티. 이전 3×3/3일/기력100은 확정 수치가 아니다.
