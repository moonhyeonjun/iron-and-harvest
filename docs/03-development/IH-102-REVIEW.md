# IH-102 Codex 기술 검토 — 2026-11-01

## 현재 판정 — 수정 재검증 완료 (Codex, 2026-11-01)

`69561cad9c44bf910797d01a0a600a265457fd14`에서 원래 재현 진단을 다시 실행해 위반0/종료0을 확인했다. 코드와 추가 회귀를 검토하고 전체 CI 10단계(Python19, 이동360, 상호작용333)를 재실행해 통과했다. **BUG-003/004 resolved, IH-102 done을 확인한다.** 검토 범위에서 추가 수정이 필요한 결함은 발견하지 못했다. [독립 재검증 기록](IH-102-VALIDATION.md)을 따른다.

아래 리뷰·수정 프롬프트는 최초 발견 시점의 이력이다. 동일 수정 작업을 다시 실행할 필요는 없다. v0.2.0 마일스톤·ADR Accepted 전환은 별도 판단이다.

## 최초 판정과 범위

대상은 develop `29b2ed3d0c78cf4f5db7d4792ab8547a45ae4e60`이다. PR #9 구현과 PR #10 기록이 원격에 병합됐음을 확인했다. 기존 자동 검사 성공과 별개로 추가 경계 검사에서 **BUG-003/004 두 건을 재현**했다. IH-102는 done에서 **review로 재개**하며, 수정·회귀·PR 검증 후 다시 완료 판정한다. v0.2.0 승격은 보류한다.

기능 구현은 Claude Code 담당이다. 이번 변경은 리뷰·수락 조건 보완·문서 정리이며 게임 코드/씬/엔진/CI 설정은 변경하지 않았다. 원래 [인수인계](IH-102-HANDOFF.md)와 [구현 검증 이력](IH-102-VALIDATION.md)은 보존한다.

## 확인한 증거

- 로컬 HEAD와 origin/develop 모두 `29b2ed3`. 추적 파일 변경 없음, 미추적 사용자 `AGENTS.md` 보존·미커밋.
- [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41267694674): 동일 SHA의 CI checks success. GitHub API로 job/step 완료 확인.
- 로컬 전체 검사: 별도 clean detached worktree(`/tmp/ih102-codex-review-20261101`)에서 `python3 tools/run_ci.py` **10단계 PASS/종료0**. Python19개, IH-101 360검사, IH-102 299검사 모두 통과. Import/smoke/runtime 오류0. player 123.973초, interaction 24.845초. 두 번 반복 측정24종 차이0·고아0·엔진 오류0. 로그는 `build/ih-102-codex-review/ci/`(Git 무시).
- 아래 추가 진단: Godot `4.7.2.stable.official.ed1daf0bf` Standard / macOS에서 **종료1, 위반2건**, 엔진 오류 없음. 입력은 실제 Input.parse_input_event + flush, 물리 틱/씬/UI 사용. Controller private 함수 호출 없음.
- GUI는 새로 실행·조작하지 않았다. 기존 사용자의 `3d99d36` 빌드 확인(“1~5 모두 정상”)은 기존 검증 문서의 증거이며 이번 SHA에 대한 새 GUI 확인이 아니다.
- 원격 main=`64928e5`, v0.1.0 대상=`d176bd7` 보존. 새 태그/릴리스 없음.

## P2 / BUG-003 — 요청 처리 시 중복 ID 재검증 누락

위치: `game/scripts/interaction/interaction_controller.gd`의 `_resolve_queued` → `_check_target` / `_is_usable` (검토 SHA에서 173, 275~280행).

후보 중 중복 ID 필터는 `_update_selection`에만 있다. 이미 표시된 대상을 E로 캡처한 뒤 다른 후보가 사용 가능해지면 요청 검증은 중복 여부를 보지 않고 `try_begin`을 호출한다. ACTIVE 검증도 같은 경로여서 패널이 유지된다.

재현: 초기 안내판이 선택된 상태에서 같은 `sign_entrance` ID의 **런타임 후보**를 available=false로 추가하고 Area 반영을 기다린다. E를 입력한 다음 다음 물리 처리 전에 그 후보를 available=true로 바꾼다. 두 후보는 검출 범위 내에 이미 있다. 초기 맵 감사는 런타임에 추가한 대상을 검사하지 않으므로, 명세의 후보 중복 검증이 필요한 경로다.

기대: ID가 중복된 요청은 거부되고 대체 대상으로 전환하지 않는다. 실제: ACTIVE=true, 패널=true, 이동 게이트=false. 현재 고정된 두 대상만 사용하는 일반 조작에서는 발생하지 않지만, 명세가 보장한 런타임 후보 중복 거부 경계가 뚫린다.

수정 수락 조건:

