# IH-002 Godot 환경 검증 — 2026-10-31

## 결론

**IH-002 done.** Godot4.7.2 Standard, 타입 명시 GDScript, Compatibility를 채택. Codex는 설계/기술 검증만 수행했고 게임플레이 기능은 추가하지 않았다.

시작 브랜치 develop, 시작 SHA478483a, 작업 트리 깨끗함. origin/develop fetch/fast-forward 확인 후 feature/godot-environment에서 작업했다. 기존 앱/파일을 삭제하거나 기존 사용자 변경을 덮어쓰지 않았다.

## 설치·검토

PATH/일반 Applications 조회에는 없었으나 Downloads에서 Godot.app=4.7.2, Godot 2.app=4.4.1 발견. 각각 실제 --version 확인. 4.7.2 Universal arm64/x86_64 바이너리이며 현재 MacBookAir M1 arm64/macOS13.4/RAM8GB에서 사용했다.

기존4.7.2 앱을 `/Users/munhyeonjun/Applications/Godot-4.7.2.app`에 복사. 실행 파일은 앱 내부 `Contents/MacOS/Godot`. 원본/ZIP 보존, 추가 다운로드 없음. codesign --verify --deep --strict 성공. 서명자 Prehensile Tales B.V., 공식 macOS 배포 주체와 일치. --version은 `4.7.2.stable.official.ed1daf0bf`로 공식 릴리스 빌드 커밋과 일치.

선택 이유: 신규 빈 프로젝트이며 이전 버전 호환 부채 없음, 공식 안정 패치/Standard로 GDScript 요구 충족, 현재 macOS에서 실제 성공. .NET/개발 빌드 도입 불필요. 출처·대안은 [ADR-011](../04-decisions/ADR/ADR-011-validated-godot-toolchain.md).

## 실제 실행 기록

모든 명령은 저장소 루트 기준. 도구가 절대 game/ 경로와 고정 버전을 검사한다.

| 검사 | 명령 | 종료 코드 | 소요초 |
|---|---|---:|---:|
| version | `python3 tools/godot.py --version` | 0 | 1.133 |
| import-pinned | `python3 tools/godot.py --headless --import` | 0 | 5.582 |
| gdscript-smoke | `python3 tools/godot.py --headless --script res://tests/smoke_engine.gd` | 0 | 0.578 |
| headless-pinned | `python3 tools/godot.py --headless --quit-after 10` | 0 | 0.526 |
| gui-editor-bounded | `python3 tools/godot.py --display-driver macos --editor --quit-after 120 --max-fps 30` | 0 | 8.719 |
| gui-project-bounded | `python3 tools/godot.py --display-driver macos --quit-after 120 --max-fps 30` | 0 | 6.052 |

Import에서 파일 스캔·클래스·GDExtension/Autoload/플러그인·레이아웃 로드가 완료됐다. GDScript smoke는 `PASS: typed GDScript and Foundation PackedScene instantiation`. GUI 두 실행 로그는 `OpenGL API 4.1 Metal - 83.1 - Compatibility - Using Device: Apple - Apple M1`. ERROR/SCRIPT ERROR/크래시 없음.

별도의 지속 GUI editor/project를 열고 사용자에게 화면 상태를 확인받았다. 사용자 응답: **“두 창 모두 정상 표시됨”**. 이는 오류 대화상자 없이 편집기와 빈 게임 창이 표시된다는 질문에 대한 확인이다. 에이전트의 자동 화면 도구는 `Sky Computer Use service startup request failed`로 실패했으며 직접 스크린샷을 보았다고 주장하지 않는다. 확인한 지속 테스트 프로세스만 종료했고, 이후 bounded GUI 실행도 정상 종료0을 검증했다.

## 발견 사항과 처리

- 기존 탐색 범위에 Downloads가 없었음 → 검색 확장으로 바이너리 발견, 안정된 버전별 앱 경로에 복사.
- GUI 편집기가 project.godot을 표준 형식/4.7 features로 저장 → diff 확인, Compatibility feature 명시. 씬 내용은 변경하지 않음.
- CUA 서비스 오류 → 로그/종료코드 + 사용자 육안 확인으로 보완. 보안/접근 설정을 우회하거나 끄지 않음.
- shasum 도구의 C.UTF-8 locale 경고는 엔진 오류가 아님. 환경 전역 locale은 변경하지 않음.
- 다른버전4.4.1과 혼동 방지 → .godot-version/실행 도구, 잘못된 버전·경로 거부 회귀 검사.

## 검사와 산출물

실제4.4.1 바이너리를 GODOT_BIN으로 지정한 음성 검사도 종료2로 거부했다. Python unittest11개 통과(기존6+실행기5), 정적 Foundation 검사 통과, diff whitespace 확인. 원시 로그/측정 JSON은 `build/ih-002/`에 있어 Git에서 제외된다. 이 문서와 실제 smoke/실행 도구가 재현 가능한 추적 산출물이다. game/.godot은 제외하고 새 .gd.uid는 추적한다.

Codex/Claude 역할과 TOOLCHAIN/TDD/ADR/작업/주간 기록 갱신. 엔진 테스트 외 게임 기능 없음. Windows/export templates·배포·Steam·고부하 성능은 미검증. 기본 운영체제 지원/최소 사양을 이 결과만으로 확정하지 않는다.

## Foundation 판정과 다음 작업

IH-001과 IH-002의 구조·관리·버전·Import/Headless/GUI 검증을 충족했다. v0.1.0 Foundation 태그는 최종 리뷰·develop/main 통합·원격 SHA 확인 후 생성 가능하다. 바이너리 배포나 GitHub 제품 릴리스는 별도 목적이 없어 이번에는 만들지 않는다.

다음 Codex 작업: IH-101을 위한 이동/충돌/상호작용 경계 명세와 검증 기준 작성, 또는 IH-004 CI 기반. 실제 Player 기능은 Claude Code가 이후 구현한다.

## Git 반영

- 구현/검증 커밋: `5cadb74de45c2c3d1f8faeb8e3c5be00b69d2ec7` — chore(toolchain): pin and validate Godot 4.7.2.
- [PR #1](https://github.com/moonhyeonjun/iron-and-harvest/pull/1): feature/godot-environment → develop 병합, `87b6a19bce9c61225bdc1eb15044618645694cab`.
- [PR #2](https://github.com/moonhyeonjun/iron-and-harvest/pull/2): develop → main 병합, `fd376d22b2e5a1566d9e97ef3caa231394eb6977`.
- 원격 병합 commit을 fetch하고 로컬 브랜치를 fast-forward. 검증한 작업 브랜치와 통합 tree 동일성을 git diff --exit-code로 확인했다.
- 이 결과 기록은 docs/ih-002-results에서 문서만 변경한 뒤 develop/main에 fast-forward 반영한다. 코드/테스트는 바뀌지 않는다.
- Foundation 기준 태그는 `v0.1.0`이며 이 최종 결과 기록 커밋을 대상으로 생성한다. 태그 원격 SHA/peeled commit과 main/develop의 일치는 최종 push 후 확인한다. 제품 릴리스는 생성하지 않는다.
- GitHub API 조회 시 Python 기본 CA가 인증서를 찾지 못했으나 시스템 `/etc/ssl/cert.pem`의 검증 컨텍스트로 해결했다. TLS 검증을 끄지 않았고 자격 증명을 저장소/출력에 기록하지 않았다.
