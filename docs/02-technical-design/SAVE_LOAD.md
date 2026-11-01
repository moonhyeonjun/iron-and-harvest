# IH-112 초기 저장·복원 구현 명세

상태: **구현·검증 완료 / IH-112 done / ADR-017 Accepted** (2026-11-01). AC-S01~15 자동529검사·독립 진단5종, AC-S16 사용자 GUI 확인과 PR/develop CI 성공을 근거로 판정했다. [검증 기록](../03-development/IH-112-VALIDATION.md), [수락 조건](../03-development/IH-112-ACCEPTANCE.md), [완료된 인수인계](../03-development/IH-112-HANDOFF.md), [ADR-017](../04-decisions/ADR/ADR-017-versioned-save-restore.md)을 따른다. 아래 최초 설계의 Proposed 수치/제품 경로/장기 확장과 실제 구현 차이를 구분한다. Codex는 설계·검증, Claude Code는 구현을 맡는다. Godot4.7.2 Standard/GDScript/Compatibility 유지.

## 목적·범위

채집·보관함 이동·이동 후 수동 저장 → 종료 → 다시 실행하여 불러오기 → 위치/방향/가방/보관함/부분 소진·완전 소진 지점이 같은 상태 → 계속 채집. 읽기·쓰기 실패에는 명시 오류를 보이고 현재 플레이와 직전 유효 저장을 보존한다.

포함: 단일 수동 슬롯, A/B 두 세대, JSON codec/검증, 초기 schema1, 메모리와 실제 파일 왕복, 손상/미래 버전 거부, 명시 복구본 선택, 새 세션 교체. 제외: 자동/종료 저장·슬롯 선택/삭제·Steam Cloud·암호화·변조 방지·농사/달력/NPC/왕조·다른 맵 이동·멀티프로세스 동시 쓰기. 미구현 상태를 빈 구조로 저장하지 않는다. v0.3.0 태그/출시 판정은 별도다.

## 현재 코드에서 필요한 변화

- InventoryService.snapshot/register_snapshot은 독립 값과 새 재고 등록을 지원하지만 JSON의 float를 직접 받으면 정수 필드 검증에 실패한다. 파일 어댑터에서 검사 후 int로 정규화한다. live 재고 덮어쓰기/수량 재지급은 금지한다.
- GatherService.build는 항상 초기 stock을 생성한다. 복원에 그대로 호출하거나 build 뒤 live stock을 수정하지 않는다. **restore 팩토리**가 저장된 모든 재고를 한 번씩 등록하고 기존 stock에 결속한다.
- GatheringTest._ready는 매번 새 게임을 만든다. 복원 bundle을 트리 진입 전에 주입하고 초기화 모드를 구분해야 한다. 기존 맵/테스트의 NEW 동작과 기본 Foundation 진입점은 보존한다.
- Player는 방향 getter만 있다. 복원용 최소 API가 필요하다. 저장된 유효 위치/방향 적용, velocity=0/IDLE, Visual 준비 전 호출 안전, 이동 키 중립 복구를 담당한다. 이동 속도/물리 정책은 변경하지 않는다.
- 모달의 기존 이동 bool 게이트에 세 번째 작성자를 추가하지 않는다. 아래 세션 조율자가 월드 처리/요청을 잠시 정지하고 기존 게이트 소유권은 그대로 둔다.

## 논리 슬롯과 A/B 파일

제품 제안 경로는 `user://saves/slot_01.a.json`, `slot_01.b.json`이다. 하나의 UI 슬롯에 최신/직전 세대가 있다. 각 파일의 검증된 generation으로 순서를 판단하며 mtime/파일 이름 순서로 최신을 결정하지 않는다. 최초 저장 generation1은 A, 그 뒤 B2/A3/B4 식으로 **더 오래된 은행 파일**만 교체한다. 새 파일이 실패해도 다른 은행의 유효본은 남는다. 별도 최신 포인터 파일은 없다.

