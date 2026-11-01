# IH-004 지속적 통합

상태: 구축·원격 검증 완료. 2026-10-31. 게임 코드 변경 없이 기존 검사를 GitHub Actions로 연결한다. 기준은 [ADR-013](../04-decisions/ADR/ADR-013-continuous-integration.md)이다.

## 실행 계약

`.github/workflows/ci.yml`은 develop/main 대상 pull_request와 두 브랜치의 push, workflow_dispatch에서 실행한다. 경로 필터가 없으므로 문서 PR에도 실행한다. PR은 기본 checkout 동작으로 합성 merge commit을 검사한다. push는 해당 branch commit을 검사한다. 같은 PR/ref의 이전 실행은 취소한다. v0.2.0 승격(PR #16)으로 기본브랜치 main에도 workflow가 반영됐다. PR·develop push·main push 실행을 검증했다. workflow_dispatch 정의도 main에 존재하지만 수동 실행 자체는 아직 검증하지 않았다.

단일 고정 이름 **CI checks**를 병합 관문으로 사용한다. Ubuntu24.04 x86_64, Python3.12, Godot4.7.2 stable official Standard. CI의 Linux headless 검증은 Linux 게임 배포 지원 선언이 아니다. macOS GUI 검증은 별도로 유지한다.

공통 실행 명령:

```sh
python3 tools/run_ci.py
```

커밋된 깨끗한 작업 트리에서 실행한다. 로컬에서는 기존 Godot 탐색 또는 GODOT_BIN을 사용한다. 마지막 검사는 staged/unstaged/untracked 변경을 모두 검사하므로 기존 사용자 수정이 있으면 실패로 보고할 뿐 삭제하지 않는다. Godot Import가 소스나 UID를 새로 만들면 변경을 검토·커밋한 뒤 재실행한다. .godot와 build는 ignore한다.

순서: Foundation 정적 검사 → Python 회귀 → 경제 설계 → 엔진 버전 → Import → 빈 Foundation smoke/실행 → IH-101 물리 suite → IH-102 상호작용 suite → IH-110 인벤토리 suite → IH-111 채집 suite → 소스 트리 청결 검사. 첫 실패 뒤 후속 단계는 미실행으로 끝낸다. IH-101 suite는 내부2회와 cap30/60/120 비교를 포함한다. IH-102 suite(약31초)도 내부2회 반복과 엔진 오류 수집을 포함하며 `RESULT: PASS` 마커가 필수다. IH-110 suite(약8초)도 내부 2회 반복·엔진 오류 수집·`RESULT: PASS` 마커를 갖는다. 단계 목록은 `ci_steps()`에 있고, Python 회귀가 네 gameplay suite의 등록·순서·마커를 검사한다. IH-111 suite(약19초)도 같은 규칙을 따른다. 종료 시 `resources still in use` 같은 엔진 ERROR도 CI 실패이며, 2026-11-01 이 검사로 테스트 쪽 RefCounted 순환을 발견해 고쳤다. 별도의4프로세스 매트릭스는 중복 실행하지 않는다.

## 실패 판정·로그

각 프로세스는 최대300초, 전체 job15분 제한이다. nonzero 종료·timeout·엔진 로그 ERROR/SCRIPT ERROR/Parse Error·필수 smoke/물리 PASS 마커 누락을 실패로 본다. POSIX timeout은 자식 Godot까지 process group을 종료한다. Windows 실행기는 아직 CI 검증 대상이 아니다.

build/ci/의 단계별 .log와 results.json은 실패 시에도 artifact로7일 보존한다. 다운로드 실패는 Actions step 로그를 사용하며 검사 로그 artifact가 없을 수 있다. 로컬 재실행은 동일 로그 이름을 갱신하므로 results.json에 나열된 현재 실행 단계만 이번 결과다. 업로드 성공이 테스트 실패를 성공으로 바꾸지 않는다.

## 의존성과 권한

- checkout v7.0.1, setup-python v7.1.0, upload-artifact v7.0.2: GitHub actions 공식 저장소의 commit SHA로 고정. 실행 시 latest 태그를 따라가지 않는다. 세 Action의 고정 commit 라이선스는 MIT로 확인했으며 런타임 게임에 포함하지 않는다. 교체 영향은 workflow의 checkout/Python 설정/artifact 단계에 한정되며 게임 코드는 의존하지 않는다.
- 엔진 ZIP은 godotengine/godot-builds의4.7.2-stable 릴리스에서 받고 공식 API asset digest의 SHA-256을 tools/ci/godot-linux.sha256에 고정했다. 압축 해제 전 해시, 실행 전 tools/godot.py의 정확한 버전을 검사한다.
- contents:read만 부여, checkout 자격증명 저장 비활성화. 개인 토큰·저장소 secrets·배포 권한을 사용하지 않는다. pull_request_target으로 외부 코드를 실행하지 않는다.
- 캐시는 처음에는 사용하지 않는다. 오래된 .godot import 상태가 결함을 숨기지 않도록 매 실행 새로 Import한다. 엔진 다운로드도 현재는 캐시하지 않는다.
- 게임 배포/Export templates/릴리스 생성은 이 workflow의 책임이 아니다.

## 병합 관문

develop/main의 required status check에 CI checks(app_id15368)를 등록했다. 최신 base 반영(strict)·관리자 포함 검사, force push/브랜치 삭제 금지를 적용한다. 기존 규칙이 발견되면 보존한다. 실제 보호 GET 결과와 실패 PR #7의 blocked 상태를 확인했다. 검증 증거는 [IH-004 기록](../03-development/IH-004-VALIDATION.md)에 있다.

단일 개발이므로 사람 승인 수를 추가하지 않는다. CI 통과는 기능/설계 리뷰를 대신하지 않는다. 보호 적용 후에는 문서 변경도 작업 브랜치 PR로 검증·통합한다. 실패/미완료 상태를 강제 우회하지 않는다.

## 유지보수·제약

엔진 업데이트는 .godot-version, Linux 체크섬, ADR·환경 문서, 실제 CI를 함께 변경한다. Python patch와 Ubuntu 이미지 자체는 hosted runner 업데이트를 따르므로 완전한 bit-for-bit 재현 환경은 아니다. Action 업데이트도 고정 SHA/릴리스 내용 검토 후 PR로 수행한다.

추가 게임 기능은 해당 runner를 명시적으로 등록한다. GUI 조작감·실제 창 포커스/리사이즈·Windows/Steam/성능·Export는 자동 PASS 범위 밖이다. IH-102 구현·회귀를 포함한 v0.2.0 판정과 발행 결과는 [마일스톤 기록](../03-development/CHARACTER-v0.2.0-VERIFICATION.md)을 따른다.

## 공식 근거

- [GitHub workflow 문법](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [GitHub Action 권한·SHA 고정](https://docs.github.com/en/actions/reference/security/secure-use)
- [고정 Godot 릴리스](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)
