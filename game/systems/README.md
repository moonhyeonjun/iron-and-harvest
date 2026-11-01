# 도메인 규칙과 상태

향후 Inventory/Calendar/Production 등 순수 규칙과 상태를 둔다. UI/씬 탐색과 파일 저장에 직접 의존하지 않도록 설계한다. 파일 접근은 save/의 SaveFileAdapter 한 곳에만 둔다. 현재 inventory/(IH-110 ItemDef·ItemCatalog·InventoryState·InventoryService), gathering/(IH-111 GatherDef·GatherCatalog·GatherService), save/(IH-112 SaveCodec·SaveStore·SaveFileAdapter, IH-120 schema2), calendar/(IH-120 CalendarRules·CalendarService)가 있다. 미래 국가 시스템의 빈 클래스를 선행 생성하지 않는다.
