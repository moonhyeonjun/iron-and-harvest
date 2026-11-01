# IH-120 달력·계절·하루 경계 수락 조건

상태: **설계 ready / 구현·신규 검사·GUI 미실행**, 2026-11-01. [CALENDAR](../02-technical-design/CALENDAR.md)·[ADR-018](../04-decisions/ADR/ADR-018-calendar-day-boundary.md)·[인수인계](IH-120-HANDOFF.md)가 계약이다. 기준 IH-112 done, schema1 지원은 현재 코드이며 아래 schema2는 구현 목표다. 아래 표는 완료 증거가 아닌 검사 요구사항이다.

| ID | 요구·실패 경계·관찰 | 방법 |
|---|---|---|
| AC-C01 정의 | 기본/빠른 프로필 검증·독립 사본. 누락/추가 키, 중복 ID, bool/소수/문자열·비유한/음수·과대 정수, 미지원 순서/Hz/한도 거부. 외부 원본/반환값 수정으로 서비스 정의 불변 | 순수 값·JSON fixture |
| AC-C02 날짜 | 초기1년 봄1일06:00. 독립 계산으로 각 계절 마지막 tick→다음 계절1일, 겨울→다음 해 봄, 23:59→00:00은 같은 day_index. 기본14일/fast2일 프로필 모두 검사, season/year 별도 저장0 | 순수 서비스 |
| AC-C03 전진 | 1tick/여러 tick/정확히하루/이미06:00에서 다음새벽. amount1..하루만, runtime bool/float/0/음수/초과 거부. revision은 성공 명령당+1. 전체 사전 검증 뒤 설치, 최대 연도/revision overflow에 상태·이벤트 변경0 | 순수 서비스 |
| AC-C04 경계·재진입 | completed_day_index=이전 날짜, 단일 알림은 설치 후1회. 알림에서 snapshot은 새 값, 재진입 전진/save/load BUSY·추가파일/epoch변경0. 읽기 전용 이벤트/독립 결과를 통해 상태 수정 불가. 같은 revision 재요청 STALE_REVISION. 거부 결과 보고 중 시간 요청도 BUSY·재귀보고0 | 서비스·실제 wrapper |
| AC-C05 어댑터 | 같은 물리스텝 수는 렌더30/60/144Hz 표현 조건·프레임 묶음 차이와 관계없이 같은 snapshot/알림 수. 자동1tick/step, pending N이 있으면 자동tick0. paused/큰 렌더 delta/휴면을 복귀 때 일괄 보충하지 않음. physics_hz60 불일치 NOT_READY | 제어된 호출·실제 엔진 |
| AC-C06 정지 합성 | user pause + 모달 + focus + suspended + tree pause 각각과 조합. 사유 하나 해제 시 나머지가 유지, 저장은 user pause와 양립. P 시간정지 중 이동·채집 가능, Player 제3 게이트/강제닫기/재고 변경0 | 실제 입력·맵 |
| AC-C07 다음새벽 입력 | N press/echo/hold·버튼 중복은 pending1개·경계1개. pending 시 F5/F9 BUSY. 소비 때 epoch/revision·모달/포커스 재검증. 취소·포커스왕복·다른 world publish 뒤 old pending 실행0. 정상 다음 press 가능 | Viewport/공개 명령 |
| AC-C08 수명 | HUD free/queue_free/remove_child 후 후속 P/N·자연 tick·F5/F9도 안전. 보고/로드 중 UI 제거 뒤 다음 요청 안전. coordinator/host/world/service 제거·queue_free, staged 후보 제거 시 죽은 참조/재시도0, old 서비스 CLOSED·새 epoch 무해 | 실제 장면·deferred |
| AC-C09 schema2 왕복 | 기본/빠른 프로필의 비초기 day/tick/revision과 전체 기존 재고·결속/위치가 파일왕복·재시작 후 동일. 화면의 날짜는 파생값 일치. load/restore 이벤트0·revision 증가0·초기 지급0. 이후 경계1회. user pause는 파일에 없고 같은 root의 현재값 유지 | 실제 파일·별도 프로세스 |
| AC-C10 migration | 기존 전체 정상v1→2, 시험v0→1→2. 원본바이트·generation·재고/revision 등 보존, v0 facing만down. calendar는 기본rule/day0/tick0/rev0. 원본 schema0/1 보고, load쓰기0·이벤트0. 다음 F5만schema2·다음generation. 먼저 v1검증: 누락/추가 키/잘못된 facing/ID/수량을 이관으로 덮지 않음 | immutable v0/v1 fixtures·파일 |
| AC-C11 codec 실패 | schema2 calendar 없음/오타/추가필드·소수/bool/문자열/범위·profile불일치, 미래schema3+/content오류 거부. 정상checksum 구조오류와 checksum불일치 구분. v0.3.0의 schema2_future fixture 보존, 새 미래 시험이 진짜3+인지 검사 | codec·A/B 상태표 |
| AC-C12 세션·복구 | A v1/B v2 혼합 generation선택·명시 이전복구. 저장 실패·손상/미래·잘못된 달력·후보 위치 실패·focus out-in/host 제거에서 파일/기존 calendar 인스턴스·snapshot 보존. publish 성공은 inventory/gather/calendar 동시 교체, staging tick0·이벤트0 | 실제 SaveCoordinator/Store·실패 주입 |
| AC-C13 호환·회귀 | 기존 save_load/gathering 맵은 passive calendar(자연tick0), 원래 기본fixture/키·버튼/포화/채집·저장 intent 보존. 기존 360/333/521/347/529 기준 검증 의도 유지, schema 예상값 변경·추가 검사 명시. import/깨끗한tree/공통CI 신규 suite 등록·실패 감지 | 로컬·Linux PR CI |
| AC-C14 반복·청소 | 독립 expected값으로 기본 최소4년/빠른4년의 모든 경계 순서·날짜·총알림 수 확인(하루 단위 API로 bounded 실행). 같은 시나리오2회 snapshot/metrics 차이0, 고아/누수/예상 밖 엔진 오류0. close/실패 후보·observer 연결 정리, 시험루트만 정리 | 결정적 runner |
| AC-C15 실패 감지·변이 | 아래 표적 변이 검출 및 inject-failure exit비0. 논리 assertion 실패와 parse/import 자체 실패 구분. 통과 marker 누락/엔진오류 exit0도 공통CI 실패로 검출 | runner·표적 변이 |
| AC-C16 GUI | 아래 사용자 조작·육안 확인, 주체·SHA·환경·기준/관찰·로그 기록. headless/화면캡처/창열기만으로 pass 처리하지 않음 | 실제 GUI |

