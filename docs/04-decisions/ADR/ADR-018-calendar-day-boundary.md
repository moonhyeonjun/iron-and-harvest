# ADR-018: 정수 달력과 새벽 하루 경계·schema2 이관

- 상태: **Proposed** (2026-11-02 구현·자동 검증 완료, Accepted 판단 전)
- 날짜: 2026-11-01
- 관련: IH-120, [CALENDAR](../../02-technical-design/CALENDAR.md), [수락 조건](../../03-development/IH-120-ACCEPTANCE.md), ADR-005(장기 시간 방향), ADR-017(Accepted 초기 저장)

## 배경

농사와 생산이 사용할 날짜 경계가 필요하다. 현재 schema1에는 시간이 없고 정확한7개 payload 키만 허용한다. 선택 필드를 조용히 추가하거나 live 세계를 순서대로 복원하면 버전·세션 일관성을 잃는다. 이동/모달/저장에는 기존 게이트·정지 경계가 있다.

## 검토한 대안

- OS 시간/오프라인 경과: 시계 변경·휴면·보상/결산의 새 계약이 필요해 제외한다.
- float 총시간/매frame Timer 누적: 저장 반올림·분할 차이·정의 복제 위험이 늘어난다.
- 정수 physics tick+단일 day_index: 렌더 FPS와 분리하고 기본60Hz·프로필·한도를 검증하기 쉽다. 시뮬레이션 지연을 벽시계로 보충하지 않는 제한을 수용한다.
- 전역 SceneTree.paused/새 이동 잠금: 시간만 멈추기와 기존 Player ALWAYS·물리 staging에 영향을 준다. 작은 Controller의 정지 합성·명령 가드를 사용한다.
- 범용 결산 플러그인 선행: 아직 농사/생산이 없어 추상화와 rollback 계약이 과하다. 현재 날짜 알림과 snapshot만 검증한다.
- schema1 optional calendar: 구버전과 필드 누락을 구분할 수 없다. schema2 필수 객체와 검증된0→1→2 이관을 제안한다.

## 결정 제안·이유

CalendarService가 rule_id/day_index/tick_in_day/revision을 소유하고 계절·연도·시각은 파생한다. 기본 제안은14일×4계절·06:00 시작·36000tick/하루·60Hz, 빠른 fixture는2일×4계절·120tick이다. 제품 밸런스와 생애 연령 변환은 TBD다. 프로필 ID는 저장 호환 식별자이므로 같은 ID의 의미를 조용히 바꾸지 않는다.

전진은 사전 검증→원자 설치→단일 날짜 알림 순서이며 보고 중 재진입/저장은 BUSY다. N pending1건을 다음 물리 step에서 재검증한 뒤 자연 시간과 같은 API로 처리하고 그 step의 자동 tick을 생략한다. 정지 사유는 독립 보존하며 휴면/포커스 복귀 때 시간을 보충하지 않는다. Player 이동 게이트 작성자는 추가하지 않는다.

교체 World 밖 Controller가 현재 coordinator world/epoch만 tick한다. 월드 안 서비스는 후보 동안 suspended, 이탈 뒤 closed다. SaveCoordinator의 선택적 외부 blocker로 pending/보고와 save/load를 직렬화한다. 기존 독립 맵은 passive calendar, 새 calendar_test만 자연 시간을 사용한다.

schema2는 calendar 필수·content1 유지다. 정상v1 검증 뒤 기본 달력을 넣고 원본 파일을 수정하지 않는다. 시험v0는 먼저 정확한 schema1로 이관한다. Accepted ADR-017의 과거 schema1 계약을 소급 변경하지 않으며 구현 뒤 지원 범위 확장 근거를 남긴다.

## 단점·고려사항

실시간은 처리된 물리 스텝 기준이며 저사양/휴면 중 느려질 수 있고 오프라인 보상은 없다. 시간 정지는 게임 전체 정지가 아님을 UI에 명시한다. 압축 연도와 인물 노화·국가 월간 단위는 별도 설계다. 날짜 알림은 경제 상태의 원자 결산이나 세션을 넘는 영구 exactly-once 보상을 보장하지 않는다.

기존 codec/manifest/회귀 예상값을 수정해야 한다. 기존 schema2_future fixture와 새3+ 미래 검사를 구분한다. v0.3.0은 새 schema2를 거부·보존하는 것이 정상이다. 전원 차단·Windows·Cloud 제약을 해소하지 않는다.

## 영향·검증 관문

Rules/Service·외부 Controller/HUD·전용 맵, gathering의 snapshot/restore/suspend/close, Codec2/fixture·Coordinator의 작은 hook·CI 등록과 문서가 필요하다. 구현 차이를 기록하며 장기 기반이라는 이유로 범위를 늘리지 않는다.

C01~16·기존 회귀·진짜 구버전/중간 이관·실패/수명/재진입·변이·반복·실제 GUI·필수 PR CI/develop 통합 후 Codex가 done/Accepted를 판단한다. ADR-005는 장기 방향 Proposed로 보존하며 이번 결정은 초기 시간 부분만 구체화한다. 월간/노화·제품 수치 전체를 승인하지 않는다.

## 구현 검증 결과 (2026-11-02)

Claude Code가 제안대로 구현했다([검증 기록](../../03-development/IH-120-VALIDATION.md)).
- 정수 상태와 파생 날짜, 06:00 경계, 원자 전진과 1회 알림
- 정지 사유 합성, N pending, 외부 blocker
- schema2와 0→1→2 이관

AC-C01~15 334검사, 변이 8종, 별도 프로세스, CI 14단계로 확인했다. GUI는 사용자 일부 확인과, 사용자 지시에 따른 Claude 조작 렌더 창 확인으로 나뉜다.

구현 차이:
- 이관 rule ID 고정
- `is_busy`가 보고 중 포함
- HUD layer 1

증거와 별개로 Accepted 전환은 Codex 판단에 남기며, 상태는 Proposed다.
