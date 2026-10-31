# 검증된 개발 환경

확인일 2026-10-31. IH-002 완료. 엔진/언어/렌더러 결정은 [ADR-011](../04-decisions/ADR/ADR-011-validated-godot-toolchain.md), 실행 증거는 [검증 보고서](../03-development/IH-002-VALIDATION.md)를 따른다.

## 고정 기준

| 항목 | 검증 결과 |
|---|---|
| Godot | **4.7.2 Standard**, `4.7.2.stable.official.ed1daf0bf` |
| 언어 | 타입을 명시한 GDScript, .NET SDK 불필요 |
| 렌더러 | Compatibility / gl_compatibility |
| macOS | 13.4 (22F66), Apple M1 arm64, RAM8GB |
| 실제 그래픽 로그 | OpenGL API4.1 Metal83.1, Compatibility, Apple M1 |
| 설치 앱 | /Users/munhyeonjun/Applications/Godot-4.7.2.app |
| 실행 파일 | /Users/munhyeonjun/Applications/Godot-4.7.2.app/Contents/MacOS/Godot |
| 프로젝트 | /Users/munhyeonjun/Desktop/Project/iron-and-harvest/game/project.godot |
| Git / Python | 2.39.3 (Apple Git-145) / 3.9.6 |

다운로드 폴더에서 4.7.2 및4.4.1 앱을 발견했다. 4.7.2의 서명 검증과 실제 버전을 확인하고 사용자 Applications의 버전별 경로에 복사했다. 원본 두 앱/ZIP은 보존했다. 추가 다운로드·Homebrew 설치·전역 PATH 변경·격리 속성 제거는 하지 않았다. 앱 서명은 Prehensile Tales B.V.의 Developer ID이고 공식 배포 안내와 일치했다.

## 실행 방법

저장소 루트에서:

```sh
python3 tools/godot.py --version
python3 tools/godot.py --headless --import
python3 tools/godot.py --headless --script res://tests/smoke_engine.gd
python3 tools/godot.py --headless --quit-after 10
python3 tools/godot.py --editor
python3 tools/godot.py
```

`.godot-version`이 패치 버전을 고정한다. 실행 도구는 버전별 사용자/시스템 Applications와 PATH를 탐색하고 정확한 stable official Standard 버전만 허용한다. 루트 `game/`을 자동 지정하므로 `--path`를 따로 넣지 않는다.

다른 설치 위치/Windows/Linux는 환경변수 `GODOT_BIN`에 **실행 파일** 경로를 설정한다. 앱 디렉터리나 명령 옵션을 함께 넣지 않는다. 명시한 경로가 잘못되거나 다른 버전이면 자동으로 다른 엔진으로 넘어가지 않고 실패한다. 전역 셸 설정을 바꿀 필요는 없다.

## 재검증 규칙

패치/마이너 버전 변경도 별도 작업 브랜치와 ADR에서 이유/차이/위험을 기록한다. `.godot-version`, 프로젝트 features, 지원 문서와 테스트를 함께 갱신한다. 새 버전으로만 씬/UID를 다시 저장하고 이전 버전으로 왕복 편집하지 않는다.

GUI 에디터가 project.godot을 표준 포맷으로 저장하고 4.7 feature를 추가하는 것을 확인했다. Compatibility feature를 명시했으며 변경 diff를 검토했다. `.godot/`는 제외하고 `.gd.uid`는 추적한다.

## 검증 한계

macOS의 빈 Foundation 씬과 GDScript smoke만 확인했다. Windows 실행, export templates/배포 빌드, Steam, 고부하 성능, 게임 기능은 미검증이다. 실제 export 시 game/tests를 제외하는 규칙은 해당 작업에서 검증한다. CUA 화면 도구는 서비스 오류가 있어 GUI 육안 확인은 사용자가 수행했다.

## 공식 근거

- [4.7.2 안정판](https://godotengine.org/download/archive/4.7.2-stable/)
- [4.7.2 릴리스·빌드 커밋](https://godotengine.org/article/maintenance-release-godot-4-7-2/)
- [macOS 배포와 서명 안내](https://godotengine.org/download/macos/)
- [시스템 요구사항](https://docs.godotengine.org/en/stable/about/system_requirements.html)
- [명령행 옵션](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)

## IH-004 CI 환경 검증 후속

Ubuntu24.04 x86_64 / Python3.12.15 / Godot4.7.2 Standard의 원격 headless Import·Foundation·IH-101 물리 검사를 통과했다. Linux 배포/GUI 지원 검증과 구분한다. 재현/업데이트/로그는 [CI 운영](CI.md), 실제 run은 [IH-004 기록](../03-development/IH-004-VALIDATION.md)을 따른다.
