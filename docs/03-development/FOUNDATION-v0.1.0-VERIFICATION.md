# Foundation v0.1.0 확정·재검증 기록

확인일: 2026-10-31 (Asia/Seoul). Codex 수행. v0.1.0은 **기술 기반 기준점**이며 게임 출시/배포 버전이 아니다.

## 기존 이력·태그 검증

작업 시작 시 develop, clean working tree. staged/unstaged/untracked 사용자 변경 없음. origin fetch 후 로컬/원격 main과 develop이 모두 d176bd7094db783c2aaf43b2ee227936a5137758임을 확인했다. 기존 변경을 삭제하거나 재작성하지 않았다.

- origin: https://github.com/moonhyeonjun/iron-and-harvest.git
- 기존 annotated tag: v0.1.0
- 태그 객체: 7488fc92e681e1695d9cad0fb793e33afebd6a27
- 태그 대상 커밋: d176bd7094db783c2aaf43b2ee227936a5137758
- git ls-remote의 refs/tags/v0.1.0 및 peeled ref 모두 로컬과 일치.
- 기존 PR #1(feature → develop), PR #2(develop → main) 통합 이력 보존.

따라서 새 태그를 중복 생성하거나 현재 문서 커밋으로 이동하지 않는다. 이번 후속 문서는 기준점 뒤의 별도 이력으로 통합한다. 이후 main/develop이 전진해도 태그 대상은 위 커밋이다. 원격 릴리스/실행파일 배포는 이번 작업 범위가 아니다.

## 완료 관문

| 관문 | 증거 | 판정 |
|---|---|---|
| IH-001 | 문서/구조/규칙/템플릿·정적검사 | done 유지 |
| IH-002 | ADR-011 Accepted, 고정4.7.2, 이전 GUI 확인과 이번 엔진 회귀 | done 유지 |
| Git 통합 | 기존 main/develop 동일 커밋, 비강제 원격 이력 확인 | 충족 |
| 버전 표식 | annotated tag 객체/대상·원격 일치 | 충족 |
| 범위 정직성 | 빈 Foundation 씬, 게임플레이/배포 미구현 명시 | 충족 |

## 이번 재실행

엔진4.7.2.stable.official.ed1daf0bf, 기존 macOS M1 환경. 아래 전부 종료 코드0.

| 명령 | 결과 |
|---|---|
| python3 tools/validate_foundation.py | 필수42파일·디렉터리·문서링크·res 경로·작업 의존·ignore 통과 |
| python3 -m unittest discover -s tests -p 'test_*.py' | 11 tests OK; 의도한 --path 거부 메시지는 실패 경로 테스트 출력 |
| python3 tools/check_economy.py | 7 design checks passed; 런타임 경제 검사가 아님 |
| python3 tools/godot.py --version | 4.7.2.stable.official.ed1daf0bf |
| python3 tools/godot.py --headless --import | Import 성공 |
| python3 tools/godot.py --headless --script res://tests/smoke_engine.gd | typed GDScript·빈 Foundation 인스턴스화 PASS |
| python3 tools/godot.py --headless --quit-after 10 | 정상 종료 |

GUI는 이번 문서 작업에서 다시 열지 않았다. IH-002의 macOS 그래픽 실행 종료0과 사용자 “두 창 모두 정상 표시됨” 확인을 기존 증거로 참조한다. 자동 화면 확인 도구 장애 ENV-003은 해소되었다고 기록하지 않는다. 자세한 GUI 증거/제약은 [IH-002](IH-002-VALIDATION.md).

## 후속 범위

IH-101 명세는 문서만 작성한다. 구현 준비 상태ready이며 AC-01~12는 아직 미실행이다. v0.2.0/게임 출시를 완료로 취급하지 않는다. Windows/Export/Steam/성능/권리 정책은 기존 후속 작업이다. 새 Foundation 결함은 발견되지 않았다.

이번 문서 변경의 commit/통합·원격 결과는 WEEKLY_LOG 후속 기록과 Git 이력에서 확인한다.
