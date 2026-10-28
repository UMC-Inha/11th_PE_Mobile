# 5주차 백엔드 핵심 키워드

## SOP와 CORS

**SOP(Same-Origin Policy, 동일 출처 정책)** 는 브라우저의 기본 보안 규칙이다. 출처(Origin)는 프로토콜 + 호스트 + 포트이고, 셋 중 하나라도 다르면 다른 출처다. `http://localhost:5173`과 `http://localhost:3000`은 포트만 달라도 다른 출처다. 브라우저는 다른 출처로 보낸 요청의 응답을 JavaScript가 읽지 못하게 막는다. 이 규칙이 없으면 사용자가 연 아무 사이트의 스크립트가 로그인된 은행·메일 서버의 응답을 읽어 갈 수 있다.

**CORS(Cross-Origin Resource Sharing)** 는 서버가 "이 출처는 읽어도 된다"고 응답 헤더로 허락하는 방식이다. 브라우저는 요청에 `Origin`을 붙이고, 응답의 `Access-Control-Allow-Origin`이 그 출처(또는 `*`)일 때만 응답을 스크립트에 넘긴다.

- 요청은 서버에 도착하고 처리된다. 막히는 것은 브라우저가 응답을 넘겨주는 단계다. 이번 실습에서도 콘솔에 `net::ERR_FAILED 200 (OK)`이 함께 찍혔다.
- `Content-Type: application/json` 본문이나 `Authorization` 헤더처럼 단순 요청 조건을 벗어나면 브라우저가 먼저 `OPTIONS` **Preflight** 를 보내 허용 Method·Header를 묻는다. 이번 서버는 OPTIONS에 204와 `Access-Control-Allow-Methods: GET,POST,PATCH,DELETE`로 답했다.
- 원인과 해결은 항상 서버 쪽 응답 헤더다. 프론트 코드를 고쳐서는 사라지지 않는다.
- CORS는 브라우저가 지키는 규칙이라 Flutter 네이티브 앱·Postman·curl은 적용받지 않는다. 서버 보안 장치가 아니므로 인증·권한 검사는 따로 해야 한다.

