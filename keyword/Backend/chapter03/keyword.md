# 3주차 Backend 키워드 — 첫 API 만들고 검증하기

> 기준 자료: 3주차 - 첫 API 만들고 검증하기 · 실습 스택: NestJS 12 + mysql2 (Raw SQL, No DTO)

## 1. 3계층 아키텍처 이외의 아키텍처

이번 주 코드는 **Controller → Service → Repository** 3계층으로 나눴다. Controller는 요청·응답만, Service는 규칙 판단만, Repository는 SQL만 맡는다. 의존은 위에서 아래 한 방향이라 단순하고 배우기 쉽다.

| 아키텍처 | 핵심 | 3계층과 다른 점 |
| --- | --- | --- |
| MVC | Model·View·Controller로 화면(표현)을 그리고 사용자 입력에 반응하는 방식을 나눈다 | 보는 관점이 다르다. 3계층은 표현·업무·데이터 **책임**을 나누고, MVC는 그중 **표현 쪽의 동작**을 나눈다. 그래서 둘을 함께 쓸 수 있다(서버가 HTML을 그리는 앱이면 표현 계층 안을 MVC로 짠다) |
| 헥사고날(Ports & Adapters) | 도메인을 가운데 두고 HTTP·DB 같은 바깥은 Port(인터페이스) + Adapter(구현)로 붙인다 | DB를 바꿔도 도메인 코드는 그대로. Service가 특정 DB 구현에 묶이는 문제를 푼다 |
| 클린 아키텍처 | Entities → Use Cases → Interface Adapters → Frameworks 동심원, 의존은 항상 안쪽으로 | 헥사고날을 일반화. 규칙이 많아 작은 프로젝트엔 과할 수 있다 |
| 마이크로서비스 | 기능별로 서버를 따로 배포한다 | 코드 구조가 아니라 **배포 단위** 분리. 서비스 하나 안은 다시 계층형으로 짠다 |

정리: 3계층은 "역할 분리"의 최소 단위이고, 헥사고날·클린은 "의존 방향까지 통제"하는 확장판이다. 이번 주에 `database.provider.ts`로 DB 연결을 토큰(`DATABASE_CONNECTION`)으로 주입받은 것도, Repository가 연결을 직접 만들지 않게 떼어 놓는 같은 방향의 첫걸음이다.