파일 작업은 앱 소유 고정 이름에만 한다. 슬롯 ID/경로를 세이브 본문이나 UI 문자열로 받지 않는다. 임시 파일은 같은 디렉터리의 `slot_01.a.pending`/`b.pending`; 기존 잔재가 있으면 앱 소유 경로만 덮어쓸 수 있고 읽기 시에는 항상 무시한다. 재귀 삭제·디렉터리 전체 정리 금지. 한 저장 루트에 writer1개만 지원하며 다중 실행 동시 쓰기는 지원하지 않는다.

Load는 없는 디렉터리를 새로 만들지 않고 NO_SAVE를 반환한다. Save는 고정 루트 디렉터리를 만들 수 있으며 생성/열기 오류를 IO_ERROR로 보고한다.

테스트는 주입된 전용 `user://tests/ih112/<run_id>/` 아래에서만 실행하고 기본 saves 경로를 만지지 않는다. 실제 GUI 테스트도 제품 슬롯과 구별된 고정 시험 네임스페이스를 표시한다. root 경로 주입은 구성/테스트 전용이며 세이브 내용으로 결정하지 않는다.

### 파일 선택·복구 정책

| A/B 상태 | 기본 불러오기 | 복구본 불러오기 | 다음 저장 대상 |
|---|---|---|---|
| 둘 다 없음 | NO_SAVE | 없음 | A1 |
| 유효1 + 없음1 | 유효본 | 없음 | 빈 은행, generation+1 |
| 유효2, 세대 다름 | 큰 generation | 작은 generation(사용자가 명시 선택) | 작은 generation 은행, max+1 |
| 유효1 + 손상1 | RECOVERY_AVAILABLE, 세계 불변 | 유효본(사용자가 명시 선택) | 손상 은행, 유효 generation+1 |
| 둘 다 손상 | CORRUPT_SAVE, 세계 불변 | 없음 | CORRUPT_SAVE로 거부, 파일 보존 |
| 둘 다 같은 세대·같은 payload | A를 동일본으로 선택 | 없음 | B, generation+1 |
| 같은 세대·다른 payload | AMBIGUOUS_SAVE로 거부 | 없음 | 거부, 파일 보존 |
| 어느 한쪽이라도 검증 가능한 미래 schema/미지원 content | INCOMPATIBLE_SAVE, 파일/세계 보존 | 이번 버전에서는 자동/명시 우회 없음 | 거부, 파일 보존 |
| 읽기 권한 오류 등 상태 판별 불가 | IO_ERROR, 세계 보존 | 없음 | 거부, 파일 보존 |

복구본 선택은 UI에 세대와 이전 진행으로 돌아갈 수 있음을 표시한다. 성공해도 파일을 자동 수정하지 않는다. 다음 수동 저장은 위 표대로 현재 복구된 세계를 더 큰 generation으로 저장한다. 최신본에서만 했던 행동은 되돌아가지만 복구한 세계의 수량은 보존되어야 한다. 두 손상 파일의 삭제/외부 보관은 별도 관리 범위이며 조용히 새 게임으로 덮어쓰지 않는다.

## wire 형식과 수치 정책

파일은 UTF-8 JSON이다. envelope 정확한 키는 format/payload_json/sha256이고 format=`iron-and-harvest-save`다. payload_json은 **JSON 문자열 자체**이며 sha256은 그 문자열 UTF-8 바이트의 SHA-256 소문자64자리다. 문자열의 원본 바이트를 검증하므로 parse→재직렬화에 따른 숫자/키 순서 차이로 hash가 달라지지 않는다. checksum은 우발 손상 검출용이며 편집·치팅 방지 수단이 아니다.

payload의 필수 키는 아래 표와 같고 알 수 없는 키는 v1에서 거부한다. 표시명/Resource 경로/NodePath를 저장하지 않는다.

