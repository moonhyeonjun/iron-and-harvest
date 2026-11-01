# IH-102 수락 조건

2026-10-31 Codex 작성 → **2026-11-01 AC-I01~12 실행, 모두 pass**(Claude Code 구현·자동 검사, GUI 항목은 사용자 확인, AC-I12의 PR CI·develop 원격 반영은 [PR #9](https://github.com/moonhyeonjun/iron-and-harvest/pull/9)(merge 318fcd2)로 확인). 측정값·명령·확인 주체는 [IH-102 검증 기록](IH-102-VALIDATION.md)에 있다. 아래 기준은 원래 계획이며 판정 기준을 넓히지 않았다. 기준은 [상호작용 명세](../02-technical-design/INTERACTION.md), 의존성은 IH-101 및 검증 도구 IH-004다.

## 후속 검토 판정 (2026-11-01)

기존 표의 pass는 당시 실행한 시나리오의 결과다. Codex 추가 재현에서 AC-I04/I06의 실행 시 중복 ID, AC-I08의 RESOLVING 중 disable 경계가 실패했다(BUG-003/004). **전체 인수 판정은 review**이며, [추가 수락 조건](IH-102-REVIEW.md)을 기존 runner에 포함하고 수정 검증 후 완료로 복귀한다. 2026-11-01 `0332b5a`에서 추가 사례를 AC-I04/I08/I10에 편입했다. 수정 전 실패와 수정 후 PASS는 [검증 기록](IH-102-VALIDATION.md)에 있다. 기준은 낮추지 않았으며, [PR #12](https://github.com/moonhyeonjun/iron-and-harvest/pull/12) 필수 CI 성공과 develop 통합(merge e5d7730)을 확인해 **전체 판정은 done**이다.

## 기존 검사표

| ID | 시나리오 | 수락 기준 | 방식 |
|---|---|---|---|
| AC-I01 | 고정 엔진 Import, Player·InteractionTest·Target·UI 생성 | 오류0, 기존 main_scene/이동 fixture 유지, 레이어3=값4, Detector/Target 설정·모듈 책임 일치 | 자동·리뷰 / pass |
| AC-I02 | 대상 진입/이탈, 거리0/31.9/32/32.1, r4 경계 후보 | Anchor 거리32 이하만 허용,32.1 거부. 거리0은 방향 조건만 면제하고 벽 내부는 거부. 최대2물리틱 내 프롬프트 반영 | 물리 / pass |
| AC-I03 | 정면/옆/뒤, dot0.5 경계,4방향·대각 이동 facing | dot≥0.5만 선택. 후면/측면 선택 없음. IH-101의 가로 우선 facing 유지 | 자동 / pass |
| AC-I04 | 거리/각도 동률, 진입 순서 반전, 빈/중복 ID | tuple/ID 순서로 동일 대상 선택. 빈/중복 ID는 선택·실행 불가. 매 프레임 전맵 검색 없음 | 자동·리뷰 / pass |
| AC-I05 | 가까운 대상과 발 사이의 world_solid 벽 | 프롬프트 없음·E 실행0회. 벽 제거 후 정상. Target Area/Player body는 LOS를 가리지 않음 | 물리 / pass |
| AC-I06 | 안내→E→다음 틱 전에 거리 밖/삭제/비활성/선택 변경 | 캡처한 대상만 재검증. 무효면 거부·대체 대상 열기 없음·NULL 접근0건. try_begin false도 게이트/패널 변화 없음 | 자동 / pass |
| AC-I07 | E 한 번/유지/echo/같은 틱 연타, ACTIVE 중 E | 유효 press1회→try_begin1회·opened1회. 중복 시작·요청 큐 누적·자원 변화 없음 | 입력·GUI / pass |
| AC-I08 | UI의 E 소비, 외부 이동 차단, interaction disabled | 소비된 키는 요청0회. 기존 차단 상태에서 패널 열기·잠금 해제 없음. disabled면 후보 표시·신규 요청 없음 | 자동·GUI / pass |
| AC-I09 | 걸으며 E, 버튼/Escape, 이동 키 유지, 과거 ID 닫기 | 열린 즉시 velocity0, ACTIVE 이동0. 종료 통지 각각1회, 새 세션에 옛 ID 무효. neutral→새 입력으로 이동 | 물리·GUI / pass |
| AC-I10 | ACTIVE 중 삭제/숨김/비활성/범위 이탈, focus out/in, Controller·맵 제거 | 안전 취소·큐 폐기·패널 숨김, 소유한 게이트만 해제, 자동 재시작 없음. ready 이전 알림·맵 재진입 오류0 | 자동+실제 앱 전환 / pass |
| AC-I11 | 프롬프트/제목/설명·닫기 포커스,1280×720/비16:9창 | 행동·대상 일치, UI의 월드/자원 수정 없음, 텍스트 잘림·의도치 않은 키 전파 없음. E→설명→닫기 완주 | GUI·리뷰 / pass |
| AC-I12 | suite2회·의도적 실패·PR/통합 CI | 반복 결과 동일, 입력·고아 노드·게이트 누수0, 엔진 오류0, 실패 exit1, IH-101 회귀·CI checks 통과, 문서/원격 검증 | 자동·리뷰 / pass |

거리/각도 경계 테스트는 직접 지정한 Vector2를 사용하고 측정 허용 오차는0.001로 기록한다. 허용 거리 자체를 넓히지 않는다. dot0.5의 실제 계산값도 출력한다. 초기 overlap이 서버에 반영되는 두 틱을 기다리는 것은 허용하지만 매 요청 검증을 생략하지 않는다.

## runner와 재현 계약

예정 game/tests/test_interaction.gd는 실제 씬·Area2D·물리 세계와 UI를 사용한다. 선택 수식만 다시 구현한 테스트로 대체하지 않는다. 테스트용 Target subclass로 거부/삭제/호출 횟수를 계측하고 실제 보상 로직은 만들지 않는다.

Headless에서도 Input.parse_input_event 후 flush_buffered_events()가 Viewport로 이벤트를 동기 전달한다(2026-11-01 실측, BUG-002). 그래서 같은 이벤트를 root.push_input으로 또 보내면 이중 전달이 된다. runner는 parse+flush 한 경로로 _unhandled_input과 Control 소비를 검증한다. Controller private 함수 직접 호출만으로 입력 검사를 통과 처리하지 않는다. 입력 시점과 다음 물리 틱의 처리 시점을 명시한다.

각 case는 입력·후보·노드·세션을 정리하고 안전한 spawn/facing을 설정한다. 종료 시 입력 잔류·게이트·고아 노드를 검사하고 새 맵으로2회 반복한다. SCRIPT ERROR는 exit0이어도 실패하며 coroutine 중단·누락 case를 성공으로 집계하지 않는다. 정상 실행과 실패 주입을 검증하고 CI에 등록한다.

## 구현 후 명령

2026-11-01에 모두 실행했다. 결과는 [검증 기록](IH-102-VALIDATION.md)에 있다.

```sh
python3 tools/godot.py --headless --import
python3 tools/godot.py --headless --script res://tests/test_interaction.gd
python3 tools/godot.py --headless --script res://tests/test_interaction.gd -- --inject-failure
python3 tools/godot.py res://scenes/tests/interaction_test.tscn
python3 tools/run_ci.py
```

실패 주입은 종료1이 정상이며 main CI에 상시 실패 명령으로 넣지 않는다. tools/run_ci.py에 정상 interaction 단계와 필수 마커 RESULT: PASS를 추가한다. 기존 player-acceptance를 제거하거나 건너뛰지 않는다. runner 등록 변경도 PR에서 검증한다.

수동 확인: E로 안내판/상자 선택→설명 읽기→버튼/Escape 닫기, 이동 키 유지 상태의 열기/닫기, 실제 앱 전환과 복귀, 비16:9 리사이즈. 주체·빌드 커밋·키/화면 관찰을 기록한다. GUI 접근이 없으면 pending이며 headless로 대체하지 않는다.

## 완료 기록

각 AC에 pass/fail/pending, commit/엔진/OS, 명령·exit, 기대/실제값·호출 횟수 또는 관찰, 로그 경로를 기록한다. 예상한 거부는 reason으로 검사하며 엔진 오류를 발생시킨 채 통과로 분류하지 않는다. AC 전체 pass·문서 일치·review·필수 CI·develop 통합이 완료되어야 IH-102 done이다. v0.2.0 승격/태그는 별도로 판정한다.
