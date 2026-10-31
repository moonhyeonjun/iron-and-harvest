# Foundation 초기 구축 보고 — 2026-10-31

## 1. 환경 분석 결과

작업 경로는 `/Users/munhyeonjun/Desktop/Project/iron-and-harvest`. 기존14파일과 Git 저장소가 있었다. Git 2.39.3 (Apple Git-145), Python 3.9.6을 확인했다. 최초 상태는 커밋 없는 main이며 origin URL이 이미 설정되어 있었다. 기존 파일은 모두 untracked였다.

Godot/godot4는 PATH와 /Applications, ~/Applications, /opt/homebrew/bin, /usr/local/bin에서 발견하지 못했다. 실제 버전은 TBD이며 모든 디스크를 조사한 것은 아니다. gh도 PATH에 없지만 이번 로컬 관리 작업에 필요하지 않다.

## 2. 구축 완료 항목

요청한 .github/.claude/docs/game/tests 구조와 CONTRIBUTING/CHANGELOG/ignore/attributes/LICENSE 결정 대기를 구성했다. 개요·시스템별 GDD·TDD·데이터·저장·성능·아트 문서에 확정/TBD와 완료 조건을 구분했다. ADR9개, 로컬 작업26개, Claude 규칙4개, GitHub Issue/PR 템플릿4개를 작성했다. CI는 실행 전 제약을 적은 README만 있으며 활성 YAML은 없다.

Godot 루트는 game/. `project.godot`과 빈 Node 씬만 있어 게임 플레이 기능은 없다. 루트 data/design은 이전 수치 검증 자료로 보존하고 런타임 콘텐츠와 분리했다. Foundation 전체는 IH-002 엔진 실행 검증이 남아 있어 완료 버전으로 태그하지 않는다.

## 3. Git 관리 상태

현재 HEAD: feature/project-foundation, unborn. 최초 커밋이 없으므로 main/develop의 실제 branch ref는 아직 없다. 사용자 승인 후 최초 기준점을 만들고 두 브랜치를 구성하는 절차를 CONTRIBUTING에 기록했다. 무조건 기존 브랜치를 재생성하지 않았다.

기존 origin: https://github.com/moonhyeonjun/iron-and-harvest.git. URL 설정만 확인했고 네트워크 접속/접근 권한/원격 기본 브랜치/보호 규칙은 검증하지 않았다. 원격 설정 변경 없음. commit/push/merge/tag/release 없음, stage도 하지 않았다.

`git diff`/`git diff --cached`는 모든 파일이 untracked라 내용이 없었다. 대신 시작 snapshot 비교와 파일 내용/whitespace/정적 검사를 함께 수행했다. README/CLAUDE 갱신 원문은 byte-identical archive로 보존했고 나머지 기존12파일은 byte-identical이다.

## 4. 생성·갱신 파일

신규66개, 갱신2개, 변경 없이 보존12개. 전체 경로는 [FILE_MANIFEST](FILE_MANIFEST.md)에 있다. README/CLAUDE만 현재 진입점으로 갱신했고 기존 원문을 삭제하지 않았다.

## 5. 미확정 설계

Godot 정확한 버전/최종 렌더러, GDScript 최종 도입 검증, JSON/Resource, 저장 포맷/슬롯, 계절 길이/생산량/주민 세부 수/전투 MVP 편입, 아트 규격/제작 비용, 개발 시간/출시일/지원 환경/언어, 라이선스. 이전 24명·14일·8~12시간 등은 참고 가정이며 확정하지 않았다.

## 6. 검증 결과·문제

- `python3 tools/validate_foundation.py`: 필수42파일, 디렉터리, 문서 링크/펜스, res:// 리소스, 작업 의존성, ignore 정책 통과. archive 원문 링크는 의도적으로 제외.
- `python3 -m unittest discover -s tests -p 'test_*.py'`: 6개 통과. 누락/외부 리소스, 정상 경로, 깨진 링크, 의존성 순환/누락 검출 검사.
- `python3 tools/check_economy.py`: 기존 설계 가정 검사7개 통과. 게임 경제 런타임 검증이 아님.
- 기존14파일 보존 검사: 기존12파일 원본 유지, README/CLAUDE 원문 archive 일치.
- 검토 대상80파일 whitespace 검사 오류0. `git diff --check` 통과하나 untracked 포함 검사는 별도로 수행.
- Godot parser/import/실행/화면/성능: 미실행. ENV-001/IH-002에 기록.

LICENSE는 미선택 알림이며 오픈소스 이용 허가가 아니다. 정적 검증 통과를 엔진 호환/게임 완성으로 해석하지 않는다.

## 7. 다음 개발 단계

IH-002에서 엔진 바이너리/버전 확인, 빈 프로젝트 import·headless 실행·실제 창 확인 후 toolchain/ADR/주간 기록을 갱신한다. 이후 작은 기능을 TASKS 순서대로 진행한다. 외부 서비스 등록·결제·게시·Git 이력/원격 변경은 이번 범위에서 하지 않았다.

## 8. 첫 개발 작업 제안

IH-101: 임시 작은 맵의 Player 이동·충돌. 선행은 IH-002. 예상 파일은 game/scripts/player.gd, game/scenes/player.tscn 및 임시 맵, 입력 설정과 관련 테스트. 입력 키·속도·타일 크기는 작업 시작 시 설계 TBD를 검토한다. 장부/경제/농사는 포함하지 않는다.

추천 커밋 메시지: `chore(foundation): establish project structure and development workflow`. 검토 후 명시 승인 전에는 실행하지 않는다.
