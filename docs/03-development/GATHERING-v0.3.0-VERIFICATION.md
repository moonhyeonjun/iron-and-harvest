# v0.3.0 Gathering 마일스톤 판정 — 2026-11-01

## 기능 판정

**완료 조건 충족(PASS).** IH-110/111/112 done. ADR-017은 초기 저장 범위에서 Accepted로 전환한다. 기존 MILESTONES의 “수집/이동/복원 일치”와 원래 수락 조건을 그대로 적용했다. v0.3.0은 채집·가방·초기 저장을 갖춘 개발 기준점이며 자립 가능한 마을 MVP나 Steam 출시판이 아니다.

판정 기준 develop `36d86f625d04e672e666527054db6a3c88228b64`. GUI 재개 기록 [PR #39](https://github.com/moonhyeonjun/iron-and-harvest/pull/39) merge, [PR CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41311167844/job/124861674152) 및 [develop CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41311509122/job/124862705115) success를 확인했다. game/tools/tests/.github는 Codex 독립 검증 d2e1c88 및 손상복구 GUI3d248d0와 동일하다(diff0).

이 문서의 기능 판정과 Git 발행은 구분한다. 아래 승격·main CI·태그 ref 확인 전에는 발행 완료로 보고하지 않는다. 실제 발행 대상은 검증된 main 병합 커밋이며 태그의 peeled SHA가 기준이다.

## 관문과 증거

| 관문 | 결과 | 근거 |
|---|---|---|
| Foundation·Character 의존 | PASS | IH-001/002/004/101/102 done, v0.1.0 및 v0.2.0 보존. Godot4.7.2 Standard/GDScript/Compatibility |
| 아이템·가방·보관 | PASS | IH-110 done, AC-N01~14. 521검사, 스택/포화/원자 전송/수량 보존/재진입/수명, BUG-005/006 수정·독립 재검증. [기록](IH-110-VALIDATION.md) |
| 유한 자원 채집 | PASS | IH-111 done, AC-G01~14. 347검사, 지점 결속/숨은 재고/소진/단발 명령/가방 포화/취소·HUD 수명, BUG-007/008 수정·독립 재검증. [기록](IH-111-VALIDATION.md) |
| 초기 저장·복원 | PASS | IH-112 done, AC-S01~16. 529검사, A/B·검증·migration·rename·중단·초기 재지급 없는 후보 복원·발 충돌·epoch/정지/보고/UI 경계. BUG-009~011 resolved. [기록](IH-112-VALIDATION.md) |
| 실제 화면·조작 | PASS(사용자 확인) | IH-110 기존 GUI, IH-111 normal/full/rebind, IH-112 빌드438ef89 기존 절차와3d248d0 손상복구 사용자 “1~4 모두 정상”. 서로 다른 확인 빌드를 명시하며 Codex 새 GUI 실행으로 주장하지 않음 |
| 손상 최신본 복구 | PASS | 새 시험 루트에서 A1 유효/B2 checksum 손상 확인. F9 RECOVERY_AVAILABLE·현재 세계 보존, 명시 복구 A1 OK recovered=true·위치/방향/수량 일치·이후 이동/채집/전송 정상, 엔진 오류0. 복구는 파일을 쓰지 않음 |
| 전체 회귀·엔진 | PASS | d2e1c88 clean worktree CI13단계(Python19·경제7·360/333/521/347/529), 원래 결함 진단5종 exit0. 저장 반복18종 차이0·고아0·예상 밖 엔진 오류0. 이후 실행 코드 변경 없음. 최신 Linux develop CI도 success |
| Git·문서·검토 | PASS / 발행 단계 별도 | 사용자 변경 보호, BUG-005~011 resolved, 수락 조건을 낮추지 않음. 필수 CI checks(strict/admins) 유지. 승격 PR과 main push도 CI 필수 |

사용자 테스트 재개가 최신 방침이다. 기존 중단·미확인·review 문구는 당시 이력으로 보존한다. GUI 기록 당시 창이 열려 있어 종료 코드는 미수집이며 정상 종료로 소급하지 않는다. GUI 수락은 실제 조작/관찰과 로그를 근거로 한다.

## Accepted 범위

[ADR-017](../04-decisions/ADR/ADR-017-versioned-save-restore.md)은 단일 수동 A/B 슬롯, 검증된 JSON 원시 값/ID, pending→rename 파일 commit, 새 서비스/후보 월드 검증→publish 세션 commit, 명시 복구 및 실패 시 기존 세계 보존의 초기 계약을 승인한다. 달력/NPC/왕조·전체 월드 저장이나 전원 차단·Windows·Cloud 보장을 포함하지 않는다. ADR-004/015/016 등 다른 Proposed 결정은 자동 승인하지 않는다.

## 포함 기능과 실행

- 7종 아이템 정의, 슬롯/스택 가방·시험 보관함, 양쪽 원자 전송·UI 보기/세션 경계.
- 나뭇가지·돌·산열매 지점, 유한 숨은 재고에서 가방으로 즉시 채집, 소진/포화/취소/재결속·표시.
- 위치·방향, 가방/보관함/지점5재고·결속3개의 단일 수동 저장과 복원. F5 저장/F9 최신 불러오기/이전 세대 명시 복구.
- 기존 이동·상호작용, 전용 시험 맵과 고정 엔진·CI.

```sh
python3 tools/godot.py res://scenes/tests/inventory_test.tscn
python3 tools/godot.py res://scenes/tests/gathering_test.tscn
python3 tools/godot.py res://scenes/tests/save_load_test.tscn
```

res://는 game/ 기준이다. 기본 main_scene은 여전히 빈 Foundation이며 명시 시험 맵 실행은 기존 계약이다. 이번 판정에서 게임 진입점/제품 UI/게임플레이를 변경하지 않는다. 기본 저장 시험 루트는 user://tests/ih112/gui이며 제품 user://saves를 사용하지 않는다.

## 비차단 한계와 다음 작업

| 항목 | 현재 판정·후속 책임 |
|---|---|
| DEBT-002 단일 bool 이동 게이트 | 현재 배타 모달·정지 명령 가드까지 검증. 제3 잠금 작성자/다중 모달은 후속 조율 설계 |
| DEBT-003 글꼴·IH-003 LICENSE | macOS fallback 확인만 유효. 배포 글꼴·콘텐츠 권리·라이선스는 IH-006/003. 소스 기준점과 제품 배포를 구분 |
| DEBT-004 ItemDef 리터럴 강제변환 | 현재 7종은 정수 리터럴이며 CI 통과. 외부 임의 ItemDef에 GatherDef 수준 원본 검사를 적용할지는 별도 작업. 미해결 상태 유지 |
| 저장 내구성·지원 OS | 프로세스 중단 APFS/Linux ext4 검증. 전원 차단·Windows 파일 잠금/GUI·다중 writer·Cloud는 미검증, 보장하지 않음 |
| Export·Steam·장기 콘텐츠 | 실행파일/제품 릴리스·성능 보장·경제/농사/다수 NPC·장기 플레이는 이번 완료 범위 밖 |
| 미확정 아트/수치·다른 ADR | ADR-015/016 등 Proposed 유지. 이번 초기 저장 계약 승인과 별개 |

다음 Codex 작업은 **IH-120 달력·계절·하루 경계 상세 설계**다. 날짜 전진/일시 정지/결산 순서/저장·migration 계약과 수락 조건을 먼저 준비한다. Claude Code는 이후 명세에 따라 구현한다. IH-120은 현재 backlog이며 이번에 구현하거나 ready로 바꾸지 않는다.

## Git 승격과 발행 절차

1. docs/v0.3.0-milestone의 판정·상태 문서를 정적 검사하고 필수 PR CI 후 develop에 통합한다.
2. develop→main 승격 PR의 변경 범위·main 이력 포함 여부·합성 병합 CI를 확인하고 병합한다.
3. main push CI success 및 승격 원본과 tree 동일을 확인한다.
4. 기존 local/remote v0.3.0 부재를 확인한 뒤 검증된 main 커밋에 annotated tag 생성·push, 객체/peeled SHA를 대조한다. 기존 태그는 이동하지 않는다.
5. main 승격 이력을 포함한 후속 발행 기록을 PR로 develop에 동기화하고 실제 SHA/CI/태그 결과를 기록한다.

GitHub Release 페이지·Export 실행파일·Steam 게시 산출물은 생성하지 않는다. 로그와 API/ref 검증은 build/v0.3.0/(Git 제외)에 남기고 실제 발행 결과는 후속 기록 및 관련 PR에서 연결한다. 사용자 미추적 AGENTS.md와 기존 .Codex/rules 링크4개 문제는 보존하며 clean worktree로 정적 검증한다. 이미 검증된 같은 코드를 이유 없이 로컬에서 반복 실행하지 않고, 각 PR/main의 필수 CI는 그대로 수행한다.
