# 변경 이력

## Unreleased — IH-110 기술 검토

- 기존 CI 11단계 통과를 독립 확인한 뒤 BUG-005(UI/서비스 수명 재검증)·BUG-006(끝 개행 ID 허용)을 추가 재현했다. IH-110 review 재개, [검토·Claude 수정 프롬프트](docs/03-development/IH-110-REVIEW.md) 작성. 게임 코드 변경 없음.

완료 조건과 검증을 충족한 버전만 자율적으로 태그/릴리스한다. Foundation 기술 관문을 충족했으며 태그/원격 반영 여부는 IH-002 검증 기록을 따른다.

## Unreleased — IH-110 리뷰 수정 (Claude Code, 2026-11-01)

- Fixed BUG-005: 가방 열기 콜백 뒤·OPEN 중 UI/서비스 수명을 재검사한다. 거부 또는 1회 닫힘으로 게이트·interaction을 복구하고, 죽은 UI 호출과 늦은 재고 변경이 없다.
- Fixed BUG-006: ID 검사가 끝 개행 포함 문자열 전체를 확인한다(자동 보정 없음).
- test_inventory 회귀 추가(521검사).
- [PR #22](https://github.com/moonhyeonjun/iron-and-harvest/pull/22)로 develop 통합(merge cbb836b), PR/develop CI success. IH-110 done. main 미반영.

## Unreleased — IH-110 구현 (Claude Code, 2026-11-01)

- ItemDef/ItemCatalog(.tres 7종 + 명시 catalog, 스칼라 복사 격리), InventoryState, InventoryService(고정 슬롯, 원자 add/remove/transfer, expected revision, 거래당 1회 변경 신호, 재진입 BUSY, 엄격 snapshot).
- InventoryController(가방/살펴보기 배타, opening 래치, session ID, 게이트·interaction 복구)와 InventoryUI(표시·의도만), `scenes/tests/inventory_test.tscn` 유한 보관함(`--fixture=full`).
- InputMap `inventory_toggle`(물리 I), `inventory_cancel`(Escape), `InteractionController.is_interaction_enabled()` 읽기 API.
- `tests/test_inventory.gd`(375검사)와 JSON 비교 fixture, `tools/run_ci.py`에 inventory-acceptance 등록.
- [PR #19](https://github.com/moonhyeonjun/iron-and-harvest/pull/19)로 develop 통합(merge f26a77e), PR/develop CI success. IH-110 done.
- 수치는 검증 제안. 채집·소비·장비·제작·드롭·예약·파일 저장·통치·전역 잠금은 미구현. 태그/릴리스 없음.

## Unreleased — 설계

- IH-110 아이템·인벤토리 상세 명세, AC-N01~14, Claude Code 인수인계, ADR-015 Proposed 작성.
- 정의 포맷 비교·고정 슬롯·원자 수량 변경/이동·revision·snapshot·가방 모달 계약 제안. TASKS ready, 게임 기능/CI 설정 변경 없음, 신규 AC 미실행.

## v0.2.0 Character — 2026-11-01

- 기능 마일스톤 판정 PASS: IH-101 이동·충돌·카메라, IH-102 대상 선택·살펴보기·안전한 종료. [판정/승격 기준](docs/03-development/CHARACTER-v0.2.0-VERIFICATION.md).
- BUG-001~004 수정과 회귀 포함. CI 10단계/Python19/이동360/상호작용333 검사, 기존 사용자 GUI 확인.
- 엔진4.7.2 Standard/GDScript/Compatibility 고정, 기본 Foundation 씬 유지, 테스트 맵 명시 실행.
- 개발용 소스 기준점이다. 채집·가방·저장·Export/Steam 출시·제품 라이선스는 후속 범위다. main CI 성공 후 annotated 태그 v0.2.0을 `8901bac`에 발행하고 로컬/원격 일치를 확인했다.

## 구현 이력 — 2026-11-01 (v0.2.0에 포함)

### IH-102 리뷰 수정 (Claude Code)

- Fixed BUG-003: 실행 직전·활성 세션에서도 후보 중 중복 ID를 재검증한다(선택과 같은 정책). 활성 대상의 ID 변경도 취소한다.
- Fixed BUG-004: try_begin 중 비활성화·포커스 상실·트리 이탈이 일어난 요청은 ACTIVE가 되지 않는다. end/rejected를 각각 1회 보고하고 게이트를 소유하지 않는다.
- test_interaction에 회귀 12종 추가(333검사), probe target `on_begin` 훅.
- [PR #12](https://github.com/moonhyeonjun/iron-and-harvest/pull/12)로 develop 통합(merge e5d7730), PR/develop CI success. IH-102 done. main 미반영.


### IH-102 Codex 후속 검토

- 추가 경계 재현으로 BUG-003(실행 시 중복 ID 검증 누락), BUG-004(RESOLVING 중 disable 무시) 등록. IH-102 review 재개, 수정 수락 조건과 Claude 프롬프트 작성.
- 기존 구현/통합/GUI 기록은 보존하고 현재 문서 상태 표기를 정리했다. 게임 코드와 CI 설정 변경 없음.

### IH-102 상호작용 대상·프롬프트 (Claude Code)

- InteractionController(Player 마지막 자식, priority 10): Area2D 후보, 거리32·정면 dot0.5·world_solid 가시선, 정수 tuple 선택, 틱당 1개 입력 의도 큐와 캡처 대상 재검증, 단조 request ID, 세션·이동 게이트·포커스·삭제·제거 취소.
- InteractionTarget(layer 3=값4, 비물리 Area): 안내판/상자 살펴보기 전용, 보상·아이템 없음. InteractionUI: 프롬프트와 제목/설명/닫기 패널, 닫기·취소 의도만 발행.
- `scenes/tests/interaction_test.tscn`: 이동 맵 인스턴스 + 대상2 + ID 검수 + 신호 연결. Foundation 진입점 유지.
- InputMap `interact`(물리 E), `interaction_cancel`(Escape), layer_3 이름.
- `tests/test_interaction.gd` AC-I01~12 자동 검사와 probe target, `tools/run_ci.py`에 interaction-acceptance 등록(`ci_steps()`).
- Fixed BUG-002: IH-101 runner의 headless 키 이중 전달과 잘못된 관찰 기록.
- [PR #9](https://github.com/moonhyeonjun/iron-and-harvest/pull/9)로 develop 통합(merge 318fcd2), PR/develop CI checks 성공. main 미반영.
- 수치·키·문구는 검증용 제안. 가방·채집·대화·상점·전투·저장·통치는 미구현. v0.2.0 태그/릴리스 없음.

## 구현 이력 — 2026-10-31 (v0.2.0에 포함)

- IH-004 완료 후 IH-102 상호작용 상세 명세·수락12항목·Claude 인수인계 작성. ADR-014 Proposed, 기능 미구현/검사 미실행.

- IH-004: 고정 Action/엔진 체크섬 기반 CI, 공통 검사 실행기와 실패 판정 회귀 추가. 원격 PR/통합 push 성공·실패 PR 차단 검증 완료, ADR-013 Accepted.

### IH-101 플레이어 이동·충돌 (Claude Code)

- CharacterBody2D floating Player: 8방향 키보드 이동(속도96 임시값), 4방향 facing·idle/walk, 조작 게이트·포커스 neutral 정책, 임시 Visual, 비활성 기본 Camera2D.
- 1280×720 테스트 맵 `scenes/tests/movement_test.tscn`(외곽·Block·폭20 통로, 카메라 limit). 기본 진입점은 Foundation 유지.
- project.godot: 이동 4액션(WASD physical·화살표 keycode), 물리60Hz, 640×360 viewport/keep/integer, 충돌 레이어 이름.
- `tests/test_player_movement.gd`: 실제 물리·입력 기반 AC-01~12 자동 검사, 2회 반복 비교, 엔진 오류 수집, `--inject-failure`.
- Fixed BUG-001: macOS 시작 시 트리 진입 전 포커스 알림의 null Visual 호출.
- [PR #4](https://github.com/moonhyeonjun/iron-and-harvest/pull/4)로 develop 통합(merge 6575a17). main 미반영.
- 수치·도형은 검증용 임시값이며 최종 밸런스/아트가 아니다. 상호작용·채집·가방·전투·저장·NPC·UI는 미구현. v0.2.0 태그 없음.

### Foundation 확인·IH-101 명세 (Codex)

- Foundation 재검증 완료, 기존 annotated v0.1.0 → d176bd7 및 원격 일치 확인; 태그 유지.
- IH-101 이동/입력/카메라/충돌/표현 상세 명세, AC-01~12 검사 계획, Claude Code 전달 프롬프트 추가.
- ADR-012 Proposed 기록, IH-101은 ready(기능 미구현·검사 미실행). 게임플레이 파일 변경 없음.

## 초기 Foundation 구축 기록 — 2026-10-31 (당시 상태)

### Added

- 요청한 개요·게임 기획·기술 설계·개발 관리·아트 문서 체계.
- Claude 규칙, GitHub Issue/PR 템플릿, Git ignore/줄바꿈 정책.
- `game/` 아래 Godot 4 계열 기반 설정과 기능 없는 빈 씬.
- Foundation 정적 검증 도구와 검증기 회귀 테스트, 로컬 관리 작업 ID.

### Changed

- README/CLAUDE의 문서 진입점을 새 체계로 갱신. 이전 원문은 docs/archive에 보존.
- 이전 상세 기획을 참조 초안으로 구분. 수치·정확한 엔진 버전·라이선스는 미확정으로 관리.

### Not implemented

- 캐릭터 이동·상호작용·채집·경제·저장 등 게임 플레이 기능.
- Godot 실제 import/실행 검증. 최초 구축 당시 Git 실행 여부는 FOUNDATION_REPORT의 역사 기록을 따른다.

## Git 운영 후속 — 2026-10-31

- 최초 Foundation 커밋 957dd3b 생성, main/develop 기준점 구성.
- ADR-010으로 Git/GitHub 자율 운영 정책 수락, 기존 안전 규칙 유지.
- 정책·원격 동기화 결과는 GIT_BOOTSTRAP과 WEEKLY_LOG에서 관리.

## v0.1.0 Foundation — 2026-10-31

- IH-002 완료: Godot4.7.2 Standard / GDScript / Compatibility 검증.
- .godot-version과 버전 검증 실행 도구, 기반 GDScript smoke, Python 실행기 회귀 검사 추가.
- Import/Headless/GUI 종료0 및 사용자 GUI 정상 표시 확인. 엔진 자동 project.godot 포맷 변경 검토.
- Codex 설계·기술/Claude Code 구현 역할을 명시하고 TDD/ADR/작업 상태 갱신.
- 게임플레이는 미구현. Windows/export/성능/Steam 검증은 포함하지 않음.
