# IH-112 초기 저장·복원 검증 — 2026-11-01

## 결론

Claude Code가 [SAVE_LOAD 명세](../02-technical-design/SAVE_LOAD.md)에 따라 다음을 구현했다.
- 단일 수동 슬롯의 A/B 두 세대
- 버전 payload JSON 문자열 + SHA-256 envelope
- 숫자 정규화와 manifest 대조
- schema1과 시험 v0 이관
- pending 작성 → flush/close → 재읽기 검증 → rename commit
- 초기 지급 없는 `GatherService.restore`
- inactive 후보 월드 검증 뒤 publish, epoch 차단
- SaveLoadTest(F5/F9, 명시 복구 버튼)

자동 검증 결과는 다음과 같다.
- AC-S01~15: 425검사 PASS(2회 반복 차이 0, 고아 0, 엔진 오류 0)
- 실패 주입과 필수 변이 7종: 모두 검출
- 별도 프로세스 재시작과 단계별 SIGKILL: 확인
- 깨끗한 worktree 공통 CI: 13단계 PASS. 기존 이동 360, 상호작용 333, 인벤토리 521, 채집 347검사가 그대로 통과했다.

AC-S16 GUI는 **부분 확인**이다. 사용자가 실제 창에서 절차 1~5를 확인했다. 절차 6(최신 세대 손상 → 기본 불러오기 거부 → 복구본)은 사용자 GUI에서 확인되지 않았다. 사용자가 이후 사용자 테스트를 진행하지 않기로 했으므로 미실행으로 남긴다. 그래서 IH-112 상태는 **review**다. 필수 PR CI와 develop 통합 뒤에도 AC-S16 미완료가 남는다. ADR-017은 **Proposed**를 유지한다.

자동 저장, 종료 저장, 슬롯 선택/삭제, Cloud, 암호화, 농사, 달력, NPC, 다른 맵 이동은 구현하지 않았다. 수치, 경로, 파일 레이아웃은 검증용 제안이다.

## 환경·대상

- 로컬: macOS 13.4(Apple M1, APFS), Godot 4.7.2 stable official Standard, Compatibility.
- 원격: Ubuntu 24.04 CI(통합 기록 참조).
- 시험 파일 위치:
  - runner: 실행마다 `user://tests/ih112/runner_<pid>_<usec>/`. 끝나면 자신이 만든 고정 이름 파일(`slot_01.{a,b}.json/.pending`, `child.out(.ready)`)과 빈 폴더만 지운다(1회 122개).
  - GUI: `user://tests/ih112/gui`.
  - 제품 `user://saves`: 생성·접근하지 않았다(실행 후 존재하지 않음 확인).
- 시험 세계: IH-111 gathering 맵의 normal fixture를 새 게임으로 시작한다. 재고 5개(bag, store, stock 3)와 결속 3개.

## 구현 파일

| 파일 | 내용 |
|---|---|
| `systems/save/save_codec.gd` | envelope 처리, checksum, 엄격한 UTF-8 검사, 숫자 정규화(bool 금지, 유한, 정수, 0..2^53-1), manifest 대조, 버전 우선 분류, v0→v1 이관 |
| `systems/save/save_file_adapter.gd` | 유일한 파일 접근점. 크기 제한 읽기, 전체 쓰기+flush 오류 검사, rename, 단일 파일 삭제 |
| `systems/save/save_store.gd` | A/B 상태표, 다음 대상과 세대 결정, pending 검증 뒤 rename, FILE_CHANGED/COMMIT_UNCERTAIN, 명시 복구 |
| `scripts/save/save_coordinator.gd` | 상태·operation·epoch 관리, 동기 capture, suspend/staging/위치 검사/publish, 실패 시 복귀 |
| `scenes/tests/save_load_test.tscn`, `scripts/tests/save_load_test.gd` | SessionHost(교체 월드), SaveCoordinator·SaveUI는 월드 밖. F5/F9, `--save-root=`(시험 접두사만), `--fixture=corrupt-latest` |
| `ui/save/save_ui.gd/.tscn` | 루트·세대·결과 표시, epoch가 붙은 의도만 발행. 버튼은 키보드 포커스 없음 |
| `tests/test_save_load.gd`, `tests/support/save_child.gd`, `tests/fixtures/save/*` | runner, 별도 프로세스, v1/v0/schema2/content2 fixture |

