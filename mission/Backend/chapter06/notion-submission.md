# 6주차 백엔드 — Notion 제출용 (체크리스트 · 실습 인증 · 미션 · 미션 기록)

> 선택 스택: **NestJS 12 + TypeORM + MySQL + bcrypt** (Spring Boot 대신 NestJS 한 스택으로 진행)
> 아래 요청·응답은 모두 실제로 실행한 기록입니다. 격리된 일회용 DB(`umc_movie_test`)에 앱을 붙여 진짜 HTTP 요청을 보냈고([전체 26건 기록](evidence/week06-api-results.json)), 개발용 `umc_movie`는 바뀌지 않았습니다(검증 전후 회원 2 · 평점 3).

## ✅ 실습 체크리스트

- [x] 회원가입 요청에서 이메일/닉네임/비밀번호를 검증했다. — `CreateMemberDto` + 전역 `ValidationPipe`. 이메일 형식 · 닉네임 2~12자 · 비밀번호 대/소문자/숫자/특수문자 포함 8자 이상
- [x] 비밀번호를 bcrypt 해시로 저장하고 응답 DTO에서 제외했다. — DB의 `password`는 `$2b$`로 시작하는 60자, 응답은 `memberId`·`email`·`nickname`만
- [x] 평점 등록/수정/삭제 API를 구현하고, 수정과 삭제 전 요청 memberId와 평점 소유자를 비교했다. — `RatingService.findOwnedRating`
- [x] 평점의 score 범위와 comment 길이를 검증했다. — score 1~5 정수(필수), comment 500자 이하(선택)
- [x] 성공과 실패 응답이 같은 구조를 사용한다. — `{ isSuccess, code, message, result }`
- [x] 중복 회원 또는 중복 평점 요청에서 409, 잘못된 입력에서 400, 다른 회원의 평점 요청에서 403, 없는 평점 요청에서 404 오류를 확인했다. — 아래 표

## ☑️ 실습 인증

> Postman 데스크톱 앱 화면 캡처는 찍지 않았습니다. 대신 실제로 보낸 요청과 받은 응답 원문을 적었고, 같은 요청을 담은 [Postman Collection](evidence/week06.postman_collection.json)을 Newman으로 실제 서버에 보내 **18개 요청 · 37개 assertion이 모두 통과**했습니다([결과](evidence/week06-newman.json)). 이미지 캡처가 필요하면 Postman에서 Collection을 Import → 서버 실행 → 각 요청 Send 후 캡처하면 됩니다.

### 1) 회원가입 성공 응답 — 201

```http
POST /members
Content-Type: application/json

{ "email": "viewer1@umc.com", "password": "Umc!1234", "nickname": "뷰어1" }
```

```http
HTTP/1.1 201 Created
```

```json
{
  "isSuccess": true,
  "code": "COMMON201",
  "message": "회원가입에 성공했습니다.",
  "result": { "memberId": 3, "email": "viewer1@umc.com", "nickname": "뷰어1" }
}
```

응답에 `password`가 없습니다. DB에는 원문이 아니라 해시만 저장됩니다.

| DB 확인 (`SELECT LEFT(password,4), CHAR_LENGTH(password) FROM member`) | 값 |
| --- | --- |
| 앞 4글자 | `$2b$` |
| 길이 | 60 |
| 원문(`Umc!1234`)과 같은가 | 아니오 |

### 2) 검증 실패 응답 — 400

```http
POST /members
{ "email": "umc-example.com", "password": "Umc!1234", "nickname": "뷰어2" }
```

```http
HTTP/1.1 400 Bad Request
```

```json
{ "isSuccess": false, "code": "COMMON400", "message": "올바른 이메일 형식이 아닙니다.", "result": null }
```

같은 방식으로 확인한 다른 검증 실패:

| 요청 Body | 상태 | message |
| --- | --- | --- |
| password `umc1234` | 400 | 비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다. |
| nickname `a` (1자) | 400 | 닉네임은 2자 이상이어야 합니다. |
| 평점 score `6` | 400 | 별점은 5점 이하여야 합니다. |
| 평점 comment 501자 | 400 | 후기는 500자 이하로 입력해주세요. |

### 3) 평점 등록 성공 — 201 / 수정 성공 — 200

```http
POST /members/3/ratings
{ "movieId": 550, "score": 5, "comment": "최고의 영화!" }
```

