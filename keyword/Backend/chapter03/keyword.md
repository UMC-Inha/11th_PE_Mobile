# 3주차 Backend 키워드 — 첫 API 만들고 검증하기

> 기준 자료: 3주차 - 첫 API 만들고 검증하기 (1) · 실습 스택: Node.js(Express 5) + mysql2

## 1. 3계층 아키텍처 이외의 아키텍처

이번 주 코드는 **Controller → Service → Repository** 3계층으로 나눴다. Controller는 요청·응답만, Service는 규칙 판단만, Repository는 SQL만 맡는다. 의존은 위에서 아래 한 방향이라 단순하고 배우기 쉽다.

| 아키텍처 | 핵심 | 3계층과 다른 점 |
| --- | --- | --- |
| MVC | Model·View·Controller로 화면 앱의 표현 계층을 나눈다 | 3계층의 Controller 부분을 더 잘게 나눈 것. Service·Repository와 함께 쓴다 |
| 헥사고날(Ports & Adapters) | 도메인을 가운데 두고 HTTP·DB 같은 바깥은 Port(인터페이스) + Adapter(구현)로 붙인다 | DB를 바꿔도 도메인 코드는 그대로. Service가 특정 DB 구현에 묶이는 문제를 푼다 |
| 클린 아키텍처 | Entities → Use Cases → Interface Adapters → Frameworks 동심원, 의존은 항상 안쪽으로 | 헥사고날을 일반화. 규칙이 많아 작은 프로젝트엔 과할 수 있다 |
| 마이크로서비스 | 기능별로 서버를 따로 배포한다 | 코드 구조가 아니라 **배포 단위** 분리. 서비스 하나 안은 다시 계층형으로 짠다 |

정리: 3계층은 "역할 분리"의 최소 단위이고, 헥사고날·클린은 "의존 방향까지 통제"하는 확장판이다. 4주차에 ORM을 붙이면서 Repository를 인터페이스처럼 떼어 두면 헥사고날의 첫걸음이 된다.

## 2. SQL Injection을 포함한 대표 웹 보안 공격

- **SQL Injection**: 입력값을 문자열로 이어 붙인 쿼리에 `' OR 1=1 --` 같은 SQL 조각을 넣어 인증 우회·유출·삭제를 일으킨다. 방어는 **파라미터 바인딩**이다. 이번 주 모든 쿼리를 `pool.query('... WHERE category_id = ?', [categoryId])`처럼 `?`로 넘겨, 값이 SQL 문법이 아니라 데이터로만 해석되게 했다.
- **XSS(Cross-Site Scripting)**: 게시글 등에 `<script>`를 심어 다른 사용자 브라우저에서 실행시킨다. 출력할 때 HTML 이스케이프, CSP 헤더로 막는다.
- **CSRF(Cross-Site Request Forgery)**: 로그인된 사용자의 브라우저가 공격자 사이트에서 몰래 요청을 보내게 한다. CSRF 토큰, `SameSite` 쿠키로 막는다.
- **인증·세션 취약점**: 비밀번호 평문 저장, 세션 고정 등. bcrypt 같은 해시, 로그인 시 세션 재발급으로 막는다.
- **민감정보 노출**: 코드에 DB 비밀번호를 적어 저장소에 올리는 경우. 이번 주 `.env`로 분리하고 `.gitignore`에 넣었다(`.env.example`만 공유).