| 필드 | v1 계약 |
|---|---|
| schema_version | 정수값1. 저장 어댑터 구조 버전 |
| content_version | 정수값1. 현 fixture 품목/지도/결속 계약 버전; schema와 독립 |
| generation | 정수값1..9007199254740991, 파일 commit 순번 |
| map_id | `gathering_test`만 허용. 로컬의 신뢰된 맵 팩토리로 해석 |
| player | 정확히 player_id=`player_01`, inventory_id=`player_bag`, position={x,y}, facing=`up/down/left/right` |
| inventories | bag/store/숨은 stock 전체5개, ID로 정렬한 snapshot 배열. 중복/누락/추가 거부 |
| points | point_id/map_id/definition_id/stock_inventory_id의 결속3개, point_id 정렬 |

JSON 밖의 내부 snapshot은 IH-110과 동일하다. capacity/quantity/schema/content/generation/revision은 **bool 제외**, finite·정수값·범위 검사 후 int 변환한다. JSON number 1과1.0은 같은 정수값으로 허용하며 소스 리터럴의 구분을 약속하지 않는다. 소수1.5/문자열"1"/null/NaN/INF/범위 밖 값은 거부한다. revision은0..9007199254740991. 더 큰 내부 revision도 조용히 반올림하지 않고 저장 NUMBER_OUT_OF_RANGE로 거부한다. 최댓값 generation에서는 다음 저장을 거부한다. 이 제한은 SaveCodec 범위이며 InventoryService의 기존 정수 계약을 축소하지 않는다.

position x/y는 finite int/float만 허용하며 bool/문자열 금지. 신뢰된 맵의 1280×720 영역 안인지 먼저 검사하고 아래 실제 플레이어 발 충돌 검사도 통과해야 한다. 위치를 반올림/안전 위치로 자동 이동하지 않는다. full_precision을 사용하고 왕복 허용 오차는0.0001월드 단위 이하로 검증한다. 방향은 enum 숫자 대신 문자열로 저장한다.

정규화 후 InventoryService.decode_snapshot/register_snapshot의 기존 키/ID/슬롯 길이/스택 검사를 통과해야 한다. bag/store capacity12·owner player_01/fixture_store_01 및 기존 결속3개의 stock ID/owner/capacity1을 로컬 manifest와 비교한다. stock은 품목 일치·빈 슬롯 또는1..초기량이며 잔량0은 null 슬롯이다. revision은 저장 값을 유지한다. remaining/depleted는 별도로 저장하지 않는다. 가방 수량을 소진량으로 재계산하지 않는다.

points는 신뢰된 현재 결속과 정확히 같아야 하며 저장 파일이 다른 재고를 stock으로 지정할 수 없다. 알려지지 않은 품목/맵/정의/인벤토리·삭제된 콘텐츠는 CONTENT_MISMATCH다. 원본 정의의 수량/품목/지도 충돌 변경 시 content_version을 올리고 이관 정책을 별도 작성한다. 세이브에 정의를 넣어 현재 콘텐츠 검증을 우회하지 않는다.

저장하지 않는 값: velocity/보행 상태·카메라 위치·선택/프롬프트·모달 상태·준비 명령·request/session ID·입력 큐·WeakRef·서비스 busy·테스트 rebind 보고·fixture 표시. 로드 후 속도0/IDLE, 카메라는 복원 위치를 보고, 모든 패널은 닫혀 있다. 초기 normal/full 재고는 새 게임 fixture일 뿐 로드에 다시 적용하지 않는다. 시험 화면은 로드 후 “저장 복원” 상태를 표시해 초기 fixture 이름을 복원 데이터로 오인하게 하지 않는다.

### 구현 fixture와 migration

정상 v1 파일 fixture는 bag/store/stock5개를 실제 기록하고 부분 소진/완전 소진을 모두 포함한다. 예: berry stock=null·revision3, branch5·revision1, bag/store에 이동된 수량. 문서의 생략 기호가 포함된 JSON을 검증 fixture로 쓰지 않는다.