```json
HTTP/1.1 201 Created
{ "isSuccess": true, "code": "COMMON201", "message": "평점 등록에 성공했습니다.", "result": 4 }
```

`result`의 `4`가 새 `ratingId`입니다.

```http
PATCH /members/3/ratings/4
{ "score": 2, "comment": "다시 보니 별로" }
```

```json
HTTP/1.1 200 OK
{ "isSuccess": true, "code": "COMMON200", "message": "평점 수정에 성공했습니다.", "result": null }
```

5주차 조회 API로 수정이 반영됐는지 확인했습니다.

```http
GET /members/3/ratings   →  200
[{ "ratingId": 4, "movieId": 550, "score": 2, "comment": "다시 보니 별로", ... }]
```

## 🔥 미션

### (필수) 1. Standard Mission

**영화 평점 서비스에 회원가입과 평점 등록/수정/삭제 API를 구현했습니다.**

- 회원가입: 이메일/닉네임/비밀번호 검증, bcrypt 저장, 201 응답
- 평점: 등록 POST, 수정 PATCH, 삭제 DELETE 구현
- 실패: 요구한 "2가지 이상"보다 많이, 중복 이메일 · 중복 닉네임 · 잘못된 별점 · 중복 평점을 모두 같은 틀로 처리했고, 다른 회원의 수정/삭제는 403, 존재하지 않는 평점은 404로 처리했습니다.

#### 제출물 1) API 명세

| API | Method | URL | Request | 성공 | 실패 |
| --- | --- | --- | --- | --- | --- |
| 회원가입 | POST | `/members` | Body: `email`, `password`, `nickname` | 201 `COMMON201`, result `{ memberId, email, nickname }` | 400 `COMMON400`, 409 `MEMBER4091`(이메일) · `MEMBER4092`(닉네임) |
| 평점 등록 | POST | `/members/{memberId}/ratings` | Body: `movieId`, `score`, `comment`(선택) | 201 `COMMON201`, result `ratingId` | 400, 404 `MEMBER4041`, 409 `RATING4091` |
| 평점 수정 | PATCH | `/members/{memberId}/ratings/{ratingId}` | Body: `score`, `comment`(선택) | 200 `COMMON200`, result `null` | 400, 403 `RATING4031`, 404 `RATING4041` |
| 평점 삭제 | DELETE | `/members/{memberId}/ratings/{ratingId}` | — | 204 (본문 없음) | 403 `RATING4031`, 404 `RATING4041` |

입력 규칙: `email` 이메일 형식 · `nickname` 2~12자 · `password` 대/소문자/숫자/특수문자 포함 8자 이상 · `movieId` 양의 정수 · `score` 1~5 정수 · `comment` 500자 이하. 로그인 전이라 요청한 회원은 경로의 `memberId`로 구분하고, 7주차에 토큰에서 꺼내는 방식으로 바꿉니다.

#### 제출물 2) 요청/응답 기록

실패 응답을 실제로 보내 확인한 결과입니다(모두 `{ isSuccess:false, code, message, result:null }` 틀).

| 요청 | 상태 | code | message |
| --- | --- | --- | --- |
| 이미 있는 이메일로 가입 | 409 | `MEMBER4091` | 이미 사용 중인 이메일입니다. |
| 이미 있는 닉네임으로 가입 | 409 | `MEMBER4092` | 이미 사용 중인 닉네임입니다. |
| 같은 영화에 평점 한 번 더 | 409 | `RATING4091` | 이미 이 영화에 평점을 남기셨습니다. |
| 별점 6 | 400 | `COMMON400` | 별점은 5점 이하여야 합니다. |
| 없는 회원(999999)에게 등록 | 404 | `MEMBER4041` | 존재하지 않는 유저입니다. |
| 없는 ratingId(999999) 수정 | 404 | `RATING4041` | 존재하지 않는 평점입니다. |
| 다른 회원이 수정 | 403 | `RATING4031` | 본인이 작성한 평점만 수정하거나 삭제할 수 있습니다. |
| 다른 회원이 삭제 | 403 | `RATING4031` | 본인이 작성한 평점만 수정하거나 삭제할 수 있습니다. |
| 이미 지운 평점을 또 삭제 | 404 | `RATING4041` | 존재하지 않는 평점입니다. |

성공한 삭제는 `DELETE /members/3/ratings/4 → 204 (본문 없음)`이고, 이어서 `GET /members/3/ratings → 200 []`로 목록에서 사라진 것을 확인했습니다.

