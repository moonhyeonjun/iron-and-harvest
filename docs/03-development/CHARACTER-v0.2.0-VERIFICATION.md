# v0.2.0 Character 마일스톤 판정 — 2026-11-01

## 발행 결과

**v0.2.0 Character 확정.** 기능 판정과 main 승격 CI가 통과했고 annotated tag의 로컬/원격 객체 및 대상 커밋 일치를 확인했다.

- 태그: [v0.2.0](https://github.com/moonhyeonjun/iron-and-harvest/tree/v0.2.0)
- 대상 main 커밋: `8901bac890393defbfdf438bc2e5b36d7c94b2a3`
- annotated tag 객체: `6a322acfa3b5f825f1877b9ebe0ac82eda39b2c6`
- 판정 문서: commit `66aa9b7`, [PR #15](https://github.com/moonhyeonjun/iron-and-harvest/pull/15), merge `61b2813`.
- main 승격: [PR #16](https://github.com/moonhyeonjun/iron-and-harvest/pull/16), [PR CI 성공](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41272706472), [main push CI 성공](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41272930692). main tree는 승격 원본61b2813과 동일하다.
- main 이력을 포함한 docs/v0.2.0-publication을 PR로 develop에 통합해 발행 기록을 동기화한다. 이는 문서 후속 기록이며 태그를 이동하지 않는다.
- v0.1.0 대상d176bd7과 객체7488fc9는 그대로 보존했다. GitHub Release 페이지·Export 실행파일·Steam 게시는 생성하지 않았다.

## 발행 전 판정


**기능 완료 조건 충족(PASS), main 승격·태그 생성 가능.** 기준은 기존 [MILESTONES](MILESTONES.md)의 “작은 맵에서 이동/대상 조작”과 IH-101/IH-102 수락 조건이다. 이번 판정을 위해 조건을 낮추거나 새 게임 기능을 추가하지 않았다. v0.2.0은 이동·상호작용을 갖춘 개발 기준점이며, 자립 가능한 마을 MVP나 Steam 출시판이 아니다.

검토 기준 develop=`35c70dd8d9248f796250baa6741e40799f4dcea1`. game/tools/tests/.github는 독립 재검증 대상 `69561ca` 및 GUI 확인 빌드 `0332b5a`와 동일하다. 이번 변경은 판정·문서·Git 관리만 포함한다. 기존 v0.1.0 → `d176bd7094db783c2aaf43b2ee227936a5137758`은 보존한다.

기능 판정과 Git 발행을 구분한다. 아래 승격 절차의 CI 성공과 원격 ref 검증 전에는 태그를 발행 완료로 보고하지 않는다. 발행 대상은 검증된 main 병합 커밋이며 Git 태그가 정확한 대상 SHA의 기준이다.

## 완료 조건과 증거

| 관문 | 결과 | 근거 |
|---|---|---|
| Foundation 의존성 | PASS | IH-001/002 done, Godot4.7.2 Standard/GDScript/Compatibility 고정, v0.1.0 보존 |
| 이동·충돌·카메라 | PASS | IH-101 AC-01~12, 물리360검사. 8방향 이동/속도 제한/벽·통로/카메라/4방향 표현/게이트·포커스 회귀. [검증](IH-101-VALIDATION.md) |
| 대상 선택·행동·종료 | PASS | IH-102 AC-I01~12, 333검사. 거리/방향/LOS/동률/중복 ID/입력 큐/재검증/패널/취소·수명. [검증](IH-102-VALIDATION.md) |
| 결함 수정 | PASS | BUG-001~004 resolved. 원래 BUG-003/004 진단은 종료0/위반0, 새 회귀 포함. [리뷰](IH-102-REVIEW.md), [버그](BUGS.md) |
| 실제 화면·조작 | PASS(기존 사용자 확인) | 이동7cd97c1 및 수정된 상호작용0332b5a의 사용자 확인 기록. 후자는 걷기/E/neutral/앱 전환/리사이즈 포함. Codex의 새 GUI 확인으로 주장하지 않음 |
| 전체 회귀·엔진 | PASS | 69561ca clean worktree에서 run_ci.py 10단계, Python19·이동360·상호작용333. 반복33종 차이0·고아0·엔진 오류0. 이후 실행 코드 변경 없음 |
| CI·Git 이력 | 승격 시에도 필수 | IH-004 성공/실패 차단 검증, PR #12/#13/#14 통합. [69561ca CI](https://github.com/moonhyeonjun/iron-and-harvest/actions/runs/41270032260). main/develop CI checks(strict/admins) 유지. 태그는 main CI 성공 이후 |
| 범위·문서 | PASS | 기능은 두 테스트 맵에서 명시 실행. 입력·씬·수락 기준·후속 책임·미확정 값 문서화. 새 gameplay 구현 없음 |

이미 검증한 같은 코드를 이유 없이 로컬에서 반복 실행하지 않는다. 이번 문서 변경은 정적 검사·diff 검토를 하고, 승격 PR과 main push는 저장소 정책에 따라 전체 CI를 실행한다. 원래 작업 트리에는 사용자 미추적 AGENTS.md의 누락 .Codex/rules 링크4개가 있으므로 정적 검사는 clean worktree에서 수행한다. 사용자 파일은 보존한다.

## 포함 기능과 실행

- Player CharacterBody2D floating 이동, 충돌, 카메라, idle/walk·방향 표현, 포커스/neutral 조작 게이트.
- InteractionController/Target/UI 분리, 가까운 정면 대상 선택, E 살펴보기, 설명 패널, 닫기/Escape, 중복 요청·수명·취소 검증.
- 임시 지형과 안내판·상자. 아이템을 지급하지 않는 읽기 전용 상호작용이다.
- 고정 엔진/의존성을 사용하는 CI와 Python·Godot 검사.

```sh
python3 tools/godot.py res://scenes/tests/movement_test.tscn
python3 tools/godot.py res://scenes/tests/interaction_test.tscn
```

기본 main_scene은 빈 Foundation이다. 위 명시 실행 방식은 최초 IH-101/102 계약이며 이번 버전에서 임의로 바꾸지 않는다. Godot 버전은4.7.2, 게임 마일스톤 태그는v0.2.0으로 서로 다른 버전이다.

## 후속 과제와 비차단 근거

| 항목 | v0.2.0 판단 | 후속 책임 |
|---|---|---|
| DEBT-002 단일 이동 게이트 | 현재 단일 상호작용 패널에는 적용 가능. 동시 모달 지원을 완료했다고 보지 않음 | 다중 모달/전투 도입 전 조율 설계 |
| DEBT-003 한글 fallback | macOS 테스트 확인만 유효. 배포 OS 글꼴 보장은 없음 | IH-006/IH-003 |
| ADR-012/014 Proposed | 구현 계약은 검증됐지만 최종 조작·아트·수치 수락은 별개. Accepted는 이 마일스톤의 기존 필수 조건이 아님 | 후속 플레이테스트·제품 결정; 상태 유지 |
| LICENSE 미확정 | 소스 기준점 태그의 기술 판정과 제품 배포 권리 결정을 구분 | IH-003, 소유자 결정 전 제품 배포 없음 |
| GUI 자동화 제한 ENV-003 | 기존 사용자 확인을 증거로 사용, 새 자동 GUI 성공으로 기록하지 않음 | 환경 접근 가능 시 재검토 |
| Windows/Linux GUI, Export, Steam | 이번 완료 조건 밖이며 검증 미실행 | IH-180/IH-190 |
| 수집·가방·저장·생활 경제 | v0.3 이후 기능이며 이번 완료 판정에 포함하지 않음 | IH-110→111→112 |

## Git 승격 절차

1. develop 기반 docs/v0.2.0-milestone에 판정·문서 정리를 커밋한다.
2. 필수 CI 통과 후 PR로 develop에 통합한다.
3. develop→main 승격 PR을 만들고 합성 병합 커밋의 CI와 변경 범위를 검토한다.
4. main에 병합한 뒤 main push CI 성공과 검증한 tree 동일성을 확인한다.
5. 기존 local/remote v0.2.0이 없음을 확인해 main 커밋에 annotated tag를 생성·push하고 객체/peeled SHA를 대조한다. 기존 태그 덮어쓰기 금지.
6. main 승격 이력을 PR로 develop에 동기화하고 발행 결과를 기록한다.

실행파일 배포나 GitHub 제품 릴리스는 이번 판정의 산출물이 아니다. GitHub Release 페이지는 만들지 않고 소스 태그로 기준점을 남긴다. 다음 작업은 IH-110 상세 설계이며, 이번에 기능 구현이나 IH-110 ready 전환을 선행하지 않는다.
