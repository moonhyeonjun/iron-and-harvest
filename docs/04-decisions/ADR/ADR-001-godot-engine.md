# ADR-001: 게임 엔진 선택

## 상태

Proposed

## 날짜

2026-10-31

## 배경

2D 생활/경영 게임을 작게 검증할 엔진이 필요하다.

## 검토한 대안

Godot 4 계열 / 다른 2D 엔진

## 결정

Godot을 우선 검토하고 game/에 최소 프로젝트만 구성. 정확한 버전은 TBD.

## 결정 이유

사용자 우선 검토 방향과 데이터 중심 2D 개발에 맞는 후보.

## 단점 및 고려사항

설치/실행 미검증; 버전별 API·export 환경 확인 필요.

## 영향

IH-002에서 실제 import/실행 후 수락 여부 기록.

변경 시 이 문서를 삭제하지 않고 후속 ADR로 대체 관계를 기록한다.

## 후속 확정

[ADR-011](ADR-011-validated-godot-toolchain.md)이 Godot4.7.2 Standard/GDScript/Compatibility를 실제 검증하여 채택했다. 위 Proposed 본문은 당시 검토 기록이다.