참고: [OWASP Top 10](https://owasp.org/www-project-top-ten/)

## 3. 커넥션 풀(Connection Pool)

DB 연결 하나를 여는 데는 TCP 접속·인증·세션 준비가 필요해 비싸다. 요청마다 열고 닫으면 서버가 연결 작업에 시간을 다 쓴다. 커넥션 풀은 연결을 **미리 여러 개 만들어 두고 빌려주고 돌려받는** 방식이다.

```js
// src/db.config.js
export const pool = mysql.createPool({
  host: process.env.DB_HOST, user: process.env.DB_USER,
  password: process.env.DB_PASSWORD, database: process.env.DB_NAME,
  connectionLimit: 10,        // 동시에 빌려줄 수 있는 최대 연결 수
  waitForConnections: true,   // 다 나가면 에러 대신 대기
});
```

- `pool.query()`는 연결을 빌려 쿼리하고 **자동으로 반납**한다.
- `pool.getConnection()`으로 직접 빌렸다면 반드시 `release()`해야 한다. 반납을 잊으면 풀이 말라 서버가 멈춘다(connection leak). 서버 시작 시 접속 확인에서 이 방식을 한 번 썼다.
- Spring Boot는 HikariCP가 기본 풀이다(기본 최대 10개).

참고: [mysql2 - Using connection pools](https://sidorares.github.io/node-mysql2/docs#using-connection-pools)

## 4. Raw SQL vs ORM

| | Raw SQL (이번 주 mysql2) | ORM (Prisma·TypeORM·JPA) |
| --- | --- | --- |
| 쿼리 | 직접 작성. 튜닝·복잡한 JOIN에 유리 | 객체를 다루면 SQL을 만들어 준다 |
| 결과 모양 | DB 컬럼 그대로(`book_id`, `is_available: 1`) | 모델 필드로 변환(`bookId`, `isAvailable: true`) |
| 오타 | `titel` 오타가 실행해 봐야 드러남(500) | 모델 필드가 틀리면 작성 단계에서 오류 |
| 스키마 변경 | 관련 SQL 문자열을 전부 찾아 고쳐야 함 | 모델 한 곳 수정 |
| 학습 비용 | 낮음 | 지연 로딩·N+1 등 개념이 많음 |

이번 주에 직접 겪은 불편: 응답이 snake_case 그대로 나가 앱 화면 코드가 DB 컬럼명에 묶이고, `BOOLEAN`이 `1/0`으로 온다. 실무는 둘을 섞는다 — 기본 CRUD는 ORM, 통계·복잡한 조회는 Raw SQL.

## 5. INSERT 외에 데이터를 다루는 핵심 SQL

```sql
INSERT INTO 테이블 (컬럼1, 컬럼2) VALUES (값1, 값2);   -- 추가
```

- 컬럼 순서 = VALUES 순서, 개수도 같아야 한다. `AUTO_INCREMENT` PK는 적지 않는다.
- `NULL` 허용이거나 `DEFAULT`가 있는 컬럼은 생략할 수 있다(`rental.returned_at`). `NOT NULL`인데 기본값이 없는 컬럼을 빼면 오류(`Column 'title' cannot be null`).
- FK는 부모가 먼저 있어야 한다. 없는 `category_id`를 넣으면 `foreign key constraint fails`.

| 분류 | 명령 | 이번 주 사용 |
| --- | --- | --- |
| DML | `SELECT` · `INSERT` · `UPDATE … SET … WHERE` · `DELETE FROM … WHERE` | 목록 조회, 도서·대여 추가, 반납(`UPDATE rental SET returned_at = NOW()`) |
| DDL | `CREATE` · `ALTER` · `DROP` · `TRUNCATE` | 2주차 스키마 재사용 |
| DCL | `GRANT` · `REVOKE` | - |
| TCL | `START TRANSACTION` · `COMMIT` · `ROLLBACK` | 4주차 과제: 대여 생성과 `is_available = FALSE`를 한 묶음으로 |

⚠️ `UPDATE`·`DELETE`에 `WHERE`를 빠뜨리면 모든 행이 바뀐다. 반납 쿼리에는 `AND returned_at IS NULL`까지 붙여 이미 반납한 기록의 날짜가 덮어써지지 않게 했다.

## 더 공부해 볼 것

- 입력 검증과 DTO: 오타·잘못된 타입을 500이 아니라 400으로 돌려주기(4주차)
- 트랜잭션과 격리 수준: 두 사람이 같은 책을 동시에 빌릴 때