지원 schema는 현재1과 **테스트 전용 schema0**이다. v0는 v1과 같은 payload에서 player.facing만 없으며 0→1 migration은 facing=`down`을 추가하고 schema만1로 바꾼다. 모든 수량/슬롯/revision/generation은 유지한다. 실제 출시된 구버전 저장이 존재한다는 뜻이 아니다. 미래 schema2+, 음수/미지원 구버전, content_version≠1은 명시 거부한다. migration은 독립 사본에만 실행하고 원본 파일을 읽기 과정에서 고치지 않는다. 이후 수동 저장은 v1으로 기록한다.

## 저장 트랜잭션

SaveCoordinator 상태: IDLE→CAPTURING→WRITING→IDLE. 시작부터 완료 신호 처리까지 busy를 유지한다. 콜백의 중첩 save/load는 BUSY로 거부하며 다음 프레임 요청으로 남기지 않는다.

1. 정상 포커스·세션 생존, InventoryController CLOSED, Interaction 완전 quiescent, Gather pending/busy 없음, Inventory busy 없음을 확인한다. 모달을 닫거나 진행 중 채집을 취소해서 저장 가능 상태를 만들지 않는다.
2. 세션 요청/처리를 잠시 정지하고 같은 조건·수명을 재검증한다. 단일 메인 스레드에서 await/신호 없이 위치/방향/결속/모든 재고 사본을 캡처한다. 이 시점이 저장할 세계다. 캡처 뒤 파일 I/O 중에는 월드를 재개할 수 있으나 저장 결과가 이후 행동을 포함한다고 표시하지 않는다.
3. 기존 A/B를 읽고 완전 검증·migration/호환 분류한다. 위 표대로 대상/generation 결정. 인코딩 결과를 먼저 검증한다.
4. 대상과 같은 디렉터리 pending 파일만 WRITE로 열고 전체 바이트를 쓴다. 쓰기 오류/길이와 flush 후 오류 상태를 확인하고 close한다. close는 반환값이 없으므로 재열기 검증으로 완료 상태를 확인한다. **유효 은행 파일을 WRITE로 열지 않는다.**
5. pending을 다시 열어 길이/원본 바이트 일치, checksum/codec/콘텐츠를 검증한다. 실패하면 은행 파일은 그대로이며 성공 보고를 하지 않는다.
6. 선택 때 읽은 A/B 바이트 지문과 현재 파일 상태가 같은지 확인하고 coordinator의 취소/수명 래치를 rename 직전에 재검사한다. 달라졌으면 FILE_CHANGED로 거부한다. 이는 오인 덮어쓰기 감소용이며 다중 프로세스 잠금을 대신하지 않는다.
7. pending→대상 은행을 동일 디렉터리 rename으로 교체한다. 사전에 대상 은행을 삭제하지 않는다. rename OK가 **파일 commit 경계**다. 그 뒤 UI/포커스/호스트 제거는 이미 저장된 파일을 실패/취소로 되돌리지 않는다. 완료 표시는 살아 있는 UI에만 한다.

rename 직전까지 실패하면 두 기존 은행 바이트가 동일해야 한다. rename 성공 뒤 후속 진단 읽기 실패는 저장 실패로 재시도하지 않고 성공+진단 경고로 처리한다. rename 반환 실패인데 대상이 바뀐 등 결과를 확정할 수 없는 어댑터 오류는 COMMIT_UNCERTAIN이며 자동 재시도 금지·다음 검사로 확인한다. 임시 파일 정리 실패는 별도 진단이며 유효 은행을 삭제하지 않는다.

프로세스 강제 종료 시험: pending 작성 중/검증 후/rename 직전에는 이전 최신본이 로드 가능, rename 후에는 새 세대가 선택 가능해야 한다. flush/rename만으로 모든 OS의 전원 차단·디렉터리 메타데이터 내구성을 보장했다고 기록하지 않는다. macOS 실제 파일 시스템과 Linux CI의 종료/재시작 검증을 수행하고 Windows·전원 차단 검증은 별도 남긴다.

