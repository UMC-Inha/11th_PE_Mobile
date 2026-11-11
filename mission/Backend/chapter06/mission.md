# 6주차 백엔드 미션 — 입력한 데이터를 저장하기

- 이름 / 닉네임: 케빈
- 선택 스택: NestJS 12 + TypeORM + MySQL + bcrypt 6 (Spring Boot 대신 NestJS 한 스택으로 진행)
- [GitHub 실습 저장소 (`movie/` 폴더)](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/tree/brownglasses/week06/movie)
- [Pull Request #20](https://github.com/UMC-Inha/11th_BE_NodeJs_Practice_Mission/pull/20)
- [원본 워크북](https://makeus-challenge.notion.site/6-1-40fb57f4596b808e84e0dd899277fdf5)
- [핵심 키워드](../../../keyword/Backend/chapter06/keyword.md)

## 실습 체크리스트

- [x] 회원가입 요청에서 이메일/닉네임/비밀번호를 검증했다 (`CreateMemberDto`, 전역 `ValidationPipe`)
- [x] 비밀번호를 bcrypt 해시로 저장하고 응답 DTO에서 제외했다 (DB의 `member.password`는 `$2b$` 60자, 응답에 `password` 문자열 없음)
- [x] 평점 등록/수정/삭제 API를 구현하고, 수정·삭제 전에 요청 memberId와 평점 소유자를 비교했다
- [x] 평점의 score 범위(1~5 정수)와 comment 길이(500자)를 검증했다
- [x] 성공과 실패 응답이 같은 구조 `{ isSuccess, code, message, result }`를 사용한다
- [x] 중복 회원·중복 평점 409, 잘못된 입력 400, 다른 회원의 평점 403, 없는 평점 404를 확인했다

## 구현 구조

5주차 레이어 구조(controller·service·entity·dto)를 그대로 두고 파일만 더했다. 워크북 예제의 import에는 확장자가 없지만 이 프로젝트는 ESM(`"type": "module"`)이라 기존 파일처럼 `.js`를 붙였다.

```
movie/src
├── controller   member.controller.ts(+POST), rating.controller.ts(+POST·PATCH·DELETE)
├── service      member.service.ts(+signUp), rating.service.ts(+create·update·delete)
├── dto          create-member.dto.ts, create-rating.dto.ts, update-rating.dto.ts,
│                member-response.dto.ts, api-response.dto.ts   ← 새 파일
├── exception    api.exception.ts   (ErrorCode, ApiException)  ← 새 파일
├── filter       all-exceptions.filter.ts                      ← 새 파일
└── app.setup.ts (forbidNonWhitelisted, 전역 필터 등록)
```

워크북과 다르게 한 부분이 있다.

- **PATCH의 `comment`**: 워크북 예제는 `dto.comment ?? null`이라 `comment`를 생략하면 기존 후기가 지워진다. PATCH는 부분 수정이므로 **생략하면 유지, `null`을 보내면 삭제**로 바꿨다(e2e로 확인).
- **비밀번호 특수문자**: 워크북 정규식은 `!@#$%^&*`만 특수문자로 인정한다. 영문·숫자·공백이 아닌 문자는 모두 허용하도록 넓히고, bcrypt가 72바이트 뒤를 무시하므로(직접 확인) 상한 72자를 더했다.
- **이메일·닉네임 공백 제거**: 앞뒤 공백을 `@Transform`으로 지우고 검증한다. 프론트가 `trim()`해서 보내는 값과 서버가 저장하는 값이 어긋나지 않게 하려는 것이다.
- **성공 응답 감싸기 범위**: 워크북 컨트롤러 예제처럼 5주차 GET의 성공 본문은 그대로 두었다(Flutter가 이미 `{available}`·배열을 그대로 읽는다). 대신 **실패 응답은 GET도 같은 틀**로 바뀐다. 상태 코드는 그대로다.

## API 명세

| API | Method | URL | Request | 성공 | 실패 |
| --- | --- | --- | --- | --- | --- |
| 회원가입 | POST | `/members` | Body: `email`, `password`, `nickname` | 201 `COMMON201`, result `{ memberId, email, nickname }` | 400 `COMMON400`, 409 `MEMBER4091`(이메일)·`MEMBER4092`(닉네임) |
| 평점 등록 | POST | `/members/{memberId}/ratings` | Body: `movieId`, `score`, `comment`(선택) | 201 `COMMON201`, result `ratingId` | 400, 404 `MEMBER4041`, 409 `RATING4091` |
| 평점 수정 | PATCH | `/members/{memberId}/ratings/{ratingId}` | Body: `score`, `comment`(선택) | 200 `COMMON200`, result `null` | 400, 403 `RATING4031`, 404 `RATING4041` |
| 평점 삭제 | DELETE | `/members/{memberId}/ratings/{ratingId}` | — | 204 (본문 없음) | 403 `RATING4031`, 404 `RATING4041` |
| (5주차) 닉네임·이메일 중복 체크 | GET | `/members/nickname/{n}`, `/members/email/{e}` | Path | 200 `{ "available": true }` (그대로) | 400 `COMMON400` |
| (5주차) 유저별 평점 조회 | GET | `/members/{memberId}/ratings` | Path, Query(선택) | 200 `[{ ratingId, movieId, score, comment, createdAt, updatedAt }]` (그대로) | 400, 404 `MEMBER4041` |

입력 규칙: `email` 이메일 형식, `nickname` 2~12자, `password` 대문자·소문자·숫자·특수문자 포함 8자 이상, `movieId` 양의 정수, `score` 1~5 정수, `comment` 500자 이하. DTO에 없는 필드는 400. 로그인 전이라 요청한 회원은 경로의 `memberId`로 구분하고, 7주차에 토큰에서 꺼내는 방식으로 바꾼다.

## 핵심 코드

[CreateMemberDto](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week06/movie/src/dto/create-member.dto.ts), [MemberService](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week06/movie/src/service/member.service.ts), [RatingService](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week06/movie/src/service/rating.service.ts), [Controller](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/tree/brownglasses/week06/movie/src/controller), [AllExceptionsFilter](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week06/movie/src/filter/all-exceptions.filter.ts), [ApiException](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week06/movie/src/exception/api.exception.ts).

```ts
// MemberService.signUp: 사전 중복 확인 → bcrypt 해시 → 저장 → 비밀번호를 뺀 응답
if (await this.memberRepository.exists({ where: { email: dto.email } })) throw emailDuplicated();
if (await this.memberRepository.exists({ where: { nickname: dto.nickname } })) throw nicknameDuplicated();
const saved = await this.memberRepository.save(
  this.memberRepository.create({
    email: dto.email,
    password: await bcrypt.hash(dto.password, BCRYPT_SALT_ROUNDS), // 10
    nickname: dto.nickname,
  }),
);
return MemberResponseDto.from(saved); // memberId, email, nickname 만 옮긴다
```

```ts
// RatingService.findOwnedRating: 먼저 찾고(404), 찾았으면 주인을 본다(403)
const rating = await this.ratingRepository.findOne({
  where: { ratingId },
  relations: { member: true }, // 작성자를 함께 불러와야 소유권을 비교할 수 있다
});
if (!rating) throw ratingNotFound();
if (rating.member.memberId !== memberId) throw ratingForbidden();
```

```ts
// AllExceptionsFilter: DB UNIQUE 위반(ER_DUP_ENTRY)을 같은 409 응답 틀로 바꾼다
const key = /for key '([^']+)'/.exec(driverError.sqlMessage)?.[1]; // 예: member.email
if (key.endsWith('uk_rating_member_movie')) return ratingDuplicated(); // RATING4091
if (key === 'member.email') return emailDuplicated();                  // MEMBER4091
if (key === 'member.nickname') return nicknameDuplicated();            // MEMBER4092
```

## 실습 인증

실제 요청·응답은 격리된 테스트 DB(`umc_movie_test`)에 앱을 붙여 보낸 것이다([전체 기록](evidence/week06-api-results.json)).

### 회원가입 성공 — 201

```http
POST /members
{ "email": "viewer1@umc.com", "password": "Umc!1234", "nickname": "뷰어1" }
```

```json
{
  "isSuccess": true,
  "code": "COMMON201",
  "message": "회원가입에 성공했습니다.",
  "result": { "memberId": 3, "email": "viewer1@umc.com", "nickname": "뷰어1" }
}
```

응답 본문에 `password`라는 문자열이 없다. DB에는 원문이 아니라 해시만 있다.

| DB 확인 | 값 |
| --- | --- |
| `LEFT(password, 4)` | `$2b$` |
| `CHAR_LENGTH(password)` | 60 |
| 원문과 같은가 | 아니오 |

### 검증 실패 — 400

| 요청 Body | 상태 | 응답 |
| --- | --- | --- |
| email `umc-example.com` | 400 | `{"isSuccess":false,"code":"COMMON400","message":"올바른 이메일 형식이 아닙니다.","result":null}` |
| password `umc1234` | 400 | `{"isSuccess":false,"code":"COMMON400","message":"비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.","result":null}` |

### 평점 등록 — 201, 수정 — 200, 삭제 — 204

```http
POST /members/3/ratings
{ "movieId": 550, "score": 5, "comment": "최고의 영화!" }
```

```json
{ "isSuccess": true, "code": "COMMON201", "message": "평점 등록에 성공했습니다.", "result": 4 }
```

| 요청 | 상태 | 응답 |
| --- | --- | --- |
| PATCH /members/3/ratings/4 `{"score":2,"comment":"다시 보니 별로"}` | 200 | `{"isSuccess":true,"code":"COMMON200","message":"평점 수정에 성공했습니다.","result":null}` |
| GET /members/3/ratings (5주차 조회 API) | 200 | `[{"ratingId":4,"movieId":550,"score":2,"comment":"다시 보니 별로", ...}]` — 수정이 반영됨 |
| DELETE /members/3/ratings/4 | 204 | 본문 없음 |
| GET /members/3/ratings | 200 | `[]` — 목록에서 사라짐 |

### 실패 응답

| 요청 | 상태 | code | message |
| --- | --- | --- | --- |
| 이미 있는 이메일로 가입 | 409 | `MEMBER4091` | 이미 사용 중인 이메일입니다. |
| 이미 있는 닉네임으로 가입 | 409 | `MEMBER4092` | 이미 사용 중인 닉네임입니다. |
| 같은 영화에 평점 한 번 더 | 409 | `RATING4091` | 이미 이 영화에 평점을 남기셨습니다. |
| 별점 6 | 400 | `COMMON400` | 별점은 5점 이하여야 합니다. |
| 없는 회원(999999)에게 등록 | 404 | `MEMBER4041` | 존재하지 않는 유저입니다. |
| 없는 ratingId(999999) 수정 | 404 | `RATING4041` | 존재하지 않는 평점입니다. |
| 다른 회원이 수정·삭제 | 403 | `RATING4031` | 본인이 작성한 평점만 수정하거나 삭제할 수 있습니다. |
| 이미 지운 평점을 또 삭제 | 404 | `RATING4041` | 존재하지 않는 평점입니다. |

> Postman **데스크톱 앱** 화면 캡처는 찍지 않았다. 같은 요청을 담은 [Postman Collection](evidence/week06.postman_collection.json)을 Newman(Postman CLI 실행기)으로 실제 서버에 보내 **18개 요청·37개 assertion이 모두 통과**했고([결과](evidence/week06-newman.json)), Postman 앱에서 Import 해서 직접 실행해 볼 수도 있다.

## 미션 인증

### (필수) Standard Mission

- **회원가입**: 이메일·닉네임·비밀번호를 검증하고 bcrypt로 저장해 201로 응답한다. 위 "회원가입 성공" 참고.
- **평점**: 등록 POST(201), 수정 PATCH(200), 삭제 DELETE(204)를 구현했다.
- **실패 처리**: 요구한 "2가지 이상"을 넘어 중복 이메일, 중복 닉네임, 잘못된 별점, 중복 평점을 모두 같은 틀로 처리했다. 다른 회원의 수정·삭제는 403, 없는 평점은 404.

확인 포인트에 대한 답:

| 확인 포인트 | 확인 방법과 결과 |
| --- | --- |
| password가 응답에 없는가? | 응답 본문 문자열에 `password`가 없다(Newman·e2e). 가입 응답은 `memberId`, `email`, `nickname` 세 키뿐이다. |
| 중복 평점이 DB에 저장되지 않는가? | 같은 영화로 등록 → 409 뒤 조회하면 1건. 같은 영화로 **동시에 5번** 보내도 201 1건·409 4건, DB에는 1건(e2e). |
| DELETE가 204로 응답하는가? | 204, 본문은 빈 문자열이고 이어서 조회하면 목록에서 사라져 있다. |

### (선택) Challenge Mission — 이메일·닉네임 중복 구분과 DB UNIQUE 위반 변환

**1) 이메일과 닉네임 중복을 다른 code·message로 구분**했다. 이메일은 `MEMBER4091 / 이미 사용 중인 이메일입니다.`, 닉네임은 `MEMBER4092 / 이미 사용 중인 닉네임입니다.`(위 표).

**2) DB UNIQUE 제약 위반도 같은 오류 형식으로 바뀌도록 전역 예외 처리에 추가**했다. `AllExceptionsFilter`가 MySQL `ER_DUP_ENTRY`를 받아 오류 메시지의 key 이름(`member.email`, `member.nickname`, `rating.uk_rating_member_movie`)으로 어느 제약인지 가려 각각 위 code로 바꾼다. 처음 보는 key면 `COMMON409`로 바꾼다.

