# 기술 설계 개요

상태: 기반 경로는 현재 구성, 게임 시스템/알고리즘은 Proposed, 정확한 Godot 버전은 TBD.

## 목적

생활과 경영이 한 상태를 공유하고 작은 기능 단위로 실행·검증할 수 있게 한다. 장기 시스템 목록이 초기 빈 매니저 수십 개를 만드는 이유가 되어서는 안 된다.

## 현재 구현

`game/project.godot`과 스크립트 없는 `game/scenes/foundation.tscn`만 있다. Node 하나의 빈 씬으로 입력·이동·경제·저장·UI 기능이 없다. Compatibility 렌더러는 기반 실험 설정이며 목표 성능/최종 렌더러를 확정한 것은 아니다. 엔진 실행은 미검증이다.

## 설계 문서

- [아키텍처](ARCHITECTURE.md): 경로·시스템 책임·의존성·이벤트·시간.
- [데이터 모델](DATA_MODEL.md): 정의/상태/참조 계약.
- [저장 시스템](SAVE_SYSTEM.md): 버전·복구·migration.
- [성능](PERFORMANCE.md): 처리 주기·측정·최적화 관문.
- [환경](TOOLCHAIN.md): 실제 발견 도구와 미확인 항목.

## 우선순위와 완료

먼저 엔진 확인·빈 프로젝트 import/실행, 다음 Player/Interaction. Inventory/Calendar/Production이 필요할 때 최소 서비스를 추가한다. headless import·정상 실행·관련 실패 경로 검증을 통과해야 기능 완료로 기록한다. 현재 Foundation의 엔진 호환성은 blocked다.

## TBD

엔진 패치 버전·플러그인·테스트 프레임워크·CI 이미지·JSON/Resource 선택·저장 형식·타깃 OS와 최소 사양. [ADR](../04-decisions/ADR/README.md)을 통해 승인/검증한다.
