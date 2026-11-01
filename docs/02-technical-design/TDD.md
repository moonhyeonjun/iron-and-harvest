# 기술 설계 개요

상태: Godot4.7.2 Standard/GDScript/Compatibility 검증 완료(ADR-011). 게임 시스템/알고리즘은 Proposed.

## 목적

생활과 경영이 한 상태를 공유하고 작은 기능 단위로 실행·검증할 수 있게 한다. 장기 시스템 목록이 초기 빈 매니저 수십 개를 만드는 이유가 되어서는 안 된다.

## 현재 구현

게임 실행 진입점은 `game/project.godot`과 스크립트 없는 `game/scenes/foundation.tscn`이다. Node 하나의 빈 씬으로 입력·이동·경제·저장·UI 기능이 없다. Compatibility는 현재 개발 렌더러로 채택했다. game/tests/smoke_engine.gd는 타입 있는 GDScript/씬 로드의 기반 검사이며 게임플레이는 아니다. Import·Headless·GUI 실행과 사용자 육안 확인을 완료했다. 목표 게임 성능은 별도 검증이다.

## 설계 문서

- [아키텍처](ARCHITECTURE.md): 경로·시스템 책임·의존성·이벤트·시간.
- [데이터 모델](DATA_MODEL.md): 정의/상태/참조 계약.
- [저장 시스템](SAVE_SYSTEM.md): 버전·복구·migration.
- [성능](PERFORMANCE.md): 처리 주기·측정·최적화 관문.
- [환경](TOOLCHAIN.md): 실제 발견 도구와 미확인 항목.
- [CI](CI.md): IH-004 완료, 공통 검사·고정 의존성·PR 병합 관문.
- [아이템·인벤토리](INVENTORY.md): IH-110 상세 명세 준비, [수락 조건](../03-development/IH-110-ACCEPTANCE.md)·[인수인계](../03-development/IH-110-HANDOFF.md), ADR-015 Proposed. Claude Code 구현·AC-N01~14 검증([검증 기록](../03-development/IH-110-VALIDATION.md)), [PR #19](https://github.com/moonhyeonjun/iron-and-harvest/pull/19)로 develop 통합, done.
- [상호작용](INTERACTION.md): IH-102 Proposed 명세, [검사](../03-development/IH-102-ACCEPTANCE.md)·[인수인계](../03-development/IH-102-HANDOFF.md). Claude Code 구현·AC-I01~12 검증 완료([검증 기록](../03-development/IH-102-VALIDATION.md)), [PR #9](https://github.com/moonhyeonjun/iron-and-harvest/pull/9)로 develop 통합. 이후 [Codex 추가 검토](../03-development/IH-102-REVIEW.md)에서 BUG-003/004 재현 → [PR #12](https://github.com/moonhyeonjun/iron-and-harvest/pull/12)로 수정·통합, done.
- [IH-101 이동 명세](PLAYER_MOVEMENT.md): Proposed 씬/입력/물리/카메라/확장 계약. Claude Code 구현과 AC-01~12 검증 완료([검증 기록](../03-development/IH-101-VALIDATION.md)), [PR #4](https://github.com/moonhyeonjun/iron-and-harvest/pull/4)로 develop 통합, done.
- [IH-101 수락 검사](../03-development/IH-101-ACCEPTANCE.md)와 [Claude 인수인계](../03-development/IH-101-HANDOFF.md): 검사12항목·작업 순서·전달 프롬프트.

## 우선순위와 완료

엔진 확인·빈 프로젝트 import/실행은 완료했다. IH-101 Player 이동·충돌은 구현·검증했다. IH-102 Interaction은 구현·검증했다. Inventory/Calendar/Production이 필요할 때 최소 서비스를 추가한다. headless import·정상 실행·관련 실패 경로 검증을 통과해야 기능 완료로 기록한다. IH-002는 완료다. Codex는 다음 구현 명세/기술 검증을 담당하고 Claude Code가 다음 IH-110 아이템·인벤토리를 구현한다. Interaction 리뷰 수정은 완료했다.

## TBD

플러그인·전체 테스트 프레임워크·JSON/Resource 선택·저장 형식·타깃 OS와 최소 사양. 엔진 패치 버전은4.7.2로 고정. [ADR](../04-decisions/ADR/README.md)을 통해 승인/검증한다.
