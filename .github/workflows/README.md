# CI workflow

ci.yml은 develop/main PR·push와 수동 실행에서 고정 Godot의 headless 검사와 저장소 검사를 실행한다. IH-004의 정상/실패 PR와 develop push 검증을 완료했다. workflow_dispatch는 기본 main에 workflow가 포함되는 다음 승격 이후 사용할 수 있다.

권한·고정 버전·실패 정책·로그·로컬 명령은 [CI 운영](../../docs/02-technical-design/CI.md)을 따른다. GUI/게임 배포/릴리스는 포함하지 않는다.
