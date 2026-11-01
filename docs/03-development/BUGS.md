# 버그·환경 장애·기술 부채

IH-101 이동과 IH-102 상호작용에서 확인된 결함은 아래에 기록한다. 검증하지 않은 기능을 결함 없음으로 선언하지 않는다.

| ID | 분류 | 상태 | 재현/관찰 | 영향·다음 조치 |
|---|---|---|---|---|
| ENV-001 | 환경 | resolved | Downloads의4.7.2 발견, 버전별 사용자 Applications로 복사 | Import/Headless/GUI 검증, 고정 실행기로 PATH 불필요 |
| ENV-003 | 검증 도구 | documented | CUA Sky service 시작 실패. IH-101에서도 Claude의 `screencapture`는 창 내용 없이 바탕화면만 기록, `osascript` 키 입력은 보조 접근 미허용(-25211) | GUI 수동 항목은 사용자 확인, 렌더링은 엔진 viewport 캡처로 보조. OS 창 자동 스크린샷/키 입력 없음 |
| BUG-001 | IH-101 / medium | resolved | macOS 4.7.2 GUI로 테스트 맵 실행 시 시작 직후 `SCRIPT ERROR: Nonexistent function 'set_presentation' in base 'Nil'` (player_controller `_set_locomotion`). APPLICATION_FOCUS_IN→OUT이 트리 진입 전에 도착해 `_halt()`가 null Visual을 호출. 기능 영향은 없었고 사용자 GUI 확인은 정상이었음 | `571c1e9`: 상태는 기록하고 Visual 갱신은 `_ready` 이후. runner가 같은 순서를 재현하고 Logger로 엔진 오류를 수집해 수정 전 코드에서 종료1, 수정 후 GUI 시작 로그 오류0 |
| BUG-002 | 테스트·문서 / low | resolved | IH-101 기록과 runner 주석은 headless에서 `parse_input_event`가 Viewport로 전달되지 않는다고 했지만 틀렸다. `flush_buffered_events()`가 동기 전달하며, IH-102에서 포커스 LineEdit에 'ee'가 찍혀 확인했다. IH-101 AC-08 UI 사례는 키를 두 번 전달했으나 판정 결론은 같았다 | `4f69d80`: 두 runner 모두 한 번만 전달. IH-101 runner 재실행 PASS, IH-101-VALIDATION·PLAYER_MOVEMENT·tests README 정정 |
| BUG-003 | IH-102 / medium (P2) | resolved | `29b2ed3`: E 캡처 뒤 중복 ID 후보의 available을 true로 바꾸면 중복 검증 없이 패널 시작 | 선택에만 중복 필터가 있고 요청 검증에는 없음. [재현·수락 조건](IH-102-REVIEW.md). `0332b5a`: 중복 ID 규칙을 `_check_target`으로 일원화해 선택·실행·활성 세션에 적용, 활성 세션은 열 때 ID로 재검증. 회귀 AC-I04(available/visible), AC-I10(세션 중 중복·이름 변경)은 수정 전 실패, 수정 후 PASS. Codex 재현 종료0 ([검증](IH-102-VALIDATION.md)) |
| BUG-004 | IH-102 / medium (P2) | resolved | `29b2ed3`: Target.try_begin이 Controller를 disable한 뒤 true 반환해도 ACTIVE·패널·이동 차단 발생 | RESOLVING 취소 상태를 반환 후 재검증. [재현·수락 조건](IH-102-REVIEW.md). `0332b5a`: try_begin 중 disable/focus out/트리 이탈을 취소 사유로 기록하고 반환 후 제거·enabled·포커스·게이트를 재검사. end1·rejected1·열림0. 회귀 AC-I08(disable, disable+enable), AC-I10(focus out, remove_child, queue_free)은 수정 전 실패, 수정 후 PASS ([검증](IH-102-VALIDATION.md)) |
| BUG-005 | IH-110 / medium (P2) | resolved | 14302e5: 가방 OPENING 중 target_changed 콜백에서 UI.queue_free 또는 service.close를 실행해도 OPEN/자기 게이트 소유 유지. 즉시 UI.free는 _show에서 signal11 충돌 | 콜백 이후·OPEN 유지 시 UI/서비스 재검증 누락. [재현·수정 수락 조건](IH-110-REVIEW.md). `fb5cd0c`: 열기 콜백 뒤, OPEN 중 매 물리 틱, 보기 전환·이동 요청 전에 UI(생존·트리·삭제 예약)와 서비스 close를 재검사한다. 거부 1회 또는 닫힘 1회(REMOVED/SERVICE_UNAVAILABLE)로 게이트·interaction을 복구하고, 죽은 UI에는 호출하지 않는다. AC-N12 회귀 8종이 수정 전 충돌(signal 11)/실패, 수정 후 PASS. [검증](IH-110-VALIDATION.md) |
| BUG-006 | IH-110 / medium (P2) | resolved | is_valid_id("wood\n")=true, 개행 포함 inventory 등록 OK·catalog compile 성공 | 끝 개행을 허용하는 정규식으로 전체 ASCII ID 규칙 불충족. 자동 trim 없이 전체 문자열 검증·catalog/register/snapshot 회귀 추가. [검토](IH-110-REVIEW.md). `fb5cd0c`: 정규식 대신 문자 단위로 전체 검사하고 trim/소문자화를 하지 않는다. AC-N01/02/09 회귀(LF/CRLF·중간 개행·공백·탭·비ASCII·대소문자·길이 1/64/65)는 수정 전 실패, 수정 후 PASS. [검증](IH-110-VALIDATION.md) |
| DEBT-002 | 설계 한계 | documented | 이동 게이트는 단일 소유자 bool이다. 상호작용 세션 중 외부가 추가로 잠근 것은 구분되지 않아 세션 종료 시 해제될 수 있다(미검사) | 다중 모달/전투가 생길 때 상위 조율자 설계(ADR-014 검토 항목). 지금 전역 잠금 시스템은 만들지 않음 |
| DEBT-004 | 데이터 검증 | documented | Godot 4.7.2는 타입 있는 int Resource 필드에 `.tres` 값 `2.5`/`true`/`"3"`을 오류 없이 2/1/3으로 로드한다(IH-111 측정). IH-111 GatherDef.initial_quantity는 원본 리터럴 검사로 막았으나 IH-110 ItemDef.stack_limit은 같은 검사가 없다 | IH-110 정의 로더에 같은 리터럴 검사를 추가할지 별도 작업에서 결정(이번 범위 밖). 현재 7종 .tres는 모두 정수 리터럴 |
| DEBT-003 | UI 글꼴 | documented | 한글 프롬프트/패널은 엔진 기본 글꼴의 시스템 fallback으로 표시된다(macOS 확인) | 배포 OS별 글꼴 포함 여부와 라이선스는 IH-006/IH-003에서 결정 |
| ENV-002 | Git 초기 상태 | resolved | 최초 커밋 957dd3b와 main/develop ref 생성, push 성공 | 원격 SHA 일치와 기본 main 확인, GIT_BOOTSTRAP 참조 |
| DEBT-001 | 문서 | documented | 이전 초안의 루트 경로/수치와 새 체계 공존 | 이전 문서는 참고 전용으로 분리, 새 문서만 현재 기준 |
| DEC-001 | 결정 대기 | open | LICENSE에 확정 조건 없음 | IH-003에서 사용자 결정 필요, 임의 라이선스 금지 |