- 선택과 요청 실행에서 동일한 ID 유효성 정책을 사용한다. 실행 직전 후보 중복을 다시 확인하며 전맵 매 프레임 검색은 도입하지 않는다.
- 위 입력→availability 변경 순서에서 begin/opened=0, rejected=1(INVALID_TARGET 등 명시한 reason), 다른 대상 실행0, 이동 게이트 유지.
- 활성 세션 중 같은 상황이 생겼을 때도 ID 무효화 처리 정책을 명세/테스트로 고정한다. 검증 기준안은 다음 틱에 INVALID_TARGET 취소·end1·게이트 복구다.
- 기존 동률·빈 ID·초기 맵 감사·가시선·거리 검사는 유지한다.

## P2 / BUG-004 — RESOLVING 중 비활성화가 세션 시작을 막지 못함

위치: 같은 파일의 `_resolve_queued`, `try_begin` 반환 이후 183~196행 및 `set_interaction_enabled`.

Target.try_begin에서 공개 API `set_interaction_enabled(false)`를 호출하고 true를 반환하면 `_enabled`는 false가 되지만 상태는 RESOLVING이다. disable 경로는 ACTIVE만 종료하며, 반환 후 검증은 대상의 유효성만 본다. 그래서 비활성 Controller가 ACTIVE로 바뀌고 패널을 연다. 다음 틱의 `_revalidate_active`도 enabled를 확인하지 않아 유지된다.

기대: 비활성화는 해결 중인 요청에도 적용되고 패널을 열지 않는다. 실제: ACTIVE=true, 패널=true, 이동 게이트=false. 단순 안내판/상자는 지금 이 콜백을 호출하지 않지만, 공개 시작/취소 계약과 재진입 안전성이 충족되지 않는다.

수정 수락 조건:

- `try_begin` 반환 후 Controller가 여전히 시작 가능한지 재검증한다. 비활성화로 무효가 된 요청은 DISABLED로 정확히 한 번 보고한다.
- true를 반환한 유효 Target에는 `end_interaction(id, true)`를 한 번만 통지하고 IDLE로 정리한다. opened=0, 패널=false, 이동 게이트를 새로 소유하지 않는다.
- 같은 RESOLVING 경계의 포커스 상실·트리 이탈도 취소를 무시하지 않는지 회귀 검사한다. 이 두 변형은 이번에 직접 재현하지 않았으므로 확인된 별도 결함으로 집계하지 않는다.
- 미래용 전역 lock/이벤트 버스/비동기 프레임워크를 추가하지 않는다.

## 재현 명령

아래 gdscript 블록은 독립 진단이다. 임시 파일로 추출한 뒤 고정 실행기로 실행한다. 코드/씬을 수정하지 않으며 기존 CI에 자동 등록하지 않는다. 수정 담당자가 이 사례를 기존 `test_interaction.gd`의 AC-I04/I06/I08/I10에 회귀 검사로 편입해야 한다.

```sh
python3 - <<'PY_REPRO'
from pathlib import Path
text = Path('docs/03-development/IH-102-REVIEW.md').read_text()
source = text.split('```gdscript\n', 1)[1].split('```', 1)[0]
Path('/tmp/ih102-review-probe.gd').write_text(source)
PY_REPRO
python3 tools/godot.py --headless --script /tmp/ih102-review-probe.gd
```

종료0=두 패널 모두 열리지 않음, 종료1=경계 위반, 종료2=초기 조건 실패. 이 짧은 진단은 통지 횟수/포커스/정리 등 전체 수정 수락 검사를 대체하지 않는다. 현재 출력:

```text
PRE duplicate_becomes_available selected=sign_entrance candidates=3
OBSERVED duplicate_becomes_available active=true panel=true control_effective=false
PRE disabled_during_begin selected=disable_probe candidates=3
OBSERVED disabled_during_begin active=true panel=true control_effective=false
EXPECTED both requests rejected; violations=2
```

