# 2주차 Backend 키워드 — SQL로 데이터 조회하기

> 기준 자료: [2주차 - SQL로 데이터 다루기 (1)](https://makeus-challenge.notion.site/2-SQL-1-3e3b57f4596b80a0bcb0d6382c23691b)

## 1. 요구사항을 SQL로 번역하기

화면 요구사항은 바로 SQL을 쓰기보다 **결과 → 테이블 → 관계 → 조건 → 정렬·범위** 순으로 나누면 안전하다. 예를 들어 “문학 카테고리에서 대여 가능한 책 10개”는 `book`과 `category`를 연결하고, 문학·대여 가능을 `WHERE`에, 최신순·10개를 `ORDER BY`·`LIMIT`에 둔다.

이 순서의 장점은 필요한 테이블과 조건을 빠뜨리지 않는 점이다. 특히 화면에 필요 없는 컬럼까지 `SELECT *`로 가져오는 일을 줄일 수 있다. SQL의 작성 순서는 `SELECT`부터 시작하지만, 데이터가 어떻게 좁혀지는지는 `FROM → JOIN → WHERE → SELECT → ORDER BY → LIMIT`으로 생각하면 이해하기 쉽다.

## 2. DDL과 DML

- **DDL(Data Definition Language)**: 데이터베이스 구조를 정의한다. `CREATE`, `ALTER`, `DROP`이 대표적이다. 이번 실습의 `CREATE TABLE book (...)`은 DDL이다.
- **DML(Data Manipulation Language)**: 테이블 안의 데이터를 다룬다. `INSERT`, `UPDATE`, `DELETE`, `SELECT`가 대표적이다. 더미 데이터를 넣는 `INSERT`와 화면 데이터를 가져오는 `SELECT`가 여기에 해당한다.

DDL을 먼저 실행해 테이블과 FK 관계를 만들고, DML로 더미 데이터를 넣은 뒤 조회해야 한다. 순서가 바뀌면 존재하지 않는 테이블에 데이터를 넣거나, FK가 가리키는 부모 행이 없어 오류가 날 수 있다.

## 3. PK·FK와 JOIN 조건

PK는 한 행을 유일하게 구분하고, FK는 다른 테이블의 PK를 참조해 데이터 관계를 만든다. `book.category_id`는 `category.category_id`를 참조하므로 카테고리 이름이 필요할 때 다음처럼 연결한다.

```sql
JOIN category AS c ON b.category_id = c.category_id
```

`ON`은 두 테이블을 어떤 키로 이어야 하는지 적는 자리다. 관계와 무관한 조건으로 JOIN하면 행이 불필요하게 늘어나는 카테시안 곱이나 중복 결과가 생길 수 있다. 따라서 ERD의 PK/FK 선을 먼저 확인하고 `ON`을 작성하는 습관이 중요하다.

## 4. WHERE와 NULL

`WHERE`는 필요한 행만 남기는 필터다. 이번 실습에서 `is_available = TRUE`는 대여 가능한 책만, `r.user_id = @target_user_id`는 로그인한 사용자의 대여만 남긴다.

`NULL`은 빈 문자열이나 0이 아니라 “값이 아직 없음/알 수 없음”을 뜻한다. 그래서 아직 반납하지 않은 대여는 `returned_at = NULL`이 아니라 `returned_at IS NULL`로 검사해야 한다. SQL의 `=` 비교는 NULL과 비교했을 때 참이 되지 않기 때문이다.

## 5. ORDER BY와 일관된 정렬

목록 화면은 정렬 기준이 없으면 데이터 입력 순서에 따라 순서가 흔들릴 수 있다. `ORDER BY b.book_id DESC`처럼 기준을 명시하면 같은 조건에서 같은 순서로 볼 수 있다.

동점이 생길 수 있는 정렬 기준(예: 같은 생성 시각)을 사용할 때는 PK를 보조 정렬로 추가하는 편이 안정적이다.

```sql
ORDER BY created_at DESC, id DESC
```

## 6. LIMIT / OFFSET과 페이지네이션

`LIMIT`은 가져올 행 수를 제한하고, `OFFSET`은 앞에서 건너뛸 행 수를 정한다. 페이지 크기가 10이면 첫 페이지는 `LIMIT 10 OFFSET 0`, 두 번째 페이지는 `LIMIT 10 OFFSET 10`이다.

OFFSET 방식은 이해하기 쉽지만 뒤 페이지로 갈수록 많은 행을 건너뛰어야 할 수 있다. 데이터가 매우 많고 연속 스크롤이 필요한 서비스에서는 마지막으로 본 정렬 키를 기준으로 이어 읽는 커서 방식도 고려할 수 있다.

## 참고 자료

- [MySQL 9.6 Reference Manual — SELECT](https://dev.mysql.com/doc/refman/9.6/en/select.html)
- [MySQL 9.6 Reference Manual — JOIN Clause](https://dev.mysql.com/doc/refman/9.6/en/join.html)
- [MySQL 9.6 Reference Manual — Problems with NULL Values](https://dev.mysql.com/doc/refman/9.6/en/problems-with-null.html)
- [MySQL 9.6 Reference Manual — LIMIT Clause](https://dev.mysql.com/doc/refman/9.6/en/limit-optimization.html)