## 복원 트랜잭션과 새 세션

상태: IDLE→READING→VALIDATING→STAGING→PUBLISHING→IDLE. 작업마다 operation_id, 세션마다 단조 증가 runtime_epoch를 사용한다. 둘 다 파일에 저장하지 않는다. 모달/채집 중에는 BUSY이며 현재 패널/명령을 임의 취소하지 않는다.

미래 schema/content 분류는 checksum과 payload 기본 타입을 확인한 직후, v1 전용 키/구조 검사보다 먼저 한다. 이후 버전의 추가 필드를 단순 손상으로 취급해 덮어쓰지 않는다.

1. 시작 조건 확인 후 현재 월드의 입력/명령을 suspend한다. SaveUI는 월드 밖에 둔다. SceneTree 전체 pause나 Player bool 게이트의 추가 소유자는 만들지 않는다. 이전 process_mode를 보관하고 **Player의 ALWAYS 모드도 포함해 각 런타임 노드를 명시적으로 정지**한다. 지연 UI 의도는 session_suspended/epoch 검사로 거부한다.
2. A/B 선택 파일을 읽어 checksum→JSON→schema/migration→숫자 정규화→키/ID/콘텐츠 검증. 오류 시 현재 세션 인스턴스/위치/재고/잔량/revision은 그대로이며 suspend만 해제한다. 입력을 재생하지 않는다.
3. GatherService.restore(...)는 새 InventoryService에 저장 재고5개를 **한 번씩** register_snapshot한다. 메타데이터 검증은 기존 bag/store와 stock 사이 역할을 구분한다. 이미 등록된 stock을 중복 ID라고 거부하거나 초기 stock으로 재등록하지 않는다. 같은 정의 검증 로직은 build와 공유하되 NEW와 RESTORE 초기 지급 경로는 명시 분리한다. 모든 stock 무결성 검사 후 새 컨텍스트를 반환하고 실패 시 전부 폐기한다. 수량 변경/획득 이벤트는 발생하지 않는다.
4. 후보 월드 인스턴스에 restore bundle/epoch/inactive 부팅 모드를 **트리 진입 전** 주입한다. 새 게임 초기 지급 없이 bootstrap한다. 모든 입력/처리·카메라를 비활성, 뷰는 숨김으로 준비한다. 노드·UI·전체 Target ID/결속·참조를 검수하고 명시 bootstrap_result를 확인한다.
5. 같은 고정 맵의 정적 월드에서 물리 동기화 후 플레이어 발의 실제 CircleShape(radius6, mask1/body만)로 저장 위치가 벽/영역 밖에 겹치지 않는지 검사한다. 후보 Player 자신은 제외한다. 영역 내부여도 충돌이면 INVALID_POSITION, 자동 보정 금지. 후보를 준비하는 동안 기존 월드는 정지된 상태로 유지한다. 카메라가 먼저 활성화되거나 새 지점이 초기 지급되지 않아야 한다.
6. publish 직전 operation/epoch·포커스·호스트·후보/현재 월드 수명을 다시 검사한다. 사전 실패는 후보 services.close/노드 정리 후, 기존 호스트가 살아 있으면 이전 월드/처리 모드를 복구한다. 현재 월드 서비스를 먼저 닫지 않는다. 호스트 자체가 종료됐다면 월드를 되살리지 않고 정상 소유권 해제·서비스 종료·후보 정리만 수행한다.
7. await/공개 완료 신호 없이 runtime_epoch 증가→현재 컨텍스트/월드 참조를 후보로 교체→기존 서비스 close/기존 월드 분리→새 뷰/카메라/요청 활성 순서로 publish한다. 기존 컨텍스트는 다시 사용하지 않는다. 외부 알림은 commit 뒤1회이며 이미 교체된 세계를 성공 후 콜백 취소로 rollback하지 않는다.
8. 새 Player 속도0/방향/위치·Visual IDLE·카메라 위치를 적용하고 모든 키가 한 번 해제된 뒤 새 입력만 받는다. 이전 UI session ID와 새 ID가 우연히 같아도 이전 epoch의 지연 요청은 새 서비스에 도달하지 않는다. 옛 GatherCommand는 CLOSED/INVALID_COMMAND, 옛 InventoryService 쓰기는 CLOSED다.