2026-11-01 Codex가 `69561ca`에서 원래 두 재현과 전체 CI를 다시 실행해 BUG-003/004 resolved를 확인했다. [독립 재검증](IH-102-VALIDATION.md).

IH-110 최초 구현 당시에는 결함을 발견하지 못했으나 후속 Codex 리뷰에서 BUG-005/006을 재현했고 이후 수정·검증했다. 정의 .tres 생성 시 기본값과 같은 stack_limit이 생략되는 위험은 커밋 전에 설계로 막았다(ItemDef 기본값 0, [검증 기록](IH-110-VALIDATION.md) 구현 차이 1). DEBT-002/003은 그대로다.

IH-111 구현 중 제품 결함은 발견되지 않았다. 테스트 쪽 RefCounted 순환(관찰 lambda가 자기 서비스를 캡처)은 공통 CI의 종료 시 엔진 오류 검사로 발견해 커밋 전에 고쳤다([검증](IH-111-VALIDATION.md)).

이슈 추가 형식: ID, 심각도/우선순위, 환경/빌드/커밋(없으면 없음), 재현, 기대/실제, 로그, 영향, 우회, 담당 작업, 회귀 검사. 추측과 확인된 재현을 구분한다. 해결 시 실제 검증 기록을 연결한다.

2026-11-01 Codex가 `a5cefeb`에서 원래 재현 종료0/위반0, 전체 CI 11단계(인벤토리521검사) PASS를 확인해 BUG-005/006 resolved를 유지했다([독립 검증](IH-110-VALIDATION.md)). 추가 수정 요청 없음. GUI는 기존8dfe8bb 사용자 확인 기록이다.