기존 파일 변경:
- GatherService: `restore`, `is_busy`, `export_bindings`. 공통 `_setup`으로 검증을 공유하고 `build`의 NEW 경로는 그대로다.
- InventoryService: `is_busy`.
- InteractionController: `is_quiescent`.
- PlayerController: `restore_state`.
- gathering 맵: RESTORE·inactive 부팅, `save_blocker`/`capture_payload`, static `save_manifest`/`restore_session`.
- 그 밖: `project.godot`의 `save_game`(F5)/`load_game`(F9), `run_ci.py` 등록, Python 등록 테스트, 디렉터리 README.

## 4.7.2 실제 측정(구현 전후 탐침)

- **JSON 숫자**
  - 모든 숫자가 float로 읽힌다. 2^53-1까지는 정확하다. `9007199254740993`은 …992로 바뀌므로 범위 검사로 거부한다.
  - `1e400`은 `inf`가 되며 엔진 경고 "Exponent too high"가 난다. runner는 INF 2사례 × 2회 = 4건을 기대값으로 세고, 그 밖의 경고·오류는 실패로 처리한다.
  - `NaN` 리터럴은 파싱 오류다. trailing comma(`[1,2,]`)는 허용된다. 중복 키는 마지막 값이 남는다. 그래서 파싱만으로는 아무것도 신뢰하지 않는다.
- **JSON 실수 왕복**: `full_precision` 출력을 다시 읽으면 마지막 자리가 바뀔 수 있다(228.12344360351563 → …565). encode의 왕복 검사는 위치만 0.0001 허용, 나머지는 완전 일치로 한다. Vector2는 float32다.
- **UTF-8**: `sha256_text`는 UTF-8 바이트 기준이다. 잘못된 UTF-8을 decode하면 엔진이 "Unicode parsing error"를 출력하고 문자를 대체한다. 그래서 decode 전에 직접 엄격한 UTF-8 검사를 한다.
- **파일**
  - `DirAccess.rename_absolute`는 같은 디렉터리의 기존 대상을 교체한다(macOS APFS 확인. Linux는 PR CI의 같은 runner로 확인). 대상 디렉터리가 없으면 실패한다.
  - `get_buffer(length)`로 정확한 길이를 읽으면 오류가 없다. 길이를 넘기면 EOF 오류다.
  - `FileAccess.flush()`는 OS에 넘길 뿐 fsync가 아니다.
- **프로세스**: `OS.kill`은 SIGKILL 뒤 waitpid까지 한다. 이후 `is_process_running`을 부르면 "not a child" 오류가 난다. runner는 kill 결과만 사용한다.
- **노드·물리**
  - PAUSABLE인 Player는 DISABLED 부모 아래에서도 처리된다. 그래서 명시 process_mode를 가진 모든 노드를 각각 정지한다.
  - DISABLED 노드의 body/area는 물리에서 제거된다(DISABLE_MODE_REMOVE). 같은 프레임에 제거와 재추가를 하면 Detector 후보가 한 틱 동안 비어, 그 사이 E가 NO_TARGET이 된다. 그래서 live 월드는 suspend 동안 KEEP_ACTIVE로 물리를 유지한다. 순서는 물리 모드 먼저, process_mode 나중이다. Player보다 자식 Detector가 먼저 제거되는 문제를 실제로 겪고 고쳤다.
  - 비활성 하위 트리의 Button은 클릭을 받지 않는다.
  - 새로 활성화된 Camera2D는 현재 카메라를 빼앗지 않는다. 그래도 후보 카메라는 publish 때까지 끈다.

## AC별 결과