참고: [MDN CORS](https://developer.mozilla.org/ko/docs/Web/HTTP/CORS), [MDN 동일 출처 정책](https://developer.mozilla.org/ko/docs/Web/Security/Same-origin_policy), [NestJS CORS](https://docs.nestjs.com/security/cors)

## Same-Origin과 Same-Site의 차이

| | Same-Origin | Same-Site |
| --- | --- | --- |
| 기준 | 프로토콜 + 호스트 + 포트가 모두 같음 | 등록 가능 도메인(eTLD+1)이 같음. 요즘 브라우저는 프로토콜(scheme)까지 봄 |
| 예 | `https://a.example.com` ↔ `https://b.example.com` 은 다른 출처 | 같은 사이트(`example.com`) |
| 쓰이는 곳 | 응답을 JavaScript가 읽어도 되는가(SOP·CORS) | 이 요청에 쿠키를 자동으로 실을 것인가(SameSite 쿠키) |

`localhost:5173`과 `localhost:3000`은 **다른 출처지만 같은 사이트**다. 그래서 CORS 설정은 필요하지만 SameSite=Lax 쿠키는 전송될 수 있다. eTLD는 `github.io`처럼 공개 접미사 목록에 있는 단위라 `a.github.io`와 `b.github.io`는 서로 다른 사이트다.

참고: [web.dev Same-site and same-origin](https://web.dev/articles/same-site-same-origin)

## 쿠키의 SameSite 속성

다른 사이트에서 시작된 요청에 쿠키를 실을지 정한다. CSRF(사용자가 모르게 다른 사이트가 요청을 보내게 하는 공격)를 줄이는 장치다.

- `Strict`: 같은 사이트에서 시작된 요청에만 쿠키를 보낸다. 다른 사이트의 링크로 들어와도 첫 요청엔 쿠키가 없다.
- `Lax`: 다른 사이트에서 오는 요청이라도 링크 클릭 같은 최상위 GET 이동에는 보내고, 이미지·iframe·fetch·POST 폼 같은 하위 요청에는 보내지 않는다. 속성을 안 쓰면 크롬은 Lax로 본다.
- `None`: 모든 요청에 보낸다. 반드시 `Secure`(HTTPS)와 함께 써야 한다.

이번 커리큘럼의 로그인은 쿠키가 아니라 `Authorization` 헤더 방식이라 SameSite를 직접 설정하지 않는다. 헤더 토큰은 브라우저가 자동으로 붙이지 않으므로 CSRF 위험은 적지만, 대신 CORS 허용 목록과 Preflight를 신경 써야 한다.

참고: [MDN Set-Cookie SameSite](https://developer.mozilla.org/ko/docs/Web/HTTP/Headers/Set-Cookie#samesitesamesite-value)

## 복합 UNIQUE 제약을 사용하는 이유

`UNIQUE KEY uk_favorite_member_movie (member_id, movie_id)`는 "두 컬럼의 조합"이 겹치지 않게 한다. member_id 하나나 movie_id 하나에만 UNIQUE를 걸면 "한 회원은 영화 하나만", "한 영화는 한 회원만" 같은 틀린 규칙이 된다. 조합에 걸어야 "같은 회원이 같은 영화를 두 번 즐겨찾기(평점)할 수 없다"는 요구사항과 정확히 맞는다.

- 애플리케이션에서 "먼저 조회 후 없으면 저장"만 하면 동시에 두 요청이 오면 둘 다 "없음"을 보고 중복 저장될 수 있다. DB 제약은 마지막 방어선이고, 위반 시 오류(MySQL 1062)를 409 같은 응답으로 바꾸면 된다.
- MySQL InnoDB는 UNIQUE에 인덱스를 만든다. `(member_id, movie_id)` 순서라 `WHERE member_id = ?` 조회(유저별 평점·즐겨찾기 목록)에도 이 인덱스의 앞부분을 쓸 수 있다.
- 이번 엔티티에도 `@Unique('uk_rating_member_movie', ['member', 'movieId'])`로 같은 제약을 표시해 코드만 보고도 규칙을 알 수 있게 했다.

참고: [MySQL CREATE INDEX / UNIQUE](https://dev.mysql.com/doc/refman/8.4/en/create-index.html), [TypeORM Indices](https://typeorm.io/docs/indices/indices/)

## 외부 Open API 연동 시 API Key를 어디에 두어야 안전한가

**비밀로 지켜야 하는 키는 백엔드에 둔다.** 프론트(웹 번들, 앱 asset, 앱 바이너리)에 넣은 값은 사용자 기기로 내려가므로 누구나 꺼낼 수 있다. 이번 Flutter Web 빌드에서도 `.env`가 `build/web/assets/.env`로 그대로 들어간 것을 확인했다. `.env`와 `.gitignore`는 Git 유출을 막을 뿐 배포 후의 노출은 막지 못한다.

- 백엔드 보관: 서버 환경변수나 Secret Manager에 두고, 서버가 대신 외부 API를 부르는 Proxy를 만든다. 사용량 제한, 캐시, 사용자 인증을 붙일 수 있고 키가 새면 서버에서만 바꾸면 된다.
- 프론트에 둬도 되는 경우: 처음부터 공개를 전제로 한 키(지도 SDK 키처럼 도메인·앱 서명 제한을 거는 것)나 읽기 전용·학습용 키. TMDB Read Access Token도 읽기 권한이지만 계정에 묶여 있어 남용되면 제한을 받으므로, 실제 서비스라면 Proxy가 맞다.
- 이번 주는 워크북 방침대로 영화 목록·상세는 프론트가 TMDB를 직접 부르고, 우리 백엔드는 회원·평점만 맡는다. 그래서 Token은 `.env`에만 두고 커밋 대상 파일·로그·화면에 없음을 검사했다(로그는 `Bearer ***`).

참고: [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html), [TMDB FAQ](https://developer.themoviedb.org/docs/faq)