**3) 반복·동시 요청으로 DB 제약 위반을 재현**했다. 같은 이메일(닉네임만 다르게)로 `POST /members`를 **동시에 8번** 보냈다.

| 항목 | 결과 |
| --- | --- |
| 상태 코드 | 201 × 1, 409 × 7 |
| DB의 그 이메일 행 | 1개 |
| 사전 중복 확인을 통과해 DB 제약에 걸린 요청 | 7건 — 서버 경고 로그 `DB UNIQUE 제약 위반을 409 로 변환했습니다 (key: member.email)` 7줄 |
| 409 응답 본문 | `{"isSuccess":false,"code":"MEMBER4091","message":"이미 사용 중인 이메일입니다.","result":null}` — 사전 확인에서 막힌 경우와 똑같은 틀 |

**왜 사전 확인만으로는 부족한가**: 8개 요청이 모두 "이 이메일은 아직 없다"는 확인을 통과했다. 사전 확인(조회)과 저장(INSERT) 사이에 틈이 있어서, 그 틈에 다른 요청이 먼저 저장하면 나머지는 확인을 통과했는데도 저장 단계에서 충돌한다. 이때 마지막으로 중복을 막는 것이 DB의 UNIQUE 제약이다. 제약이 없었다면 같은 이메일이 7건 더 저장됐을 것이다. 그래서 서비스의 사전 확인은 **친절한 메시지용**, DB 제약은 **정합성의 최종 방어선**으로 둘 다 필요하고, 제약 위반을 500이 아니라 같은 409 응답 틀로 바꿔 주는 것까지가 이번 챌린지다. 이 재현은 e2e 테스트에서 사전 확인이 항상 "없음"이라고 답하도록 바꿔(spy) 결정적으로도 확인했다(이메일·닉네임·평점 각각).

