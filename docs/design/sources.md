# 공식 참고 자료

확인일: 2026-10-31. 게임 수치·일정·콘텐츠는 자체 설계 초안이며 아래 자료가 재미나 사업성을 보증하지 않는다. 외부 규정과 엔진 안정판 문서는 바뀔 수 있어 적용 시 다시 확인한다.

| 출처 | 이 설계에서 사용하는 근거 |
|---|---|
| [Godot Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html) | Resource는 데이터 컨테이너이며 로드된 인스턴스 공유에 주의 |
| [Godot Saving games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html) | JSON과 사용자 저장 경로, 커스텀 타입 직렬화 고려 |
| [Godot RandomNumberGenerator](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html) | seed/state와 재현성, RNG 내부 알고리즘 의존 제한 |
| [Steam Direct](https://partner.steamgames.com/steamdirect/) | 등록과 첫 출시 대기 조건 |
| [Steam Release Process](https://partner.steamgames.com/doc/store/releasing) | 상점/빌드 검토와 공개 출시 절차 |
| [Steam Review Process](https://partner.steamgames.com/doc/store/review_process) | 심사 준비 기간, 실제 빌드와 상점 설명 일치 |

이 프로젝트의 명령 처리·일일 단계·저장 트랜잭션·세대 시간 설계는 자체 제안이며 공식 문서의 권장 아키텍처를 그대로 인용한 것이 아니다.