#### 제출물 3) 핵심 코드 링크

> 실습 PR: [UMC-Inha/11th_BE_NodeJs_Practice_Mission#20](https://github.com/UMC-Inha/11th_BE_NodeJs_Practice_Mission/pull/20)

- [CreateMemberDto](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week06/movie/src/dto/create-member.dto.ts)
- [MemberService (signUp)](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week06/movie/src/service/member.service.ts)
- [RatingService (create · update · delete · 소유자 확인)](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week06/movie/src/service/rating.service.ts)
- [Controller](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/tree/brownglasses/week06/movie/src/controller)
- [AllExceptionsFilter (전역 예외 처리)](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week06/movie/src/filter/all-exceptions.filter.ts)
- [ApiException · ErrorCode](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week06/movie/src/exception/api.exception.ts)

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

#### 확인 포인트

| 확인 포인트 | 확인 방법과 결과 |
| --- | --- |
| password가 응답에 없는가? | 응답 본문 문자열에 `password`가 없습니다(Newman · e2e). 가입 응답은 `memberId`, `email`, `nickname` 세 키뿐입니다. |
| 중복 평점이 DB에 저장되지 않는가? | 같은 영화로 등록 → 409 뒤 조회하면 1건. 같은 영화로 **동시에 5번** 보내도 201 1건 · 409 4건이고 DB에는 1건입니다(e2e). |
| DELETE가 204로 응답하는가? | 204, 본문은 빈 문자열이고 이어서 조회하면 목록에서 사라져 있습니다. |

#### 제출물 4) 트러블 슈팅 1건

##### ⚡ 이슈 No.1 검증 스크립트의 SQL이 문법 오류

`이슈`
👉 동시 요청 결과를 DB 행 수로 확인하려고 `SELECT COUNT(*) AS rows FROM member WHERE email = ?`를 보냈더니 스크립트가 멈췄습니다.

`문제`
👉 `ER_PARSE_ERROR: You have an error in your SQL syntax; ... near 'rows FROM ...'`. `rows`가 MySQL 예약어라서 별칭으로 쓸 수 없었습니다. 스크립트는 `finally`에서 테스트 DB를 지우고 끝났고, 개발용 `umc_movie`의 회원 2 · 평점 3은 그대로였습니다.

`해결`
👉 별칭을 `cnt`로 바꿨습니다(`scripts/verify-week06.mjs`). 다시 실행해 26개 확인이 통과했습니다.

`참고레퍼런스`
- [MySQL Keywords and Reserved Words](https://dev.mysql.com/doc/refman/8.4/en/keywords.html)

### (선택) 2. Challenge Mission — 이메일·닉네임 중복 구분과 DB UNIQUE 위반 변환

**1) 이메일과 닉네임 중복 오류를 각각 다른 code와 message로 구분했습니다.**

| 중복 대상 | 상태 | code | message |
| --- | --- | --- | --- |
| 이메일 | 409 | `MEMBER4091` | 이미 사용 중인 이메일입니다. |
| 닉네임 | 409 | `MEMBER4092` | 이미 사용 중인 닉네임입니다. |

**2) DB UNIQUE 제약 위반도 같은 오류 형식으로 바뀌도록 전역 예외 처리에 추가했습니다.**

`AllExceptionsFilter`가 MySQL `ER_DUP_ENTRY`를 받아, 오류 메시지의 key 이름(`member.email` · `member.nickname` · `rating.uk_rating_member_movie`)으로 어느 제약인지 가려 위 code로 바꿉니다. 처음 보는 key면 `COMMON409`로 바꿉니다. 로그에는 key 이름만 남기고 사용자가 넣은 값(이메일 등)은 남기지 않습니다.

```ts
// AllExceptionsFilter: DB UNIQUE 위반(ER_DUP_ENTRY)을 같은 409 응답 틀로 바꾼다
const key = /for key '([^']+)'/.exec(driverError.sqlMessage)?.[1]; // 예: member.email
if (key.endsWith('uk_rating_member_movie')) return ratingDuplicated(); // RATING4091
if (key === 'member.email') return emailDuplicated();                  // MEMBER4091
if (key === 'member.nickname') return nicknameDuplicated();            // MEMBER4092
```

전체 코드: [AllExceptionsFilter](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week06/movie/src/filter/all-exceptions.filter.ts)