## 필수 표적 변이

1. 날짜 rollover를 한 tick 이르게/늦게 바꾸거나06:00 대신midnight에 일자증가 → C02/03.
2. tick마다 경계알림 또는 설치 전 알림·busy가드 제거 → C04.
3. 모달/focus/user-pause 중 한 가드를 제거, 또는 한 사유 해제로 모두 재개 → C06.
4. pending N 처리와 자동tick 둘다 실행/hold를 매frame 새의도로 처리 → C05/07.
5. restore 시calendar를 새게임값으로 재설정 또는 day event발행 → C09.
6. v0→1에서 최신schema2를 넣어 중간검증/이관 생략 → C10(실제v0도2까지 도달·최종구조 확인).
7. schema2 calendar를 optional로 허용하거나 원본파일을 migration 중 다시씀 → C10/11.
8. session_suspended/epoch 가드를 제거 또는 후보를 driver가 tick → C08/12.

변이는 task-owned 별도 checkout/시험파일에서만 하고 제품/사용자 저장은 수정하지 않는다. 각 변이의 실패항목·exit·엔진 구문오류 여부를 남긴다. 오류 없는 정상 suite/공통 CI로 원복 상태를 확인한다. 테스트를 구현과 같은 함수 호출로 예상값 재계산하지 않는다.

## 실제 GUI 절차

기존 테스트 재개 지시가 유효하다. 구현 후 Claude Code가 새 전용 user://tests/ih120/ 경로/확인용 fixture를 준비해 사용자가 조작하도록 안내하고 응답을 기다린다. 사용자 확인을 자동 추정하지 않는다. 비교할 상태는 필요하면 P로 시간 정지해 읽고 N을 시험할 때만 해제한다. 기존 ih112 GUI 파일과 제품 saves는 건드리지 않는다.

1. 기본 프로필에서 1년 봄1일06:00 시작·분 진행·프로필/시험루트 표시를 확인한다. P로 ‘시간 정지’ 후 달력은 멈추고 이동은 가능하다. 재개 뒤 정상 진행한다.
2. 가방·보관/살펴보기 중 날짜 정지·닫힌 뒤 재개를 확인한다. P정지+가방조합에서 가방을 닫아도 P정지가 유지되는지 확인한다. 앱 전환 후 P/N을 놓은 새 입력만 수락하고 유령 날짜 점프가 없어야 한다.
3. 빠른 boundary fixture(별도root)에서 자연 새벽 경계를 관찰한다. 일시정지해 기준을 읽고 재개 후 N의 한 press/hold가 하루만 넘는지 확인한다. 봄2일→여름1일·겨울2일→2년봄1일을 시험버튼/N으로 확인한다. HUD가 SaveUI/복구 안내를 가리지 않아야 한다.
4. 기본프로필 비초기 시점에서 P정지·F5, 재개해 다음날로 바꾼 뒤 다시P·F9. 저장한 날짜/시각·위치/재고 복원과 현재P정지 유지, 이후 새벽1회·이동/채집/전송 정상을 확인한다. 종료·재시작 뒤 F9도 확인한다(새 프로세스P상태는 초기값).
5. 구현자가 **신규root의** 유효v1 migration fixture와 A/B손상 최신본을 준비하고 SHA/세대/날짜기준을 먼저 기록한다. v1로드는 봄1일06:00과 기존재고 보존·이관안내, 손상 최신본F9는 현재달력/세계보존·명시복구버튼은 표시된 이전세대의 달력/재고복원임을 확인한다. 파일이 load만으로 바뀌지 않았는지는 구현자가 바이트/log로 별도 기록한다.

부분 확인은 항목별로 남긴다. GUI불가·확인응답 없음은 C16미실행/review이고, 이를 CI 통과로 대체하지 않는다. IO/미래버전/강제HUD제거는 자동증거이며 사용자가 그 동작을 직접 확인한 것으로 기록하지 않는다. 자연시간과 빠른fixture의 결과를 혼동하지 않는다.

## 검증 기록과 완료

구현 때 IH-120-VALIDATION.md를 생성한다. C01~16별 pass/fail/미실행, 실제 검사수·명령/exit/로그·반복/변이·이관전후 bytes/schema·주체/SHA/프로필/GUI응답·파일/세션실패·차이/제약·PR/CI/merge를 기록한다. 현재 이 문서는 설계 검사표이며 검증 완료 증거가 아니다.

실제 실행 코드와 문서 일치·전체 수락·필수PR CI/검토/develop통합 후에만 done, ADR-018 Accepted는 별도 근거로 판단한다. v0.4.0 Farming은 IH-121 등 농사조건까지 남아 있으므로 IH-120만으로 태그를 생성하지 않는다.
