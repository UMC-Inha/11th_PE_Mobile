# 6주차 백엔드 핵심 키워드

## 입력을 믿지 않는 서버: Bean Validation(`@Valid`)과 class-validator·ValidationPipe

저장 API는 입력이 DB에 닿기 전에 **세 개의 문**을 지난다. 각 문이 막는 것이 다르다.

| 문 | 검사 | 실패하면 |
| --- | --- | --- |
| DTO 검증 | 형식·범위 (이메일 모양, 별점 1~5, 후기 500자) | 400 |
| 서비스 검증 | 존재 여부·업무 규칙 (없는 회원, 남의 평점, 이미 쓴 이메일) | 404 / 403 / 409 |
| DB 제약 | UNIQUE·FK (동시에 들어온 중복) | 409 (오류를 변환) |

- **Spring**: Jakarta Bean Validation 어노테이션(`@Email`, `@Size`, `@NotBlank`)을 DTO에 붙이고 컨트롤러 파라미터에 `@Valid`를 붙이면, 검증 실패가 `MethodArgumentNotValidException`(400)으로 이어진다.
- **NestJS**: class-validator 데코레이터(`@IsEmail`, `@Min`, `@MaxLength`)를 DTO 클래스에 붙이고 전역 `ValidationPipe`를 켠다. 파이프는 컨트롤러 메서드가 실행되기 **전에** 돌기 때문에, 검증에 실패한 요청은 Service에 닿지 않는다(실습에서 400 뒤 DB 행 수가 그대로임을 확인).
- `ValidationPipe` 옵션 세 가지를 구분해서 썼다.
  - `transform: true` — JSON을 DTO **클래스 인스턴스**로 바꾼다. 이메일·닉네임 앞뒤 공백을 지우는 `@Transform`이 동작하려면 필요하다.
  - `whitelist: true` — DTO에 없는 속성을 조용히 지운다.
  - `forbidNonWhitelisted: true` — 없는 속성이 있으면 지우는 대신 400으로 막는다. `{ "role": "admin" }`을 몰래 보내면 `property role should not exist`.
- 위반 메시지는 배열로 온다. 화면에는 첫 번째 이유 하나만 보여주도록 필터에서 골랐다.

