# IH-111 정의 fixture

런타임 원본이 아니다. `test_gathering.gd`의 AC-G01이 로드 시 엔진이 조용히 정수화하는 값(2.5, true, "3")과 누락된 initial_quantity를 GatherCatalog가 원본 텍스트 검사로 거부하는지 확인한다.

`embedded_*.tres`는 GatherDef를 카탈로그 안에 내장한 형식이다(BUG-008). 원본 타입을 검증할 수 없으므로 정상 정수(`embedded_valid`)를 포함해 모두 거부되어야 한다.
