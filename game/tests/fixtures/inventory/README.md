# IH-110 정의 형식 비교 fixture

런타임 원본이 아니다. `test_inventory.gd`의 AC-N01이 `res://data/items/wood.tres`와 동등한 JSON을 비교하고, JSON이 숫자/필드/문법 오류를 별도 검사해야 함을 확인한다. 런타임은 `res://data/items/catalog.tres`만 읽는다.