| ID | 결과 | 측정·관찰 | 확인 주체 |
|---|---|---|---|
| AC-S01 | pass | 아래 정리 참조 | 자동 |
| AC-S02 | pass | 아래 정리 참조 | 자동 |
| AC-S03 | pass | 아래 정리 참조 | 자동 |
| AC-S04 | pass | 아래 정리 참조 | 자동(실제 입력) |
| AC-S05 | pass | 아래 정리 참조 | 자동(실제 파일+실패 어댑터) |
| AC-S06 | pass | 아래 정리 참조 | 자동(파일+장면) |
| AC-S07 | pass | 아래 정리 참조 | 자동 |
| AC-S08 | pass | 아래 정리 참조 | 자동(장면) |
| AC-S09 | pass | 아래 정리 참조 | 자동(물리+장면) |
| AC-S10 | pass | 아래 정리 참조 | 자동(단계 주입) |
| AC-S11 | pass | 아래 정리 참조 | 자동(콜백+입력) |
| AC-S12 | pass | 아래 정리 참조 | 자동(실제 Viewport 입력) |
| AC-S13 | pass | 아래 정리 참조 | 자동(macOS 실제 FS·별도 프로세스) |
| AC-S14 | pass | 아래 정리 참조 | 자동 |
| AC-S15 | pass | 아래 정리 참조 | 자동+로컬 CI |
| AC-S16 | **부분** | 아래 GUI 확인 참조. 절차 6은 사용자 GUI 미확인 | 사용자(1~5) |

**AC-S01 codec**
- v1 fixture가 정상 decode되고 envelope 키·형식이 맞는다. sha256은 payload_json 원문(envelope 안에서는 escape됨)의 해시와 같다.
- encode→decode 왕복이 일치한다(위치 오차 ≤ 0.0001).
- 비ASCII map_id에 맞는 해시를 붙이면 checksum은 통과하고 CONTENT_MISMATCH가 된다. UTF-16 바이트로 만든 해시는 CHECKSUM_MISMATCH다.
- 손상 입력 14종을 모두 value 없이 거부한다: 잘림, 빈 입력, 배열/null 루트, 키 누락/추가, 형식, 대문자 해시, payload_json 비문자열, payload만 변경(해시 유지), 해시를 다시 계산한 배열/잘린 payload, 1 MiB 초과, 잘못된 UTF-8.

**AC-S02 숫자**
- 30사례가 기대 코드와 일치한다.
- 허용: 1.0, 1, 0, 최대값(9007199254740991), 2.0, 12.0, 3.0. 결과는 int이며 기존 `decode_snapshot`을 통과한다.
- 거부:
  - INVALID_SAVE: true, 1.5, "1", null, 2.5, "3"
  - NUMBER_OUT_OF_RANGE: 0, 최대값+1, INF, -1, -2, 위치 -1, 위치 1281
- 위치: int는 허용하고, 문자열·bool·INF는 거부한다.
- NaN 텍스트는 INVALID_SAVE다.
- 내부 revision이 2^53이면 저장이 NUMBER_OUT_OF_RANGE로 거부되고 파일은 생기지 않는다.

**AC-S03 참조·콘텐츠**
- codec 18사례가 기대대로다.
  - 재고 누락·중복·추가, 결속 누락, payload 추가 키, remaining 필드: INVALID_SAVE
  - 미지 재고·품목·맵·정의, bag을 stock으로 연결, owner/capacity 변경, player ID: CONTENT_MISMATCH
  - stock의 다른 품목·초기량 초과: INVALID_SAVE
  - 수량 0 스택: NUMBER_OUT_OF_RANGE
  - 소진 null: OK
- `GatherService.restore`는 정상 fixture를 복원(berry 소진, branch 5)하고, 오염된 7종을 INVALID_SETUP·null로 거부한다.

