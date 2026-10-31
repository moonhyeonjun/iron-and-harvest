# ADR-002: 스크립트 언어

## 상태

Proposed

## 날짜

2026-10-31

## 배경

Godot 프로젝트에서 빠른 기능 반복과 유지보수가 필요하다.

## 검토한 대안

GDScript / C#

## 결정

GDScript 우선 검토, 타입 명시 제안. 현재 .gd 코드 없음.

## 결정 이유

사용자 방향과 작은 기능 단위 개발에 부합.

## 단점 및 고려사항

도구·성능·언어 버전 제약은 실제 기능에서 검증.

## 영향

Player 구현 전에 엔진/코딩 규칙 확인.

변경 시 이 문서를 삭제하지 않고 후속 ADR로 대체 관계를 기록한다.

## 후속 확정

[ADR-011](ADR-011-validated-godot-toolchain.md)이 Godot4.7.2 Standard/GDScript/Compatibility를 실제 검증하여 채택했다. 위 Proposed 본문은 당시 검토 기록이다.