후보와 이전 월드가 물리 공간에 잠시 함께 있어도 입력/선택/모니터링으로 상호 참조하지 않게 한다. 구체 staging 연결은 구현 검증 기록에 남긴다. 기존 Scene의 ready가 활성화를 강제한다면 최소 bootstrap 옵션으로 바꾸며, 사후에 live 서비스를 바꿔 끼우는 우회는 금지한다. 실패한 후보의 오류를 숨겨 계속 진행하지 않는다.

포커스 상실/취소/호스트 제거는 publish 전에는 취소 래치를 유지한다(복귀해도 자동 재개 금지). publish 후에는 현재 복원 결과를 보존하고 기존 포커스 정책을 적용한다. 이전 월드 해제 알림·UI 완료 콜백에서 재진입한 요청은 epoch/busy로 막는다. UI 삭제는 이미 완료된 저장/복원을 되돌리지 않고 표시만 생략한다.

## API·모듈·UI 제안

| 신규 후보(game/ 기준) | 책임 |
|---|---|
| systems/save/save_codec.gd | 순수 값↔envelope/payload, checksum, 정규화·키/버전·migration; Node/파일 접근 없음 |
| systems/save/save_store.gd | A/B 선택·유한 파일 작업·검증 후 rename·결과, 작은 주입 가능한 파일 어댑터 |
| scripts/save/save_coordinator.gd | busy/operation/epoch, 안정 시점 capture, stage/publish·수명·입력 조율 |
| scripts/save/session_bootstrap.gd | NEW/RESTORE의 최소 공유 초기화·후보 검수; 필요 시 작은 기존 맵 코드 추출 |
| scenes/tests/save_load_test.tscn, scripts/tests/save_load_test.gd | Gathering 맵·서비스·UI 재사용, SaveUI와 교체 가능한 SessionHost |
| ui/save/* | 저장/불러오기/복구본 버튼·상태, 표시·의도만 |
| tests/test_save_load.gd, tests/fixtures/save/* | 실제 파일·상태 왕복·실패·migration·입력·수명·복구 검증 |

작은 결과/값 클래스는 해당 파일 내부에 둘 수 있다. SaveStore API 후보 inspect_slot/save/load(source=latest|recovery), Codec encode/decode/migrate, Coordinator request_save/request_load다. 결과는 ok/code/detail/source_bank/generation/committed/recovered/operation_id 등 독립 값이며 내부 context는 외부 UI로 노출하지 않는다.

기존 파일 수정 후보: GatherService.restore와 결속 사본 exporter, InventoryService.is_busy 읽기 getter, InteractionController.is_quiescent 읽기 getter/일시 suspend, InventoryController의 세션 suspend 요청 가드, Player 복원/중립 입력 API, GatheringTest의 inactive/restore bootstrap, project.godot 입력2개, 공통 CI 등록·검사/문서. 기존 입력/서비스 거래는 보존한다. 범용 Autoload/잠금·직렬화 프레임워크를 만들지 않는다.

검증 맵은 외부 SaveLoadTest→SessionHost→현재 World(Gathering 맵)와 SaveUI로 구성한다. SaveUI는 월드 교체 뒤에도 살아 있다. 입력 제안 save_game=물리F5, load_game=물리F9(새 누름/echo 무시), 복구본은 버튼만. 저장/로드 중에는 버튼 비활성·중복 요청 BUSY. 가방/살펴보기 중 F5/F9는 BUSY 안내만 하고 기존 패널/게이트를 유지한다. 정상 저장/복원은 비모달 결과 안내, 실패는 짧은 원인과 다음 행동을 표시한다. 전체 에러/파일 경로는 진단 로그에 둔다.

오류 최소: BUSY, NO_SAVE, IO_ERROR, FILE_CHANGED, CORRUPT_SAVE, CHECKSUM_MISMATCH, INVALID_SAVE, NUMBER_OUT_OF_RANGE, UNSUPPORTED_SCHEMA, CONTENT_MISMATCH, INCOMPATIBLE_SAVE, INVALID_POSITION, RECOVERY_AVAILABLE, AMBIGUOUS_SAVE, CANCELLED, REMOVED, COMMIT_UNCERTAIN. UI 분류와 원래 진단 code를 함께 보존한다. 파일 없음·손상·버전 불일치를 같은 '새 게임'으로 처리하지 않는다.

## 구현·검증 관문과 근거

최대 파일1MiB를 **읽기 전에** 검사하며 payload 길이·배열/문자열 길이·정확한5재고/3결속도 제한한다. 임의 Object/Resource 복원, str_to_var/bytes_to_var의 객체 허용, 세이브가 지정한 스크립트/씬 실행은 사용하지 않는다. JSON.parse 결과 타입을 검증한다. Godot JSON parser의 허용 문법(예: trailing comma)을 엄격 표준 파서라고 주장하지 않으며 별도 범용 JSON 파서를 작성하지 않는다. 유효 파싱 뒤에도 도메인 검증은 필수다.

[AC-S01~16](../03-development/IH-112-ACCEPTANCE.md), 기존360/333/521/347 회귀·실패 주입·변이·실제 GUI·필수 PR CI가 구현 완료 관문이다. 저장 검사는 game/tests/test_save_load.gd 및 공통 CI에 구현됐다. 제품 경로·슬롯 수·수치/키·파일 레이아웃은 Proposed이며 실제 엔진/OS 측정으로 보완하고 ADR에 차이를 기록한다.

공식 API 확인(2026-11-01): [JSON](https://docs.godotengine.org/en/stable/classes/class_json.html)은 숫자 변환·parse 오류·full_precision/비유한 값 제한의 근거, [FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)는 user 파일 I/O·flush/close, [DirAccess](https://docs.godotengine.org/en/stable/classes/class_diraccess.html)는 rename 오류/기존 대상 교체의 근거다. 이 문서의 A/B 프로토콜·실패/복구 정책은 프로젝트 설계 제안이며 공식 API가 crash/power-loss 보장을 제공한다는 뜻이 아니다. 실제4.7.2에서 구현·회귀로 확인한다.

## 구현 결과·차이 (2026-11-01, Claude Code)

- **모듈**: `systems/save/`(SaveCodec, SaveStore, SaveFileAdapter), `scripts/save/save_coordinator.gd`, `ui/save/`, `scenes/tests/save_load_test.tscn`.
  - session_bootstrap.gd는 만들지 않았다. NEW/RESTORE 분기와 후보 검수는 gathering 맵의 최소 훅에 있다(`restore_context`, `start_inactive`, `activate`, `save_blocker`, `capture_payload`, static `save_manifest`/`restore_session`).
- **4.7.2 측정**
  - JSON 숫자는 모두 float(2^53까지 정확)다. `1e400`은 inf와 엔진 경고, trailing comma는 허용, 중복 키는 마지막 값이 남는다.
  - full_precision 실수를 다시 읽으면 마지막 자리가 바뀔 수 있다. 그래서 encode 왕복 검사에서 위치만 0.0001을 허용한다.
  - 잘못된 UTF-8은 엔진이 대체 문자로 바꾸며 메시지를 낸다. 그래서 codec이 먼저 엄격한 UTF-8 검사를 한다.
  - rename은 같은 디렉터리의 기존 대상을 교체한다. flush는 fsync가 아니다.
  - `OS.kill`은 waitpid까지 한다.
  - PAUSABLE Player는 DISABLED 부모 아래에서도 처리된다.
  - DISABLED body/area는 물리에서 빠지며, 다시 들어오면 감지 후보가 한 틱 비어 있다.
- **상태표 보완**
  - 손상+없음은 CORRUPT_SAVE이며 불러오기와 저장을 모두 거부한다.
  - checksum이 맞는 CONTENT_MISMATCH는 INCOMPATIBLE로 분류해 보존한다.
- **suspend**
  - 명시 process_mode를 가진 모든 노드(Player 포함)를 각각 DISABLED로 둔다.
  - live 월드는 물리를 KEEP_ACTIVE로 유지한다(실패 후 선택 상태 보존). 후보는 물리에서 빼고 WorldCollision만 ALWAYS로 둔다.
  - 이동 게이트, 패널, interaction 상태는 건드리지 않는다.
  - 저장 capture와 파일 I/O는 동기 단일 호출이므로 저장 중에는 월드를 정지하지 않는다.
- **추가 코드**: STALE_SESSION, BOOTSTRAP_FAILED, NOT_READY, NO_RECOVERY, FOCUS_LOST. 결과를 보고하는 중에 들어온 요청은 반환값으로만 거부한다(재귀 방지).
- **키**: F5/F9는 새 누름만 받고 한 프레임에 요청 1회다. GUI 루트는 `user://tests/ih112/gui`다. `--save-root=`는 `user://tests/ih112/` 접두사만 허용한다. `--fixture=corrupt-latest`는 시험 전용이다.
- **내구성**: 프로세스 중단 회복은 macOS 실제 FS와 Linux CI에서 검증 대상이다. 전원 차단, Windows, 다중 writer는 미검증·미지원이다.

### BUG-009~011 수정에 따른 차이 (2026-11-01)

- **키 요청 정책**: F5/F9는 장면이 받는 실제 입력이므로 coordinator의 현재 epoch를 쓴다. SaveUI가 없어도 동작하며 결과 표시만 생략한다. coordinator가 없으면 무시한다. 버튼 의도는 UI의 epoch를 쓰므로, 이전 epoch 버튼 의도는 계속 STALE_SESSION이다.
- **보고 중 BUSY**: 완료와 시작 전 거부 모두, 결과를 보고하는 동안의 새 save/load는 BUSY다.
- **세션 정지 경계**: process_mode는 직접 호출과 call_deferred를 막지 않는다. 그래서 조율자가 로드 동안 `set_session_suspended`로 세션을 표시하고, InventoryController의 open/view/전송 진입이 이를 확인한다. 후보는 publish 전까지 정지 상태다. 강제 닫기, 게이트 소유자 추가, 전역 잠금은 없다.

## IH-120 후속 schema2 설계 (미구현)

현재 Accepted IH-112 계약/코드는 schema1·시험0이다. [CALENDAR](CALENDAR.md#6-저장-schema2와-구버전-이관)는 schema2 필수 calendar·0→1→2 검증 이관·기존 파일 보존·미래3+ 분리를 제안한다. 규칙 프로필/content1·새 컨텍스트/실패 복귀·선택적 clock blocker와 기존 fixture의 보존을 함께 검증해야 한다. 이 절은 현재 schema2 지원 완료를 뜻하지 않으며 실제 구현 차이/검증 후 지원 상태를 갱신한다.

## IH-120 schema2 (2026-11-02)

- 현재 schema는 2이며, 필수 `calendar`는 manifest 프로필의 rule_id/day_index/tick_in_day/revision이다. content는 1이다.
- v0 → 1(facing) → v1 전체 검증 → 2(기본 달력 0/0/0) 순서로 메모리에서만 이관한다. 파일은 쓰지 않는다.
- schema3 이상은 UNSUPPORTED다. IH-112의 schema2_future fixture는 보존하되 이제 calendar 누락으로 INVALID_SAVE다. 새 미래 fixture는 schema3_future다.
- 자세한 내용은 [CALENDAR](CALENDAR.md)와 [IH-120 검증](../03-development/IH-120-VALIDATION.md)에 있다.
