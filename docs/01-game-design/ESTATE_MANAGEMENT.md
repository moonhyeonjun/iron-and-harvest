# 영지 관리

## 목적·경험

작은 시설과 주민을 조직해 생활 문제를 지속적으로 해결하고 자립하는 영지를 만든다. 직접 작업이 장기 위임으로 이어진다.

## 주요 기능

MVP: 건설/수리, 인력 배치, 생산 상태, 세금/재정, 주요 인물 임명, 자립 목표. 후보 건물은 농장·벌목장·광산·대장간·시장·주점·병영·제재소·제분소·빵집·창고·교회·성채이며 약10종을 선택한다. 이전 10종 목록은 Proposed다.

## 데이터와 연결

BuildingDef(cost, jobs, recipe_id, upkeep), BuildingState(id, plot, progress, workers, status), Assignment(character_id, target_id), EstateState(resources, policies, reputation). 비용은 공통 원장, 작업자는 공통 주민 ID를 참조한다. 직접/위임은 하나의 수리/건설 진행 상태를 사용한다.

## 우선순위·완료 조건

v0.5 건설·생산, v0.6 경영, v0.7 인물. 자원 부족 시 시작 거부, 인력 이중 배치 방지, 취소 환급 한 번, 완료 시 시설과 장부 일치, 자립 조건을 명시적으로 평가한다.

## TBD

자유/지정부지 배치, 건물 확정 목록, 비용/유지비/인원, 권한 위임 범위, 세율, 자립 판정 수치. 봉신·법률·외교·군대는 MVP 이후다. 전체 완성 기준은 [마일스톤](../03-development/MILESTONES.md)에 둔다.
