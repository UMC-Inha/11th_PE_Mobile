# 7주차 백엔드 미션 — 로그인한 사용자를 구분하기

- 이름 / 닉네임: 케빈
- 선택 스택: NestJS 12 + TypeORM + MySQL + bcrypt 6 + `@nestjs/jwt` (Spring Boot 대신 NestJS 한 스택으로 진행)
- [GitHub 실습 저장소 (`movie/` 폴더)](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/tree/brownglasses/week07/movie)
- Pull Request: [Pull Request #23](https://github.com/UMC-Inha/11th_BE_NodeJs_Practice_Mission/pull/23)
- [원본 워크북](https://makeus-challenge.notion.site/7-1-416b57f4596b80fa98cefa0f46b16d43)
- [핵심 키워드](../../../keyword/Backend/chapter07/keyword.md)
- 같은 주 프론트엔드 미션: [프론트 7주차](../../Frontend/chapter07/mission.md)

> 증거 파일(요청·응답 원문과 Newman 결과)은 [evidence/](evidence/)에 있다. 모든 JWT는 서명 부분을 `<signature masked>`로 가렸다.

## 실습 체크리스트

- [x] `ApiException`을 던졌을 때 6주차 전역 처리기가 받아서 우리가 정한 code와 상태 코드로 응답하는지 확인했다.
  - `all-exceptions.filter.spec.ts`가 `AUTH401_1~4`·`RATING403_1`·`RATING404_1`을 던져 상태·code·`{isSuccess:false, …, result:null}`을 확인하고, 실제 서버의 6~8단계 응답이 모두 같은 틀이다.
- [x] `POST /auth/login`으로 토큰을 발급받고 payload 내용을 직접 확인했다.
  - 발급된 토큰의 Header·Payload를 base64url로 디코드해 `{"alg":"HS256","typ":"JWT"}`와 `{"sub":"3","email":"viewer1@umc.com","iat":…,"exp":…}`(유효 3600초, 비밀번호·해시 없음)를 읽었다. **jwt.io 사이트를 직접 열지는 않았고**, 같은 디코드를 스크립트로 했다.
- [x] 존재하지 않는 이메일과 틀린 비밀번호가 같은 응답을 돌려주는지 확인했고 그 이유를 설명할 수 있다.
  - 두 응답 본문이 글자까지 같다(Newman `2-3`·`2-4`, e2e). 이유: 가입 여부 자체가 개인정보라 응답(내용과 시간)으로 이메일이 존재하는지 알아내지 못하게 하려는 것이다.
- [x] Guard를 등록해 토큰 없이 `GET /members/me`를 호출하면 401이 나오는 것을 확인했다.
- [x] 토큰 payload의 한 글자를 다른 글자로 **교체**해서 호출했을 때 서명 검증에 걸려 401(`AUTH401_3`)이 나오는 것을 확인했다.
- [x] 평점 등록/수정/삭제 API에서 memberId를 받는 코드를 전부 제거했다.
  - 컨트롤러·서비스 시그니처에 `memberId` 파라미터가 없다(공개 조회의 `:memberId` 경로 제외). 6주차 경로로 요청하면 404, 요청 Body에 `memberId`를 넣으면 400이다.
- [x] 회원 두 명으로 남의 평점 수정을 시도해 403을 받아냈고 401과 어떻게 다른지 설명할 수 있다.
  - 401은 요청자를 특정할 수 없는 것(토큰 없음·변조·만료), 403은 요청자는 알지만 그 데이터가 남의 것인 것이다. 인증은 컨트롤러 앞 Guard, 인가는 DB를 봐야 아는 서비스가 맡는다.

## 이번 주에 바뀐 것

| API | 7주차 | 6주차 | 변화 |
| --- | --- | --- | --- |
| 로그인 | `POST /auth/login` | — | 새로 만듦. 200 + `{nickname, accessToken}` |
| 내 정보 조회 | `GET /members/me` + `Authorization: Bearer` | — | 새로 만듦 |
| 내 정보 수정 | `PATCH /members/me` + `Authorization: Bearer` | — | 새로 만듦. 닉네임만 |
| 평점 등록 | `POST /ratings` | `POST /members/{memberId}/ratings` | 경로·요청에서 memberId 제거. 응답 `result`가 ratingId 숫자 → 평점 객체 |
| 평점 수정 | `PATCH /ratings/{ratingId}` | `PATCH /members/{memberId}/ratings/{ratingId}` | memberId 제거. 응답 `result`가 `null` → 평점 객체 |
| 평점 삭제 | `DELETE /ratings/{ratingId}` | `DELETE /members/{memberId}/ratings/{ratingId}` | memberId 제거. **204 → 200**(`result: null`) |
| 유저별 평점 조회 | `GET /members/{memberId}/ratings` | 같음 | 공개 API라 그대로 |

요청 Body는 6주차 그대로다. 누구인지는 URL이 아니라 `Authorization` 헤더의 토큰이 알려 준다. 204를 200으로 바꾼 것은 204가 본문을 보낼 수 없어 `{isSuccess, code, message, result}` 틀을 실을 수 없기 때문이다.

### 에러 code

| 상황 | code | 상태 | message |
| --- | --- | --- | --- |
| 로그인 정보가 틀림 | `AUTH401_1` | 401 | 이메일 또는 비밀번호가 올바르지 않습니다. |
| 토큰이 없음 | `AUTH401_2` | 401 | 로그인이 필요한 요청입니다. |
| 토큰이 위조됨 | `AUTH401_3` | 401 | 유효하지 않은 토큰입니다. |
| 토큰이 만료됨 | `AUTH401_4` | 401 | 토큰이 만료되었습니다. 다시 로그인해주세요. |
| 회원을 찾을 수 없음 | `MEMBER404_1` | 404 | 해당 회원을 찾을 수 없습니다. |
| 닉네임이 이미 쓰이는 중 | `MEMBER409_1` | 409 | 이미 사용 중인 닉네임입니다. |
| 이메일이 이미 쓰이는 중 | `MEMBER409_2` | 409 | 이미 사용 중인 이메일입니다. |
| 평점을 찾을 수 없음 | `RATING404_1` | 404 | 해당 평점을 찾을 수 없습니다. |
| 남의 평점을 건드림 | `RATING403_1` | 403 | 본인이 작성한 평점만 수정하거나 삭제할 수 있습니다. |
| 같은 영화에 평점을 또 남김 | `RATING409_1` | 409 | 이미 이 영화에 평점을 남기셨습니다. |

`{도메인}{HTTP 상태}_{일련번호}` 규칙이다. 성공은 6주차 그대로 `COMMON200`/`COMMON201`이다. 6주차의 `MEMBER4041`·`MEMBER4091`(이메일)·`MEMBER4092`(닉네임)·`RATING4041`·`RATING4031`·`RATING4091`은 이 규칙으로 바꿨다. 이메일 중복 `MEMBER409_2`는 워크북 표에 없어 닉네임 `MEMBER409_1`과 구분하려고 내가 추가했다(번호가 6주차와 서로 뒤바뀐 점 주의). HTTP 상태 코드는 6주차와 같다.

## 구현 구조

```
movie/src
├── config       jwt.config.ts          ← JWT_SECRET·만료 검사, HS256 고정 (새 파일)
├── guard        auth.guard.ts          ← 컨트롤러 앞 관문 (새 파일)
│                authenticated-request.ts  요청 키 상수 LOGIN_MEMBER_KEY 한곳
├── decorator    login-member.decorator.ts ← @LoginMember() (선택 2)
├── controller   auth.controller.ts(새), member.controller.ts(+GET·PATCH me), rating.controller.ts(@Controller(), /ratings)
├── service      auth.service.ts(새), member.service.ts(+getMyInfo·updateMyInfo), rating.service.ts(memberId 첫 인자)
├── dto          login-request / login-response / member-info-response / member-update-request (새 파일)
└── exception    api.exception.ts       ← 새 code
```

설정: `npm i @nestjs/jwt`, `.env`에 `JWT_SECRET`(32자 이상)과 `JWT_ACCESS_EXPIRATION`(초)을 넣고 `JwtModule`을 전역으로 등록했다. `.env`는 Git에 올라가지 않으며(`git check-ignore`로 확인), `.env.example`의 `JWT_SECRET`은 일부러 서버가 거부하는 예시 값이다.

## 핵심 코드

- [`src/guard/auth.guard.ts`](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week07/movie/src/guard/auth.guard.ts) — 토큰 검사 관문
- [`src/service/auth.service.ts`](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week07/movie/src/service/auth.service.ts) — 로그인
- [`src/service/rating.service.ts`](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week07/movie/src/service/rating.service.ts) — `findOwnedRating`(404 → 403 순서의 소유권 검사)
- [`src/controller/rating.controller.ts`](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week07/movie/src/controller/rating.controller.ts) — 토큰 기반 평점 CRUD
- [`src/decorator/login-member.decorator.ts`](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week07/movie/src/decorator/login-member.decorator.ts) — `@LoginMember()`
- [`src/config/jwt.config.ts`](https://github.com/brownglasses/11th_BE_NodeJs_Practice_Mission/blob/brownglasses/week07/movie/src/config/jwt.config.ts) — 비밀키·만료 설정 검사

```ts
// src/guard/auth.guard.ts (발췌)
async canActivate(context: ExecutionContext): Promise<boolean> {
  const request = context.switchToHttp().getRequest<AuthenticatedRequest>();
  const token = extractBearerToken(request.headers.authorization);
  if (token === null) throw tokenMissing();                 // AUTH401_2

  let payload: AccessTokenPayload;
  try {
    payload = await this.jwtService.verifyAsync<AccessTokenPayload>(token); // 서명 + 만료
  } catch (error) {
    if (error instanceof TokenExpiredError) throw tokenExpired();           // AUTH401_4
    throw tokenInvalid();                                                   // AUTH401_3
  }
  const memberId = Number(payload.sub);
  if (!Number.isSafeInteger(memberId) || memberId < 1) throw tokenInvalid();
  request[LOGIN_MEMBER_KEY] = memberId;
  return true;
}
```

```ts
// src/service/auth.service.ts (발췌) — 없는 이메일에도 bcrypt 비교를 한 번 한다
const member = await this.memberRepository.findOne({ where: { email: dto.email } });
const matched = await bcrypt.compare(dto.password, member?.password ?? TIMING_EQUALIZER_HASH);
if (!member || !matched) throw loginFailed();               // 둘 다 AUTH401_1
```

## 실습 인증

워크북의 "회원을 두 명 만들어 두는" 시나리오 9단계를 실제 서버(일회용 DB)에 보낸 결과다. Postman **데스크톱 앱 캡처는 없다**. 같은 요청을 [Postman Collection](evidence/week07.postman_collection.json)으로 만들어 Newman(Postman CLI 실행기)으로 실행했고, Collection을 Postman 앱에서 Import 해서 직접 실행해 볼 수도 있다.

### ① 로그인 성공 — 200 (accessToken)

```http
POST /auth/login
{ "email": "viewer1@umc.com", "password": "Umc!1234" }
```

```json
{
  "isSuccess": true,
  "code": "COMMON200",
  "message": "로그인에 성공했습니다.",
  "result": {
    "nickname": "뷰어1",
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIzIiwiZW1haWwiOiJ2aWV3ZXIxQHVtYy5jb20iLCJpYXQiOjE3OTQ0NjY4NjYsImV4cCI6MTc5NDQ3MDQ2Nn0.<signature masked>"
  }
}
```

토큰을 디코드한 값:

```json
{ "header": { "alg": "HS256", "typ": "JWT" },
  "payload": { "sub": "3", "email": "viewer1@umc.com", "iat": 1794466866, "exp": 1794470466 } }
```

`exp − iat = 3600`초이고, 비밀번호나 해시는 들어 있지 않다.

### ② 토큰 없이 `GET /members/me` — 401

```http
GET /members/me
```

```json
{ "isSuccess": false, "code": "AUTH401_2", "message": "로그인이 필요한 요청입니다.", "result": null }
```

### ③ 다른 회원의 토큰으로 평점 수정 — 403

회원 A(뷰어1)가 만든 평점 4번을 회원 B(뷰어2)의 토큰으로 수정해 본다.

```http
PATCH /ratings/4
Authorization: Bearer <회원 B의 토큰, 서명 가림>
{ "score": 1 }
```

```json
{ "isSuccess": false, "code": "RATING403_1", "message": "본인이 작성한 평점만 수정하거나 삭제할 수 있습니다.", "result": null }
```

토큰은 멀쩡한데도 막혔다. 인증은 통과했고 인가에서 걸린 것이다.

### ④ 본인 토큰으로 평점 등록 — 201 (Body에 memberId 없음)

```http
POST /ratings
Authorization: Bearer <회원 A의 토큰, 서명 가림>
{ "movieId": 550, "score": 5, "comment": "최고의 영화!" }
```

```json
{
  "isSuccess": true,
  "code": "COMMON201",
  "message": "평점 등록에 성공했습니다.",
  "result": { "ratingId": 4, "movieId": 550, "score": 5, "comment": "최고의 영화!",
              "createdAt": "2026-11-12T07:01:07.000Z", "updatedAt": "2026-11-12T07:01:07.000Z" }
}
```

## 미션 인증

### (필수) 시나리오 9단계

| 단계 | 요청 | 결과 | code |
| --- | --- | --- | --- |
| 1 | 회원 A(`뷰어1`), B(`뷰어2`) 가입 `POST /members` | 201, memberId 3·4 | `COMMON201` |
| 2 | 각자 `POST /auth/login` | 200, 토큰 A·B | `COMMON200` |
| 3 | 토큰 A로 `POST /ratings` | **201**, ratingId 4 | `COMMON201` |
| 4 | 같은 movieId로 한 번 더 | **409** | `RATING409_1` |
| 5 | 토큰 A로 `PATCH /ratings/4` | **200**, 점수 5→2, 후기 변경 | `COMMON200` |
| 6 | 토큰 B로 같은 `PATCH` | **403** | `RATING403_1` |
| 7 | 토큰 없이 같은 `PATCH` | **401** | `AUTH401_2` |
| 8 | 토큰 A로 `DELETE /ratings/99999` | **404** | `RATING404_1` |
| 9 | 토큰 A로 `DELETE /ratings/4` | **200**, `result: null` | `COMMON200` |

9단계 뒤 `GET /members/3/ratings`는 `200 []`로 목록에서 사라진 것을 확인했다. 요청·응답 원문은 [week07-api-results.json](evidence/week07-api-results.json)에 있다.

**확인 포인트**

- 평점 등록 요청 바디에 `memberId`가 없다(위 ④). 넣어서 보내면 400 `property memberId should not exist`.
- 401(`AUTH401_2`)과 403(`RATING403_1`)의 code가 서로 다르다. 스크립트와 Newman이 둘이 다른지 직접 assert한다.
- 6주차 방식 `POST /members/3/ratings`, `DELETE /members/3/ratings/4`는 둘 다 404다(사라진 경로).

### (선택 1) 토큰 만료 — `AUTH401_4`

`JWT_ACCESS_EXPIRATION=60`으로 줄인 서버를 띄우고(이 실행에서만 쓰는 무작위 키), 로그인한 뒤 같은 토큰으로 `GET /members/me`를 두 번 불렀다.

| | 만료 전 (로그인 후 0.1초) | 만료 후 (로그인 후 60.7초, 같은 토큰) | 토큰 없음 (비교) |
| --- | --- | --- | --- |
| 상태 | **200** | **401** | **401** |
| code | `COMMON200` | `AUTH401_4` | `AUTH401_2` |
| message | 회원 정보를 조회했습니다. | 토큰이 만료되었습니다. 다시 로그인해주세요. | 로그인이 필요한 요청입니다. |

두 401이 code로 구분된다. 응답만 보고도 "토큰이 없다(로그인 필요)"와 "토큰이 만료됐다(다시 로그인)"를 가를 수 있다. 다시 로그인해 받은 새 토큰으로는 200이었다. 자동 테스트도 있다(단위: 과거 `exp`로 서명한 토큰, e2e: `expiresIn: 1`로 발급해 2.2초 뒤 401). 원문: [week07-expiry.json](evidence/week07-expiry.json)

### (선택 2) `@LoginMember()`로 반복 줄이기

**적용 전** — 요청 객체에서 키 문자열로 직접 꺼낸다.

```ts
@Post('ratings')
@UseGuards(AuthGuard)
async create(
  @Req() request: AuthenticatedRequest,
  @Body() dto: CreateRatingDto,
) {
  const memberId = request['memberId'] as number;
  const result = await this.ratingService.create(memberId, dto);
  ...
}
```

**적용 후**

```ts
@Post('ratings')
@UseGuards(AuthGuard)
async create(
  @LoginMember() memberId: number,
  @Body() dto: CreateRatingDto,
) {
  const result = await this.ratingService.create(memberId, dto);
  ...
}
```

```ts
// src/decorator/login-member.decorator.ts
export const LoginMember = createParamDecorator(
  (_data: unknown, context: ExecutionContext): number => {
    const memberId = context.switchToHttp().getRequest<AuthenticatedRequest>()[LOGIN_MEMBER_KEY];
    if (memberId === undefined) {
      // 가드를 붙이지 않은 곳에서 쓴 개발 실수 → 500으로 드러낸다
      throw new Error('@LoginMember() 는 @UseGuards(AuthGuard) 가 붙은 핸들러에서만 쓸 수 있습니다.');
    }
    return memberId;
  },
);
```

**확인 포인트**: 이름만 보고도 "이 값은 로그인한 사용자에게서 온다"가 드러나고, 컨트롤러에서 문자열 `"memberId"`를 요청에서 꺼내는 곳이 없어졌다. 키 상수 `LOGIN_MEMBER_KEY`는 Guard와 데코레이터가 같이 쓰는 한 파일에만 있다. 컨트롤러 소스를 읽어 `request['memberId']`·`@Req(`가 없고, `'memberId'` 문자열은 공개 조회의 `@Param('memberId', ParseIntPipe)` 한 줄뿐인지 검사하는 테스트를 추가했다. 바꾼 뒤에도 e2e 66개가 그대로 통과했다(동작 동일).

## 미션 기록

### 진행 과정

1. 워크북을 읽고 6주차 코드와 비교했다. 6주차에 이미 `ApiException`과 전역 필터가 있어서 "이번 주에 새로 생기는 건 예외 클래스 하나"라는 안내와 달리 **에러 code 체계를 워크북 규칙으로 바꾸는 일**이 더 큰 변경이었다.
2. `JwtModule`과 `JWT_SECRET` 설정부터 만들고, 키가 없거나 32자보다 짧거나 예시 값이면 서버가 뜨지 않게 했다.
3. 로그인 → Guard → `GET·PATCH /members/me` → 평점 CRUD 토큰 전환 순서로 만들었다. Guard를 먼저 세운 뒤에 `/members/me`를 만들어 "관문이 준비되면 컨트롤러가 얇아진다"를 확인했다.
4. 6주차 평점 서비스의 인자 순서를 `(memberId, ratingId, …)`로 통일하고 `findOwnedRating`에서 404를 먼저, 403을 나중에 판정하게 했다.
5. 단위 테스트(114개)와 e2e(66개), 실제 서버 검증 스크립트(31개 확인), Newman(20개 요청·46개 assertion)으로 확인했다.
6. 일부러 코드를 망가뜨려 테스트가 잡는지도 확인했다(아래 "검증").
7. 선택 1(만료)은 실제로 60초를 기다려 확인했고, 선택 2(`@LoginMember`)로 컨트롤러를 정리했다.

### 워크북과 다르게 한 부분

- **PATCH의 `comment`**: 워크북은 `rating.comment = dto.comment ?? null`(생략하면 후기 삭제)이다. 6주차에 정한 **생략 = 유지, `null` = 삭제**를 그대로 뒀다. 프론트가 `comment`를 항상 명시해서 보내므로 호환된다.
- **Guard의 추가 방어**: 알고리즘을 HS256으로 고정했고, 서명이 맞아도 `sub`가 양의 정수가 아니면 거절한다. `Bearer ` 접두사의 대소문자를 구분하지 않고, 뒤가 비어 있으면 토큰이 없는 것으로 본다.
- **로그인 이메일 trim**: 가입 때 trim해서 저장하므로 로그인도 trim해서 찾는다. 비밀번호는 trim하지 않는다.
- **`createdAt` 형식**: 워크북 예시는 오프셋 없는 시각이고, 우리는 기존 응답과 같은 ISO UTC(`…Z`)다.
- **성공 message**: 평점 등록·수정·삭제는 6주차 문구('평점 등록에 성공했습니다.' 등)를 유지했다. code와 상태는 워크북과 같다.
- **시드 회원은 로그인할 수 없다**: 시드의 수현·민서 비밀번호는 유효한 해시가 아닌 더미 값이다. 이 계정으로 로그인하면 500이 아니라 `AUTH401_1`이 나오는 것을 단위·e2e로 확인했다. 로그인해 볼 회원은 `POST /members`로 새로 가입해야 한다.

### 검증

| 항목 | 결과 |
| --- | --- |
| `npm run build` | 통과 |
| `npm run lint` (oxlint --type-aware) | 경고·오류 0 |
| `npm test` (단위) | 114개 통과 (6주차 52개) |
| `npm run test:e2e` | 66개 통과 (6주차 36개) |
| 실제 서버 검증 `verify:week07` | 31개 확인 통과 ([결과](evidence/week07-api-results.json)) |
| Newman `newman:week07` | 20개 요청 · 46개 assertion · 실패 0 ([결과](evidence/week07-newman.json)) |
| 토큰 만료 `verify:expiry` | 만료 전 200 → 60.7초 뒤 401 `AUTH401_4` ([결과](evidence/week07-expiry.json)) |

- **변이 검사**: 코드를 일부러 망가뜨리면 테스트가 실제로 실패하는지 확인했다. ① 삭제 API의 `@UseGuards`를 지움 → e2e 2개 실패 ② 소유자 비교(403)를 지움 → e2e 2개 실패 ③ `verifyAsync`를 서명 검증 없는 `decode`로 바꿈 → e2e 3개 실패 ④ 타이밍 보정을 지움 → 단위 1개 실패 ⑤ 닉네임 중복 검사에서 `Not(memberId)`를 지움 → e2e 1개 실패. 모두 원복했다.
- 쓰기 테스트는 매번 새로 만드는 일회용 DB에서만 돈다. 개발 DB `umc_movie`는 작업 전과 후 모두 회원 2·평점 3 그대로였다.
- 변경·신규 파일 전체에서 `.env`의 실제 `JWT_SECRET` 값과 서명이 가려지지 않은 JWT를 검색했고 한 건도 없었다.

### 확인하지 못한 것

- Postman **데스크톱 앱 화면 캡처**는 없다(Newman으로 같은 Collection을 실행). jwt.io **사이트를 직접 열어 본 것도 아니다**(같은 디코드를 스크립트로 했다).
- 로그아웃·토큰 폐기·Refresh Token·로그인 시도 횟수 제한은 워크북 범위 밖이라 없다. 한 번 발급된 토큰은 만료 전까지 유효하다.
- 로그인 응답 시간 보정은 같은 머신·단일 연결에서 중앙값만 본 것이다. 서버가 여러 대이거나 부하가 있는 상황, 서버끼리 시계가 어긋난 상황의 만료 판정은 확인하지 않았다.
- 실제 브라우저(Flutter Web)에서 `Authorization` 헤더를 단 요청의 CORS는 e2e의 preflight 요청으로만 확인했고 브라우저로는 확인하지 않았다.
- 이 주차의 프론트(Flutter) 쓰기 화면은 6주차 계약(`/members/{memberId}/ratings`)으로 만들어져 있어서, 이번 서버(`/ratings`, 토큰)와는 아직 연결되지 않았다. 프론트의 JWT 전환은 다음 주차 몫이다.

## 트러블슈팅

### ⚡ No.1 워크북의 `request['memberId']`가 컴파일되지 않음

- **이슈**: `npx nest build`가 `error TS7053: Element implicitly has an 'any' type because expression of type '"memberId"' can't be used to index type 'Request<…>'`를 5곳(member.controller 2, rating.controller 3)에서 냈다.
- **문제**: Express `Request` 타입에는 `memberId` 속성이 없다. 이 프로젝트의 tsconfig는 strict라 문자열 키 인덱싱을 `any`로 넘겨 주지 않는다. 워크북 예제는 느슨한 설정을 전제로 쓴 코드였다.
- **해결**: `src/guard/authenticated-request.ts`에 `type AuthenticatedRequest = Request & { memberId?: number }`와 키 상수 `LOGIN_MEMBER_KEY`를 두고 컨트롤러가 이 타입을 받게 했다. 이후 선택 2에서 `@LoginMember()`로 컨트롤러의 문자열 키 자체를 없앴다.

### ⚡ No.2 로그인 응답 시간이 달라서 가입 여부가 새어 나갈 뻔함

- **이슈**: 응답 **본문**은 "없는 이메일"과 "틀린 비밀번호"가 같게 만들었는데, 보정 없이 응답 **시간**을 재 보니 틀린 비밀번호 중앙값 75.9ms, 없는 이메일 1.7ms로 약 44배 차이였다. 응답 시간만 봐도 "이 이메일은 가입돼 있다"를 알 수 있다.
- **문제**: 이메일이 없으면 bcrypt 비교(cost 10, 수십 ms)를 건너뛰고 바로 401을 돌려줬다.
- **해결**: 없는 이메일에도 cost 10의 가짜 bcrypt 해시(`TIMING_EQUALIZER_HASH`)와 `bcrypt.compare`를 한 번 실행하게 했다. 보정 후 57.8ms 대 57.5ms였다. "없는 이메일에도 `compare`가 한 번 호출된다"를 단위 테스트로 고정했고, 보정을 지우면 그 테스트가 실패하는 것을 확인했다. (한계: 같은 머신에서 중앙값을 본 것이다.)

### ⚡ No.3 린트 경고 — 클래스 인스턴스에 spread

- **이슈**: `npm run lint`가 `auth.service.spec.ts`와 `member.service.spec.ts`에서 "Using the spread operator on class instances will lose their class prototype." 경고를 4건 냈다(6주차까지는 경고 0).
- **문제**: 테스트에서 `Member`(엔티티 클래스) 인스턴스를 `{ ...stored }`로 복사했다. 이렇게 복사하면 클래스의 프로토타입이 사라진다.
- **해결**: `structuredClone(stored)`와 `Object.assign({}, stored, {…})`로 바꿔 경고 0으로 되돌렸다.

### ⚡ No.4 5주차 검증 스크립트를 돌리자 커밋된 5주차 증거 파일이 덮어써짐

- **이슈**: 7주차 이후에도 5주차 스크립트가 도는지 확인하려고 `node scripts/verify-week05.mjs`를 실행하자 `git status`에 `M evidence/week05-api-results.json`이 생겼다(타임스탬프와 404 응답 본문이 6주차 필터 모양으로 바뀜).
- **문제**: 이 스크립트는 실행할 때마다 같은 증거 파일에 결과를 다시 쓴다.
- **해결**: `git checkout -- evidence/week05-api-results.json`으로 5주차 기록을 되돌렸다. 5주차 스크립트 자체는 새 코드에서도 18개 요청이 모두 통과했다. README에 "실행하면 다시 쓴다"고 적어 두었다.

## 학습 후기

가입 여부가 응답 본문이 아니라 응답 시간으로 새어 나갈 수 있다는 것을 직접 재 보고서야 알았다. 본문을 같게 만들었으니 끝났다고 생각했는데, 이메일이 없을 때는 bcrypt 비교를 건너뛰기 때문에 44배 빨랐다. "실패를 하나로 합친다"는 규칙이 겉모양뿐 아니라 **일하는 양**까지 같아야 완성이라는 것이 이해됐다. 또 워크북의 예제 코드가 그대로는 컴파일되지 않는 경우(`TS7053`)가 있어서, 예제를 옮겨 적는 것과 이 프로젝트의 설정에서 동작하게 만드는 것이 다르다는 점도 겪었다. 401과 403은 표로 외울 때보다, 같은 요청에서 토큰만 B로 바꿨더니 "토큰은 멀쩡한데 막히는" 403이 나오는 것을 눈으로 본 뒤에 구분이 분명해졌다. 아직 이해가 덜 된 부분은 토큰을 한 번 발급하면 취소하기 어렵다는 점이다. 다음에 Refresh Token과 폐기를 배우면 이번에 "한계"로 적어 둔 것들을 다시 보고 싶다.