## IH-111 Codex 후속 검토(c266d52)

| ID | 분류 | 상태 | 재현/영향 | 다음 조치 |
|---|---|---|---|---|
| BUG-007 | IH-111 / medium (P2) | resolved(Codex 1cb3471 재검증) | Inventory 변경 콜백에서 GatheringHUD.free 후 _on_gathered146행의 hud.show_toast가 signal11/exit250. queue_free는 첫 거래 bag9/stock5 성공 후 다음 E에서 같은 충돌 | HUD 쓰기·지연 갱신·rebind의 수명 가드, 실제 HUD 제거 후 후속 입력 회귀. [리뷰](IH-111-REVIEW.md) |
| BUG-008 | IH-111 / medium (P2) | resolved(Codex 1cb3471 재검증) | 내장 GatherDef(path에 ::)의 initial_quantity 2.5/true/"3"이 각각2/1/3으로 로드되고 compile=true/build=OK | 검증 불가 원본 fail-closed 또는 모든 지원 경로의 원본 타입 검증, 내장 fixture 회귀. [리뷰](IH-111-REVIEW.md) |

위 두 건은 최초 구현 중 미발견 기록 이후 추가로 확인했다. IH-111 review 재개. DEBT-004의 기존 ItemDef 제한과 BUG-008의 GatherDef 우회를 구분한다.

2026-11-01 Claude 수정(`b5afd93`):
- BUG-007: 시험 맵 HUD 쓰기 5곳에 수명 가드를 넣었다. 거래 결과는 유지된다.
- BUG-008: 외부 `.tres`만 지원한다. 내장 정의는 거부하고, 경로 없는 정의는 opt-in일 때만 허용한다.
- 수정 전 Codex 진단 4종은 실패했고, 수정 후 모두 PASS다. 회귀는 AC-G01/G09에 편입했다. 변이 5종 검출, 사용자 GUI 정상.
- [수정 기록](IH-111-VALIDATION.md#bug-007008-수정--claude-code-2026-11-01). [PR #29](https://github.com/moonhyeonjun/iron-and-harvest/pull/29)로 develop 통합(merge ed554c5, PR/develop CI success). resolved 판정은 Codex 재검증 뒤에 한다. DEBT-004는 미변경이다.

2026-11-01 Codex가 1cb3471에서 원래 진단4종 종료0/RESULT: PASS, 전체 CI12단계·채집347검사 PASS를 확인했다. BUG-007/008 resolved, IH-111 done 복귀. [독립 재검증](IH-111-VALIDATION.md#codex-독립-수정-재검증). 추가 수정 요청 없음. GUI는 기존 b5afd93 사용자 확인 기록이며 DEBT-004는 유지한다.

## IH-112 구현 기록(2026-11-01)

- **제품 결함**: 구현 중 발견한 문제는 모두 커밋 전에 고치고 회귀로 편입했다. 미해결 제품 결함은 없다. 다음 4건은 [검증 기록](IH-112-VALIDATION.md)에 있다.
  - 해제된 후보를 타입 변수에 대입함
  - 완료 신호 재귀
  - 같은 프레임 suspend/resume 뒤 선택 공백
  - 자식 PID 이중 대기
- **관찰(미재현)**: GUI 창 3(corrupt-latest) 첫 인스턴스가 약 90초 동안 시작 fixture를 적용하지 않았다(파일 mtime·checksum 변화 없음, 로그는 엔진 헤더뿐). 같은 인자로 헤드리스·GUI를 다시 실행하면 즉시 적용된다. 원인은 확인하지 못했다. 영향은 시험 fixture 경로뿐이며, 이 관찰이 결함이라는 증거는 없다.
