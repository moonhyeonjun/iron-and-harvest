# IH-112 저장·복원 수락 조건

**현재 추가 판정: BUG-009~011 open / review.** 기존 AC-S01~15 자동 PASS를 보존하되 후속 진단에서 UI 다음 입력(S11/12), 거부 보고 재진입(S11), 일시 정지 중 지연 명령(S10/11)의 공백을 재현했다. [수정 수락 조건](IH-112-REVIEW.md)을 추가해 재검증한다. AC-S16 손상복구 GUI 미확인은 그대로이며 추가 사용자 테스트를 재요청하지 않는다.

상태: **구현·자동 검증 완료 / AC-S16 부분 / review**, 2026-11-01 Claude Code.
- AC-S01~15: 자동 425검사 pass. 변이 7종 검출, 별도 프로세스 재시작·SIGKILL 확인, 깨끗한 worktree CI 13단계 PASS.
- AC-S16: 사용자 GUI 절차 1~5 확인(빌드 `438ef89`). 절차 6은 사용자 GUI 미실행(사용자가 이후 사용자 테스트 중단을 지시). 따라서 IH-112 done이 아니다.

결과와 측정은 [검증 기록](IH-112-VALIDATION.md)에 있다. 원래 상태는 설계 ready였다. [SAVE_LOAD](../02-technical-design/SAVE_LOAD.md)의 계약을 검사한다. 아래 기준은 원래 계약이며 낮추지 않았다. [전달 프롬프트](IH-112-HANDOFF.md), [ADR-017](../04-decisions/ADR/ADR-017-versioned-save-restore.md)를 함께 따른다.

| ID | 완료 조건·관찰 | 방법 |
|---|---|---|
| AC-S01 codec | v1 envelope/payload 정상 왕복, checksum 원문 UTF-8 바이트 일치. 키/형식/타입 오류·잘린 JSON·hash 불일치·용량 초과·null/root형식 오류를 거부하고 부분 상태를 반환하지 않음. 실제 UTF-8/escape/full_precision 포함 | 순수 값+파일 |
| AC-S02 숫자 | 정수값1/1.0 허용, bool/소수/문자열/음수/비유한/한도 초과 거부. revision/generation safe-integer 양끝과 초과, capacity/quantity 한도, finite 위치 검증. 내부 int snapshot으로 변환한 뒤 기존 decode 통과 | codec 경계 |
| AC-S03 참조·콘텐츠 | 재고5/결속3의 누락·중복·추가, 미지 품목/맵/정의, owner/capacity/stock 연결 오염 거부. bag을 stock으로 연결할 수 없음. 소진 null은 허용, 잘못된 빈스택/초기량 초과는 거부 | codec+서비스 |
| AC-S04 snapshot | 안정 시점에 위치/방향·bag/store·stock·revision을 일관되게 캡처. 조회 사본 수정이 live 상태에 영향 없음. Inventory busy/Gather pending/Interaction 큐·RESOLVING/EXECUTING/보고 중/가방 OPENING·OPEN은 BUSY이며 기존 요청·패널·게이트를 임의 변경하지 않음 | 도메인+입력 |
| AC-S05 파일 commit | 빈 슬롯→A1→B2→A3 정상, 작은 generation 파일만 교체. 쓰기·flush·close·재읽기·길이·checksum·rename 전 검증. 각 사전 실패는 두 은행의 기존 바이트 동일, rename 뒤 성공/진단 실패를 구분 | 실제 파일+실패 어댑터 |
| AC-S06 선택·복구 | 없음/유효1/유효2/손상1/손상2/동일 세대 동일·상충/IO 실패/미지원 버전의 표를 전부 검사. mtime을 역전해도 generation 선택. pending은 무시. 복구 필요 시 기본 Load는 세계 불변, 명시 선택만 이전 유효본 로드 | 파일+UI |
| AC-S07 migration | v0 시험 fixture→v1 facing down, 수량/슬롯/revision/generation 완전 보존. 파일 원문 불변. 미래2·미지원 음수/구버전·content≠1 거부, 호환 안 되는 은행을 다른 유효본으로 조용히 덮어쓰지 않음 | fixture |
| AC-S08 새 컨텍스트 | 저장한 부분 소진/완전 소진과 bag/store를 새 서비스에 정확 복원. stock 재지급0, 변경/획득 신호0. 이후 채집/전송은 기존 revision+1·수량 보존. 기존 GatherService.build NEW 동작은 유지 | 서비스+씬 |
| AC-S09 위치 | 위치 왕복 오차≤0.0001·방향 일치·속도0·IDLE·카메라 복원. 영역 밖/벽 내부/발 충돌 위치 거부, 자동 텔레포트 없음. 실패 시 이전 위치/컨텍스트/수량/revision 유지 | 물리+씬 |
| AC-S10 후보 실패 | 잘못된 노드/UI/Target ID·후보 bootstrap 실패·물리 검사 실패·호스트 이탈/queue_free·포커스 out→in을 단계별 주입. publish 전 실패는 호스트 생존 시 후보 폐기·이전 서비스 open/상태 유지·입력 복구. 호스트 종료 시 정상 해제·늦은 호출 없음. 모든 경우 누수0 | stage 실패 주입 |
| AC-S11 세션·재진입 | 이전 UI 요청/session ID·GatherCommand·서비스 참조가 로드 뒤 새 세계를 변경하지 않음(같은 ID 재사용 포함). 중첩 save/load·완료 신호의 재진입은 BUSY·추가 작업0. commit 뒤 UI 삭제/포커스 상실은 성공을 취소/중복 적용하지 않음 | 콜백+입력 |
| AC-S12 키·모달 | F5/F9 새 누름1회, echo/동일 틱 반복 중복0. E/I/이동을 로드 중 눌러도 다음 프레임 유령 행동0. 키 해제 뒤 새 입력 정상. 가방/살펴보기 중 저장/로드 거부, 기존 패널 유지. 실패 뒤 게이트/interaction 원래 상태 복구 | 실제 Viewport 입력 |
| AC-S13 재시작·중단 | 프로세스 종료 후 다시 실행해 디스크 파일로 복원. pending 작성/검증/rename 전/후 각각 자식 프로세스를 종료시켜 이전/새 유효본 선택 확인. 없는 쓰기를 성공으로 보고하지 않음. macOS 실제 FS와 Linux CI 범위를 기록 | 실제 파일·별도 프로세스 |
| AC-S14 독립 보존 검사 | 채집→store 이동→완전 소진→저장→세계 추가 변경→로드→계속 채집 시퀀스를 독립 oracle로 비교. v0 이관/복구 선택/파일실패 포함 고정 입력2회 snapshot·신호 수 동일. 저장한 세계와 로드 후 세계의 품목별 총량 일치 | 결정적 시퀀스 |
| AC-S15 CI·실패 감지 | 새 runner 공통 CI 등록, 실패 주입 nonzero·마커 누락·엔진 오류 검출, 아래 변이 검출. 기존 이동360/상호작용333/인벤토리521/채집347 검증 의도 보존. 엔진 오류·고아·누수0 | 로컬+원격 |
| AC-S16 GUI | 아래 실제 창 절차를 조작, 확인 주체/빌드 SHA/환경/결과/로그 기록. 캡처/headless만으로 pass 처리하지 않음 | 실제 GUI |

