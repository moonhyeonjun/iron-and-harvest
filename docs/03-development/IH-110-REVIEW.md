# IH-110 Codex 기술 검토 — 2026-11-01

## 판정

대상 develop/origin `14302e5`. 기존 자동 검사·GUI 기록은 유지하지만 추가 경계에서 **BUG-005/006(P2) 재현 → IH-110 done에서 review로 재개**한다. 수정 후 회귀를 편입하고 재검증해야 done으로 복귀한다. ADR-015 Proposed, IH-111 구현 착수/새 마일스톤 판정은 보류한다. Codex는 게임 코드·씬·테스트·CI 설정을 수정하지 않았다.

## 기존 증거와 독립 확인

- Claude 구현 PR #19 merge f26a77e, 기록 PR #20 merge14302e5. 동일 SHA develop CI run41277180799 success를 확인했다.
- 별도 clean detached worktree에서 공통 CI 실행 종료0, 11단계 PASS. Python19·경제설계7·이동360·상호작용333·인벤토리375검사. 인벤토리 반복2회 측정45종 차이0, 고아0, 엔진 오류0.
- 검토 실행은 `python3 /tmp/ih110-codex-review-14302e5/tools/run_ci.py --help`였다. 이 실행기는 인자를 해석하지 않으므로 도움말 대신 정상 공통 CI 전체를 실행했다. 이를 확인했으며 불필요한 재실행은 하지 않았다.
- GUI는 새로 조작하지 않았다. [Claude 검증 기록](IH-110-VALIDATION.md)의 사용자 빌드025c863 확인과 구분한다. 해당 빌드 이후 실행 코드 변경은 없고 game/ 하위 README만 변경됐다.
- 새 진단은 메모리/씬 API를 통해 아래 경계만 재현한다. 정상 GUI에서 수량 소실을 관찰했다는 뜻이 아니다. 혼합 타입의 스택 키는 INVALID_SNAPSHOT으로 정상 거부됐다.
- 진단 원본/로그는 `build/ih-110-codex-review/`(Git 무시), CI 로그 복사본은 그 안의 ci/다. 사용자 미추적 AGENTS.md는 보존한다. 그 파일의 없는 .Codex/rules 링크4개와 커밋된 worktree 검사 결과를 구분한다.

## BUG-005 — 가방 열기 콜백 뒤 UI·서비스 수명 재검증 누락 (P2)

위치: `game/scripts/inventory/inventory_controller.gd`의 request_open(97~108행), _still_openable(191~200행), _show(221~225행), 열린 상태 검사(146~148행).

재현: inventory_test에서 대상 프롬프트가 선택된 상태에 Interaction.target_changed 콜백을 연결한다. 가방 열기가 Interaction을 disable하여 이 콜백을 호출할 때 (a) InventoryUI.queue_free() 또는 (b) InventoryService.close()를 실행한다. 그 후 가방 열기 결과와 다음 프레임 상태를 확인한다.

관찰:

```text
queue_ui: callback=true ui_valid=false service_closed=false result="" state=2 owns_gate=true player_effective=false
close_service: callback=true ui_valid=true service_closed=true result="" state=2 owns_gate=true player_effective=false
```

빈 결과 문자열은 성공, state2는 OPEN이다. UI가 사라진 뒤에도 잠금이 남거나, 닫힌 서비스로 빈 패널을 열고 이동을 막는다. 최초 진단에서 queue_free 대신 free를 호출하자 `_show:224`에 native signal11 충돌이 발생했다. 안전한 삭제 예약 재현만으로도 오류 상태가 확인되므로 수정 전 즉시 free 진단을 반복할 필요는 없다.

원인: 최초 _open_blocker의 서비스·UI 확인은 콜백 전에만 수행한다. _still_openable은 Player/Interaction 일부 조건만 확인하고, _show는 UI를 무조건 호출한다. OPEN 유지 검사도 Player만 검사한다. 콜백 전후의 UI 생존/트리/삭제 예약 및 서비스 closed 상태를 보장해야 한다. _reject/show_notice/뷰 전환/늦은 transfer도 제거된 UI를 호출하지 않아야 한다.

수정 수락 조건:

