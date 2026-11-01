# 저장·불러오기

상태: 장기 방향 Proposed. IH-112 최소 저장(단일 수동 A/B 슬롯)은 2026-11-01에 구현했고 review 상태다([검증](../03-development/IH-112-VALIDATION.md)). IH-112의 구현 가능한 최소 계약은 [SAVE_LOAD](SAVE_LOAD.md), [AC-S01~16](../03-development/IH-112-ACCEPTANCE.md), [인수인계](../03-development/IH-112-HANDOFF.md)에 구체화했다(2026-11-01 최초 설계 ready, 현재 review). 아래 장기 대상 전체를 이번에 구현하지 않는다.

## 포함할 상태

플레이어 위치/장비, 인벤토리와 예약, 건물/진행량/배치, 자원/재정, NPC/관계, 영지/정책, 시간/계절, 세계 플래그/사건/연대기. 가문/왕조는 해당 기능이 구현될 때 migration과 함께 추가하며 초기부터 가짜 데이터를 만들지 않는다.

## 포맷 초안

SaveEnvelope(schema_version, content_version, build_id, engine_version, world, rng_states). IH-112에서는 schema1/content1·단일 수동 슬롯 A/B 두 세대·원시 JSON payload 문자열과 checksum을 제안한다. 장기 envelope 확장은 별도 버전에서 한다. 날짜별 결산 ID, 미해결 사건, 직접/위임 프로젝트를 복원해 재실행 이득을 막는다. 표시 문자열 대신 안정 ID를 저장한다.

사용자 데이터는 `user://`에 쓰며 배포 후 읽기 전용일 수 있는 `res://`에 쓰지 않는다. [Godot 저장 문서](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)

## 안정성 제안

안정 시점 snapshot → 임시 파일 쓰기/닫기 → 재파싱 검증 → 기존 유효본 백업 → 교체. 교체의 원자성/전원 차단 내구성은 OS별 테스트한다. 로드는 별도 상태에 parse→version/migrate→참조 검증 후 교체하고 실패하면 현재 플레이를 보존한다.

마이그레이션은 vN→vN+1 순서, 원본 보존, fixture 회귀. 미래 스키마는 조용히 읽지 말고 거부한다. 삭제된 아이템/인물 ID는 alias/보상/기록 보존 정책을 명시한다. 64비트 RNG 값을 JSON에 넣는 경우 정밀도 보존 방식도 검증한다.

## 완료 조건

저장 왕복, 구버전 fixture, 잘못된 JSON/누락 ID/미래 버전, 쓰기 실패·프로세스 중단, 같은 일자 중복 결산, 프로젝트 완료 중복이 검사되어야 한다. 슬롯/자동저장/백업 UI의 실제 동작도 확인한다.

## TBD

제품 슬롯 수·압축·자동저장 시점·장기 지원 버전 범위·Steam Cloud는 TBD다. IH-112는 UTF-8 JSON·수동 슬롯1개·schema1/시험v0만 제안한다. 기존 3슬롯+3자동저장은 확정하지 않는다.

## IH-110과의 경계

[인벤토리 명세](INVENTORY.md)는 ID·capacity·revision·slots의 순수 값 snapshot과 새 상태로의 메모리 왕복만 정의한다. 디스크 쓰기/SaveEnvelope/schema_version은 구현하지 않는다. 활성 ID 덮어쓰기·revision 되감기는 허용하지 않으며 IH-112가 새 세션 복원과 UI 요청 무효화를 함께 설계한다. JSON 숫자 변환/손상·미래 버전/아이템 ID migration은 저장 어댑터 책임으로 남는다.

## IH-111과 IH-112 인계

[채집 명세](GATHERING.md)는 PointBinding 목록과 숨은 지점 재고 snapshot을 저장 대상 후보로 지정한다. remaining/depleted를 중복 저장하지 않는다. 같은 세션 뷰 재바인딩은 파일 저장이 아니다. IH-112 복원은 초기 지급 없는 새 컨텍스트에서 정의/품목/owner/capacity/ID 참조를 검증하고 교체하는 방향이며, 실패 시 현재 상태를 보존한다. 준비 명령/뷰/WeakRef/request ID는 저장하지 않는다. 초기 포맷·schema1/시험v0 migration·후보 세션 publish는 SAVE_LOAD에서 제안했다. 실제 구현·호환 검증은 아직 없고 제품 장기 migration은 후속이다.

## IH-112 현재 검토

초기 파일 저장·복원은 구현됐고 자동13단계·저장425검사를 통과했다. Codex 후속 검토에서 [BUG-009~011](../03-development/IH-112-REVIEW.md)을 재현해 review다. GUI 손상복구 미확인도 별개로 유지한다. 최초 설계/장기 방향과 현재 구현 판정을 구분한다.
