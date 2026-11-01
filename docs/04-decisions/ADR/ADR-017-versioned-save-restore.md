# ADR-017: 버전 저장과 검증 후 새 세션 복원

- 상태: **Accepted** (2026-11-01 Codex 최종 검토, IH-112 초기 저장 범위)
- 날짜: 2026-11-01
- 관련: IH-112, [SAVE_LOAD](../../02-technical-design/SAVE_LOAD.md), [ADR-004](ADR-004-save-system.md), [ADR-015](ADR-015-inventory-contract.md), [ADR-016](ADR-016-atomic-gathering.md)

## 배경

Inventory/Gathering의 상태가 생겼고, 기존 build는 새 게임의 stock을 초기 지급한다. 기존 모달 ID·지연 입력·서비스 참조가 남은 채 live 상태를 덮어쓰면 아이템 복제·유실 위험이 있다. 파일 쓰기 중 중단과 손상에서도 유효본이 필요하다.

## 검토한 대안

- 단일 JSON을 직접 덮어쓰기: 단순하지만 중단 시 유일본을 잃음.
- primary/tmp/backup 순차 회전: 익숙하지만 회전 중간 상태와 손상본의 backup 덮어쓰기 정책이 늘어남.
- **논리 슬롯1개·A/B 두 세대**: pending 검증 후 오래된 은행만 rename 교체. 별도 최신 포인터 없이 검증한 generation으로 선택. 초기 제안으로 선택.
- Resource/임의 Object 직렬화: 엔진 타입과 결합. 대신 ID·원시 값의 JSON과 엄격 도메인 검증을 사용.
- live 서비스 수정 복원: 기존 참조/부분 실패를 다루기 어려움. 대신 별도 후보 컨텍스트/월드를 검증 후 교체.

## 결정·이유

JSON payload 문자열과 SHA256 envelope로 바이트 손상을 검사한다. schema1/content1과 시험v0→v1 migration으로 초기 버전 경계를 둔다. bool/소수/비유한 값을 검사하고 안전 정수 범위로 제한한다. ID·결속·전체 재고를 새 서비스에서 검증한다. 기존 GatherService.build와 복원 경로를 분리해 초기 stock을 다시 지급하지 않는다.

한 수동 슬롯에 두 세대를 보관하고 임시 파일 검증 후 같은 디렉터리 rename을 파일 commit으로 정의한다. 기본 Load는 손상 시 현재 세계를 보존하고 명시 복구본 선택을 제공한다. publish 전에는 현재 세션 서비스를 닫지 않고, publish 후에는 old epoch/명령/UI 요청이 새 세계를 변경하지 못하게 한다. 새 입력은 키 중립 이후에만 받는다.

## 단점·고려사항

A/B 선택·checksum·후보 세션 때문에 단일 덮어쓰기보다 코드와 검사가 늘어난다. 두 세대만 보관하며 자동 저장/Cloud는 후속이다. checksum은 변조 방지가 아니다. safe-integer 범위 밖 revision은 저장할 수 없으며 조용히 반올림하지 않는다. 같은 루트의 다중 프로세스 동시 writer는 지원하지 않는다. 프로세스 중단 회복과 OS 전원 차단 내구성은 구분해서 검증한다. Player ALWAYS/물리·카메라·Node 수명과 기존 모달 게이트를 보존해야 한다.

## 영향·상태 변경 관문

SaveCodec/Store/Coordinator, 최소 bootstrap/복원 API·SaveLoadTest·UI·CI 회귀가 필요하다. ADR-004의 envelope/migration/검증 후 교체 원칙을 IH-112 범위에서 구체화하며 기존 ADR을 삭제하거나 Accepted로 소급 변경하지 않는다.

AC-S01~16, 기존 회귀·실패/중단 시험·실제 GUI·필수 PR CI를 증거로 구현 완료와 Accepted 전환을 각각 판단한다. 현재 ready는 구현 완료가 아니다.

## 구현 검증 결과 (2026-11-01)

Claude Code가 이 제안대로 구현했다. 확인한 내용은 다음과 같다([검증 기록](../../03-development/IH-112-VALIDATION.md)).
- A/B 두 세대, payload 문자열 SHA-256, 숫자 정규화
- schema1과 시험 v0
- pending 검증 뒤 rename, 명시 복구
- 초기 지급 없는 restore, 후보 검증 뒤 publish, epoch 차단
- AC-S01~15 자동 425검사, 변이 7종, 별도 프로세스 SIGKILL

실측에 따른 구현 차이:
- 위치만 왕복 허용 오차를 둔다.
- 엄격한 UTF-8 검사를 선행한다.
- 손상+없음과 checksum이 맞는 콘텐츠 불일치는 보존·거부한다.
- live 월드의 물리는 유지하고 process만 정지한다.

전원 차단, Windows, 다중 writer는 미검증이다. 이 한계를 유지한 채 IH-112의 단일 수동 A/B 슬롯·후보 검증/publish 계약을 Accepted로 전환한다.

## Accepted 전환 근거 (2026-11-01)

- 독립 자동 검증: d2e1c88에서 CI13단계·저장529검사, 원래 결함 진단5종 PASS. BUG-009~011 resolved. 보고 중 BUSY, 키 입력의 UI 수명 분리, 실제 명령 진입의 세션 정지 가드를 검증했다.
- 사용자 GUI: 기존438ef89 절차와3d248d0 손상복구에서 “1~4 모두 정상”. 손상 최신본을 기본 Load로 거부·현재 세계 보존, 명시 이전 세대 복원·이후 조작을 확인했다. 기록 당시 GUI 종료 코드는 미수집이며 성공 종료로 소급하지 않는다.
- PR #39 merge36d86f6, 필수 PR CI41311167844 및 develop CI41311509122 success. 현재 game/tools/tests/.github는 독립 검증 코드와 동일하다.
- 초기 파일/세션 commit 계약의 승인이다. 향후 전체 NPC·달력 저장, 전원 차단 내구성, Windows·Cloud 지원을 승인/검증한 것은 아니다. ADR-004/015/016의 상태는 변경하지 않는다.
- [수락/검증](../../03-development/IH-112-VALIDATION.md), [마일스톤 판정](../../03-development/GATHERING-v0.3.0-VERIFICATION.md).
