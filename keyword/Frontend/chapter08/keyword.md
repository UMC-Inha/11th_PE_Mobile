# 8주차 프론트엔드 핵심 개념

> "테스트로 확인"은 가짜 서버(Fake)를 쓴 위젯·ViewModel 테스트에서 본 것이다. 실제 서버와 실제 화면(Flutter Web)에서 본 것은 [미션 문서](../../../mission/Frontend/chapter08/mission.md)에 따로 적었다. 기기의 보안 저장소(iOS Keychain·Android Keystore)는 이 환경(Xcode·Android SDK 없음)에서 확인하지 못했다.

## 인증과 인가, 그래서 401과 403은 다르게 다룬다

| | 질문 | 실패하면 | 앱이 하는 일 |
| --- | --- | --- | --- |
| 인증(Authentication) | 너는 누구인가? | 401 | 로그인 상태를 풀고 로그인 화면으로 보낸다 |
| 인가(Authorization) | 너에게 이 일을 할 권한이 있는가? | 403 | **안내만 한다.** 로그인은 유효하므로 로그아웃하지 않는다 |

- 남의 평점을 수정하려 하면 서버는 403(`RATING403_1`)을 준다. 이때 세션을 정리하면 멀쩡한 사용자를 로그아웃시키는 버그가 된다. 403을 만료로 처리하도록 일부러 바꿔 보면 테스트 5개가 실패한다(변이 검사 M5).
- **401도 하나가 아니다.** 로그인 요청의 `AUTH401_1`(이메일·비밀번호 틀림)은 "아직 로그인하지 않은 사람이 입력을 틀렸다"는 뜻이라 입력 폼에 안내만 하고 만료 안내는 띄우지 않는다. 보호 요청의 `AUTH401_2`(토큰 없음)·`AUTH401_3`(서명·형식 무효)·`AUTH401_4`(만료)만 "세션이 끝났다"는 뜻이다. `AUTH401_1`을 만료로 취급하도록 바꾸면 테스트가 실패한다(M6).
- **네트워크 실패는 401이 아니다.** 응답이 없었으니 토큰이 무효한지 알 수 없다. 이 경우 토큰을 지우면 서버가 잠깐 꺼졌다는 이유로 사용자가 로그아웃된다(M1).

## 토큰이 저장돼 있어도 바로 "로그인됨"이 아니다

앱을 다시 켰을 때 저장소에 토큰 문자열이 있다는 사실은 "이 토큰이 아직 유효하다"는 뜻이 아니다. 만료됐거나 서버가 다른 키로 바뀌었을 수도 있다. 그래서 토큰을 읽은 뒤 `GET /members/me`로 서버에 물어 **성공했을 때만** `signedIn`이 된다.

| `AuthStatus` | 뜻 | 화면 |
| --- | --- | --- |
| `initializing` | 저장된 토큰을 확인하는 중 | 시작(스플래시) 화면 |
| `signedOut` | 로그인하지 않음(직접 로그아웃·만료·로그인 실패 포함) | 로그인 화면 |
| `authenticating` | 로그인 요청 중 | 로그인 화면 |
| `signedIn` | 로그인됨 | 홈 |
| `retryRequired` | 토큰은 있는데 서버·저장소 문제로 확인하지 못함 | 시작 화면 + 다시 시도, **토큰은 유지** |

- `initializing`이 따로 있는 이유: 이 상태가 없으면 토큰을 확인하는 짧은 시간 동안 `signedOut`으로 보여 로그인 화면이 잠깐 비친다.
- GET me 전에 `signedIn`을 확정하도록 바꾸면 테스트가 실패한다(M8). 직접 확인했다.
- 로그인 응답(`POST /auth/login`)에는 `nickname`과 `accessToken`만 있고 `memberId`가 없다. 문서에 없는 값을 JWT 안에서 꺼내 쓰지 않고, 내 정보가 필요하면 `GET /members/me`를 쓴다.

## 토큰은 어디에 두나 — `flutter_secure_storage` vs `shared_preferences`

| | 저장 방식 | 이번에 쓴 것 |
| --- | --- | --- |
| `flutter_secure_storage` | iOS Keychain · Android Keystore 같은 OS 보안 영역 | Access Token |
| `shared_preferences` | 일반 key-value(평문) | 로그인 화면의 "이메일 저장"(이메일만) |

- 토큰은 그 자체가 신분증이라 평문 저장소에 두지 않는다. 비밀번호는 어디에도 저장하지 않는다(이메일 저장이 비밀번호까지 기억하지 않는다는 것을 테스트로 확인했다).
- 로그인·로그아웃·요청 인증 코드가 저장소 구현에 직접 기대지 않도록 `TokenStorage` 인터페이스를 두고 `SecureTokenStorage`가 구현한다. 테스트에서는 메모리 저장소로 바꿔 끼운다.
- **웹에서는 다르다.** Flutter Web의 `flutter_secure_storage`는 Keychain/Keystore가 아니라 WebCrypto와 브라우저 저장소 위에서 동작한다. 그래서 웹에서 "토큰이 저장되고 복원된다"를 확인한 것을 모바일 기기의 보안 수준을 확인한 것으로 말하면 안 된다.

## 공개 Client와 보호 Client를 나누고, Interceptor는 host·path를 본다