참고: [Martin Fowler - GUI Architectures](https://www.martinfowler.com/eaaDev/uiArchs.html)

## 2. SQL Injection을 포함한 대표 웹 보안 공격

- **SQL Injection**: 입력값을 문자열로 이어 붙인 쿼리에 `' OR 1=1 --` 같은 SQL 조각을 넣어 인증 우회·유출·삭제를 일으킨다. 방어는 값을 SQL 문법과 분리해서 넘기는 것이다. mysql2에는 두 방법이 있다.
  - `pool.query(sql, [값])`: `?` 자리표시자에 값을 **드라이버가 escape해서** 끼운 뒤 완성된 SQL을 보낸다.
  - `pool.execute(sql, [값])`: 서버가 SQL을 먼저 준비(**prepared statement**)하고 값은 따로 보낸다. 값이 SQL로 해석될 여지가 구조적으로 없다.
  - 이번 주에는 입력이 없는 `SELECT * FROM book`만 `query()`, 사용자 값이 들어가는 쿼리는 전부 `execute()`로 썼다. 둘 다 문자열 `+` 조립보다 안전하다.
- **XSS(Cross-Site Scripting)**: 게시글 등에 `<script>`를 심어 다른 사용자 브라우저에서 실행시킨다. 기본 방어는 **출력 위치(문맥)에 맞는 인코딩**이다 — HTML 본문, HTML 속성, JavaScript 안, URL은 각각 다른 규칙으로 바꿔야 해서 HTML escape 하나로는 모든 자리를 못 막는다. CSP 헤더는 인코딩을 대신하는 게 아니라, 뚫렸을 때 피해를 줄이는 **추가 방어선**이다. 서버를 거치지 않고 브라우저 JS 안에서만 생기는 DOM 기반 XSS도 따로 있다.
- **CSRF(Cross-Site Request Forgery)**: 로그인된 사용자의 브라우저가 공격자 사이트에서 몰래 요청을 보내게 한다. CSRF 토큰, `SameSite` 쿠키로 막는다.
- **인증·세션 취약점**: 비밀번호 평문 저장, 세션 고정 등. bcrypt 같은 해시, 로그인 시 세션 재발급으로 막는다.
- **민감정보 노출**: 코드에 DB 비밀번호를 적어 저장소에 올리는 경우. 이번 주 `.env`로 분리하고 `.gitignore`에 넣었다(`.env.example`만 공유). 인증이 없는 실습 API라 서버도 `127.0.0.1`에만 열었다.

참고: [OWASP Top 10](https://owasp.org/www-project-top-ten/), [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html), [mysql2 - Prepared Statements](https://sidorares.github.io/node-mysql2/docs/documentation/prepared-statements)

## 3. 커넥션 풀(Connection Pool)

DB 연결 하나를 여는 데는 TCP 접속·인증·세션 준비가 필요해 비싸다. 요청마다 열고 닫으면 서버가 연결 작업에 시간을 다 쓴다. 커넥션 풀은 **한 번 연 연결을 닫지 않고 모아 두었다가 다음 요청에 다시 빌려주는** 방식이다.

```ts
// src/database.provider.ts (워크북 코드)
return mysql.createPool({
  host: configService.get<string>('DB_HOST', 'localhost'),
  // ...
  waitForConnections: true, // 다 빌려 가면 에러 대신 대기
  connectionLimit: 10,      // 동시에 빌려줄 수 있는 최대 연결 수
  queueLimit: 0,            // 대기 줄 길이 제한 없음
});
```

- mysql2의 `createPool()`은 만들 때 10개를 한꺼번에 열지 **않는다**. 요청이 오면 그때 연결을 만들고, 다 쓴 연결은 풀에 돌려놓아 재사용하며, 최대 10개까지만 늘어난다. 그래서 `main.ts`에서 서버가 켜질 때 `SELECT 1`을 한 번 보내 연결을 확인했다(안 그러면 비밀번호가 틀려도 첫 API 요청 때에야 안다).
- Spring Boot의 기본 풀 HikariCP는 반대로 최소 유휴 연결 수(`minimumIdle`, 기본값 = 최대 10개)만큼 **미리 채워 두려고** 한다. 워크북의 "핫라인 10개를 미리 꽂아 둔다"는 설명은 이쪽에 더 가깝다.
- `pool.query()`·`pool.execute()`는 연결을 빌려 쓰고 **자동으로 반납**한다. `pool.getConnection()`으로 직접 빌렸다면 반드시 `release()`해야 한다. 반납을 잊으면 풀이 말라 서버가 멈춘다(connection leak).

참고: [mysql2 문서](https://sidorares.github.io/node-mysql2/docs), [HikariCP](https://github.com/brettwooldridge/HikariCP), [NestJS - Custom providers](https://docs.nestjs.com/fundamentals/custom-providers)

## 4. Raw SQL vs ORM

| | Raw SQL (이번 주 mysql2) | ORM (TypeORM·Prisma·JPA) |
| --- | --- | --- |
| 쿼리 | 직접 작성. 튜닝·복잡한 JOIN에 유리 | 객체를 다루면 SQL을 만들어 준다 |
| 결과 모양 | DB 컬럼 그대로(`book_id`, `is_available: 1`) | 엔티티 필드로 변환(`bookId`, `isAvailable: true`) |
| 오타 | `titel` 오타가 요청을 보내 봐야 드러남(500) | 엔티티·DTO 필드가 틀리면 작성 단계에서 오류 |
| 스키마 변경 | 관련 SQL 문자열을 전부 찾아 고쳐야 함 | 엔티티 한 곳 수정 |
| 학습 비용 | 낮음 | 지연 로딩·N+1 등 개념이 많음 |

이번 주에 직접 겪은 불편: 응답이 snake_case 그대로 나가 앱 화면 코드가 DB 컬럼명에 묶이고, `BOOLEAN`이 `1/0`으로 오고, DB에 한국 시간으로 저장된 `DATETIME`이 응답에서는 UTC 문자열(`...T13:20:00.000Z`)로 바뀌어 나갔다. 실무는 둘을 섞는다 — 기본 CRUD는 ORM, 통계·복잡한 조회는 Raw SQL. 노드 트랙은 4주차에 TypeORM을 쓴다.

## 5. INSERT 외에 데이터를 다루는 핵심 SQL

```sql
INSERT INTO 테이블 (컬럼1, 컬럼2) VALUES (값1, 값2);   -- 추가
```

- 컬럼 순서 = VALUES 순서, 개수도 같아야 한다. `AUTO_INCREMENT` PK는 적지 않는다.
- `NULL` 허용이거나 `DEFAULT`가 있는 컬럼은 생략할 수 있다(`rental.returned_at`).
- `NOT NULL`인데 기본값이 없는 컬럼을 빼면 어떻게 될지는 **SQL 모드**에 따라 다르다. 임시 테이블로 직접 확인했다.
  - strict 모드(`STRICT_TRANS_TABLES`, 이 맥 MySQL의 기본값): 오류 `Field 'title' doesn't have a default value`
  - strict가 아닐 때: 경고만 남기고 **빈 문자열 `''`이 들어간다**. 오류가 안 나서 더 위험하다
  - `NULL`을 직접 넣으면 한 행일 때는 두 모드 모두 `Column 'title' cannot be null` 오류다
- FK는 부모가 먼저 있어야 한다. 없는 `category_id`를 넣으면 `foreign key constraint fails`(이번 주 요청으로 확인).

| 분류 | 명령 | 이번 주 사용 |
| --- | --- | --- |
| DML | `SELECT` · `INSERT` · `UPDATE … SET … WHERE` · `DELETE FROM … WHERE` | 목록 조회, 도서·대여 추가, 반납(`UPDATE rental SET returned_at = NOW()`) |
| DDL | `CREATE` · `ALTER` · `DROP` · `TRUNCATE` | 2주차 스키마 재사용 |
| DCL | `GRANT` · `REVOKE` | - |
| TCL | `START TRANSACTION` · `COMMIT` · `ROLLBACK` | 다음 과제: 대여 생성과 `is_available = FALSE`를 한 묶음으로 |

⚠️ `UPDATE`·`DELETE`에 `WHERE`를 빠뜨리면 모든 행이 바뀐다. 반납 쿼리에는 `AND returned_at IS NULL`까지 붙여 이미 반납한 기록의 날짜가 덮어써지지 않게 했다.

참고: [MySQL 8.4 - Data Type Default Values](https://dev.mysql.com/doc/refman/8.4/en/data-type-defaults.html), [MySQL 8.4 - UPDATE](https://dev.mysql.com/doc/refman/8.4/en/update.html)

## 더 공부해 볼 것

- 입력 검증과 DTO: 오타·잘못된 타입을 500이 아니라 400으로 돌려주기(4주차)
- 트랜잭션과 격리 수준: 두 사람이 같은 책을 동시에 빌릴 때
