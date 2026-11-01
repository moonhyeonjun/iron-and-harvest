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
| DEBT-002 | 설계 한계 | documented | 이동 게이트는 단일 소유자 bool이다. 상호작용 세션 중 외부가 추가로 잠근 것은 구분되지 않아 세션 종료 시 해제될 수 있다(미검사) | 다중 모달/전투가 생길 때 상위 조율자 설계(ADR-014 검토 항목). 지금 전역 잠금 시스템은 만들지 않음 |
| DEBT-003 | UI 글꼴 | documented | 한글 프롬프트/패널은 엔진 기본 글꼴의 시스템 fallback으로 표시된다(macOS 확인) | 배포 OS별 글꼴 포함 여부와 라이선스는 IH-006/IH-003에서 결정 |
| ENV-002 | Git 초기 상태 | resolved | 최초 커밋 957dd3b와 main/develop ref 생성, push 성공 | 원격 SHA 일치와 기본 main 확인, GIT_BOOTSTRAP 참조 |
| DEBT-001 | 문서 | documented | 이전 초안의 루트 경로/수치와 새 체계 공존 | 이전 문서는 참고 전용으로 분리, 새 문서만 현재 기준 |
| DEC-001 | 결정 대기 | open | LICENSE에 확정 조건 없음 | IH-003에서 사용자 결정 필요, 임의 라이선스 금지 |

2026-11-01 Codex가 `69561ca`에서 원래 두 재현과 전체 CI를 다시 실행해 BUG-003/004 resolved를 확인했다. [독립 재검증](IH-102-VALIDATION.md).

이슈 추가 형식: ID, 심각도/우선순위, 환경/빌드/커밋(없으면 없음), 재현, 기대/실제, 로그, 영향, 우회, 담당 작업, 회귀 검사. 추측과 확인된 재현을 구분한다. 해결 시 실제 검증 기록을 연결한다.