- AC-N12에 OPENING 중 UI queue_free/remove_child 및 service.close를 추가한다. 시작 거부1회, opened0회, CLOSED·자기 게이트 미소유, 자신이 disable한 Interaction 복구, Player 중립 복구, 재고 불변.
- 이미 OPEN인 UI/서비스 소멸에서도 안전하게 종료하고 중복 해제·이미 제거된 노드 호출·엔진 오류를 만들지 않는다. 비정상 상태에서 보기 전환/늦은 UI 명령은 재고를 변경하지 않는다.
- _ready 이전/조율자/Player/전체 맵 종료·focus out·E큐·살펴보기와의 기존 회귀를 보존한다. 일반 다중 잠금/제3 작성자 지원(DEBT-002)은 범위 밖이다.
- 새 검사를 먼저 실패시키고 수정 후 통과시킨다. 즉시 free 경로는 필요하면 별도 프로세스 timeout으로 검증하여 runner 전체 충돌을 격리한다.

## BUG-006 — ID 정규식이 끝 개행을 허용 (P2)

위치: `game/systems/inventory/item_catalog.gd:26~27`, is_valid_id의 `^[a-z][a-z0-9_]*$` 검색. 요구 계약은 문자열 전체가 ASCII 소문자 ID인 것이다.

실측: `is_valid_id("wood\n") == true`, `register_inventory("bag\n", "owner", 1).code == OK`, `item_id="wood\n"`인 단일 ItemDef 카탈로그도 compile.ok=true다. 따라서 정의와 상태 입력 경계에서 보이지 않는 끝 개행을 가진 별도 ID가 들어온다. 정상 `wood` 참조와 일치하지 않으며 콘텐츠 ID 오타를 조기에 거부한다는 계약에 어긋난다. 근거는 고정 엔진에서의 재현이며 정규식 동작에 대한 추측만으로 판정하지 않았다.

수정 수락 조건:

- 문자열 전체가 규칙을 만족하는지 검사한다. trim/lowercase로 자동 정규화하여 기존 ID와 합치지 않는다.
- AC-N01/02/09에 끝 LF/CRLF·중간 개행·공백·탭·비ASCII·길이 경계(1/64/65)를 추가한다. 카탈로그 item_id, inventory_id/owner_id 등록 및 snapshot 내 ID에 동일 거부 정책 적용.
- 정상 ID 보존, 잘못된 등록/복원은 기존 재고·revision·이벤트 불변. 정의 실패는 catalog 전체 거부. 수정 전 실패/수정 후 통과를 기록한다.

## 간단 재현 스크립트

아래를 임시 .gd로 저장하고 고정 실행기로 `python3 tools/godot.py --headless --script /absolute/path/probe.gd`를 실행한다. game/나 테스트 runner를 덮어쓰지 않는다. 현재 종료1/위반3(수명2 + ID1)이다. 추가 등록/catalog 출력은 같은 ID 결함의 영향 경로다. 진단 종료에 ObjectDB 클래스2개 경고도 기록됐다. 기존 suite는 고아/오류0이며 이 경고를 별도 제품 누수 결함으로 판정하지 않았다.