```gdscript
extends SceneTree

class DisableOnBegin extends InteractionTarget:
	var controller: InteractionController
	func try_begin(request_id: int) -> bool:
		controller.set_interaction_enabled(false)
		return super(request_id)

func _initialize() -> void:
	_run.call_deferred()

func ticks(count: int) -> void:
	for i: int in count:
		await physics_frame

func press_e() -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = KEY_E
		event.keycode = KEY_E
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()

func _run() -> void:
	var failures: int = 0
	for kind: String in ["duplicate_becomes_available", "disabled_during_begin"]:
		var world: Node2D = load("res://scenes/tests/interaction_test.tscn").instantiate()
		root.add_child(world)
		var player: PlayerController = world.get_node("World/Player")
		var controller: InteractionController = player.get_node("InteractionController")
		player.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		controller.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		var target: InteractionTarget = load("res://scenes/interaction/interaction_target.tscn").instantiate()
		if kind == "disabled_during_begin":
			target.set_script(DisableOnBegin)
			target.controller = controller
			target.target_id = &"disable_probe"
			target.position = Vector2(128, 380)
		else:
			target.target_id = &"sign_entrance"
			target.available = false
			target.position = Vector2(130, 385)
		world.get_node("Targets").add_child(target)
		await ticks(4)
		var expected: StringName = &"sign_entrance" if kind == "duplicate_becomes_available" else &"disable_probe"
		if controller.get_selected_target_id() != expected or controller.get_candidate_count() != 3:
			printerr("SETUP FAILED: ", kind)
			quit(2)
			return
		print("PRE ", kind, " selected=", controller.get_selected_target_id(), " candidates=", controller.get_candidate_count())
		press_e()
		if kind == "duplicate_becomes_available":
			target.available = true
		await ticks(2)
		var opened: bool = controller.get_state() == InteractionController.State.ACTIVE
		print("OBSERVED ", kind, " active=", opened, " panel=", world.get_node("InteractionUI/InspectPanel").visible, " control_effective=", player.is_control_effective())
		if opened:
			failures += 1
		world.queue_free()
		await process_frame
		await ticks(2)
	print("EXPECTED both requests rejected; violations=", failures)
	quit(1 if failures > 0 else 0)
```

## Claude Code 전달용 수정 프롬프트

```text
IH-102 Codex 리뷰의 BUG-003/BUG-004를 수정하라.
CLAUDE.md와 규칙, TASKS, INTERACTION, IH-102-REVIEW, IH-102-ACCEPTANCE를 먼저 읽는다.
현재 Git/사용자 변경을 보호하고 최신 develop에서 fix/interaction-request-validation으로 분기한다.
두 재현을 먼저 실행하고 기존 test_interaction.gd에 실패하는 회귀 사례를 추가한다.
1. 캡처 대상의 실행 직전 후보 ID 중복을 재검증하고, 세션 중 ID 무효화 정책도 검사한다.
2. try_begin 반환 후 disable/focus/tree 수명으로 무효가 된 요청이 ACTIVE가 되지 않게 정리한다.
반환 true인 대상의 end 통지는 정확히 한 번, rejected도 한 번이며 stale ID/다른 대상 자동 실행을 막는다.
Controller/Target/UI 책임과 기존 IH-101 게이트/neutral 규칙을 유지한다.
범용 잠금 관리·새 게임플레이·아이템/인벤토리/채집을 추가하지 않는다.
기존 수락 검사/새 회귀/실패 주입/전체 CI를 실행하고 GUI 영향 항목을 실제 확인한다.
실행 주체·빌드·명령·결과·미실행 범위를 기록한다. 테스트가 없다는 이유로 기존 기준을 낮추지 않는다.
BUGS/TASKS/WEEKLY_LOG/검증보고를 갱신하고 필수 CI 성공 후 PR로 develop에 통합한다.
main/v0.1.0은 유지한다. v0.2.0 및 ADR Accepted 전환은 별도 판단이다.
완료 보고에 수정 SHA, PR/CI, 회귀 결과, 남은 문제를 포함한다.
```

## 환경·문서 관찰

사용자 미추적 AGENTS.md의 `.Codex/rules/*` 경로는 현재 없다. 저장소의 `.claude/rules/*`와 CONTRIBUTING 및 최신 사용자 역할 분담을 읽고 적용했다. AGENTS.md의 역할 문장/이전 IH-102 상태는 이번에 수정하거나 stage하지 않았다. README·TDD·생활 문서·ADR의 구현 전 설명은 현재 검토 상태와 구분하도록 정리했다.

현재 사용자 작업 트리의 `validate_foundation.py`는 미추적 AGENTS.md에 있는 누락 `.Codex/rules/*` 링크4개 때문에 실패한다. 파일을 숨기거나 지우지 않았다. 위 10단계 PASS는 사용자 미추적 파일을 포함하지 않는 커밋 기준 clean worktree의 결과다.

## Claude Code 수정 결과 (2026-11-01)

`aaac5da`에서 위 재현을 기존 runner의 AC-I04/I08/I10 회귀로 편입해 수정 전 실패(26검사)를 확인했다. 이어 `0332b5a`에서 수정했다. 수정 후 재현 진단 종료0, runner 333검사 PASS, 깨끗한 worktree 로컬 CI 10단계 PASS를 확인했고, 사용자 GUI 확인 결과는 "1~5 모두 정상"이다. 포커스 상실·트리 이탈·queue_free 변형도 수정 전 실패를 확인해 함께 처리했다. 세부 사항은 [검증 기록](IH-102-VALIDATION.md)에 있다. [PR #12](https://github.com/moonhyeonjun/iron-and-harvest/pull/12)의 필수 CI 성공 후 develop 통합(merge e5d7730), develop CI 성공을 확인해 IH-102 done으로 복귀했다.