**AC-S04 snapshot·정지 상태**
- capture는 live snapshot 5개, 위치, 방향, 결속과 같다. remaining은 담지 않는다. 사본을 고쳐도 live는 바뀌지 않는다.
- 다음 8상태에서 save/load가 모두 BUSY이고 상태는 그대로다:
  - 가방 OPEN(게이트 유지)
  - 살펴보기 ACTIVE(게이트 유지)
  - 준비된 명령(유지)
  - commit 신호 중(EXECUTING, inventory busy)
  - 완료 보고 중
  - E가 큐에 있음(큐 유지, 이후 정상 지급)
  - RESOLVING(probe try_begin)
  - 가방 OPENING
- 다시 정지 상태가 되면 1세대가 저장된다.

**AC-S05 파일 commit**
- 빈 슬롯에서 A1→B2→A3→B4로 저장된다. 매번 더 오래된 은행만 바뀌고 pending이 남지 않는다.
- 쓰기, flush, 짧은 쓰기, 재읽기 실패, 재읽기 불일치, rename 실패 6종은 IO_ERROR이며 두 은행 바이트가 그대로이고 pending은 지워진다.
- pending 검증 뒤 다른 은행이 바뀌면 FILE_CHANGED다(대상 불변).
- commit guard가 CANCELLED이면 은행은 그대로다.
- rename이 실패를 보고했지만 대상이 바뀐 경우는 COMMIT_UNCERTAIN이다. 재시도하지 않고, 다음 검사가 5세대를 본다.
- commit 뒤 진단 읽기 실패는 성공+경고다(6세대).
- 남은 pending은 읽을 때 무시하고 다음 저장이 교체한다(7세대).

**AC-S06 선택·복구**
- 상태표 11행이 모두 명세대로다: 없음, 유효+없음, 유효2(세대 다름), 유효+손상, 손상2, 손상+없음, 같은 세대 같은/다른 payload, 미래 schema, content 2, IO 오류.
- 읽기는 파일을 바꾸지 않는다.
- a가 mtime이 더 새로워도 세대가 큰 b를 고른다. pending b는 무시한다.
- 장면: 최신 은행 손상 상태에서 F9는 RECOVERY_AVAILABLE이고 세계는 같은 인스턴스·같은 상태로 남으며 UI가 복구를 안내한다. 명시 복구는 1세대(wood 8)를 불러오고 파일은 바뀌지 않는다. 다음 저장은 손상된 은행에 2세대로 쓴다.

**AC-S07 이관**
- v0는 facing=down, generation 2로 이관되고 슬롯·수량·revision이 v1 fixture와 같다. 불러오기는 파일을 바꾸지 않는다.
- 다음 저장은 v1(b3)으로 쓴다.
- 거부: schema 2/-1/99는 UNSUPPORTED_SCHEMA, content 2/0은 CONTENT_MISMATCH, facing이 있는 v0는 INVALID_SAVE.
- 미래 은행이 유효 은행 옆에 있으면 불러오기와 저장이 모두 거부되고 두 파일이 보존된다.

**AC-S08 새 컨텍스트**
- 채집, 산열매 소진, 보관함 이동 4개 뒤 저장했다. 이어 돌 2개를 더 채집한 뒤 불러왔다.
- 재고 5개가 저장본과 revision까지 같다. berry는 소진, branch 5, stone 4다. 이전 서비스는 닫혔다. 합계는 독립 기대값과 같다.
- 이후 채집과 이동이 정상이다(이벤트 2, revision +1/+2, stone 3).
- build NEW 경로는 6/4/3 그대로다.

**AC-S09 위치**
- (300.5, 410.25, left) 왕복 오차 ≤ 0.0001, 속도 0, IDLE, 카메라는 current이며 플레이어를 따른다.
- 왼쪽 벽 (8,360)과 블록 (632,360)은 INVALID_POSITION이다. 맵 밖 1290은 codec이 거부한다(손상+없음 → CORRUPT_SAVE).
- 세 경우 모두 이전 세계 인스턴스·상태·열린 서비스를 유지한다. 호스트 자식 1개, 텔레포트 없음, 이후 채집 정상.

