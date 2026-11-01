# Claude Code 인수인계 — IH-112

**현재 작업은 BUG-009~011 수정이다.** [Codex 리뷰의 수정 전달용 프롬프트](IH-112-REVIEW.md)를 사용한다. 아래 최초 구현 프롬프트는 완료 이력이며 다시 실행하지 않는다. IH-112 review 및 AC-S16 부분 확인을 유지한다.

상태: **구현됨 / review**(2026-11-01 Claude Code, [검증 기록](IH-112-VALIDATION.md). AC-S16 절차 6은 사용자 GUI 미실행). 원래 상태는 상세 설계 완료 / 구현 ready였다(2026-11-01). IH-110/111은 구현·수정·독립 재검증 done. Codex는 이번에 설계 문서만 작성했다. 파일 저장/신규 runner/GUI는 아직 없고 ADR-017은 Proposed다.

## 읽기·변경 범위·순서

CLAUDE.md/.claude/rules → [TASKS](TASKS.md) → [SAVE_SYSTEM](../02-technical-design/SAVE_SYSTEM.md) → [SAVE_LOAD](../02-technical-design/SAVE_LOAD.md) → [AC-S01~16](IH-112-ACCEPTANCE.md) → [ADR-017](../04-decisions/ADR/ADR-017-versioned-save-restore.md) → Inventory/GatherService·맵 bootstrap·Player·Interaction/InventoryController 실제 코드 → [CI](../02-technical-design/CI.md).

신규/수정 파일 후보는 SAVE_LOAD의 모듈 표를 따른다. 이 문서의 이름은 제안이며 기존 구조와의 차이를 먼저 기록한다. 기본 Foundation/기존 독립 맵과 서비스 거래 계약은 보존한다.

1. Git/최신 develop/사용자 변경 확인, feature/save-load-system 분기, 변경 파일·계획 제시.
2. 현4.7.2의 JSON 숫자·checksum·파일 rename/오류·충돌 검사 API를 작은 예제로 확인하고 차이를 기록한다.
3. Codec v1/시험v0·참조 검증·정규화와 실패 fixture 구현. 완전한 정상 fixture를 실제 로드해 검증.
4. A/B SaveStore와 실제 파일/실패 주입·세대 선택·복구/중단 검사 구현. 사용자 세이브와 격리.
5. GatherService.restore·snapshot 경계, 작은 세션 bootstrap/조율자, 후보 검증·epoch·publish·입력 수명 구현.
6. SaveLoadTest/UI/F5/F9 연결, 새 runner/공통 CI 등록, 기존 회귀·변이·실제 GUI 확인.
7. 검증/작업/문제/ADR 차이 기록, 필수 PR CI 후 develop 통합·원격 확인. 이번에는 main/태그/릴리스 없음.

## 전달용 프롬프트

```text
IH-112 초기 저장·복원을 구현하라.
CLAUDE.md/.claude/rules, docs/02-technical-design/SAVE_SYSTEM.md와 SAVE_LOAD.md,
docs/03-development/IH-112-ACCEPTANCE.md, IH-112-HANDOFF.md,
ADR-017 및 기존 Inventory/GatherService, Player, Interaction/InventoryController와 맵 bootstrap을 읽는다.
Git/최신 develop/사용자 변경을 확인하고 feature/save-load-system에서 시작한다.
수정 파일·계획을 먼저 제시하고 Godot4.7.2 Standard/GDScript/Compatibility를 유지한다.
단일 수동 슬롯의 A/B 두 세대, 버전 payload JSON 문자열+SHA256 envelope를 구현한다.
위치/방향·bag/store/숨은 stock5개·결속3개만 저장한다. remaining을 중복 저장하지 않는다.
JSON bool/비정수/비유한/안전 범위 밖 값을 거부하고 검사 후 내부 int로 변환한다.
schema1/시험v0 migration과 미래 schema·미지원 content 거부를 구현한다.
파일은 user:// 고정 경로에서 pending 작성/flush-close/재읽기 검증 후 rename한다.
대상 은행 사전 삭제/직접 truncate, 무검증 복구/mtime 최신 선택을 하지 않는다.
A/B 상태표와 명시 복구본 선택을 구현하고 기본 Load 실패 시 현재 세계를 보존한다.
GatherService.build로 복원 stock을 재지급하지 않는다. restore가 모든 재고를 새 서비스에 한 번씩 등록한다.
후보 월드를 inactive bootstrap해 노드/결속/물리 위치를 검증한 뒤 publish한다.
검증 전에 live 서비스를 닫지 않는다. old epoch의 UI/명령이 새 서비스를 바꾸지 못하게 한다.
모달/채집/입력 큐 처리 중에는 BUSY, 임의 취소/닫기 없음. 새 Player는 속도0·IDLE·키 중립 복구다.
Player ALWAYS 처리도 staging 중 멈추되 기존 이동 bool 게이트의 제3 소유자/범용 잠금을 만들지 않는다.
파일/세계 commit 뒤 UI 제거·포커스 상실은 이미 성공한 결과를 취소하거나 재시도하지 않는다.
SaveLoadTest의 SaveUI는 교체 월드 밖에 둔다. F5 저장/F9 불러오기, 복구본은 명시 버튼이다.
자동/종료 저장·슬롯 선택/삭제·Cloud·농사·달력·NPC·다른 맵 이동·암호화는 구현하지 않는다.
AC-S01~16과 기존 이동360/상호작용333/인벤토리521/채집347 검증 의도를 보존한다.
새 runner를 공통 CI에 등록하고 실제 파일·별도 프로세스 종료/재시작·실패 주입·표적 변이·반복을 검증한다.
시험 파일은 전용 user://tests 네임스페이스만 사용하고 제품 saves/사용자 파일은 건드리지 않는다.
OS별 rename/내구성 확인 범위를 기록하고 전원 차단 안전을 검증 없이 보장하지 않는다.
GUI는 실제 조작 주체/빌드 SHA/절차를 기록하고 미실행을 pass로 보고하지 않는다.
IH-112-VALIDATION.md와 TASKS/WEEKLY_LOG/BUGS/CHANGELOG/설계 차이·ADR 상태를 갱신한다.
필수 PR CI 통과 후 develop 통합·원격 확인, 커밋/PR/CI/결과를 보고한다.
사용자 미추적 AGENTS.md는 보존·미커밋한다. main/태그/릴리스는 변경하지 않는다.
```

## 알려진 제약·완료 경계

미추적 AGENTS.md의 없는 .Codex/rules 링크4개는 사용자 파일을 수정해 검사 통과시키지 않는다. 원래 루트 검사와 깨끗한 커밋 worktree 검사를 구분하고 .claude/rules를 따른다. DEBT-002(다중 게이트)·003(배포 글꼴)·004(ItemDef 원본 타입)는 이번 범위 밖이다.

ready는 명세 준비 상태다. 실제 API/FS 측정과 구현 차이는 ADR-017에 기록하고, AC·필수 CI·리뷰·통합 증거 뒤에만 done으로 바꾼다. v0.3.0 마일스톤은 IH-112 완료 이후 별도 판단한다.
