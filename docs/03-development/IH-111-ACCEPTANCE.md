# IH-111 수락 조건

**현재 판정: review.** Codex 후속 재현에서 AC-G01의 내장 정의 타입 검사, AC-G09/11의 실제 GatheringHUD 수명 검사가 미충족임을 확인했다. [BUG-007/008 수정 수락 조건](IH-111-REVIEW.md)을 추가하고 재검증해야 done으로 복귀한다. 아래 pass 표기는 최초 자동/GUI 검사 이력이다.

2026-11-01 Claude 수정(`b5afd93`)에서 위 조건을 회귀로 추가했다. AC-G01은 내장 정의 거부와 경로 없는 정의 opt-in을, AC-G09는 실제 GatheringHUD free/queue_free/remove_child 뒤 후속 E·전송·full·rebind를 검사한다. 347검사 PASS, 변이 5종 검출, 사용자 GUI normal/full/rebind "1~5 모두 정상"(`b5afd93`)이다([수정 기록](IH-111-VALIDATION.md#bug-007008-수정--claude-code-2026-11-01)). done 복귀는 develop 통합과 Codex 독립 재검증 뒤 판정한다.

상태: **AC-G01~14 실행, 모두 pass**(2026-11-01, Claude Code 구현·자동 309검사, AC-G14는 사용자 GUI 확인, 빌드 `7787c26`). [PR #26](https://github.com/moonhyeonjun/iron-and-harvest/pull/26) 필수 CI 성공과 develop 통합(merge 42e3f4b)을 확인해 **전체 판정은 done**이다. 측정·명령·변이·설계 차이는 [IH-111 검증 기록](IH-111-VALIDATION.md)에 있다. 아래 기준은 원래 계약이며 기준을 낮추지 않았다. 원래 상태: 설계 ready, 2026-11-01. 계약은 [GATHERING](../02-technical-design/GATHERING.md), 전달은 [HANDOFF](IH-111-HANDOFF.md). 실제 runner/GUI 증거가 있을 때만 pass로 기록한다. 기존 PASS가 신규 채집 검증을 대신하지 않는다.

| ID | 검사·수락 조건 | 방법 |
|---|---|---|
| AC-G01 정의 | 세 정의 로드. 미등록 품목·음수/0/소수/bool/스택 초과 거부. ID 빈값/끝 개행/공백/길이65 거부. 공유 Resource/외부 사본 수정이 live 정의·재고에 영향 없음 | 도메인 / pass |
| AC-G02 결속 | 중복 point/stock/전체 target ID(비가용 포함), bag/store와 stock 충돌, 동일 point의 활성 뷰2개 거부. 잘못된 마지막 항목 때문에 부분 플레이가 허용되지 않음. 동일 정의의 두 지점은 독립 | 도메인+씬 / pass |
| AC-G03 성공 | stock -1/bag +1, 두 revision +1, 신호1회/ID2개. 신호에서 양쪽 최종 상태 조회 가능. 다른 품목/store 불변, 독립 초기 합과 일치 | 도메인 / pass |
| AC-G04 공간 | 기존 스택 여유만 있어도 성공. full이면 NO_SPACE, 전체 snapshot/revision/이벤트 불변. store로 옮긴 뒤 성공. 초과 지급/바닥 드롭 없음 | 도메인+GUI / pass |
| AC-G05 소진 | 마지막1개 후 null슬롯/잔량0/소진 뷰/프롬프트 없음. 반복 요청 DEPLETED, 음수/추가 이벤트 없음. stock 구조 손상은 INVALID_STOCK, 자동 재충전 금지 | 도메인+씬 / pass |
| AC-G06 명령 | prepare 수량/신호 변경0. bag·stock 변경 각각 STALE_REVISION. 취소/소비/타 서비스 명령 INVALID_COMMAND. 성공/실패/취소 뒤 새 준비 가능. 같은 명령 재사용 지급0 | 도메인 / pass |
| AC-G07 재검증 | 실제 E 입력 후 실행 전 거리/정면/벽/ID/중복/available/삭제 변경 시 지급0. 다른 대상으로 대체 지급 없음. 요청 terminal 보고 최대1 | 입력+물리 / pass |
| AC-G08 commit 전 취소 | try_begin에서 disable→enable, focus-out→복귀, 대상/Controller 이탈·queue_free, Escape 주입. 취소 래치 유지, 명령 해제, end/rejected 각 최대1, 재고 불변, 새 요청 정상 | 엔진 콜백 / pass |
| AC-G09 commit 후 수명 | 변경 신호에서 Target/UI 즉시 free·queue_free, Controller/맵 이탈·queue_free, GatherService/InventoryService.close. 이미 적용된 양쪽 거래는1회 성공. 죽은 Node 호출/오류/누수 없음. 표시 생략을 실패/rollback으로 처리하지 않음 | 엔진 콜백 / pass |
| AC-G10 입력·재진입 | 변경 신호에서 prepare/commit 및 E/I 재진입은 BUSY/거부, 다음 틱 추가 지급0. echo/held E 반복 지급0, 같은 틱 복수 입력 최대1, 정상 key-up/down 후 다음 채집1 | 도메인+Viewport / pass |
| AC-G11 UI·이동 | instant의 inspect session_opened0/이동 게이트 소유0, 알림 정확. 가방/살펴보기 열림 중 채집0, 닫은 뒤 기존 중립키 정책. UI 제거로 거래 반복 없음 | 자동+GUI / pass |
| AC-G12 재진입 | 부분/완전 소진 각각 뷰 unload/rebind 뒤 값/revision 동일, 초기 재지급0, 이전 준비 명령 무효. 숨은 stock은 bag/store UI 대상이 아님. 세션 종료 뒤 명령 CLOSED/INVALID_COMMAND | 씬+GUI / pass |
| AC-G13 회귀 | 새 runner 공통 CI 등록, 결정적 반복 결과 일치, 아래 실패/변이 검출. 기존 이동360/상호작용333/인벤토리521 검증 의도 보존. 엔진 오류/고아0 | 로컬+원격 CI / pass |
| AC-G14 GUI | 아래 실제 조작 확인 주체·빌드 SHA·환경·결과·로그 기록. headless/캡처만으로 키 조작·감각 pass 처리 금지 | 실제 창 / pass |

## 독립 검증·실패 주입

- 전후 snapshot, 품목별 합, revision, 변경/terminal 신호 수를 독립 검사한다. production 로직을 복사한 oracle이나 ASSERT 개수만으로 판정하지 않는다.
- 결정적 시퀀스: gather→bag/store transfer→full 실패→stale 실패→cancel→deplete→rebind. 테스트가 독립 계산한 초기 물자 합과 매 단계 비교한다. 고정 seed/입력·최종 snapshot·이벤트 수를 두 실행에서 비교한다.
- 변이 최소: NO_SPACE인데 stock 차감, prepare 중 지급, consumed 검사 제거, stale 검사 제거, rebind refill, EXECUTING 재진입 입력 큐 유지. 각 목표 회귀에서 검출해야 한다. 구문 오류는 결함 검출 증거가 아니다.
- runner는 RESULT: PASS 최종 마커·정상 종료·엔진 오류0이 모두 필요하다. 실패 주입 옵션에서 비정상 종료/FAIL 확인. Godot 종료0+SCRIPT ERROR도 CI 실패여야 한다. Python CI 목록 테스트도 갱신한다.

## GUI 절차

1. 일반 맵 이동/안내판 살펴보기 후 세 지점 접근. E1회에 해당 품목1개/잔량 감소. inspect 패널 없이 이동 가능. E를 누른 채 있어도 추가 지급 없음.
2. I 가방에서 품목/스택 확인. 가방 열린 채 E는 지급0. 닫고 키 중립 후 다시 채집. 기존 설명용 상자는 지급0.
3. full fixture에서 E 실패·지점 보존. bag wood10을 store로 옮긴 뒤 E 성공, 합계 보존.
4. 완전 소진 시 빈 표시/프롬프트 없음. 멀어졌다 돌아와도 재생 없음. rebind fixture에서 최초 채집 뒤 수량 유지.
5. 포커스 이탈/복귀 후 유령 입력/추가 지급 없음, 새 누름 정상. 알림/글자/가방이 겹쳐 조작을 막지 않음. 사용자 확인 시 빌드와 체크 항목을 함께 제시.

## 구현 후 명령(2026-11-01 실행, 결과는 검증 기록)

```sh
python3 tools/godot.py --headless --import
python3 tools/godot.py --headless --script res://tests/test_gathering.gd
python3 tools/godot.py res://scenes/tests/gathering_test.tscn
python3 tools/godot.py res://scenes/tests/gathering_test.tscn -- --fixture=full
python3 tools/godot.py res://scenes/tests/gathering_test.tscn -- --fixture=rebind
python3 tools/run_ci.py
```

구현 때 IH-111-VALIDATION.md를 생성해 각 AC pass/fail/미실행, 명령/exit/log, 반복/변이, GUI 주체/SHA, 설계 차이, PR/CI/merge SHA를 기록한다. 모든 AC·필수 CI·리뷰·develop 통합 뒤 IH-111 done을 판정한다. v0.3.0은 IH-112와 마일스톤 조건을 포함한 별도 판정이다.
