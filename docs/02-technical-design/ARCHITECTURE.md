# 아키텍처

## 실제 경로와 경계

저장소 루트는 Git/문서/관리 도구, Godot 루트는 `game/`다. `res://scripts/...`는 `game/scripts/...`이고 `res://game/...`가 아니다. 게임에서 루트 docs/data/tools를 읽지 않는다. 원본 아트는 `art/source/`, 게임용 출력 에셋은 `game/assets/`, 배포 빌드는 무시되는 build/dist/exports에 둔다.

| 경로 | 책임 |
|---|---|
| game/scripts | 씬 어댑터·입력·애플리케이션 작업 흐름 |
| game/systems | 도메인 상태·게임 규칙·명령 처리 |
| game/scenes | 월드/오브젝트 씬 |
| game/ui | UI 씬/스크립트, 읽기 모델과 입력 |
| game/data | 런타임 정의/시작 시나리오 |
| game/tests | 향후 엔진 내부 검증, 현재 실행기 없음 |
| tests | Python 저장소 검증기 회귀 테스트 |
| data/design | 기존 수치 가정 자료, 런타임 사용 금지 |

## Proposed 책임과 의존성

입력/장부 → 명령 검증 → 공유 상태 반영 → 이벤트 → 월드/UI/연대기. 정의 데이터는 읽기 전용, 상태는 인스턴스별로 소유한다. UI가 생산 계산·저장 파일 조작을 맡지 않는다.

| 모듈 | 책임 | 주요 의존/단계 |
|---|---|---|
| Player, Interaction | 이동·대상 탐지·행동 요청 | 입력/월드, v0.2 |
| Inventory, Resource | 수량·예약·이동 원자성 | ItemDef, v0.3 |
| Calendar, Season | 날짜·경계·주기 이벤트 | 저장 상태, v0.4 |
| Building, Production | 건설 진행·입출력·노동 | 자원/시간, v0.5 |
| Trade, Tax | 거래 검증·세금/재정 | 자원/가구, v0.6 이후 |
| Population, Character, Relationship | 노동 자격·인물·관계 | 안정 ID/시간, v0.6~0.7 |
| Event | 조건·결과·중복 방지 | 상태/날짜, 필요 기능부터 |
| Dynasty, Diplomacy, Faction, Law | 계승·계약·파벌·정책 | MVP 이후, 세부 의존 TBD |
| Army, Combat, Siege | 병력·전투·공성·보급 | 경제/영토, MVP 이후 검토 |
| WorldMap, Territory | 지역 연결·소유·접근 | 세계 상태, 확장 단계 |

모든 모듈은 예정 책임이며 클래스 파일이 존재한다는 뜻이 아니다. God Object/과도한 Autoload/ECS/범용 이벤트 프레임워크를 선행 도입하지 않는다.

## 시간·이벤트 제안

이동/표현은 프레임, 영지 생산은 하루, 국가 정책은 월, 역사 집계는 연 단위를 검토한다. 일일 파이프라인 제안은 원료→가공→식사→재정→프로젝트→사건→날짜→검증/저장이다. 월/년 빠른 진행도 일일 효과를 보존해야 한다. 정확한 순서는 IH-120에서 검증 후 확정한다.

Event는 event_id/type/date/actor_ids/target_ids/payload_version을 갖고 상태 반영 후 발행한다. 동일 완료 이벤트를 재수신해도 보상/기록을 중복 적용하지 않는다. 화면 이벤트가 도메인 상태를 재귀 변경하지 않는다.

## 완료 조건·TBD

같은 행동이 생활/장부 어디서 들어와도 동일 검증을 통과하고 동일 상태를 만든다. 재고·인력·하루 진행의 불변식을 테스트한다. 서비스 수/폴더 세분화/이벤트 타입/주기 구현은 실제 기능 시 확정한다.

경로 근거: [Godot 파일 시스템](https://docs.godotengine.org/en/stable/tutorials/scripting/filesystem.html). 기존 루트 src 구조는 참조 초안으로 대체되었다.
