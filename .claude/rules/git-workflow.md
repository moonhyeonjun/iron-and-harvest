# Git 자율 운영 규칙

2026-10-31 사용자 최신 지시에 따라 이전 승인 대기 정책을 대체한다. ADR-010이 현재 기준이다.

- 시작: git status/현재 브랜치/기존 diff·staged·untracked와 원격 상태 확인.
- 작업 목적과 완료 조건에 맞는 stage/commit, 브랜치 생성·전환·병합·삭제, fetch/pull/push, Issue/PR 생성·종료·병합, 원격 설정 변경, 검증된 태그/릴리스는 별도 사용자 승인 없이 수행한다.
- develop에서 작업 브랜치 분기 → 작은 기능/검증 → Conventional Commit → 필요한 push/PR/merge → develop 통합 → 안정화 후 main 반영.
- 모든 단계는 항상 필요한 것이 아니다. 초기 빈 저장소의 기준점은 로컬 검증과 초기 push로 구성한다.
- 관련 Issue가 있으면 연결한다. 원격 ref·PR 상태·태그·릴리스의 실제 반영을 확인한다.
- untracked도 사용자 작업이다. 기존 변경/브랜치/원격 이력을 임의 삭제·교체하지 않는다.
- reset --hard, clean -fd, force/force-with-lease push, 임의 이력 재작성은 기본적으로 하지 않는다. 백업·복구 가능한 병합 대안을 먼저 적용한다.
- 안전한 대안이 없거나 충돌의 파일별 의도를 판단할 수 없으면 사용자에게 확인한다.
- 커밋 해시·변경·검증·push/merge 결과를 문서에 기록한다. 미실행·실패를 성공으로 기록하지 않는다.
- 기능 완료 조건을 충족한 버전만 태그/릴리스한다. Foundation은 IH-001/IH-002 검증과 통합 완료를 근거로만 v0.1.0 태그를 생성한다. 게임 출시와 구분한다.
- 이 권한은 Git/GitHub 개발 라이프사이클 범위다. Steam 출시·결제·라이선스 결정은 별도 범위다.

- IH-004 보호 적용: main/develop은 GitHub Actions의 CI checks 성공과 최신 base 반영이 필수이며 관리자도 적용된다. 후속 문서 변경도 작업 브랜치 PR로 검증한다. 실패·미완료 검사를 우회하거나 보호를 일시 해제하지 않는다. 운영/로컬 재현은 docs/02-technical-design/CI.md를 따른다.