**3) 동시 요청으로 DB 제약 위반을 재현했습니다.** 같은 이메일(`race@umc.com`, 닉네임만 `경주0~7`로 다르게)로 `POST /members`를 **동시에 8번** 보냈습니다.

| 항목 | 결과 |
| --- | --- |
| 상태 코드 | `[201, 409, 409, 409, 409, 409, 409, 409]` — 201 × 1, 409 × 7 |
| DB의 그 이메일 행 | 1개 |
| 사전 중복 확인을 통과해 DB 제약에 걸린 요청 | 7건 — 서버 경고 로그 `DB UNIQUE 제약 위반을 409 로 변환했습니다 (key: member.email)` 7줄 |
| 409 응답 본문 | `{"isSuccess":false,"code":"MEMBER4091","message":"이미 사용 중인 이메일입니다.","result":null}` — 사전 확인에서 막힌 경우와 똑같은 틀 |

#### 확인 포인트: 사전 중복 체크를 통과한 상황에서도 DB 제약 위반이 발생할 수 있다는 점

8개 요청이 모두 "이 이메일은 아직 없다"는 사전 확인(조회)을 통과했습니다. 사전 확인과 저장(INSERT) 사이에 틈이 있어서, 그 틈에 다른 요청이 먼저 저장하면 나머지는 확인을 통과했는데도 저장 단계에서 충돌합니다. 이때 마지막으로 중복을 막는 것이 DB의 UNIQUE 제약입니다. 제약이 없었다면 같은 이메일이 7건 더 저장됐을 것입니다.

그래서 서비스의 사전 확인은 **친절한 메시지를 주기 위한 것**, DB 제약은 **정합성의 최종 방어선**으로 둘 다 필요합니다. 제약 위반을 500이 아니라 같은 409 응답 틀로 바꿔 주는 것까지가 이번 챌린지입니다. 이 재현은 e2e 테스트에서 사전 확인이 항상 "없음"이라고 답하도록 바꿔(spy) 결정적으로도 확인했습니다(이메일 · 닉네임 · 평점 각각).

## 💪 미션 기록

### 진행 과정

1. **워크북과 5주차 코드 비교.** NestJS 워크북 예제를 읽고, 5주차 `movie` 프로젝트의 레이어 구조(controller · service · entity · dto)와 ESM(`"type": "module"`, import에 `.js`)을 그대로 두고 파일만 더했습니다.
2. **응답 틀과 오류 코드부터 정했습니다.** `ApiResponse`(`{ isSuccess, code, message, result }`), `ErrorCode`/`ApiException`, 전역 `AllExceptionsFilter`를 먼저 만들어 성공과 실패가 처음부터 같은 틀을 쓰게 했습니다.
3. **DTO 검증.** `CreateMemberDto` · `CreateRatingDto` · `UpdateRatingDto`에 규칙을 두고, DTO에 없는 필드는 400이 되도록 `forbidNonWhitelisted`를 켰습니다.
4. **Service.** 회원가입은 사전 중복 확인 → bcrypt → 저장 → 비밀번호를 뺀 응답. 평점 수정·삭제는 먼저 찾고(404) 주인을 비교(403)합니다.
5. **테스트.** 단위 테스트 52개(응답 틀 · DB 변환 필터 · 가입 규칙 · 평점 Service), e2e 36개(5주차 조회 8 + 6주차 쓰기 28, 쓰기는 일회용 `umc_movie_test`에서만), 라이브 검증 스크립트 26건, Newman 18개 요청 · 37개 assertion.
6. **동시 요청 재현.** 같은 이메일로 8건을 동시에 보내 DB UNIQUE 위반이 7번 409로 바뀌는 것을 서버 로그로 확인했습니다.
7. **직접 다시 실행해 확인.** 위 결과를 믿고 넘기지 않고 `npm run build` · `lint` · `test`(52개) · `test:e2e`(36개)를 다시 돌렸고, 실제 서버를 띄워 5주차 조회 API가 예전 모양 그대로({"available":…}, 배열)인지 확인했습니다. 개발용 DB는 전후로 회원 2 · 평점 3 그대로였습니다.
8. **프론트 연동 확인.** 6주차 Flutter 앱을 같은 서버에 붙여 닉네임·이메일 중복 확인과 마이페이지 평점 조회가 그대로 동작하는지 Chrome에서 직접 확인했습니다. ([프론트 6주차 기록](../../Frontend/chapter06/mission.md))

