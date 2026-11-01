# IH-111 채집·자원 지점 검증 — 2026-11-01

## Codex 후속 판정 — review

2026-11-01 `c266d52`에서 BUG-007(채집 HUD 해제 후 호출·충돌), BUG-008(내장 정의의 비정수 수량 허용)을 추가 재현했다. **IH-111 done→review**, 두 결함 open. [재현·수정 수락 조건·Claude 프롬프트](IH-111-REVIEW.md)를 따른다. 아래는 Claude의 최초 구현/검증/통합 기록으로 보존한다. 기존 suite PASS/GUI 확인은 새 경계의 통과를 뜻하지 않는다.

## 결론

Claude Code가 [GATHERING 명세](../02-technical-design/GATHERING.md)에 따라 다음을 구현했다.
- 정의·결속
- 지점별 숨은 1슬롯 재고(같은 InventoryService)
- 단발 명령(stock→bag `transfer`)
- Interaction의 INSTANT 실행
- GatherTarget과 단일 세션 시험 맵(normal/full/rebind)

AC-G01~13 자동 309검사는 PASS다. 공통 CI 12단계에서 기존 이동 360, 상호작용 333, 인벤토리 521검사 회귀도 통과했다. 명세의 최소 변이 6종과 추가 1종은 모두 검출됐다. AC-G14 GUI는 사용자가 실제 창 3개에서 확인했다.

