## Keyword 정리

## 요구사항 -> SQL

보여줄 항목은 SELECT, 가져올 테이블은 FROM, 다른 테이블과 연결은 JOIN ON, 걸러낼 조건은 WHERE, 그룹 집계는 GROUP BY/HAVING, 정렬과 개수 제한은 ORDER BY/LIMIT로 매핑한다.

## DDL과 DML
DDL(CREATE/ALTER/DROP/TRUNCATE)은 테이블·스키마 구조 자체를 정의하며 대부분 auto-commit이라 롤백이 어렵고, DML(INSERT/UPDATE/DELETE/SELECT)은 행 데이터를 조작하며 트랜잭션으로 롤백할 수 있다. CREATE는 구조를 처음 만드는 것, ALTER는 기존 구조를 바꾸는 것, INSERT는 데이터를 넣는 것이다.

## PK-FK와 JOIN 조건
 PK는 행을 고유하게 식별하고, FK는 다른 테이블의 PK를 참조해 참조 무결성을 보장한다. JOIN의 ON절이 PK-FK 관계가 아니거나 조건이 빠지면 카테시안 곱이 발생해 중복행이 폭증한다.

## WHERE와 NULL
 NULL은 값이 없거나 모른다는 뜻이고 SQL은 TRUE/FALSE/UNKNOWN의 3값 논리를 쓰기 때문에, 컬럼 = NULL은 항상 UNKNOWN이 되어 WHERE에서 자동으로 제외된다. 그래서 NULL 여부는 IS NULL 또는 IS NOT NULL로 확인한다.

## ORDER BY와 일관된 정렬 
ORDER BY가 없으면 결과 순서는 표준상 보장되지 않으며 인덱스나 실행계획에 따라 달라질 수 있다. 정렬 기준값이 같은 행이 여럿이면 그 안의 순서도 보장되지 않으므로, PK 같은 고유 컬럼을 2차 정렬 키로 추가해야 순서가 항상 같게 고정된다.

## LIMIT/OFFSET과 페이지네이션
 LIMIT은 반환할 행 수, OFFSET은 건너뛸 행 수를 뜻하고 페이지 번호는 보통 (page-1)×pageSize로 OFFSET에 매핑한다. OFFSET이 커질수록 DB가 버릴 행까지 다 읽어야 해서 대용량 데이터에서는 점점 느려지며, 그 대안으로 마지막으로 본 행의 키값 이후부터 조회하는 키셋 페이지네이션이 실무에서 널리 쓰인다.