## 필수 실패·변이

파일 어댑터는 read/write/flush/rename 단계의 실패/짧은 쓰기/읽기 시 파일 변경을 주입할 수 있는 작은 경계로 둔다. 성공 경로만 흉내낸 가짜 파일 시스템으로 실제 파일 검사를 대체하지 않는다. 강제 종료 시험은 테스트 전용 자식 프로세스만 대상으로 하고 사용자 편집기/게임 프로세스를 종료하지 않는다.

변이 최소: (1) 은행을 직접 truncate-write, (2) pending 검증 생략, (3) checksum 생략, (4) restore에서 초기 stock 재지급, (5) live 서비스부터 close 후 후보 검증, (6) 미래 schema/content 허용, (7) 이전 epoch UI 요청 허용. 각 변이를 해당 수락 검사가 검출해야 한다. 문법 오류·runner 자체 중단을 논리 결함 검출 증거로 세지 않는다(수명 충돌은 실제 runtime 실패로 별도 기록).

Snapshot/총량/신호/파일 바이트를 테스트가 독립 계산해 비교한다. 파일에 total 필드를 추가해 같은 값을 서로 확인하는 검사나 production의 재계산을 그대로 복사하지 않는다. hash를 바꾸지 않은 손상과 hash를 다시 계산한 구조 오류를 모두 검사하여 checksum과 도메인 검증이 각각 작동하는지 확인한다.

## 실제 GUI 절차

1. SaveLoadTest에서 이동·방향 변경, wood 채집·store 이동·berry 완전 소진. F5 저장 세대 표시 확인.
2. 추가 채집/이동 후 F9로 이전 저장 위치/방향·bag/store·잔량·소진을 복원. 이후 E와 보관함 전송 정상, 수량/소진 보존.
3. 창을 닫고 다시 실행해 F9로 동일 파일 복원. 실제 저장 루트가 시험 네임스페이스임을 표시한다.
4. 두 번째 저장으로 A/B 최신·직전 세대 생성. 시험 fixture로 최신 손상 상태를 준비해 기본 Load는 복구 안내·현재 세계 보존, 복구본 버튼은 표시된 이전 세대로 복원. 제품 UI에 손상 버튼/임의 경로 입력을 추가하지 않는다.
5. 가방·살펴보기 중 F5/F9 거부, 닫은 뒤 정상. 키를 누른 채 복원·포커스 왕복해 유령 이동/채집/가방 열림 없음. 알림·복구 안내가 다른 UI를 가리지 않음.

IO 실패·미래 버전·강제 HUD 제거는 자동 검사 증거로 남기고 사용자가 직접 조작한 것처럼 기록하지 않는다. 새 기능 GUI 확인이 불가능하면 AC-S16을 미실행으로 남긴다.

## 구현 후 명령 후보(현재 파일 없음)

```sh
python3 tools/godot.py --headless --import
python3 tools/godot.py --headless --script res://tests/test_save_load.gd
python3 tools/godot.py --headless --script res://tests/test_save_load.gd -- --inject-failure
python3 tools/godot.py res://scenes/tests/save_load_test.tscn
python3 tools/run_ci.py
```

기본 runner는 고유한 시험 폴더를 생성하고 생성한 고정 파일만 정리한다. 실제 중단 fixture 실행/GUI 네임스페이스 옵션 이름은 구현 검증 보고에 명시한다. 원격 CI13단계가 될 것으로 예상하지만 실제 목록·마커·Python 등록 테스트를 기준으로 판정한다.

IH-112-VALIDATION.md는 구현 때 생성한다. AC별 pass/fail/미실행, 명령/exit/로그, 실패 전후 바이트/상태, 반복/변이, 실제 FS·프로세스 중단 관찰, GUI 주체/SHA, 차이·제약, PR/CI/merge를 기록한다. 모든 수락 조건·리뷰·필수 CI·develop 통합 후 done을 판정한다. 설계 ready나 단순 import는 구현 완료 증거가 아니다.
