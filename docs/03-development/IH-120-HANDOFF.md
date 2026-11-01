# Claude Code 인수인계 — IH-120 달력·계절·하루 경계

상태: **구현됨 / review**(2026-11-02 Claude Code, [검증 기록](IH-120-VALIDATION.md)). 아래 프롬프트는 완료 이력이며 다시 실행하지 않는다. 원래 상태는 상세 설계 ready / 구현 전(2026-11-01)이었다. 기준 develop4d30344(IH-112 done·ADR-017 Accepted·v0.3.0 확정). Calendar 코드·신규 runner·새 GUI 검증은 없다. 아래 프롬프트는 다음 구현 작업용이다. Codex가 설계·기술 검토, Claude Code가 구현을 맡는다. 제품 수치와 장기 월간/노화 설계는 미확정이다.

## 읽을 순서·수정 범위

CLAUDE.md/.claude/rules → [CALENDAR](../02-technical-design/CALENDAR.md) → [AC-C01~16](IH-120-ACCEPTANCE.md) → [ADR-018](../04-decisions/ADR/ADR-018-calendar-day-boundary.md) → SAVE_LOAD/ADR-017·DATA_MODEL/ARCHITECTURE → 실제 SaveCodec/Store/Coordinator, gathering_test의 manifest/capture/restore/suspend/close, SaveLoadTest/SaveUI, Inventory/Interaction/Player, 공통 CI/테스트를 읽는다.

| 범위 | 작업 |
|---|---|
| 신규 calendar 도메인/정의 | CalendarRules/Service·검증된 두 프로필 JSON·유일 상태/순수 snapshot/새 restore |
| 신규 입력/HUD/시험맵 | 교체 World 밖 Controller/HUD·기존 SaveLoad wrapper 재사용·새 테스트 namespace |
| 기존 gathering 맵 훅 | calendar 생성/캡처/복원/manifest/정지/정리. 기존 맵은 실시간 driver 없이 passive |
| SaveCodec/fixtures | schema2 필수 calendar·정확한0→1→2 이관·미래3+·수량/기존 필드 보존 |
| SaveCoordinator/SaveLoadTest | 기본값이 기존 동작인 작은 설정/외부 blocker hook. 파일 commit/세션 publish 경계 보존 |
| tests/CI/docs | 새 runner·기존 검증 의도 보존·검증기 등록·실패 주입/변이·실제 GUI·검증 기록 |

파일명은 후보이며 관련 역할·의존성 계약이 기준이다. 파일/단계를 먼저 제시하고 꼭 필요한 hook만 바꾼다. 전체 wrapper/도메인을 복제하거나 미래 생산·농사 매니저를 만들지 않는다.

## 권장 구현 순서

1. Git/환경·기존 코드·수락 조건을 확인하고 변경 파일/계획을 제시한다. feature/calendar-system에서 시작한다.
2. 검증된 규칙/상태·파생 날짜·전진·한도·알림/재진입의 순수 실패 회귀를 만든다.
3. schema2와 immutable0/1 fixture·중간 이관·원본 파일 보존을 먼저 검증한다.
4. 기존 World의 passive calendar와 새/복원 컨텍스트·close/suspend를 연결한다. 기존 맵의 날짜가 자동 흐르지 않음을 확인한다.
5. 전용 Controller/HUD/맵을 붙여 물리 step·정지 사유 합성·N pending·epoch/수명·save/load 외부 blocker를 검증한다.
6. 전용 runner/CI 등록·결정적 반복·변이·실제 파일 재시작/복구·기존 회귀를 수행한다.
7. GUI 시험 루트를 준비하고 사용자에게 짧은 단계별 안내 후 실제 응답을 기다린다. 테스트 재개 지시가 유효하며 확인 주체/빌드/결과를 구분한다.
8. 구현 차이·검증 기록·개발 현황/주간/버그/변경 이력을 갱신하고 필수 PR CI 후 develop에 통합한다. Codex 후속 검토 전 완료를 임의 확정하지 않는다.

## 전달용 프롬프트