### 워크북 예제와 다르게 한 부분

- **PATCH의 `comment`**: 워크북 예제는 `dto.comment ?? null`이라 `comment`를 생략하면 기존 후기가 지워집니다. PATCH는 부분 수정이므로 **생략하면 유지, `null`을 보내면 삭제**로 바꿨습니다(e2e로 확인).
- **비밀번호 특수문자**: 워크북 정규식은 `!@#$%^&*`만 특수문자로 인정합니다. 영문·숫자·공백이 아닌 문자는 모두 허용하도록 넓히고, bcrypt가 72바이트 뒤를 무시하므로(직접 확인) 상한 72자를 더했습니다.
- **이메일·닉네임 공백 제거**: 앞뒤 공백을 `@Transform`으로 지우고 검증합니다. 프론트가 `trim()`해서 보내는 값과 서버가 저장하는 값이 어긋나지 않게 하려는 것입니다.
- **성공 응답 감싸기 범위**: 5주차 GET의 성공 본문은 그대로 두었습니다(Flutter가 이미 `{available}`·배열을 그대로 읽습니다). 대신 **실패 응답은 GET도 같은 틀**로 바뀝니다. 상태 코드는 그대로입니다.
- **응답 생성 방식**: 인터셉터 대신 응답 헬퍼를 썼습니다.

### 트러블 슈팅 (추가)

##### ⚡ 이슈 No.2 테스트는 통과하는데 출력에 `ERROR` 스택이 찍힘

`이슈`
👉 필터 단위 테스트가 모두 통과했는데 터미널에 `[Nest] ERROR [AllExceptionsFilter] Error: Access denied for user 'root'@'localhost'` 스택이 길게 찍혔습니다.

`문제`
👉 "처음 보는 오류는 500으로 바꾸고 원문은 서버 로그에만 남긴다"는 동작이 테스트에서도 그대로 로그를 출력한 것입니다. 실패가 아니라 의도한 동작이지만 진짜 오류와 구분이 안 돼서 출력이 읽기 어려웠습니다.

`해결`
👉 해당 테스트에서 `Logger.prototype.error`·`warn`을 `vi.spyOn`으로 막고, 막은 로그가 실제로 한 번 호출됐는지(그리고 key 이름만 있고 값은 없는지)를 `expect`로 검증했습니다. 출력은 조용해지고 로그를 남긴다는 동작은 테스트가 계속 보장합니다.

`참고레퍼런스`
- [NestJS Logger](https://docs.nestjs.com/techniques/logger)

##### ⚡ 이슈 No.3 린트 경고 — 클래스 인스턴스 spread와 `sort()`

`이슈`
👉 테스트 코드에 `oxlint` 경고 6개가 떴습니다. `no-misused-spread`(클래스 인스턴스에 `...`)와 `require-array-sort-compare`(숫자 배열 `.sort()`).

`문제`
👉 `{ ...rating }`는 Entity 클래스의 프로토타입을 잃습니다. 숫자 상태 코드 배열을 비교 함수 없이 `.sort()`하면 문자열 순서로 정렬돼 우연히 맞더라도 안전하지 않습니다.

`해결`
👉 spread는 `Object.assign`으로, 정렬은 `.sort((a, b) => a - b)`로 바꿨습니다. 경고 0.

### 검증 요약

- `npm run build` · `npm run lint` 성공 (경고 0)
- `npm test` **52개** 통과
- `npm run test:e2e` **36개** 통과 (5주차 조회 8 + 6주차 쓰기 28)
- 라이브 검증 스크립트 **26건** → [기록](evidence/week06-api-results.json)
- Newman **18개 요청 · 37개 assertion** → [Collection](evidence/week06.postman_collection.json) · [결과](evidence/week06-newman.json)

### 확인하지 못한 것

- Postman 데스크톱 앱 화면 캡처는 없습니다(위 "실습 인증" 참고).
- 쓰기 API(POST/PATCH/DELETE)를 Flutter 화면에서 직접 호출한 확인은 없습니다. 6주차 Flutter 워크북은 조회·중복 확인만 사용합니다.
- 동시성 재현은 서버 1개 프로세스와 로컬 MySQL 1대에서 한 것입니다. 여러 서버 인스턴스나 부하 상황은 확인하지 않았습니다.
- 비밀번호 해시 비교(로그인)는 7주차 범위라 구현하지 않았습니다.
