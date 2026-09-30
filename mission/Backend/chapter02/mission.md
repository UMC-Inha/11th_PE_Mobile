# 2주차 Backend 미션 — SQL로 화면 데이터 조회하기

> 기준 자료: [2주차 - SQL로 데이터 다루기 (1)](https://makeus-challenge.notion.site/2-SQL-1-3e3b57f4596b80a0bcb0d6382c23691b)

## 1. 목표와 준비

온라인 도서 대여 서비스의 기준 ERD를 MySQL 테이블과 더미 데이터로 구현하고, 화면 요구사항에 맞는 조회 SQL 3개를 작성했다. 마지막에는 1주차에 설계한 지역별 가게 방문 리워드 서비스 ERD에 같은 방식을 적용했다.

실행 순서:

```text
sql/01_schema.sql → sql/02_seed.sql → sql/03_mission_queries.sql → sql/04_week01_reward_extension.sql
```

로컬 MySQL Community Server `26.7.0`에서 실행했다. 실행 출력은 [`sql/execution_results.txt`](sql/execution_results.txt)에 남겼다.

## 2. 공통 실습: 온라인 도서 대여 관리 시스템

### 미션 1 — 문학 카테고리의 대여 가능한 도서

요구사항: 문학 카테고리에서 대여 가능한 도서를 최신순으로 최대 10개 조회한다.

```sql
SELECT b.title, b.description, c.name AS category_name
FROM book AS b
JOIN category AS c ON b.category_id = c.category_id
WHERE c.name = '문학' AND b.is_available = TRUE
ORDER BY b.book_id DESC
LIMIT 10;
```

- 기준 테이블은 화면에 보여 줄 책 정보를 가진 `book`이다. 카테고리 이름은 `category`에 있으므로 `book.category_id = category.category_id`로 JOIN했다.
- `WHERE`에서 문학과 대여 가능 상태를 함께 제한했다. `book_id DESC`와 `LIMIT 10`으로 최신순 목록 범위를 고정했다.
- 검증: 더미 데이터에서 문학 책 두 권 중 `겨울의 편지`는 대여 불가이므로 `달빛 도서관` 한 권만 조회됐다.

| title | description | category_name |
| --- | --- | --- |
| 달빛 도서관 | 소설 | 문학 |

### 미션 2 — 아직 반납하지 않은 내 책

요구사항: 사용자 1(민서)이 아직 반납하지 않은 책을 반납 예정일 순으로 조회한다.

```sql
SELECT b.title, r.rented_at, r.due_at
FROM rental AS r
JOIN book AS b ON r.book_id = b.book_id
WHERE r.user_id = @target_user_id
  AND r.returned_at IS NULL
ORDER BY r.due_at ASC;
```

- 대여 상태와 날짜가 있는 `rental`을 기준으로 시작하고, 책 제목을 얻기 위해 `book`을 JOIN했다.
- `returned_at IS NULL`은 아직 반납 시각이 없다는 뜻이다. NULL은 `= NULL`이 아니라 `IS NULL`로 검사한다.
- 검증: 사용자 1의 `겨울의 편지`만 미반납이며, 반납 예정일이 2026-08-17이라 한 건이 조회됐다.

| title | rented_at | due_at |
| --- | --- | --- |
| 겨울의 편지 | 2026-08-10 10:00:00 | 2026-08-17 10:00:00 |

### 미션 3 — 책 태그와 좋아요 여부

요구사항: 책 1의 태그 목록과 사용자 1의 좋아요 여부를 조회한다.

```sql
SELECT b.title, t.name AS tag_name,
       EXISTS (SELECT 1 FROM book_like AS bl
               WHERE bl.book_id = b.book_id AND bl.user_id = @target_user_id) AS is_liked
FROM book AS b
LEFT JOIN book_tag AS bt ON b.book_id = bt.book_id
LEFT JOIN tag AS t ON bt.tag_id = t.tag_id
WHERE b.book_id = @target_book_id
ORDER BY t.tag_id ASC;
```

- `book_tag`은 책과 태그의 N:M 관계를 풀어 주는 매핑 테이블이므로 `book → book_tag → tag` 순서로 JOIN했다.
- 태그가 없는 책도 화면에 표시할 수 있도록 태그 연결은 `LEFT JOIN`으로 두었다. 좋아요는 현재 사용자와 책 쌍이 있는지 `EXISTS`로 확인했다.
- 검증: 책 1에는 `소설`, `추천` 태그가 연결되어 있고, 사용자 1의 `book_like` 행이 있어 두 결과 모두 `is_liked = 1`이다.

| title | tag_name | is_liked |
| --- | --- | ---: |
| 달빛 도서관 | 소설 | 1 |
| 달빛 도서관 | 추천 | 1 |

## 3. 확장: 1주차 지역별 가게 방문 리워드 서비스

요구사항: 로그인한 회원이 인하대 후문 지역에서 진행 중인 미션을 최신 시작 순으로 최대 10개 보여 준다.

```sql
SELECT s.name AS store_name, m.content AS mission_content, m.reward_point,
       mm.status, mm.started_at
FROM member_mission AS mm
JOIN mission AS m ON mm.mission_id = m.id
JOIN store AS s ON m.store_id = s.id
JOIN region AS r ON s.region_id = r.id
WHERE mm.member_id = @target_member_id
  AND r.id = @target_region_id
  AND mm.status = 'IN_PROGRESS'
ORDER BY mm.started_at DESC
LIMIT 10;
```

- 회원이 미션을 수행한 상태는 N:M 매핑 테이블인 `member_mission`에 있으므로 여기서 시작했다. 이 테이블은 1주차 ERD의 `member`와 `mission` 관계를 표현한다.
- 가게·지역 정보는 `mission → store → region` FK 경로를 따라 JOIN했다. 현재 회원, 선택 지역, 진행 상태는 모두 누락되면 안 되는 필터라 `WHERE`에 뒀다.
- 검증: 회원 1이 인하대 후문에서 진행 중인 `캠퍼스 커피` 미션 한 건만 조회됐다.

| store_name | mission_content | reward_point | status |
| --- | --- | ---: | --- |
| 캠퍼스 커피 | 아메리카노를 주문하고 사진 인증하기 | 100 | IN_PROGRESS |

## 4. 미션 기록

1. **어떤 테이블에서 시작했는가?** 목록의 중심 데이터가 책이면 `book`, 대여 상태가 중심이면 `rental`, 회원별 미션 상태가 중심이면 `member_mission`에서 시작했다. 화면에 필요한 결과가 어느 테이블에 실제로 저장되는지 먼저 확인했다.
2. **왜 JOIN이 필요한가?** 책의 카테고리 이름은 `book`에 없고 `category`에 있으며, 태그는 N:M 매핑 테이블 `book_tag`를 거쳐야 한다. 리워드 서비스에서도 지역은 가게에, 수행 상태는 회원-미션 관계에 있으므로 FK 경로를 따라 JOIN했다.
3. **예상과 다른 결과가 나오면 무엇을 확인하는가?** 먼저 기준 ID와 더미 데이터가 맞는지 확인하고, 다음으로 JOIN의 PK/FK 조건과 `WHERE`의 NULL·상태 조건을 확인한다. 마지막으로 정렬과 LIMIT이 결과를 의도치 않게 잘라내지 않는지 본다.

## 5. 실습 체크

- [x] MySQL Community Server 설치 후 `SELECT VERSION();` 실행
- [x] `01_schema.sql`, `02_seed.sql`을 순서대로 실행
- [x] 단일 테이블·JOIN·N:M 매핑 테이블 조회 작성
- [x] `ORDER BY`, `LIMIT`, `OFFSET` 개념 정리
- [x] 공통 미션 3개와 1주차 ERD 확장 쿼리 실행
- [x] 실행 결과를 `sql/execution_results.txt`에 저장

## 파일 구성

```text
mission/Backend/chapter02/
├── mission.md
├── images/
└── sql/
    ├── 01_schema.sql
    ├── 02_seed.sql
    ├── 03_mission_queries.sql
    ├── 04_week01_reward_extension.sql
    └── execution_results.txt
```
