# IH-112 저장 fixture

런타임 원본이 아니다. `test_save_load.gd`가 실제 파일 바이트로 decode·선택·이관·거부를 검사한다. 모든 파일의 sha256은 payload_json 원문 UTF-8 바이트와 일치한다.

| 파일 | 내용 | 기대 |
|---|---|---|
| `v1_valid.json` | schema1/content1/generation3. branch 5(rev1), berry 소진 null(rev3), 가방 wood6·berry3, 보관함 wood3, 위치 x=228.12345(float32) 오른쪽 | 정상 로드 |
| `v0_valid.json` | 같은 재고, generation2, player.facing 없음(시험 전용 schema0) | facing=down으로 이관, 수량/revision/generation 유지, 원본 불변 |
| `schema2_future.json` | schema2와 알 수 없는 키 `weather` | UNSUPPORTED_SCHEMA → 은행 INCOMPATIBLE, 덮어쓰기 거부 |
| `content2.json` | content_version 2 | CONTENT_MISMATCH → 은행 INCOMPATIBLE |

생성: 2026-11-01. 실제 GatherService/InventoryService 거래 결과를 SaveCodec.encode로 기록했다(v0/미래 파일은 같은 payload에서 버전 필드만 바꾸고 hash를 다시 계산했다). 실제 출시된 구버전 저장이 있다는 뜻이 아니다.