**AC-S10 후보 실패**
- 결과 코드:
  - 포커스 out→in: FOCUS_LOST
  - before_publish에서 후보 queue_free: REMOVED
  - 중복 target ID 후보: BOOTSTRAP_FAILED
  - 닫힌 서비스: BOOTSTRAP_FAILED
  - restore 실패: INVALID_SAVE
  - 조율자 제거: REMOVED
- 위 경우 모두 이전 세계 그대로, 서비스 open, process_mode(INHERIT/PAUSABLE) 복구, interaction 활성, 후보 서비스 닫힘, 호스트 자식 1개, 이후 채집 정상이다.
- 호스트가 해제되면 REMOVED이고 되살리지 않으며 후보 서비스는 닫히고 늦은 호출은 없다.

**AC-S11 세션·재진입**
- 불러온 뒤 옛 GatherService·InventoryService 쓰기는 CLOSED, 옛 명령은 실패하며 새 세계는 바뀌지 않는다.
- 옛 InventoryUI가 session 1 의도를 보내면 옛 컨트롤러가 STALE_SESSION으로 처리하고 새 세계는 그대로다. 새 가방도 session 1을 받는다.
- 완료 신호 안의 save/load 4회는 모두 BUSY이며 다시 보고되지 않는다(재귀 없음).
- 옛 epoch의 UI save/load는 STALE_SESSION이다.
- rename 뒤 SaveUI 해제와 포커스 상실이 있어도 2세대 저장은 1회로 유지된다.
- publish 뒤 포커스 상실은 load를 되돌리지 않는다(epoch +1, 교체 1회).

**AC-S12 키·모달**
- F5 누름 + echo + 같은 프레임 두 번째 누름에서 저장은 1회다.
- 가방이 열렸을 때 F5/F9는 BUSY이고 가방과 게이트는 유지된다. 살펴보기 중 F9도 BUSY이고 패널은 유지된다.
- F9 직후 E/I를 누르고 D를 누른 채 있어도 publish 뒤 지급·가방·이동이 없다(D를 계속 누르는 동안 정지). 키를 놓고 새로 누르면 이동과 채집이 된다.
- 손상된 불러오기 뒤에는 제어와 interaction이 복구된다.

**AC-S13 재시작·중단**
- 자식 프로세스가 저장(1세대)하고 종료한 뒤, 다른 자식과 이 프로세스가 같은 세계를 불러온다(bag wood 8, store wood 2).
- 저장 중 자식을 SIGKILL했을 때:
  - pending_written, pending_verified, before_rename: 최신은 1세대, A 바이트 불변
  - after_rename: 최신은 2세대
  - 이후 저장은 각각 2세대 또는 3세대로 정상이다.

**AC-S14 결정적 시퀀스**
- 채집 → 보관함 9 → 소진 → 저장 → 돌 → 불러오기 → 채집 순서다.
- 매 단계 합계가 독립 기대값 wood 14, stone 14, berry 3, axe 1과 같다. 불러온 직후 가방은 berry3/stone10/axe1/빈칸, 보관함은 wood9다.
- 2회 실행의 측정값 15종이 같다.

**AC-S15 CI·실패 감지**
- 공통 CI에 save-load-acceptance로 등록했다(13단계).
- `--inject-failure`는 exit 1이다.
- 변이 7종을 검출했다.
- 기대 경고 4건 외 엔진 오류 0, 고아 0, 종료 누수 경고 0이다.
- 기존 360/333/521/347검사가 그대로 통과했다.

## 명령·결과