```text
IH-120 달력·계절·하루 경계를 구현하라.
CLAUDE.md/.claude/rules, CALENDAR.md, IH-120-ACCEPTANCE.md/HANDOFF.md,
ADR-018, SAVE_LOAD/ADR-017 및 실제 저장·gathering bootstrap·기존 입력/CI를 먼저 읽는다.
현재 Git/최신 develop/사용자 변경을 확인하고 feature/calendar-system에서 시작한다.
변경 파일과 단계별 계획을 제시한다. Godot4.7.2 Standard/GDScript/Compatibility를 유지한다.
CalendarState는 rule_id/day_index/tick_in_day/revision만 소유하고 계절·연도·시각은 파생한다.
기본 제안14일×4계절·36000tick/하루·60Hz·06:00시작, 빠른프로필은2일·120tick/하루다.
값은 검증된 정의에 두고 제품 밸런스 확정으로 보고하지 않는다.
물리스텝1회=1tick이며 OS시간/렌더delta/휴면 경과를 일괄 보충하지 않는다.
한 명령 최대하루, 사전 검증 뒤 원자 설치·날짜 경계1회 알림, 보고 중 전진/save/load BUSY다.
completed_day_index는 지나간 날이며 load/restore에서는 이벤트·revision 증가·초기 지급0이다.
서비스는 순수 값/RefCounted, Node/파일/입력은 Controller/adapter 책임이다.
Controller/HUD는 교체 World 밖에서 현재 SaveCoordinator world/epoch만 사용한다.
P 시간정지와 N 다음새벽은 새 press만. N pending1건을 다음 물리step에서 재검증해
자연 전진과 같은 API로 실행하고 그step 자동tick은 생략한다.
user pause/모달/focus/SceneTree pause/save-load/suspended/수명 사유를 합성한다.
사유 하나 해제로 다른 정지가 풀리지 않게 하고 pending 취소·키중립·old epoch를 검사한다.
CalendarService의 직접/deferred 전진도 suspended/closed/busy 검사를 우회하지 못한다.
SaveCoordinator에 작은 선택적 외부 blocker hook을 두어 pending/보고 중 F5/F9를 BUSY로 거부한다.
Clock이 거부 보고 중도 감지하게 is_busy에 _emitting을 포함하거나 동등한 읽기 API를 제공한다.
Player 게이트의 제3 작성자·강제 패널닫기·범용 Autoload/이벤트버스·결산프레임워크를 추가하지 않는다.
HUD free/queue_free/remove_child 뒤에도 현재 epoch의 키/시간은 안전하고 표시만 생략한다.
기존 gathering/save_load 맵은 passive calendar로 유지하고 새 calendar_test만 자연 진행한다.
schema2 필수calendar/content1 유지,0→정확한1→2 검증 이관을 구현한다.
정상v1 전체 검증 뒤 기본달력day0/tick0/rev0만 추가한다. 구파일/세대/수량·재고revision을 보존한다.
load는 원본파일을 쓰지 않는다. 이후 명시F5만 schema2·다음 generation으로 저장한다.
미래schema3+/다른rule_id/잘못된calendar를 거부하고 A/B·checksum·rename·명시복구 계약을 유지한다.
기존schema2_future 및v0/v1 fixture는 과거증거로 보존하고 신규미래검사를3+로 구분한다.
후보검증 실패 시 기존calendar와재고/위치/epoch를 보존하고 성공시 새서비스를 함께 publish한다.
AC-C01~16, 기존360/333/521/347/529 검증 의도와 CI 실패 감지를 보존한다.
실제검사수·스키마 예상값 변경·추가회귀·반복·변이·실제파일/별도프로세스 결과를 기록한다.
신규 runner는 공통 CI에 등록한다. 미래 suite를 현재 PASS처럼 기록하지 않는다.
새 user://tests/ih120/ 경로만 사용하고 제품 saves/기존 ih112 GUI 파일/사용자 작업은 건드리지 않는다.
실제 GUI는 사용자 조작을 안내하고 응답을 기다린다. 주체/SHA/프로필/기준/관찰/로그를 남긴다.
IH-120-VALIDATION.md를 만들고 AC/TASKS/WEEKLY_LOG/BUGS/CHANGELOG·기술 차이/ADR을 갱신한다.
농사/생산 결산/노화/수면/배속/오프라인 보상/Cloud/월간 국가는 이번에 구현하지 않는다.
필수 PR CI 후 develop 통합·원격 확인과 커밋/PR/CI 결과를 보고한다.
Codex 후속 검토를 위해 review로 남기고 ADR-018은 검증 근거 없이 Accepted로 바꾸지 않는다.
사용자 미추적 AGENTS.md는 보존·미커밋한다. main/태그/릴리스는 변경하지 않는다.
```

## 완료·한계

ready는 구현 준비 상태다. 기존 run_ci.py는13단계이며 Calendar suite/스키마2는 아직 없다. 이번 문서 PR의 기존 CI 성공은 Calendar 구현 검증이 아니다. v0.4.0은 농사까지 필요하므로 IH-120만으로 태그를 만들지 않는다.

DEBT-002/003/004, Windows/전원차단/Cloud·라이선스 한계를 유지한다. AGENTS.md의 기존 .Codex/rules 링크4개 오류는 사용자 파일을 고쳐 통과시키지 않는다. 별도 clean worktree의 정적 검사와 원래 루트 결과를 구분한다. 관련 문서의 과거 IH-112 프롬프트는 완료 이력이며 다시 실행하지 않는다.