- Dio를 **공개용**(로그인·회원가입·중복 확인·유저별 평점 조회)과 **보호용**(내 정보, 평점 등록·수정·삭제)으로 나눴다. `AuthInterceptor`는 보호용에만 달려 있다.
- Interceptor 안에서도 **어디로 가는 요청인지** 다시 본다. 서버 주소(scheme·host·port)와 경로(`/members/me`, `/ratings`, `/ratings/…`)가 모두 맞을 때만 `Authorization: Bearer …`를 붙인다. 외부 이미지 URL이나 TMDB에는 절대 붙이지 않는다. 모든 요청에 붙이도록 바꾸면 테스트 4개가 실패한다(M3).
- 요청에 이미 들어 있던 `Authorization`은 먼저 지운다(이전 요청의 토큰이 재사용되지 않게).
- 토큰 저장소를 읽지 못하면 401처럼 보이지 않게 `unknown` 오류로 요청을 중단한다. 서버가 거절한 것과 기기 저장소 문제는 다른 일이다.
- TMDB 토큰과 MovieLog JWT는 서로 다른 Client에만 간다. 두 Client를 합치지 않는다.
- 개발 로그에는 `accessToken`·`password`·`authorization` 같은 키의 값을 가려서 남긴다. 처음 만든 로그 테스트는 JWT처럼 생긴 값만 써서, 키 이름 기반 가림이 아무 테스트에도 물려 있지 않았다(가림을 지워도 통과). 모양이 다른 값과 중첩 구조까지 쓰는 테스트를 더한 뒤에야 가림을 지우면 실패하게 됐다.

## `GoRouter`의 `redirect`와 `refreshListenable`

- 화면 이동은 ViewModel이 하지 않는다. 로그인·로그아웃·만료가 모두 **상태(`AuthStatus`)만** 바꾸고, `authRedirect(status, location)` 한 함수가 "이 상태에서 이 위치면 어디로 보낼지"를 정한다.
  - `initializing`·`retryRequired` → 시작 화면, `signedOut`·`authenticating` → 공개 화면(로그인·회원가입)만, `signedIn` → 시작·공개 화면이면 홈.
  - 이 표를 `auth_redirect_test`에서 상태×위치 조합으로 전부 확인했다.
- `redirect`는 사용자가 이동할 때만 실행된다. 그래서 상태가 바뀌면 다시 실행하도록 `refreshListenable`을 연결한다. 없으면 만료돼도 화면이 그대로다.
- **`refreshListenable`에 ViewModel 전체를 넘기면 안 된다.** `AuthViewModel`은 내 정보·안내 문구가 바뀔 때도 `notifyListeners`를 부른다. 그때마다 Router가 현재 주소를 다시 해석하면, 방금 `pop`한 화면이 되살아난다(프로필 저장에 성공했는데 수정 화면이 안 닫힘). 테스트 중에 실제로 만난 문제라서 "상태가 바뀔 때만" 알리는 `statusListenable`(`ValueNotifier`)을 따로 만들어 연결했다. 원인을 go_router 내부 코드까지 추적하지는 않았고, 수정 전후 테스트로 확인했다.
- GoRouter는 `build()`가 아니라 `State.initState`에서 **한 번만** 만든다. `build()`에서 만들면 화면이 다시 그려질 때마다 새 Router가 생겨 위치가 초기화된다.

## `sessionVersion` — 지난 세션의 늦은 응답이 새 세션을 지우지 못하게

로그인·복원·세션 정리가 시작될 때마다 `sessionVersion`이 올라간다. 비동기 작업은 시작할 때의 값을 기억했다가, 끝났을 때 지금 값과 같을 때만 결과를 반영한다.

- 이전 계정의 요청에서 **늦게 도착한 401**이 방금 로그인한 새 계정을 로그아웃시키지 않는다(검사를 지우면 테스트 4개·2개가 실패한다, M7·M13).
- 로그인 요청 중에 로그아웃을 눌렀다면, 뒤늦게 온 로그인 성공 응답은 토큰을 저장하지 않는다.
- 같은 세션에서 여러 요청이 동시에 401을 받아도 첫 번째가 버전을 올리므로 세션 정리와 안내는 한 번만 실행된다.
- 만료 안내 Snackbar는 `sessionExpired` 플래그로 한 번만 띄운다(`consumeSessionExpired`로 끈다). 직접 로그아웃이나 로그인 실패에서는 켜지 않는다.

## 서버 계약이 못 주는 것은 만들어 내지 않는다

- 이번 서버에는 **토큰으로 "내 평점 목록"을 가져오는 GET**이 없고, 로그인·내 정보 응답에는 `memberId`도 없다. 6주차의 공개 조회(`GET /members/{id}/ratings`)로 우회하거나 JWT의 claim을 추측하지 않았다.
- 그래서 "내가 등록한 평점"은 **이번 로그인에서 등록한 것만** 보여 준다(`SessionRatings`). 화면에 그 사실을 상시 표시했고, 앱을 다시 켜면 비어 있다. 이것은 프론트 버그가 아니라 서버 계약의 한계이며, 완료된 기능처럼 포장하지 않는다.
- 로그아웃은 기기의 토큰과 메모리만 지운다. 서버에 로그아웃 API가 없어서 서버 쪽에서 토큰이 즉시 폐기됐다고 말할 수 없다.

## 참고

- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) · [Dio Interceptors](https://pub.dev/packages/dio#interceptors) · [go_router: redirection](https://pub.dev/documentation/go_router/latest/topics/Redirection-topic.html) · [shared_preferences](https://pub.dev/packages/shared_preferences)