IH-111 상태는 **done**이다. [PR #26](https://github.com/moonhyeonjun/iron-and-harvest/pull/26) 필수 CI 성공 후 develop에 통합하고 원격 CI를 확인했다(아래 통합 기록). ADR-016은 **Proposed**를 유지한다. 수량(6/4/3)·좌표·표현은 검증 fixture이며 밸런스가 아니다. 도구·기력·작업 시간·재생·파일 저장·농사·전투·위임·범용 잠금은 구현하지 않았다. IH-102 상자는 살펴보기 전용이며, `can_interact`/`try_begin`/프롬프트/`session_opened`에서는 아무것도 지급하지 않는다.

## 환경·대상

- macOS 13.4, MacBook Air M1, Godot `4.7.2.stable.official.ed1daf0bf` Standard, Compatibility.
- 브랜치 `feature/gathering-system` ← develop `fe6a293`. 커밋은 다음과 같다.
  - `14a2687`: 정의·서비스
  - `24bf870`: Interaction INSTANT
  - `5a5f5f5`: Target·맵·HUD
  - `03c6a65`: runner·fixture
  - `a56ab1d`: CI 등록
  - `7787c26`: 테스트 순환 참조 수정
- 사용자 미추적 `AGENTS.md`는 수정·커밋하지 않았다. 원시 로그는 `build/ih-111/`(Git 무시)에 있다.

## 사전 측정: 타입 있는 Resource의 조용한 정수화

int로 타입 지정된 Resource 필드에 `.tres` 값 `2.5`, `true`, `"3"`이 들어오면 Godot 4.7.2는 오류 없이 각각 2, 1, 3으로 로드한다. `set("qty", 7.9)`도 7이 된다. 로드된 값만으로는 소수/bool을 거부할 수 없다. 그래서 GatherCatalog가 정의 원본 `.tres`의 `initial_quantity =` 줄이 정수 리터럴인지 확인한다. 줄이 없으면 `<missing>`으로 거부한다. IH-110 ItemDef.stack_limit에도 같은 엔진 동작이 있다. 이번 범위 밖이라 DEBT-004로 기록만 했다.

## 실행 명령·결과

| 명령 | 빌드 | 종료 | 결과 |
|---|---|---:|---|
| `python3 tools/godot.py --headless --import` | 각 단계 | 0 | 오류/경고 0 |
| `python3 tools/godot.py --headless --script res://tests/test_gathering.gd` | `7787c26` | 0 | 309검사 PASS, 2회 측정 차이 0, 고아 0, 엔진 오류 0, 종료 시 누수 경고 0, 약 19초 |
| 같은 runner `-- --inject-failure` (`run_step` 판정) | `a56ab1d` | 1 | nonzero exit, engine error in log, missing completion marker |
| 표적 변이 7종 | `03c6a65` 변형 | 모두 1 | 파싱 오류 0, `RESULT: FAIL`과 함께 해당 AC 실패(아래) |
| `python3 -m unittest discover -s tests -p 'test_*.py'` | `a56ab1d` | 0 | 19개 OK(gameplay suite 4개 등록·순서·마커) |
| `python3 tools/run_ci.py` (깨끗한 worktree) | `a56ab1d` | 1 | gathering 단계가 `engine error in log`로 실패. 종료 시 ObjectDB 146개 누수·리소스 4개 사용 중. runner 자체는 PASS(아래) |
| 같은 명령 | `7787c26` | 0 | 12단계 PASS. 이동 360(123.9초), 상호작용 333(29.7초), 인벤토리 521(9.9초), 채집 309(18.7초), 각 엔진 오류·누수 경고 0 |
| GUI: `gathering_test.tscn` normal / `-- --fixture=full` / `-- --fixture=rebind` | `7787c26` | full·rebind 0 | 사용자 조작. 로그 오류 0. normal 창은 확인 응답 시점에 열려 있었고 그때까지 오류 0 |

누수 조사: 처음 CI가 실패한 원인은 테스트였다. AC-G03/G09의 관찰 lambda가 자기가 연결된 InventoryService/GatherService를 캡처하고도 연결을 해제하지 않아 RefCounted 순환이 생겼다. runner의 고아 *노드* 검사로는 보이지 않았지만, 공통 CI의 엔진 오류 로그 검사가 잡았다. 제품 코드는 맵만 쓰는 탐침과 도메인만 쓰는 탐침(준비 명령을 남긴 채 종료하는 경우 포함)을 따로 실행해 누수 0을 확인했다. 연결 해제로 고쳤다(`7787c26`).

표적 변이:

| 변이 | 검출 AC |
|---|---|
| NO_SPACE인데 stock 차감 | G04 |
| prepare에서 지급 | G01, G02, G03, G04, G06, G08, G10, G11, G12, G13 |
| 명령 소비 검사 제거(재사용 가능) | G04, G05, G06, G09, G10, G11, G12, G13 |
| stale revision 검사 제거 | G06 |
| rebind 시 stock 재충전 | G12 |
| EXECUTING 중 E를 다음 틱 큐에 유지 | G10 |
| (추가) Target이 try_begin 안에서 commit | G08, G10, G11, G12, G13 |

## AC별 결과

| ID | 결과 | 측정·관찰 | 확인 주체 |
|---|---|---|---|
| AC-G01 | pass | 정의 3종을 순서·값(wood 6, stone 4, berry 3, 따기)대로 로드. 잘못된 정의 11종(미등록 품목, 0, -1, wood 11, 도끼 2, 빈/끝 개행/공백/65자 ID, 빈 이름/행동)은 컴파일·build 전체 거부. fixture `2.5`/`true`/`"3"`/누락은 엔진이 2/1/3/0으로 로드했지만 리터럴 검사로 모두 거부. 캐시된 gather_branches.tres를 수량 99/품목 stone/이름으로 변조하거나 query 사본을 수정해도 live 값은 6/wood/나뭇가지 그대로 | 자동 |
| AC-G02 | pass | 잘못된 결속 12종은 부분 세션 없이 INVALID_SETUP: 중복 point, stock 중복·bag·store 충돌, 끝 개행/빈/65자 ID, 미지 정의, 키 누락/추가, 비Dictionary, 마지막 항목만 잘못됨. 미등록 bag도 거부. 같은 정의의 두 지점은 독립. 씬에서 지점 ID=안내판, 비가용 상자의 중복 ID, 한 지점의 뷰 2개, 결속 없는 뷰는 setup 거부(상호작용 비활성, 가방 NOT_READY) | 자동 |
| AC-G03 | pass | stock -1(wood5), bag +1(wood9), 두 revision +1, 신호 1회(`player_bag`, `stock_branch_01`). 신호 안에서 양쪽 최종 상태 관찰. store와 다른 stock 불변, 합계가 독립 계산값 wood14/stone14/berry3/tool_axe1과 일치 | 자동 |
| AC-G04 | pass | 슬롯은 꽉 찼지만 wood9 스택 여유만으로 성공. wood10+stone10×11이면 세 지점 모두 NO_SPACE: 전체 snapshot·revision·이벤트 불변, 명령 해제. bag wood10을 store로 옮긴 뒤 성공, 합계 보존. GUI full 창에서 안내·보존 확인 | 자동 + 사용자 GUI |
| AC-G05 | pass | berry 3회 뒤 slot 비움, 잔량 0, depleted. 다시 prepare하면 DEPLETED, 이벤트 0. 다른 품목이나 초기보다 많은 수량이 들어간 stock은 INVALID_STOCK이며 재충전하지 않음. 씬에서 소진 시 회색·'-'·프롬프트 없음 | 자동 + 사용자 GUI |
| AC-G06 | pass | prepare는 지급·신호 0. 대기 중에 다시 prepare하면 BUSY(기존 유지). 명령 내부 필드를 변조해도 원래 point/request로 실행. 재사용·취소(2회 안전)·타 서비스 명령은 INVALID_COMMAND이고 기존 대기 명령은 유지. bag·stock이 바뀌면 각각 STALE_REVISION. close 후 CLOSED. request 0/1.0/true, store를 목적지로 지정, 끝 개행 point는 INVALID_ARGUMENT, 미지 point는 INVALID_POINT | 자동 |
| AC-G07 | pass | 실제 E 입력 뒤 처리 전에 범위 밖=OUT_OF_RANGE, 벽=OCCLUDED, ID 변경·비가용·queue_free·쌍둥이 가용화=INVALID_TARGET. 모두 지급 0·이벤트 0·대체 실행 없음·최종 보고 1회·대기 명령 없음 | 자동(입력+물리) |
| AC-G08 | pass | try_begin 안에서 disable→enable=DISABLED, focus out→in=FOCUS_LOST, Controller 트리 이탈=REMOVED, 대상 queue_free=INVALID_TARGET, Escape=CANCELLED. 각각 지급 0, end(cancelled) 최대 1, 거부 1, 명령 해제, 다음 E는 정상 1개 | 자동(엔진 콜백) |
| AC-G09 | pass | commit 변경 신호 안에서 9가지(Target free/queue_free, 프롬프트 UI free/queue_free, Controller 트리 이탈/queue_free, 맵 queue_free, GatherService.close, InventoryService.close)를 실행. 모두 bag 9/branch 5로 1회만 적용되고 이후 이벤트 0, 죽은 노드 호출·엔진 오류·누수 0. 표시 생략을 실패나 롤백으로 처리하지 않음 | 자동(엔진 콜백) |
| AC-G10 | pass | 신호 안에서 prepare=BUSY, E는 소비(다음 틱 지급 0), I는 가방 거부(CLOSED 유지). 완료 보고 콜백의 E도 폐기. E 유지+echo 8회=1, 같은 틱 2회 누름=1, 새 누름=1 | 자동(Viewport) |
| AC-G11 | pass | INSTANT는 session_opened 0, 신호 시점 Player 이동 가능, 게이트 미소유, 토스트 '목재 1개를 얻었습니다 (남은 5)'. 가방이 열려 있으면 E 지급 0, 가방·보관함 화면에 stock ID 없음. 상자 살펴보기는 지급 0, 패널 중 E는 BUSY, 닫은 뒤 채집 정상 | 자동 + 사용자 GUI |
| AC-G12 | pass | 부분(branch 5, rev 1)·완전 소진(berry 0, rev 3) 값이 rebind 전후 같고 재충전 없음. 뷰가 들고 있던 명령은 INVALID_COMMAND. 새 뷰로 같은 stock에서 채집. rebind fixture 보고의 전후 값 일치. 세션 종료 후 명령·조회 CLOSED | 자동 + 사용자 GUI |
| AC-G13 | pass | 스크립트+seed 1111 시퀀스(채집→store 이동→가득 참→stale→취소→소진, 이후 120단계 무작위)를 매 단계 독립 합계로 확인했고 2회 결과가 같음. suite 2회 측정 차이 0, 고아 0, 키 잔류 0, 엔진 오류 0, 남은 맵 0. 실패 주입·변이·CI 등록·기존 회귀 통과 | 자동 |
| AC-G14 | pass | 아래 GUI 확인 | 사용자 |

## AC-G14 실제 GUI 확인

- 확인 주체: **사용자**(실제 창·키보드·마우스·육안), 2026-11-01, 빌드 `7787c26`, macOS 13.4 / M1, Godot 4.7.2 Standard.
- 창은 제목으로 구분했다: 'IH-111 gathering test (normal)', '(full)', '(rebind)'.
- 확인 항목:
  1. 안내판 살펴보기 뒤 세 지점 1회 1개 획득·잔량·토스트, 패널 없이 이동, E 유지 시 추가 없음.
  2. 가방 품목 확인(지점 재고 비노출), 가방 중 E 무획득, 닫은 뒤 재채집, 상자 무지급.
  3. full 창에서 가득 참 안내·보존, 보관함 이동 후 성공, 합계 유지.
  4. 완전 소진 표시·재생 없음, rebind 토스트·수량 유지.
  5. Cmd+Tab 왕복 후 유령 입력 없음, 표시 겹침 없음.
- 응답: "1~5 모두 정상". 항목별 메모는 없다.
- Claude는 화면 기록 권한이 없어(ENV-003) 엔진 viewport 캡처로 프롬프트·토스트·소진 표시만 보조 확인했다(`build/ih-111/gui/`). 이것은 OS 창 증거가 아니다.

## 구현 차이·결정

1. **GatherCatalog 파일 추가**: 명시 목록용 `systems/gathering/gather_catalog.gd`를 추가했다(명세 표에는 gather_def/gather_service만 있음).
2. **initial_quantity 원본 리터럴 검사**: 위 측정 때문에 추가했다. 메모리에서 만든 정의(경로 없음)는 타입 int라 검사하지 않는다.
3. **build 정적 팩토리**: `GatherService.build(item_catalog, gather_catalog, snapshots, bag_id, bindings)`가 모든 검증과 등록을 새 InventoryService에서 수행한다. 하나라도 실패하면 INVALID_SETUP이고, 아무것도 반환하지 않는다.
4. **명령 경로**: `GatherCommand.commit()/cancel()`은 발급 서비스의 `execute()/release()`로 위임한다. 실제 캡처 값은 서비스가 보관하므로 명령 객체 필드를 변조해도 효과가 없다. 명령은 서비스를 WeakRef로 참조해 순환이 없다. 진단용 `has_pending_command()`를 추가했다.
5. **stock 무결성**: capacity 1·owner=point 외에, 다른 품목이나 초기보다 많은 수량이 들어 있으면 INVALID_STOCK이다(재충전 탐지).
6. **Interaction**: 상태 EXECUTING, 신호 `instant_completed`를 추가했다. 실행·보고 중 E는 BUSY 거부 대신 조용히 소비한다(명세가 허용한 두 방식 중 하나). **RESOLVING 중 Escape는 요청을 취소**하며, 이는 INSPECT에도 적용된다(패널이 열리기 전 취소). 콜백으로 트리에서 빠지면 그 틱의 선택 갱신을 건너뛴다.
7. **GatherTarget 표시**: 변경 신호 대신 `_process`에서 잔량을 조회해 갱신한다. commit 신호 안에서 Node 콜백을 늘리지 않기 위해서다.
8. **씬 구성**: 지점 뷰는 rebind를 위해 `scenes/gathering/gathering_points.tscn`로 분리했다. 좌표는 나뭇가지 (250,360), 돌 (250,470), 산열매 (360,300)이고, 시작 위치 (128,360)의 아래를 보면 안내판이 선택되는 조건을 유지한다. HUD 합계는 가방+보관함+지점이다. 테스트는 맵 `fixture` 속성으로 fixture를 지정하고, GUI는 `--fixture=`를 쓴다.
9. **prepare는 공간 예약이 아님**: 가방이 가득 차도 prepare는 성공하고 commit이 NO_SPACE를 반환한다(명세 그대로).

## 미검증·남은 범위

- Windows/Linux GUI, 배포 빌드, 한글 글꼴(DEBT-003)은 확인하지 않았다. DEBT-002(제3 게이트 작성자)는 해결하지 않았다.
- 파일 저장(IH-112), 재생·도구·작업 시간·위임은 범위 밖이다.
- 통합 결과는 아래 기록에 있다.

## 통합 기록

- [PR #26](https://github.com/moonhyeonjun/iron-and-harvest/pull/26): feature/gathering-system(`c036f90`) → develop, merge `42e3f4b230bd901a6fdab1122e592ed809822ccf`. 병합 전 mergeable_state=clean, base `fe6a293`. 보호 우회·강제 push 없음.
- [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41283403152/job/124779743066): Ubuntu 24.04 / Godot 4.7.2에서 12단계 PASS. 네 gameplay suite 모두 `RESULT: PASS`, 엔진 오류 0, 종료 시 누수 경고 없음.
- [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41283663628/job/124780504085): develop push(`42e3f4b`) CI checks success.
- 통합 tree는 검증한 `c036f90`과 동일(`git diff --exit-code`). main·태그·릴리스는 변경하지 않았다.
