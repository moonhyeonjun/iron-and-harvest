# 저장·불러오기

상태: 설계 Proposed, 저장 구현 없음. v0.3부터 상태가 생기는 범위에 맞춰 증분 구현하며 v0.8에서 통합 검증한다.

## 포함할 상태

플레이어 위치/장비, 인벤토리와 예약, 건물/진행량/배치, 자원/재정, NPC/관계, 영지/정책, 시간/계절, 세계 플래그/사건/연대기. 가문/왕조는 해당 기능이 구현될 때 migration과 함께 추가하며 초기부터 가짜 데이터를 만들지 않는다.

## 포맷 초안

SaveEnvelope(schema_version, content_version, build_id, engine_version, world, rng_states). 첫 스키마 버전은 실제 저장 구현 시 정의한다. 날짜별 결산 ID, 미해결 사건, 직접/위임 프로젝트를 복원해 재실행 이득을 막는다. 표시 문자열 대신 안정 ID를 저장한다.

사용자 데이터는 `user://`에 쓰며 배포 후 읽기 전용일 수 있는 `res://`에 쓰지 않는다. [Godot 저장 문서](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)

## 안정성 제안

안정 시점 snapshot → 임시 파일 쓰기/닫기 → 재파싱 검증 → 기존 유효본 백업 → 교체. 교체의 원자성/전원 차단 내구성은 OS별 테스트한다. 로드는 별도 상태에 parse→version/migrate→참조 검증 후 교체하고 실패하면 현재 플레이를 보존한다.

마이그레이션은 vN→vN+1 순서, 원본 보존, fixture 회귀. 미래 스키마는 조용히 읽지 말고 거부한다. 삭제된 아이템/인물 ID는 alias/보상/기록 보존 정책을 명시한다. 64비트 RNG 값을 JSON에 넣는 경우 정밀도 보존 방식도 검증한다.

## 완료 조건

저장 왕복, 구버전 fixture, 잘못된 JSON/누락 ID/미래 버전, 쓰기 실패·프로세스 중단, 같은 일자 중복 결산, 프로젝트 완료 중복이 검사되어야 한다. 슬롯/자동저장/백업 UI의 실제 동작도 확인한다.

## TBD

파일 형식·슬롯 수·압축·자동저장 시점·지원 버전 범위·Steam Cloud. 기존 3슬롯+3자동저장은 확정하지 않는다.

## IH-110과의 경계

[인벤토리 명세](INVENTORY.md)는 ID·capacity·revision·slots의 순수 값 snapshot과 새 상태로의 메모리 왕복만 정의한다. 디스크 쓰기/SaveEnvelope/schema_version은 구현하지 않는다. 활성 ID 덮어쓰기·revision 되감기는 허용하지 않으며 IH-112가 새 세션 복원과 UI 요청 무효화를 함께 설계한다. JSON 숫자 변환/손상·미래 버전/아이템 ID migration은 저장 어댑터 책임으로 남는다.

## IH-111과 IH-112 인계

[채집 명세](GATHERING.md)는 PointBinding 목록과 숨은 지점 재고 snapshot을 저장 대상 후보로 지정한다. remaining/depleted를 중복 저장하지 않는다. 같은 세션 뷰 재바인딩은 파일 저장이 아니다. IH-112 복원은 초기 지급 없는 새 컨텍스트에서 정의/품목/owner/capacity/ID 참조를 검증하고 교체하는 방향이며, 실패 시 현재 상태를 보존한다. 준비 명령/뷰/WeakRef/request ID는 저장하지 않는다. 실제 포맷·스키마·migration은 아직 미정이다.