| 명령 | 결과 |
|---|---|
| `python3 tools/godot.py --headless --import` | exit 0, 오류 0. 새 스크립트 `.uid`를 생성해 커밋 |
| `python3 tools/godot.py --headless --script res://tests/test_save_load.gd` | exit 0, `RESULT: PASS`, 425검사(S01 38, S02 66, S03 54, S04 28, S05 34, S06 36, S07 22, S08 10, S09 14, S10 30, S11 14, S12 14, S13 12, S14 17, S15 36), 약 25초 |
| 같은 명령 `-- --inject-failure` | exit 1, `RESULT: FAIL (1)` |
| 기존 suite(test_gathering/inventory/interaction/player_movement) | 각각 exit 0, 347/521/333/360 |
| `python3 -m unittest discover -s tests -p "test_*.py"` | OK(19) |
| 깨끗한 worktree `python3 tools/run_ci.py`(`438ef89`) | exit 0, 13단계 PASS. 이동 360(123.9초), 상호작용 333(29.8초), 인벤토리 521(9.8초), 채집 347(22.5초), 저장 425(23.4초), 누수 경고 0 |

로그는 `build/ih-112/`(Git 무시)에 있다: run1~4, inject, reg_*, mutations/m1~m7, ci/run.log, gui/w1~w3b.

## 표적 변이

각 변이를 적용한 뒤 runner를 실행하고 파일을 복원했다. 구문 오류는 모두 0이다.

| 변이 | 결과 | 검출한 AC |
|---|---|---|
| m1 은행 파일에 직접 쓰기(pending 없음) | FAIL 87 | S05(짧은 쓰기로 은행 손상) 외 다수 |
| m2 pending 재읽기·decode 검증 생략 | FAIL 12 | S05(짧은 쓰기·불일치가 rename됨) |
| m3 checksum 검사 생략 | FAIL 16 | S01(해시 유지 변경), S06, S12 |
| m4 restore 대신 build(초기 stock 재지급) | FAIL 12 | S08, S13, S14 |
| m5 후보 검증 전에 live 서비스 close | FAIL 19 | S10(실패 뒤 이전 서비스 닫힘), S06, S09 |
| m6 미래 schema/content와 추가 키 허용 | FAIL 14 | S03, S06, S07 |
| m7 이전 epoch 요청 허용 | FAIL 6 | S11 |

## OS·내구성 범위

macOS APFS에서 다음을 실제 파일로 검증했다: rename 교체, 단계별 SIGKILL 뒤 세대 선택, 재시작 뒤 복원. Linux ext4(Ubuntu CI)는 같은 runner로 확인한다(통합 기록 참조).

`flush()`는 fsync가 아니고 디렉터리 fsync도 하지 않는다. 따라서 **전원 차단이나 OS 충돌 뒤의 내구성은 검증하지 않았고 보장하지 않는다.** Windows의 rename 교체 의미와 백신·인덱서 잠금도 미검증이다. 같은 루트에 여러 프로세스가 동시에 쓰는 경우는 지원하지 않는다. FILE_CHANGED는 오인 덮어쓰기를 줄이는 장치일 뿐 잠금이 아니다.

## AC-S16 실제 GUI 확인

- 확인 주체: **사용자**(실제 창·키보드·마우스·육안). 2026-11-01, 빌드 `438ef89`, macOS 13.4 / M1, Godot 4.7.2 Standard. 저장 루트는 `user://tests/ih112/gui`(패널에 표시).
- 창 1·2(절차 1~5): 받은 응답은 두 번이다. 첫 응답 "1~6 모두 정상"은 창 2가 열려 있고 창 3이 시작되기 전이었다. 두 번째 응답 "5·6 모두 정상"은 첫 창 3이 막 열린 직후였다. 로그와 대조한 결과:
  - 창 1: 저장 1~5세대(A/B 교대), F9 4세대 복원, 가방/살펴보기 중 BUSY 거부, 복구 버튼으로 이전 세대 복원, 엔진 오류 0, exit 0.
  - 창 2(재시작): F9로 5세대 복원, 복구 버튼으로 4세대, 오류 0, exit 0.
