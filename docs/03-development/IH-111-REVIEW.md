# IH-111 Codex 기술 검토 — 2026-11-01

## 현재 판정 — 수정 검증 완료

2026-11-01 Codex가 develop/origin `1cb3471`에서 원래 진단4종을 그대로 재실행해 모두 종료0/RESULT: PASS를 확인했다. 전체 CI 12단계·채집347검사도 통과했다. **BUG-007/008 resolved, IH-111 done 복귀**. [독립 재검증](IH-111-VALIDATION.md#codex-독립-수정-재검증)을 따른다. 아래 최초 재현과 수정 프롬프트는 완료 이력이며 다시 구현할 작업이 아니다. ADR-016 Proposed는 유지한다.

## 최초 검토 판정(수정 전)

대상 develop/origin `c266d52`. **BUG-007/008(P2) 재현으로 IH-111 done→review**. 기존 구현·자동 PASS·사용자 GUI 기록은 이력으로 보존한다. 수정 회귀와 독립 재검증 뒤 done 복귀를 판단한다. ADR-016 Proposed, IH-112 구현 착수/새 마일스톤 판정은 이 수정 이후다. Codex는 게임 코드·씬·CI 설정을 변경하지 않고 검토·인수인계만 작성했다.

## Claude 수정 결과 (2026-11-01)

브랜치 `fix/gathering-hud-and-definition-validation`, 커밋 `28e5a80`(실패 회귀), `56b7d5b`(수정), `b5afd93`(HUD fixture 표시).
- **BUG-007**: 시험 맵의 HUD 쓰기 5곳을 `_hud_usable()`(유효·트리 안·삭제 예약 아님)로 감쌌다. 거래와 rebind는 그대로 진행한다. 실제 HUD free/queue_free/remove_child 뒤 다음 E·store 이동·다시 E, HUD 없는 full/rebind를 AC-G09에 추가했다.
- **BUG-008**: 지원 형식을 제한했다(외부 `.tres`만, 정수 리터럴 검사). 내장(`::`) 정의는 값과 무관하게 거부한다. 경로 없는 정의는 코드 전용 opt-in일 때만 허용한다. 내장 2.5/true/"3"/누락/정상 5종은 INVALID_SETUP·null로 처리되고, 출하 외부 정의는 성공한다.
- 수정 전 Codex 진단 4종은 실패(exit 250 2회, FAIL)였고, 수정 후 모두 exit 0·PASS다. runner는 347검사 PASS다. 변이 5종(HUD 가드 3곳 제거, 내장 허용, 경로 없음 기본 허용)이 모두 검출됐다.
- 사용자 GUI는 normal/full/rebind "1~5 모두 정상"(`b5afd93`)이다. 깨끗한 worktree CI 결과와 PR/통합은 [검증 기록](IH-111-VALIDATION.md#bug-007008-수정--claude-code-2026-11-01)에 있다.
- [PR #29](https://github.com/moonhyeonjun/iron-and-harvest/pull/29)로 develop 통합(merge `ed554c5`, PR/develop CI success, 통합 tree=`1010bde`).
- 남은 제한: DEBT-004(ItemDef) 미변경. Codex 독립 재검증 대기.

## 확인한 증거·검증 범위

- PR #26 merge42e3f4b, 기록 PR #27 mergec266d52. 동일 SHA develop CI41284249678 success를 확인했다.
- 별도 clean detached worktree에서 공통 CI 종료0/12단계 PASS. Python19·경제7·이동360·상호작용333·인벤토리521·채집309. 채집 반복2회 측정22종 차이0·고아0·엔진 오류0.
- GUI는 이번에 새로 조작하지 않았다. [Claude 검증 기록](IH-111-VALIDATION.md)의 사용자 빌드7787c26 확인과 구분한다. 이후 game/tools/tests/.github 변경은 README 문서뿐이며 실행 코드는 같다.
- 추가 진단은 실제 맵·입력/서비스 API와 Resource 로드 경로를 사용했다. 정상 플레이 중 무작위 충돌이나 수량 유실을 관찰했다는 뜻이 아니다. 원시 로그/진단은 `build/ih-111-codex-review/`(Git 무시)에 보존한다.
- 사용자 미추적 AGENTS.md는 변경/커밋하지 않는다. 기존 .Codex/rules 링크4개 오류는 깨끗한 커밋 worktree 검사와 구분한다.

## BUG-007 — 제거된 GatheringHUD 호출로 엔진 충돌 (P2)

위치: `game/scripts/tests/gathering_test.gd`의 `_on_gathered`146행, 관련 `_on_rejected`153행·`_rebind_fixture`160행·`_update_hud`195행. 이 맵은 IH-111의 실제 실행 진입점이다.

재현:

1. gathering_test 일반 fixture에서 branch_pile_01을 선택한다(기존 test_gathering의 `_load_map`/`_stand` 사용).
2. InventoryService.inventories_changed에 일회 콜백을 연결하여 `map.get_node("GatheringHUD").free()`를 실행한다.
3. 실제 E 입력으로 1개 채집한다. 양쪽 상태 설치 후 instant_completed→맵 `_on_gathered`가 이미 해제된 `hud.show_toast`를 호출한다.
4. Godot signal11, launcher exit250. GDScript 역추적의 첫 위치가 gathering_test.gd:146이다.

queue_free 경로도 확인했다. 첫 E는 오류0·bag wood9/stock5로 완료하지만 HUD가 실제 해제된 뒤 **다음 E에서 같은 signal11/exit250**이 발생한다. 따라서 즉시 free라는 특수 조건만의 문제가 아니다.

기존 AC-G09는 `Interaction/InteractionUI`(살펴보기 프롬프트)만 free/queue_free하고 새 `GatheringHUD`는 제거하지 않는다. queue_free 검사도 현재 거래 이후 입력까지 이어가지 않아 공백이 남았다. 진단: `probe.log`(즉시 free), `queue-probe.log`(첫 거래 보존), `queue-next-probe.log`(다음 E 충돌).

기대: HUD가 없거나 트리 밖/삭제 예약이면 표시만 생략한다. 도메인 성공은 그대로 유지하고 재시도/rollback하지 않는다. 후속 채집·가방 전송도 오류 없이 동작해야 한다.

수정·수락 조건:

- HUD를 참조하는 성공/실패/지연 갱신/rebind 표시 경로를 모두 점검한다. 호출 전 is_instance_valid·is_inside_tree·is_queued_for_deletion을 확인하고, 서비스/맵 종료 중 지연 콜백도 안전하게 종료한다.
- 실제 GatheringHUD free, queue_free, remove_child를 commit 콜백에서 각각 주입한다. 성공1회·양 revision+1·수량 보존·terminal 최대1·엔진 오류0·누수0을 확인한다.
- 다음 E까지 진행하여 추가 정상 거래1회가 가능함을 확인한다. 가방 full의 거부 안내, store 이동의 지연 HUD 갱신, rebind fixture도 HUD 없는 상태에서 검사한다.
- 기존 InteractionUI/InventoryUI/Target 수명 회귀는 유지한다. null 예외를 숨기거나 채집 전체를 막아 통과시키지 않는다.

## BUG-008 — 내장 GatherDef의 비정수 수량이 검증을 통과 (P2)

위치: `game/systems/gathering/gather_catalog.gd`의 `_authored_literal`58~67행. `resource_path`에 `::`가 있으면 빈 문자열을 반환하고 compile은 리터럴 검사를 생략한다.

재현: 아래 catalog를 로드한 뒤 `catalog.compile(item_records)`와 `GatherService.build(item_catalog, catalog, snapshots, &"player_bag", [branch_binding])`를 호출한다. branch_binding은 기존 BINDINGS[0], snapshots는 기존 `_snapshots()`다.

```ini
[gd_resource type="Resource" script_class="GatherCatalog" load_steps=4 format=3]
[ext_resource type="Script" path="res://systems/gathering/gather_catalog.gd" id="1"]
[ext_resource type="Script" path="res://systems/gathering/gather_def.gd" id="2"]
[sub_resource type="Resource" id="GatherDef_bad"]
script = ExtResource("2")
definition_id = &"gather_branches"
display_name = "Branches"
action_label = "Gather"
item_id = &"wood"
initial_quantity = 2.5
[resource]
script = ExtResource("1")
definitions = Array[ExtResource("2")] ( [SubResource("GatherDef_bad")] )
```

| 원본 initial_quantity | 엔진 로드 값 | compile | build | 기대 |
|---|---:|---|---|---|
| 2.5 | 2 | true | OK | 거부 |
| true | 1 | true | OK | 거부 |
| "3" | 3 | true | OK | 거부 |

분리 진단 `catalog-probe.log`: 종료1, 위반3, 엔진/파싱 오류0. 원본 경로는 `...tres::GatherDef_bad`다. 외부 .tres만 검사하는 기존 AC-G01 fixture가 이 우회를 놓쳤다. 현재 세 정상 콘텐츠의 수량이 잘못됐다는 뜻은 아니지만 새 콘텐츠를 내장 Resource로 작성하면 조용히 다른 양이 등록된다.

수정·수락 조건:

- 검증할 수 없는 원본을 검증 성공으로 취급하지 않는다. 최소 대안은 지원 콘텐츠를 명시 외부 .tres로 제한하고 내장/원본 불명 경로를 명확한 오류로 거부하는 것이다. 또는 지원하는 모든 정의 경로에서 변환 전 타입을 검증한다. 선택과 제한을 ADR/명세에 기록한다.
- 외부/내장 각각 소수·bool·숫자 문자열·누락을 거부하고 build 결과가 INVALID_SETUP/value=null인지 검사한다. 내장 형식을 지원하지 않기로 하면 정상 정수 내장도 명확히 거부하고 외부 정상 정수는 성공한다.
- 경로 없는 테스트용 정의의 허용 정책도 명시한다. 엔진의 조용한 변환 뒤 타입을 검사하는 것만으로 원본 타입을 증명했다고 기록하지 않는다. 실험 코드를 복사한 취약한 범용 .tres 파서는 만들지 않는다.
- 기존 정의 복사 격리·아이템/수량/ID 검증은 유지한다. IH-110의 DEBT-004를 함께 확장 수정하지 않는다. 두 도메인의 남은 제한을 구분한다.

## Claude Code 수정 전달용 프롬프트

```text
IH-111 Codex 리뷰의 BUG-007/008을 수정하라.
CLAUDE.md/.claude/rules, docs/03-development/IH-111-REVIEW.md,
IH-111-ACCEPTANCE.md, IH-111-VALIDATION.md, GATHERING.md와 실제 코드를 읽는다.
최신 develop/Git 상태/사용자 변경을 확인하고 fix/gathering-hud-and-definition-validation에서 시작한다.
수정 파일/계획을 먼저 제시하고 기존 구현을 다시 만들지 않는다.
BUG-007: 변경 신호에서 GatheringHUD free 및 queue_free 후 다음 E를 재현한다.
_on_gathered/_on_rejected/_update_hud/_rebind_fixture 등 표시 경로의 수명을 검증한다.
없는 HUD에는 표시만 생략하고 원자 거래 성공을 보존한다. 후속 채집/전송도 안전해야 한다.
BUG-008: 내장 GatherDef의 2.5/true/"3"이 compile/build에 성공하는 재현을 회귀로 추가한다.
검증 불가 경로를 조용히 허용하지 말고 지원 형식 제한 또는 원본 타입 검증 방식을 명시한다.
외부/내장/경로 없음 정책과 실패 시 부분 세션 없음, 정상 외부 정의 성공을 검증한다.
실패 회귀를 먼저 기록하고 최소 코드 수정 후 신규 회귀·기존 전체 CI를 실행한다.
표적 변이로 실제 GatheringHUD 수명 검사 및 내장 정의 거부가 빠지면 실패함을 확인한다.
기존 이동360/상호작용333/인벤토리521/채집309의 검사 의도를 보존한다.
Godot4.7.2, 기존 진입점·수량 보존·단발 명령·취소/재진입 계약을 유지한다.
실제 normal/full/rebind GUI를 검증하고 주체/빌드 SHA를 기록한다.
신규 기능/파일 저장/재생/범용 잠금/DEBT-004 일괄 수정은 하지 않는다.
검증/REVIEW/AC/TASKS/WEEKLY_LOG/BUGS/CHANGELOG 및 설계 차이를 실제 결과로 갱신한다.
수정 뒤 필수 PR CI 성공 후 develop 통합·원격 결과를 확인한다. main/태그/릴리스는 변경하지 않는다.
사용자 미추적 AGENTS.md는 보존·미커밋한다. 미검증을 완료로 기록하지 않는다.
파일·재현 전후·테스트/GUI·남은 문제·커밋/PR/CI를 보고한다.
```
