# 개발 환경 확인

확인일 2026-10-31. 이 표는 설치를 가정하지 않고 실제 조회한 결과다.

| 항목 | 결과 |
|---|---|
| 작업 경로 | /Users/munhyeonjun/Desktop/Project/iron-and-harvest |
| 셸 | zsh |
| Git | /usr/bin/git, 2.39.3 (Apple Git-145) |
| Python | /Library/Frameworks/Python.framework/Versions/3.9/bin/python3, 실행 결과 3.9.6 |
| godot / godot4 | PATH에서 발견되지 않음 |
| 일반 앱/실행 경로 | /Applications, ~/Applications, /opt/homebrew/bin, /usr/local/bin에서 Godot 이름의 항목 없음 |
| gh | PATH에서 발견되지 않음; 로컬 템플릿/TASKS 작업에는 필요 없음 |
| Godot 정확한 버전 | TBD, 설치/실행 검증 대기 |
| 엔진 기반 파일 | Godot 4 계열 최소 설정과 빈 Node 씬, 실제 import 미검증 |

모든 디스크를 검색한 것은 아니므로 Godot이 전혀 설치되지 않았다고 단정하지 않는다. IH-002에서 실행 파일을 확보/식별하고 `--version`을 기록한다. 대용량 다운로드나 전역 환경 변경은 이번 작업에 포함하지 않는다.

## 엔진 확보 후 확인 순서

```sh
godot --version
godot --headless --path game --editor --quit
godot --headless --path game --quit-after 2
godot --path game
```

실제 바이너리 경로로 대체한다. 첫 두 엔진 검사는 import/짧은 빈 씬 실행이며 게임 플레이가 아니다. 종료 코드·오류·실제 창 결과를 WEEKLY_LOG에 기록한 뒤 버전/렌더러 ADR을 확정한다.

## TBD

Windows 검증 장비, export templates, GDScript 도구, 테스트 플러그인, CI 환경, 외부 라이브러리. 현재 추가 패키지 설치는 없다.
