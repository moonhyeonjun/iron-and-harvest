# 저장소 검증 테스트

Python 표준 라이브러리 unittest로 구조 검증기가 누락 리소스·res:// 외부 참조·잘못된 문서 링크·작업 의존성 순환을 실제로 감지하는지 검사한다.

```sh
python3 -m unittest discover -s tests -p 'test_*.py'
```

게임 코드/저장/재미 검사는 아직 없다. test_godot_launcher.py는 엔진 버전/경로 실패 처리를 확인한다. 실제 엔진 smoke는 game/tests/smoke_engine.gd에 있다.
