# IH-110 수락 조건

상태: **AC-N01~14 실행, 모두 pass**(2026-11-01, Claude Code 구현·자동 375검사, AC-N14는 사용자 GUI 확인, 빌드 `025c863`). [PR #19](https://github.com/moonhyeonjun/iron-and-harvest/pull/19) 필수 CI 성공과 develop 통합(merge f26a77e)을 확인해 **전체 판정은 done**이다. 측정·명령·변이 검사·설계 차이는 [IH-110 검증 기록](IH-110-VALIDATION.md)에 있다. [명세](../02-technical-design/INVENTORY.md)가 계약의 단일 기준이며, 판정 기준은 낮추지 않았다.

## 자동 검사

| ID | 실행·경계 | 기대 결과 |
|---|---|---|
| AC-N01 | 7종 Resource 정의 로드, 동등한 wood JSON 비교. null/중복·빈/형식 위반 ID, 이름/category/limit 오류 | 정상 catalog 일관. 잘못된 catalog 전체 거부, 원인 식별. 하나의 런타임 원본 선택과 근거 기록 (pass) |
| AC-N02 | 빈 재고, capacity0/257, 중복 inventory ID, snapshot/원본 정의 외부 변경 | 유효 등록만 성공. 외부 변경은 내부 상태/stack 제한에 영향 없음. 두 서비스/두 재고 상태 독립 (pass) |
| AC-N03 | wood8+5(다른 stone10 유지), 기존 스택 여럿과 빈 슬롯, limit1 도구2개 | 낮은 인덱스 병합 후 빈 슬롯 분산. 다른 슬롯 불변, limit1은 각각 별도 슬롯 (pass) |
| AC-N04 | 꽉 찬 재고, wood9+2/남는 공간1, quantity0/음수/상한초과, UNKNOWN_ITEM, 외부 float/bool | 전체 거부. 슬롯·수량·revision·이벤트 횟수 모두 불변, 타입 오류를 조용히 정수화하지 않음 (pass) |
| AC-N05 | `[wood4,wood3]`에서5 remove, 정확히 전량, 부족8, 유효하지만 미소지 ID | 성공 후 `[null,wood2]`;0 스택 없음. 부족은 원본 그대로. 다른 ID 미차감 (pass) |
| AC-N06 | bag/store 양방향 transfer, 여러 목적지 스택, 원본 슬롯 전량/부분 | 아이템별 두 재고 총합 보존. 양쪽 revision 각각+1, 변경 신호1회. 읽기 콜백에서 양쪽 완료 상태 관찰 (pass) |
| AC-N07 | 목적지 NO_SPACE, 빈/범위 밖 원본 슬롯, source==destination, 없는 재고, 원본 슬롯보다 큰 요청(다른 슬롯엔 충분) | 계약의 오류 코드와 전체 불변. 원본 먼저 차감/다른 슬롯 자동 차감 없음 (pass) |
| AC-N08 | 같은 expected revision으로 명령2회, 목적지만 바뀐 stale, 변경 신호에서 재귀 transfer | 첫 성공만 적용, stale/BUSY 거부. 자동 재시도 없음. fresh revision의 새로운 명령은 정상 (pass) |
| AC-N09 | 스냅샷 메모리 왕복·수정 사본 격리, 누락/추가 키·길이·ID·수량·revision 손상 | 배치/수량/revision 동일 왕복. Resource/Node 참조 없음. 실패 decode/등록은 활성 상태 불변, 중복 ID 덮어쓰기 없음 (pass) |
| AC-N10 | 가방·보관함 열기/닫기/재열기, 한 개/스택 이동, 옛 session/선택/revision UI 요청, 성공/실패 화면 | 초기 지급1회, 수량 보존, stale 요청 거부. 오류 표시 후 최신값만 읽고 재실행 없음. UI 직접 상태 변경 없음 (pass) |
| AC-N11 | 살펴보기 ACTIVE/RESOLVING에서 I, E큐 다음 I, 가방 중 E·echo·중복닫기, focus된 Button에서 I/Escape | 두 패널 동시 열림0. 활성 살펴보기 보존, E큐 폐기, 게이트 획득/해제 각1회. 같은 키를 두 훅에 전달해 이중 명령 만들지 않음 (pass) |
| AC-N12 | 걷는 중 가방, 닫을 때 방향키 계속 누름/반대키 동시, 포커스 상실·시작 전 알림·opening 콜백 중 취소, 조율자/Player/맵 제거 | 열림 중 정지, 해제 후 neutral 복구. 포커스 취소 래치. 늦은 UI 요청/해제된 노드 호출/고아/엔진 오류0. 조율자만 제거하면 남은 Player 복구 (pass) |
| AC-N13 | 고정 seed의 add/remove/transfer 수열, 재고 재시작 반복, 의도 실패 주입, 공통 CI 등록·기존 회귀 | 매 명령 불변식 확인, 같은 seed 최종 snapshot/결과 동일. 실패 주입 종료비0. 새 runner 정상 RESULT: PASS/종료0, 엔진 ERROR도 CI 실패 (pass) |

정해진 불변식: 슬롯 길이=capacity; 스택은 정의 존재·정수1~limit; 성공 add/remove의 해당 ID 순증감=요청 q; transfer의 모든 ID 총합 일정; 실패는 두 전체 snapshot과 revision 동일; 거래당 변경 이벤트 정확히1회, 실패0회. 임의 수열의 기대값은 생산 코드의 슬롯 배치 함수를 재호출하지 말고 독립 counts 모델과 보존식을 사용한다. 슬롯 순서는 AC-N03/05의 명시 예로 따로 검사한다.

AC-N11/12는 `_unhandled_input` 직접 호출만으로 끝내지 않는다. 기존 runner 방식대로 실제 InputEvent→Viewport→물리 틱을 사용하고 GUI 소비/키 전달을 확인한다. BUG-003/004의 callback 재진입/취소 회귀를 유지한다. DEBT-002의 제3 외부 잠금은 지원 대상으로 확대하지 않으며 이 검사를 근거로 해결이라 보고하지 않는다.

## AC-N14 실제 GUI 확인

실제 빌드 SHA·OS·엔진·확인 주체와 다음 항목별 결과를 기록한다. Headless·화면 캡처는 직접 조작 확인을 대체하지 않는다.

1. 테스트 맵에서 I로 가방 열기: 한글 이름/수량/빈 슬롯/닫기, 기본640×360 및 비16:9에서 내용과 선택 포커스가 보인다.
2. 마우스와 키보드로 검증용 보관함을 열고 wood를1개/스택씩 양방향 이동한다. 총15가 유지되고 재열어도 중복 지급되지 않는다.
3. 꽉 찬 상태의 별도 fixture(테스트 설정으로 구성)에서 이동 실패 안내를 보고 양쪽 수량 보존을 확인한다. 확인 후 정상 시나리오를 새로 실행한다.
4. 살펴보기 중 I, 가방 중 E, I/Escape 연타, 버튼에 포커스 후 I/Escape: 패널 겹침·재개 직후 이동·키 유출이 없다.
5. 걸으며 I, 방향키 유지한 채 닫기, Cmd+Tab 왕복, 정상 씬 종료/재실행: 키 중립 복구·엔진 오류·잠금 잔류를 확인한다.

GUI 제약이 있으면 미확인으로 남기고 사용자 확인을 요청한다. 자동검사 성공만으로 전체 pass/done을 기록하지 않는다.

## 실행·결과 기록

2026-11-01에 모두 실행했다(결과: [IH-110 검증 기록](IH-110-VALIDATION.md)):

```sh
python3 tools/godot.py --headless --import
python3 tools/godot.py --headless --script res://tests/test_inventory.gd
python3 tools/godot.py --headless --script res://tests/test_inventory.gd -- --inject-failure
python3 tools/godot.py res://scenes/tests/inventory_test.tscn
python3 tools/run_ci.py
```

새 runner는 tools/run_ci.py의 ci_steps에 inventory-acceptance로 추가하고 tests의 실행 순서 기대값도 갱신한다. 기존10단계의 기능을 제거하지 않는다. 실패 주입은 정상 CI 단계에 상시 넣지 말고 검출 경로 검증에 사용한다. 로그는 build/ih-110/ 아래(ignored)에 두고 source-tree-clean 검사 시 오염시키지 않는다.

구현 시 새 IH-110-VALIDATION.md에 AC별 결과/근거, 실행 명령·환경·종료 코드·실패와 수정·반복 결과·GUI 확인·미검증·커밋/PR/CI를 남긴다. 지금 결과용 빈 문서를 만들거나 검사를 PASS로 미리 채우지 않는다. 테스트/리뷰/필수 PR CI/develop 통합까지 완료해야 TASKS를 done으로 바꾼다. IH-110만으로 v0.3.0을 발행하지 않는다(IH-111/112 및 마일스톤 기준 확인).
