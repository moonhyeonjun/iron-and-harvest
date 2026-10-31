# Godot 기반 검증

현재 smoke_engine.gd는 타입 있는 GDScript 실행과 configured Foundation PackedScene 로드/인스턴스화를 확인한다. 게임플레이·사용자 데이터 변경 없음.

```sh
python3 tools/godot.py --headless --script res://tests/smoke_engine.gd
```

저장소 루트에서 실행한다. 이후 실제 씬 구성이 바뀌면 이 Foundation 전용 검사도 해당 마일스톤 계약에 맞춰 갱신한다. export에서 tests 리소스를 제외하는 정책은 배포 단계에서 검증한다.