## 검증

- `npm run build`, `npm run lint` 성공 (경고 0)
- `npm test` **52개** 통과: 응답 틀·DB 변환 필터, 가입 규칙(DTO), 평점 등록·수정·삭제 Service, 5주차 Service
- `npm run test:e2e` **36개** 통과: 5주차 조회 8개(개발용 `umc_movie`, 조회만) + 6주차 쓰기 28개(일회용 `umc_movie_test`)
- 라이브 검증 스크립트 26개 확인 → [기록](evidence/week06-api-results.json)
- Newman 18개 요청·37개 assertion → [Collection](evidence/week06.postman_collection.json), [결과](evidence/week06-newman.json)
- 개발용 `umc_movie`는 바뀌지 않았다(검증 전후 회원 2·평점 3). 쓰기 검증은 모두 `umc_movie_test`에서만 돌고 끝나면 지운다.

### 확인하지 못한 것

- Postman 데스크톱 앱과 Flutter 화면에서 쓰기 API를 직접 호출한 캡처는 없다. 6주차 Flutter 워크북은 조회·중복 확인만 사용한다.
- 동시성 재현은 서버 1개 프로세스와 로컬 MySQL 1대에서 한 것이다. 여러 서버 인스턴스나 부하 상황은 확인하지 않았다.
- 비밀번호 해시 비교(로그인)는 7주차 범위라 구현하지 않았다.