```gdscript
extends SceneTree
var violations: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var service := InventoryService.new(load("res://data/items/catalog.tres"))
	var bad := {"inventory_id":"bag", "owner_id":"player", "capacity":1,"revision":0,"slots":[{"item_id":"wood", "quantity":1, 99:"bad"}]}
	var bad_result := service.decode_snapshot(bad)
	print("MIXED_KEYS result=", bad_result.code)
	print("ID_NEWLINE accepted=", ItemCatalog.is_valid_id("wood\n"))
	if ItemCatalog.is_valid_id("wood\n"): violations += 1
	var id_result := service.register_inventory("bag\n", "owner", 1)
	print("REGISTER_NEWLINE code=", id_result.code)
	var d := ItemDef.new()
	d.item_id = &"wood\n"
	d.name_key = &"WOOD"
	d.fallback_name = "Wood"
	d.category = &"material"
	d.stack_limit = 10
	var catalog := ItemCatalog.new()
	catalog.definitions.append(d)
	print("CATALOG_NEWLINE accepted=", catalog.compile().ok)
	for variant: String in ["queue_ui", "close_service"]:
		var map := (load("res://scenes/tests/inventory_test.tscn") as PackedScene).instantiate()
		root.add_child(map)
		await process_frame
		for i: int in 5: await physics_frame
		var c: InventoryController = map.controller
		var p: PlayerController = map.player
		var interaction: InteractionController = map.interaction
		var fired: Array = [false]
		interaction.target_changed.connect(func(_id: StringName, _a: String, _d: String) -> void:
			if fired[0]: return
			fired[0] = true
			if variant == "queue_ui": map.ui.queue_free()
			else: map.service.close()
		, CONNECT_ONE_SHOT)
		var result: StringName = c.request_open(InventoryController.View.BAG)
		await process_frame
		await process_frame
		print("OPEN_CASE ",variant," callback=",fired[0]," ui_valid=",is_instance_valid(map.ui)," service_closed=",map.service.is_closed()," result=", result," state=", c.get_state()," owns_gate=",c.owns_movement_gate()," player_effective=",p.is_control_effective())
		if fired[0] and (c.get_state() == InventoryController.State.OPEN or c.owns_movement_gate()): violations += 1
		map.queue_free()
		await process_frame
		await process_frame
	d = null
	catalog = null
	service = null
	await process_frame
	print("VIOLATIONS=", violations)
	call_deferred("quit", 1 if violations else 0)
```

## Claude Code 전달용 수정 프롬프트

```text
IH-110 Codex 리뷰의 BUG-005/006을 수정하라.
CLAUDE.md/.claude/rules, IH-110-REVIEW.md, INVENTORY.md,
IH-110-ACCEPTANCE.md와 기존 코드/검증 기록을 먼저 읽는다.
현재 Git/브랜치/사용자 변경을 확인하고 최신 develop에서
fix/inventory-lifecycle-and-id-validation 브랜치를 구성한다.
위 재현과 기존 test_inventory에 실패 회귀를 먼저 추가한다.
가방 OPENING 콜백 이후와 OPEN 중 UI/서비스 수명 조건을 검사하고
UI 삭제/이탈·서비스 close에 안전하게 거부/종료·게이트 복구하도록 수정한다.
제거된 UI에 표시/notice/전환을 호출하거나 늦은 명령으로 재고를 바꾸지 않는다.
ID 검사는 끝 개행까지 포함한 문자열 전체의 ASCII 규칙을 강제한다.
trim 등 자동 보정으로 다른 ID를 합치지 않는다.
변경 범위는 두 결함과 관련 회귀·문서에 한정한다.
채집/저장/장비/범용 잠금을 새로 구현하지 않는다.
기존 AC-N01~14, 이동/상호작용 회귀와 CI 11단계를 보존한다.
수정 전후 결과, 새 회귀/변이 검출, 실제 GUI의 가방/살펴보기/보관함/포커스
확인 주체와 빌드를 기록한다. 자동 검사를 GUI 확인으로 대체하지 않는다.
TASKS/WEEKLY_LOG/BUGS/IH-110-VALIDATION/REVIEW를 실제 증거로 갱신한다.
Conventional Commits, push, 필수 PR CI checks 성공 후 develop에 통합하고
원격 결과를 확인한다. 사용자 AGENTS.md를 수정/커밋하지 않는다.
main/태그/릴리스는 변경하지 않는다. 미검증이면 done으로 기록하지 않는다.
완료 보고에 수정 파일·AC 결과·미검증·커밋/PR/CI 링크를 포함한다.
```

## Claude Code 수정 결과 (2026-11-01)

`5004419`에서 위 재현을 기존 runner의 AC-N01/02/09/12 회귀로 편입했다. 수정 전에는 `free_ui` 충돌(signal 11)과 25검사 실패를 확인했다. `fb5cd0c`에서 수정한 뒤 재현 진단 종료 0, runner 521검사 PASS, 표적 변이 5종 검출, 깨끗한 worktree CI 11단계 PASS를 확인했다. 사용자 GUI 응답은 "1~4 모두 정상"(`8dfe8bb`)이다. 범위는 두 결함과 회귀·문서로 한정했고, 채집·저장·장비·범용 잠금은 추가하지 않았다. 세부 사항은 [검증 기록](IH-110-VALIDATION.md)에 있다. 완료 판정은 PR 필수 CI와 develop 통합 뒤에 한다.