- 창 3(corrupt-latest, 절차 6): 첫 인스턴스는 약 90초 동안 fixture를 적용하지 못했다(은행 파일 mtime·checksum 변화 없음, 로그는 엔진 헤더뿐). 같은 인자로 헤드리스와 별도 GUI에서 재현하면 fixture가 정상 적용되어, 원인은 확인하지 못했다. 종료 후 다시 띄운 인스턴스는 즉시 5세대를 손상시켰다. 그러나 사용자가 "앞으로는 사용자 테스트는 진행하지 않는다"고 답해 **절차 6은 사용자 GUI 미실행**이다. 같은 경로는 자동 AC-S06 장면 사례로만 검증했다.
- Claude는 화면 기록 권한이 없어(ENV-003) OS 창을 보지 않았다. 위 판단은 사용자 응답과 프로세스 로그·파일 상태에 근거한다.

## 구현 차이·결정

1. **session_bootstrap.gd를 만들지 않았다.** NEW/RESTORE 공유 초기화와 후보 검수는 원래 세션을 소유하던 gathering 맵에 최소 훅으로 넣었다:
   - 주입값: `restore_context`, `start_inactive`, `owns_window_title`
   - 활성화: `activate`
   - 저장 훅: `save_blocker`, `capture_payload`
   - static 함수: `save_manifest`, `restore_session`

   조율자는 맵 씬과 restorer Callable만 받는다.
2. **손상 + 없음** 조합(상태표에 없음): 유효본이 없으므로 CORRUPT_SAVE다. 불러오기와 저장 모두 거부하며 빈 은행에도 쓰지 않는다.
3. **checksum은 맞지만 CONTENT_MISMATCH**(미지 품목/맵 등)인 은행은 손상이 아니라 INCOMPATIBLE로 분류한다. 덮어쓰지 않고 보존한다.
4. **위치 왕복 허용 오차**: encode 왕복 검사는 위치만 0.0001 허용이다(위 측정).
5. **suspend 물리 정책**:
   - live 월드: body/area를 KEEP_ACTIVE로 유지한다.
   - 후보: 물리에서 제거하고 WorldCollision만 ALWAYS로 둔다.

   그래서 두 월드 사이에 감지나 선택이 섞이지 않는다. 이동 bool 게이트, 패널, interaction 상태는 건드리지 않는다.
6. **저장 capture는 동기 단일 호출**이다(프레임 경과 없음). 그래서 저장 중에는 월드를 정지시키지 않는다. 파일 I/O도 같은 호출 안에서 끝난다(상태 CAPTURING→WRITING→IDLE).
7. **추가 코드**: STALE_SESSION(이전 epoch), BOOTSTRAP_FAILED, NOT_READY, NO_RECOVERY, FOCUS_LOST(조율자). UI는 원래 cause도 함께 표시한다.
8. **보고 규칙**:
   - 결과는 busy 상태에서 1회 보고한다.
   - 거부도 같은 신호로 보고한다. 다만 결과를 보고하는 중에 들어온 요청은 반환값으로만 거부하고 다시 보고하지 않는다(재귀 방지. 처음 구현에서 무한 재귀를 발견해 고쳤다).
9. **F5/F9**는 새 누름만 받고, 한 프로세스 프레임에 요청 1회다.
10. **InventoryController 추가 가드는 넣지 않았다.** 정지된 하위 트리는 입력·클릭·처리를 받지 않는다(측정). 대신 `save_blocker`가 OPENING/OPEN을 BUSY로 거부한다.
11. 시험 전용 옵션:
    - `--save-root=`는 `user://tests/ih112/` 접두사만 허용하고 `..`를 금지한다.
    - `--fixture=corrupt-latest`는 최신 은행 checksum 한 글자를 바꾼다.

    제품 UI에는 손상 버튼이나 경로 입력이 없다.

## 미검증·남은 범위

- AC-S16 절차 6(사용자 GUI).
- 첫 창 3 인스턴스의 fixture 미적용 원인(재현 안 됨).
- Windows, 전원 차단, 다중 writer.
- DEBT-002/003/004는 범위 밖이다.
- IH-112 done 판정과 ADR-017 Accepted 전환은 리뷰 뒤 별도로 한다. v0.3.0 판정은 별도다.

## 통합 기록

PR·CI·merge 결과는 PR 이력과 후속 기록에 남긴다.