## 트러블슈팅

### ⚡ No.1 검증 스크립트의 SQL이 문법 오류

`이슈`
👉 동시 요청 결과를 DB 행 수로 확인하려고 `SELECT COUNT(*) AS rows FROM member WHERE email = ?`를 보냈더니 스크립트가 멈췄다.

`문제`
👉 `ER_PARSE_ERROR: You have an error in your SQL syntax; ... near 'rows FROM `umc_movie_test`.member ...'`. `rows`가 MySQL 예약어라서 별칭으로 쓸 수 없었다. 스크립트는 `finally`에서 테스트 DB를 지우고 끝났고, `umc_movie`의 회원 2·평점 3은 그대로였다.

`해결`
👉 별칭을 `cnt`로 바꿨다. 다시 실행해 26개 확인이 통과했다.

`참고레퍼런스`
- [MySQL Keywords and Reserved Words](https://dev.mysql.com/doc/refman/8.4/en/keywords.html)

### ⚡ No.2 테스트는 통과하는데 출력에 `ERROR` 스택이 찍힘

`이슈`
👉 필터 단위 테스트가 모두 통과했는데 터미널에 `[Nest] ERROR [AllExceptionsFilter] Error: Access denied for user 'root'@'localhost'` 스택이 길게 찍혔다.

`문제`
👉 "처음 보는 오류는 500으로 바꾸고 원문은 서버 로그에만 남긴다"는 동작이 테스트에서도 그대로 로그를 출력한 것이다. 실패가 아니라 의도한 동작이지만, 진짜 오류와 구분이 안 돼서 테스트 출력이 읽기 어려웠다. UNIQUE 위반 변환 경고도 같은 이유로 찍힐 것이었다.

`해결`
👉 해당 테스트에서 `Logger.prototype.error`·`warn`을 `vi.spyOn`으로 막고, 막은 로그가 실제로 한 번 호출됐는지(그리고 key 이름만 있고 값은 없는지)를 `expect`로 검증했다. 출력은 조용해지고 로그를 남긴다는 동작은 테스트가 계속 보장한다.

`참고레퍼런스`
- [NestJS Logger](https://docs.nestjs.com/techniques/logger)

### ⚡ No.3 린트 경고 — 클래스 인스턴스 spread와 `sort()`

`이슈`
👉 테스트 코드에 `oxlint` 경고 6개가 떴다. `no-misused-spread`(클래스 인스턴스에 `...`)와 `require-array-sort-compare`(숫자 배열 `.sort()`).

`문제`
👉 `{ ...rating }`는 Entity 클래스의 프로토타입을 잃는다. 숫자 상태 코드 배열을 비교 함수 없이 `.sort()`하면 문자열 순서로 정렬돼 `[201, 409, ...]`이 우연히 맞더라도 안전하지 않다.

`해결`
👉 spread는 `Object.assign`으로, 정렬은 `.sort((a, b) => a - b)`로 바꿨다. 경고 0.

## 학습 후기

사전 중복 확인을 이미 만들었는데도 같은 이메일로 8개를 동시에 보내자 7개가 그 확인을 그대로 통과해서 DB 제약에 걸렸다. "먼저 조회하니까 안전하다"는 생각이 틀릴 수 있다는 것을 로그 7줄로 직접 봤고, 서비스 검증과 DB 제약이 서로 다른 역할이라는 것이 이해됐다. 응답 틀을 처음부터 `isSuccess/code/message/result`로 정하니, 같은 409라도 이메일·닉네임·평점을 code로 구분하는 것이 쉬웠다. 조회 API의 성공 본문을 바꾸지 않은 것은 이미 프론트가 그 모양을 쓰고 있었기 때문인데, 이미 연결된 API를 바꿀 때는 어디까지가 호환되는지 먼저 따져야 한다는 점을 배웠다. bcrypt는 해시를 두 번 만들면 서로 다르게 나오고 72바이트 뒤는 무시된다는 것을 직접 실행해 확인하니 비밀번호 상한을 왜 두는지 납득됐다.
