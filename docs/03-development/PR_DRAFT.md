# 로컬 PR 준비 초안 — Foundation

상태: 원격 PR 아님. 아직 커밋이 없어 정상 compare/PR을 만들 수 없다. 승인 후 최초 기준점 구성과 일반 develop 대상 흐름을 시작한다.

## 변경 사항과 이유

프로젝트를 장기간 관리하기 위해 사용자 지정 문서 체계, Git/Claude 규칙, Issue/PR 템플릿, 빈 Godot 기반 파일과 검증을 구성한다. 게임 플레이는 구현하지 않는다. 기존 설계/도구는 보존하고 README/CLAUDE 원문을 archive에 남긴다.

## 관련 작업

IH-001, IH-002(엔진 검증 미완료).

## 검증

실제 명령/결과는 WEEKLY_LOG.md와 FOUNDATION_REPORT.md를 참조한다. 정적 경로 검사는 Godot import를 대신하지 않는다. UI 변경이 없어 스크린샷/영상은 해당 없음.

## 검토할 점

미확정 수치의 분리, res:// 루트, unborn Git 상태, 라이선스 미선택, 기존 원문 보존, 테스트의 실제 범위.

추천 커밋 메시지: `chore(foundation): establish project structure and development workflow`.

commit/push/merge/tag/release/remote 변경은 각각 사용자 승인 전 실행하지 않는다.
