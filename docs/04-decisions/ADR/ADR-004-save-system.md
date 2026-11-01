# ADR-004: 저장과 마이그레이션

## 상태

Proposed

## 날짜

2026-10-31

## 배경

장기 개발 중 저장 구조가 변한다.

## 검토한 대안

JSON / 바이너리 / Resource 직렬화

## 결정

버전 envelope·검증 후 교체·백업·연속 migration 제안.

## 결정 이유

상태 복원과 실패 복구를 테스트할 수 있음.

## 단점 및 고려사항

원자적 교체/전원 차단은 OS별 검증 필요; 형식 TBD.

## 영향

IH-112부터 구현, 확장 시 fixture 유지.

변경 시 이 문서를 삭제하지 않고 후속 ADR로 대체 관계를 기록한다.

2026-11-01 후속 [ADR-017](ADR-017-versioned-save-restore.md)과 [SAVE_LOAD](../../02-technical-design/SAVE_LOAD.md)에서 IH-112 최소 파일/버전/세션 복원 계약을 제안했다. 이 문서의 초기 방향과 Proposed 상태를 보존한다.
