# IH-112 Codex 기술 검토 — 2026-11-01

## 현재 판정

Codex가 develop `d2e1c88`에서 수정 코드를 검토하고 원래 진단 5종(exit 0)과 깨끗한 worktree 공통 CI 13단계(저장 529검사)를 독립 재실행했다. **BUG-009~011 resolved, IH-112 review 유지**. AC-S16 손상 최신본의 명시 복구 GUI는 미확인이며 추가 사용자 테스트를 재요청하지 않는다. ADR-017 Proposed, main·태그·릴리스는 변경하지 않는다.

아래 최초 재현과 수정 프롬프트는 완료 이력이다. 반복 실행할 수정 요청은 없다. [독립 재검증](IH-112-VALIDATION.md#codex-독립-수정-재검증)을 따른다.

## Claude 수정 결과 (2026-11-01)

브랜치 `fix/save-input-and-session-boundaries`, 커밋 `450a988`(실패 회귀), `8e18a75`(수정), `bc0d44f`(열린 패널 가드 검사).
- **BUG-009**: F5/F9는 coordinator의 현재 epoch를 쓴다. UI가 없어도 동작하고 표시만 생략하며, coordinator가 없으면 무시한다.
- **BUG-010**: 보고 중(`_emitting`)이면 시작 경계에서 BUSY다.
- **BUG-011**: coordinator가 로드 동안 세션 정지를 걸고, 맵과 InventoryController가 open/view/전송 의도를 BUSY/STALE_SESSION으로 거부한다. 강제 닫기·제3 게이트·전역 잠금은 없다.
- 결과:
  - Codex 진단 5종: 수정 전 exit 250/250/1/1/1 → 수정 후 모두 exit 0·PASS.
  - runner 529검사 PASS, 변이 5종 검출.
  - 깨끗한 worktree CI 13단계 PASS(360/333/521/347/529).
- 새 GUI는 미실행이다(사용자 테스트 중단 존중). AC-S16 손상복구 GUI도 미확인이다. 위 결과는 Claude 검증 기록이며 Codex 독립 재검증도 완료했다. [수정 기록](IH-112-VALIDATION.md#bug-009011-수정--claude-code-2026-11-01)

## 최초 검토의 기준과 검증 범위

- PR #33 merge3ab4795, 기록 PR #34 mergeb13292b. 동일 SHA develop CI41303127354 success 확인.
- 별도 clean detached worktree에서 공통 CI 종료0/13단계 PASS: Python19·경제7·이동360·상호작용333·인벤토리521·채집347·저장425. 저장 반복2회 측정15종 차이0·고아0·엔진 오류0. INF fixture의 예정된 overflow 경고4건은 기존 runner 정책으로 별도 계수됐다.
- 새 GUI/변이는 실행하지 않았다. [Claude 검증 기록](IH-112-VALIDATION.md)의 사용자438ef89 부분 확인과 구분한다. 기록된 추가 사용자 테스트 중단 요청을 존중하며 재요청하지 않는다. Claude 절차6은 수락 문서의 GUI4(손상 최신본/명시 복구)에 해당한다. 자동 AC-S06을 실제 GUI 통과로 바꾸지 않는다.
- 추가 진단은 실제 SaveLoadTest/Viewport 입력·공개 명령·deferred 호출을 사용했다. 정상 플레이에서 무작위 충돌/파일 소실을 관찰했다는 뜻이 아니다. 로그/진단은 build/ih-112-codex-review/에 보존한다. 제품 saves와 사용자 GUI 시험 파일은 접근하지 않고 고유 user://tests/ih112/codex_probe_*만 사용했다.
- 미추적 AGENTS.md 보존. 기존 .Codex/rules 링크4개 실패와 깨끗한 worktree 정적 검사를 구분한다.

## BUG-009 — SaveUI 제거 후 F5/F9가 해제된 UI를 호출 (P2)

위치: `game/scripts/tests/save_load_test.gd` `_unhandled_input`68/70행.

재현: 실제 맵을 열고 SaveUI.free 또는 queue_free 후2틱을 기다린다. F5를 실제 입력으로 전달한다. `coordinator.request_save(ui.get_epoch())`가 해제된 UI에 접근한다. 두 경우 모두 Godot signal11/launcher exit250, 첫 GDScript 역추적은 save_load_test.gd:68이다. F9도 같은 무검사 ui.get_epoch 경로다(동일 코드 검토, 이번 충돌 실행은 F5만).

기존 AC-S11은 rename 직후 UI를 해제해 현재 결과가 보존되는지만 보고, 이후 F5/F9 입력을 검사하지 않는다. 완료 표시의 수명 검사는 키 입력의 수명 검사를 대신하지 않는다.

수정 수락 조건:

- UI가 없거나 트리 밖/삭제 예약일 때 F5/F9 요청 정책을 명시한다. 현재 Coordinator epoch를 쓰는 안전한 키 경로 또는 안전한 거부/무시 중 선택하고 문서화한다. 죽은 UI를 호출하지 않는다.
- free/queue_free/remove_child 뒤 F5와 F9 각각, 성공 콜백에서 UI 제거 후 다음 키, 로드 중 제거·실패 후 다음 키를 회귀로 추가한다.
- 이미 commit된 저장/복원 결과는 유지하고 중복 작업0, 엔진 오류/고아/누수0이어야 한다. UI/Coordinator 부재에서 임의 파일 작업이나 새 세션 생성으로 우회하지 않는다.

## BUG-010 — 거부 결과 보고 중 재진입 저장이 실제 실행됨 (P2)

위치: `game/scripts/save/save_coordinator.gd` `_request_blocker`259~269행, `_reject`·`_emit_and_idle` 보고 경계.

재현: 비어 있는 시험 슬롯·정상 세계에서 operation_finished에 일회 observer를 연결한다. observer가 현재 epoch로 request_save를 호출하게 하고, 바깥 호출은 request_save(epoch-1)로 거부시킨다.

실제: 바깥 STALE_SESSION, observer 안의 새 저장은 **OK**, A은행 generation1이 생긴다. 진단 exit1/위반1/엔진 오류0. 기대: 보고 중 새 요청은 BUSY, 은행은 둘 다 없음, 보고는 원래 거부1회뿐이다.

원인: 정상 완료 보고 때는 state가 busy지만, 시작 전 거부는 state=IDLE에서 `_emitting=true`만 설정한다. `_request_blocker`가 `_emitting`을 보지 않아 정상 인수로 재진입하면 새 작업을 시작한다. 기존 AC-S11은 정상 완료 콜백의 BUSY만 검사한다.

수정 수락 조건:

- 정상 완료와 시작 전 거부 모두 보고 중 save/load 진입을 차단한다. 중첩 거부를 다시 emit하지 않아 재귀/중복 결과를 만들지 않는다.
- STALE_SESSION/NO_SAVE 또는 NOT_READY/모달 BUSY 등 실제 거부·실패 보고에서 save와 load의 교차 재진입을 검사한다. 거부 테스트를 위해 callback을 제거하거나 결과 신호를 없애지 않는다.
- 파일 바이트/세대·epoch·월드 참조/재고·operation 수가 추가 변경되지 않아야 한다. 보고가 끝난 뒤 정상 새 요청은 성공해야 한다.

## BUG-011 — 일시 정지가 지연된 기존 세션 명령을 막지 못함 (P2)

위치: `game/scripts/save/save_coordinator.gd`의 request_load/_suspend/_fail_load, `game/scripts/inventory/inventory_controller.gd` request_open 및 명령 진입 경계.

재현:

1. 정상 시험 세계에서 generation1 저장. 기존 InventoryController는 CLOSED·게이트 미소유다.
2. request_load(current_epoch)로 STAGING을 시작한다. 기존 컨트롤러의 `request_open.call_deferred(InventoryController.View.STORE)`를 예약한다.
3. position_checked 훅에서 Coordinator에 focus out→in을 보내 publish 전에 취소한다. deferred 호출은 그 전에 실행된다.
4. 실제 FOCUS_LOST로 원래 월드가 복귀하지만 **InventoryController OPEN(2), owns_movement_gate=true**다. 진단 exit1/위반1/엔진 오류0. 처음 CLOSED였던 상태와 달라졌다.

기대: suspended 세션에 뒤늦게 도착한 열기/전송 의도는 거부되며, 취소 복귀 시 원래 CLOSED·게이트 미소유를 유지한다. process_mode를 DISABLED로 해도 call_deferred/직접 메서드 호출이 차단되지는 않는다. 비활성 Button 클릭 측정만으로 이 경계를 증명할 수 없다.

수정 수락 조건:

- 기존 설계의 session_suspended/epoch 가드를 명령 진입에 적용하거나 동등하게 입증 가능한 작은 조율 경계를 만든다. Player bool 게이트에 제3 소유자를 추가하지 않는다.
- staged 중 기존 컨트롤러의 지연 request_open, view/transfer/close 의도가 현재/후보 세계를 임의 변경하지 못하게 한다. API 의미에 맞는 명시 BUSY/STALE_SESSION 결과를 검사한다.
- 로드 성공·위치 실패·포커스 out→in·후보 실패 각각 이전 모달/게이트·interaction·재고/revision·준비 명령을 비교한다. 실패 뒤 새 정상 입력은 동작해야 한다.
- 잘못 열린 창을 뒤늦게 강제 닫아 결과만 맞추지 않는다. 정지 중 명령 자체가 실행되지 않는 실패 회귀를 먼저 추가한다. 후보/이전 세션 정리·기존 게이트 복구 검사는 유지한다.

## 진단 실행

`game/build/review/probe.gd`는 기존 test_save_load.gd를 상속하는 임시 진단이며 제품 소스에 편입하지 않았다. 다음 네 모드로 별도 프로세스를 실행했다.

```sh
python3 tools/godot.py --headless --script res://build/review/probe.gd -- --case=ui_free
python3 tools/godot.py --headless --script res://build/review/probe.gd -- --case=ui_queue
python3 tools/godot.py --headless --script res://build/review/probe.gd -- --case=reject
python3 tools/godot.py --headless --script res://build/review/probe.gd -- --case=suspend
```

ui_free/ui_queue는250, reject/suspend는1이었다. 후자의 engine error 목록은0이며 실패 assertion이 의도대로 출력됐다. 원본 script와 네 로그를 build/ih-112-codex-review/에 보존한다. 핵심 재현은 위 절차와 실제 API만으로 runner 회귀에 옮길 수 있다.

## Claude Code 수정 전달용 프롬프트 (완료 이력)

```text
IH-112 Codex 리뷰의 BUG-009/010/011을 수정하라.
CLAUDE.md/.claude/rules, docs/03-development/IH-112-REVIEW.md,
IH-112-ACCEPTANCE.md, IH-112-VALIDATION.md, SAVE_LOAD.md와 실제 코드를 읽는다.
최신 develop/Git 상태/사용자 변경을 확인하고 fix/save-input-and-session-boundaries에서 시작한다.
수정 파일/계획을 먼저 제시하고 실패 회귀를 먼저 추가한다.
BUG-009: SaveUI free/queue_free/remove_child 후 F5/F9, 완료 뒤 다음 입력을 안전하게 처리한다.
없는 UI의 키 요청 정책을 명시하고 이미 commit된 저장/복원은 유지한다.
BUG-010: 시작 전 거부 보고 중에도 새 save/load는 BUSY여야 한다. 파일/epoch/월드 변경0, 재귀 보고0을 검사한다.
BUG-011: process_mode만으로 지연 메서드가 차단된다고 가정하지 않는다.
suspended/epoch 경계를 기존 InventoryController의 열기/전송 등 실제 명령 진입에 적용한다.
로드 성공/실패/취소에서 기존 세션의 지연 의도와 패널/게이트/재고를 검증한다.
임의 강제 닫기/Player 제3 게이트 소유/전역 잠금으로 우회하지 않는다.
기존 360/333/521/347/저장425 검사 의도를 보존하고 새 회귀를 공통 CI에 포함한다.
표적 변이로 수명/보고/정지 가드 제거가 실제 검출되는지 확인한다.
사용자가 추가 사용자 테스트를 중단한 기록을 존중하고 다시 요청하지 않는다.
가능한 자동 검증과 GUI의 미확인 범위를 구분한다. AC-S16 손상복구 GUI를 확인한 것처럼 기록하지 않는다.
Godot4.7.2·A/B 파일/세션 commit·수량 보존 계약을 유지한다.
제품 saves/사용자 GUI 시험 파일은 건드리지 않고 고유 시험 루트만 사용한다.
검증/REVIEW/AC/HANDOFF/TASKS/WEEKLY_LOG/BUGS/CHANGELOG와 설계 차이를 갱신한다.
필수 PR CI 후 develop 통합·원격 확인한다. main/태그/릴리스는 변경하지 않는다.
사용자 미추적 AGENTS.md를 보존·미커밋한다. 미검증을 done으로 보고하지 않는다.
파일·재현 전후·실제 테스트·남은 GUI 조건·커밋/PR/CI를 보고한다.
```
