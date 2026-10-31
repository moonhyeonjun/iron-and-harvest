# IH-004 CI 구축 검증

2026-10-31 (Asia/Seoul), Codex. 상태: **done**. 게임플레이 코드는 변경하지 않았다.

## 변경·통합

- 시작 develop cd06f94, clean. feature/ci-foundation에서 CI workflow/공통 실행기/실패 회귀6개/운영 문서를 추가했다.
- 구현 commit547b117d24a24b6de08db5cfacedd95c62da382f.
- [PR #6](https://github.com/moonhyeonjun/iron-and-harvest/pull/6) → develop, merge e50a8a283310b54be6eeaa81cd25da1b8c033a86. 보호 적용 후 정상 merge 성공, fetch 및 tree 일치 확인.
- main의 파일/커밋과 v0.1.0 태그는 그대로다. main에도 CI 필수 보호를 적용했으므로 다음 develop→main 승격 PR은 CI를 통과해야 한다. 기본브랜치에 workflow가 아직 없어서 workflow_dispatch 수동 실행은 main 승격 후 사용할 수 있다.

## 정상 경로

| 환경·증거 | 결과 |
|---|---|
| 로컬 macOS M1 / Python3.9.6 / 고정 Godot | python3 tools/run_ci.py 전체9단계 종료0 |
| [PR run41210930155](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41210930155) | Ubuntu24.04 / Python3.12.15 / Godot4.7.2, conclusion=success |
| 원격 results.json | 9단계 모두passed=true·exit0; 물리 검사123.659초 |
| 검사 수 | Python17개, 경제 설계7개, IH-101 물리360개(반복2회), 엔진오류0 |
| 로그 artifact | ci-logs-41210930155-1, ID13045384866; 다운로드해 results와 물리 출력 확인 |
| YAML/문서/공백 | Ruby YAML 파싱, Foundation 정적42파일 검사, diff --check 통과 |

통합 후 [develop push run41211192044](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41211192044)도 e50a8a2에서success를 확인했다. PR 합성 merge 검사와 실제 통합 commit 검사가 모두 통과했다.

## 실패 경로·병합 차단

- 독립 experiment/ci-failure-probe에 의도적으로 실패하는 unittest1개만 추가했다(12d099f23328d2fbe632cfa1379d872adeb3c3b5). develop에는 이 파일이 없다.
- [PR #7](https://github.com/moonhyeonjun/iron-and-harvest/pull/7)의 [run41210992257](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41210992257)은 failure. Python18개 중 의도한 실패1개, 이후 엔진 단계는 미실행. 다운로드/Action 단계는 성공했으므로 인프라 실패를 오인한 것이 아니다.
- 실패 artifact13046182736을 내려받아 traceback과 results.json의 exit1/failed 확인. upload step은success여도 job은failure 유지.
- required status check 적용 후 GitHub API에서 PR #7의 mergeable_state=blocked, merged=false 확인. 강제 병합을 시도하지 않았으며 PR은 병합 없이closed로 종료했다. 실험 이력은 검증 증거로 보존한다.
- 실행기 회귀6개: 정상 완료, 성공마커 뒤 exit1, exit0 엔진오류, 마커 누락, timeout, ANSI 오류 감지. 모두통과.

## 원격 보호·권한

이전 main/develop 보호 없음 확인 후 신규 적용했다. 두 브랜치를 다시 GET하여 CI checks(app_id15368/GitHub Actions), strict=true, enforce_admins=true, allow_force_pushes=false, allow_deletions=false 확인. 별도 사람 승인 수를 강제하지 않는다. 기존 규칙/사용자 데이터/이력 삭제 없음.

workflow는 contents:read, checkout credentials 비저장, 공식 Action SHA 고정, 엔진 압축 SHA-256 검증이다. secrets/외부 Godot 설치 Action/캐시/배포 권한 없음. 성공과 실패에서 로그 artifact7일 보존을 확인했다.

## 범위와 다음 단계

Linux headless와 macOS 로컬 검사이며 실제 GUI, Windows, Export, Steam, 고부하 성능을 검증하지 않는다. CI에서 수동 GUI 확인을 대체하지 않는다. 태그/릴리스 추가 없음. IH-004 완료 후 IH-102 상호작용 상세 설계로 이어간다.
