# ADR-011: 검증된 Godot 개발 기준

## 상태·날짜

Accepted, 2026-10-31. ADR-001/002의 검토 대기 결정을 구체화하고 엔진/언어 선택을 대체한다. 이전 ADR 원문은 보존한다.

## 배경

IH-002는 실제로 열고 실행할 수 있는 엔진과 재현 가능한 개발 기반을 확정해야 한다. 현재는 게임플레이 없이 빈 Node 씬이며 초기 코드 마이그레이션 제약이 없다.

## 검토한 대안

- 다운로드에 있던4.4.1: 실제 버전 확인, 오래된 후보를 기준으로 고정할 필요가 없음.
- 4.7.2 Standard: 공식 안정 패치이고 기존 다운로드를 활용 가능. macOS M1에서 Import/Headless/GUI 검증 성공.
- .NET: C# 요구가 없어 SDK/런타임 의존성을 추가할 이유 없음.
- 개발/RC 또는 다른 엔진: 현 요구와 검증 범위를 벗어남.
- Forward+/Mobile: 현재2D 기반에 필요한 근거가 없어 기존 Compatibility를 유지.

## 결정·이유

Godot4.7.2 stable official Standard, 타입 명시 GDScript, Compatibility를 개발 기준으로 채택한다. `.godot-version`과 tools/godot.py로 잘못된 버전 실행을 차단한다. 플랫폼별 설치 경로는 저장소 게임 리소스에 하드코딩하지 않는다.

버전 문자열 `4.7.2.stable.official.ed1daf0bf`는 [공식 릴리스의 커밋](https://godotengine.org/article/maintenance-release-godot-4-7-2/)과 일치했다. 실제 프로젝트 Import와 Headless, 타입 있는 GDScript의 PackedScene 로드/인스턴스화, macOS 그래픽 editor/project 종료 코드0을 확인했다. 사용자가 두 GUI 창의 정상 표시를 확인했다.

## 단점·고려사항

이 결과는 macOS13.4/M1·빈 씬에 한정한다. 다른OS와 배포/성능의 검증을 대체하지 않는다. CUA 서비스가 동작하지 않아 에이전트의 스크린샷 검증은 없으며 GUI 육안 증거는 사용자 확인이다. 자동 버전 업그레이드는 하지 않는다.

## 영향

Codex는 설계·기술 기반·검증을 맡고 Claude Code는 향후 게임 기능 구현을 맡는다. 이번 .gd 파일은 엔진 smoke 테스트이며 게임플레이가 아니다. 이후 IH-101 구현 명세/수락 조건을 정리한 뒤 Claude Code에 전달한다.

IH-001과 IH-002의 Foundation 관문을 충족했으므로 통합/원격 검증 후 v0.1.0 Foundation 태그를 생성할 수 있다. 태그는 게임 출시나 배포 빌드가 아니다.