참고: [NestJS Validation](https://docs.nestjs.com/techniques/validation), [class-validator](https://github.com/typestack/class-validator), [Spring Validation](https://docs.spring.io/spring-framework/reference/core/validation/beanvalidation.html)

## bcrypt와 salt round

비밀번호는 **암호화(복호화 가능)가 아니라 해시(단방향)** 로 저장한다. 서버도 원문을 알 필요가 없고, 로그인 때는 입력값을 같은 방식으로 해시해 비교하면 된다.

- **salt**: 해시할 때마다 섞는 무작위 값. 같은 비밀번호 `Umc!1234`를 두 번 해시하면 서로 다른 문자열이 나온다(직접 확인). 미리 계산해 둔 해시 표(레인보우 테이블)와 "같은 비밀번호 = 같은 해시" 비교를 막는다.
- **해시 문자열 구조**: `$2b$10$` + salt 22자 + 해시 31자 = **항상 60자**. salt와 cost가 해시 안에 들어 있어서 `bcrypt.compare(입력값, 저장된 해시)`만 부르면 된다. 그래서 `member.password`를 `VARCHAR(60)`으로 만들어 두었다.
- **salt round(cost)**: 내부 반복을 2^cost번 한다. 일부러 느리게 만들어 무차별 대입 공격 비용을 올린다. 이 Mac에서 측정한 한 번 해시 시간은 cost 4 ≈ 8ms, **cost 10 ≈ 170ms**, cost 12 ≈ 646ms. 1 올릴 때마다 2배라서 너무 낮으면 약하고, 너무 높으면 가입·로그인 서버가 느려진다. 워크북 기본값 10을 썼다.
- **72바이트 한계**: bcrypt는 비밀번호의 앞 72바이트만 쓴다. 72바이트 뒤만 다른 두 비밀번호가 `compare`에서 같다고 나오는 것을 직접 확인했고, 그래서 비밀번호 상한을 72자로 두었다.
- 응답에는 해시도 넣지 않는다. Entity를 그대로 반환하지 않고 `MemberResponseDto`가 `memberId`, `email`, `nickname`만 옮긴다.

참고: [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html), [bcrypt npm](https://www.npmjs.com/package/bcrypt)

## HTTP 201 Created / 204 No Content / 409 Conflict

| 상태 | 뜻 | 이번 API |
| --- | --- | --- |
| 201 Created | 새 리소스를 만들었다 | `POST /members`, `POST /members/{id}/ratings` (새 ratingId를 result로) |
| 200 OK | 성공, 본문 있음 | `PATCH .../ratings/{ratingId}` |
| 204 No Content | 성공, **돌려줄 본문이 없다** | `DELETE .../ratings/{ratingId}` |
| 400 Bad Request | 요청 형식·범위가 틀렸다 | 이메일 형식, 별점 6, 깨진 JSON |
| 403 Forbidden | 누구인지는 알지만 **권한이 없다** | 다른 회원의 평점 수정·삭제 |
| 404 Not Found | 대상이 없다 | 없는 회원, 없는 평점 |
| 409 Conflict | 요청은 올바르지만 **현재 서버 상태와 충돌** | 이미 쓴 이메일·닉네임, 같은 영화에 두 번째 평점 |

- 204는 본문이 비어 있어서 프론트가 `jsonDecode('')`를 하면 오류가 난다. 응답 본문이 있는지 먼저 봐야 한다(Newman에서 `본문이 비어 있다`로 확인).
- 400과 409의 차이: 400은 "값 자체가 틀림", 409는 "값은 맞는데 이미 있음". 닉네임 `a`는 400, 이미 있는 닉네임 `뷰어1`은 409다.
- 403(권한 없음)과 401(로그인 안 함)은 다르다. 지금은 로그인 전이라 memberId를 경로로 받으므로 403만 쓰고, 7주차에 토큰이 생기면 401이 따라온다.
- 같은 409라도 **code로 사유를 구분**한다: `MEMBER4091`(이메일), `MEMBER4092`(닉네임), `RATING4091`(평점). 화면은 문구가 아니라 code로 분기할 수 있다.
- 수정·삭제는 먼저 평점을 찾고(없으면 404) 그다음 주인을 비교한다(다르면 403).

참고: [MDN 201](https://developer.mozilla.org/ko/docs/Web/HTTP/Status/201), [MDN 204](https://developer.mozilla.org/ko/docs/Web/HTTP/Status/204), [MDN 409](https://developer.mozilla.org/ko/docs/Web/HTTP/Status/409)

## UNIQUE 제약 조건과 동시성

"이미 있는지 조회하고, 없으면 저장"은 두 요청이 거의 동시에 오면 둘 다 "없음"을 보고 둘 다 저장하려 한다(check-then-act 경쟁). 서비스의 사전 확인은 **친절한 메시지를 위한 것**이고, 중복을 **확실히 막는 것은 DB의 UNIQUE 제약**이다.

이번 실습에서 직접 재현했다. 같은 이메일로 8개 요청을 동시에 보냈다.

| 항목 | 결과 |
| --- | --- |
| 응답 상태 | 201이 1건, 409가 7건 |
| DB에 그 이메일의 행 | 1개 |
| 사전 확인을 통과해 DB 제약에 걸린 요청 | 7건 (서버 경고 로그 7줄) |
| 409 응답 본문 | `MEMBER4091` — 사전 확인에서 막힌 것과 똑같은 형식 |

- MySQL은 UNIQUE 위반을 `ER_DUP_ENTRY`(errno 1062), `Duplicate entry '…' for key 'member.email'`로 알려 준다. key 이름(`member.email`, `member.nickname`, `rating.uk_rating_member_movie`)으로 **어느 제약인지** 구분해 각각 다른 code로 바꿨다.
- 알 수 없는 key면 일반 409(`COMMON409`)로 바꾼다. 어느 쪽이든 "이미 있다"는 것은 확실하기 때문이다.
- 로그에는 key 이름만 남기고 값(이메일)은 남기지 않는다. 로그에 개인정보가 쌓이지 않게 하려는 것이다.
- 평점은 `(member_id, movie_id)` **복합 UNIQUE**라서 "같은 회원이 같은 영화에 두 번"만 막고, 다른 회원은 같은 영화에 평점을 남길 수 있다.

참고: [MySQL 서버 오류 목록(ER_DUP_ENTRY)](https://dev.mysql.com/doc/mysql-errors/8.4/en/server-error-reference.html)

## 전역 예외 처리: Exception Filter와 `@RestControllerAdvice`

컨트롤러마다 `try-catch`를 두면 같은 오류를 여러 번 처리하고 응답 모양이 조금씩 달라진다. 전역 예외 처리는 어디서 오류가 나든 **한곳에서 같은 틀로** 돌려준다.

- **NestJS**: `@Catch()`를 붙인 필터 클래스를 `app.useGlobalFilters()`로 등록한다. 요청은 미들웨어 → 가드 → 인터셉터 → **파이프** → 컨트롤러 순으로 흐르고, 어디서든 던져진 예외는 필터가 받는다.
- **Spring**: `@RestControllerAdvice` 클래스에 `@ExceptionHandler`를 둔다. 역할이 같다.
- 이번 필터는 예외를 네 종류로 나눈다.
  1. `ApiException` — 우리가 정한 상태·code·message 그대로
  2. DB UNIQUE 위반 — 위의 409 변환
  3. 그 밖의 `HttpException` — ValidationPipe의 400, 없는 경로의 404. code는 `COMMON` + 상태
  4. 처음 보는 오류 — 500과 고정 문구만 응답하고 원문(스택)은 서버 로그에만 남긴다. DB 접속 오류 같은 내부 메시지가 화면으로 새지 않는다(단위 테스트로 확인).
- 응답 틀 `{ isSuccess, code, message, result }` 덕분에 프론트는 HTTP 상태와 code만 보고 분기하면 된다.
- 5주차 조회 API의 **성공 본문은 감싸지 않았다**(이미 프론트가 `{available}`·배열을 그대로 읽는다). 대신 실패는 조회 API도 같은 틀로 바뀐다. 상태 코드는 그대로라서 프론트의 기존 분기는 영향을 받지 않는다.

참고: [NestJS Exception filters](https://docs.nestjs.com/exception-filters), [Spring @RestControllerAdvice](https://docs.spring.io/spring-framework/reference/web/webmvc/mvc-controller/ann-advice.html)
