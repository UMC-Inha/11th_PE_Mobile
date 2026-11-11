# 6주차 프론트엔드 핵심 개념

## v5 API는 왜 공통 Wrapper가 없을까

6주차 프론트가 쓰는 조회 API(닉네임·이메일 중복 확인, 유저별 평점 조회)는 결과값을 감싸지 않고 그대로 돌려준다.

```json
{ "available": true }
[ { "ratingId": 12, "movieId": 550, "score": 5, "comment": "최고의 영화!", ... } ]
{ "message": "존재하지 않는 유저입니다.", "error": "Not Found", "statusCode": 404 }
```

성공은 값 그대로, 실패는 프레임워크 기본 오류 형식(`message`·`error`·`statusCode`)이다. 그래서 응답 body를 곧바로 `CheckResult.fromJson`·`RatingDto.fromJson`에 넘긴다. 이후 주차에 `isSuccess / code / message / result` 형태의 Wrapper가 도입되면 파싱 지점이 `result` 한 겹 안쪽으로 바뀌므로, 지금 방식과 섞어 기억하지 않도록 DTO 파싱을 Service 한 곳에 모아 둔다.

## 공용 Widget은 MVVM의 어디에 두나

화면 하나에만 쓰는 Widget은 그 화면의 폴더에, 여러 화면이 그대로 재사용하는 Widget은 `widgets/`에 둔다(`widgets/movielog_button.dart`, 이미 있던 `tmdb_poster_image.dart`와 같은 자리). 공용 Widget은 **표시만** 한다. 지금 통신 중인지, 눌러도 되는지, 너비를 얼마나 쓸지는 View가 ViewModel에서 읽어 값으로 넘기고, 실제 요청과 상태 전환은 ViewModel이 결정한다. 공용 Widget이 스스로 상태를 바꾸면 같은 버튼이 화면마다 다르게 동작한다.

## 버튼의 세 상태: 기본 · 통신 중 · 비활성

| 상태 | 입력 | 모양 |
| --- | --- | --- |
| 기본 | `onPressed != null`, `isLoading == false` | label, 눌린다 |
| 통신 중 | `isLoading == true` (`onPressed`와 무관) | 가운데 인디케이터만, 눌리지 않는다 |
| 비활성 | `onPressed == null` | label, 비활성 배경색, 눌리지 않는다 |

`_disabled = isLoading || onPressed == null` 한 줄로 두 비활성을 묶으면 "통신 중에 다시 눌러 요청이 중복되는" 실수가 구조적으로 사라진다. 통신 중에는 label과 인디케이터를 함께 그리지 않고 하나만 고른다(함께 그리면 버튼 폭이 흔들린다).

## width: null · double.infinity · 고정 값

`SizedBox(width: …)`에 넘기는 값이 가로 공간을 정하는 방식을 바꾼다.

| 값 | 의미 | 쓰는 곳 |
| --- | --- | --- |
| `null` | 부모가 허용하는 범위 안에서 내용(label 길이)만큼 — Intrinsic 크기 | 입력창 옆 `중복 확인` |
| `double.infinity` | 부모가 허용하는 최대 너비 | Form 아래 `가입하기` |
| 고정 값(예: 96) | 주변과 상관없이 그 크기 | 크기가 정해진 버튼 |

`double.infinity`는 "부모가 정해 준 최대치까지"라는 뜻이라 부모가 너비를 정해 주지 않는 곳에서는 기준이 없다. 제약 없는 `Row` 안에 그대로 넣으면 실제로 `BoxConstraints forces an infinite width` 예외가 난다(테스트로 재현했다). 이때는 `Expanded`나 고정폭 `SizedBox`로 감싸 먼저 너비를 정해 준다. `Column(crossAxisAlignment: stretch)`나 폭이 정해진 Form 안에서는 문제가 없다.

## 서버 오류를 Form의 errorText에 연결하기

`validator`는 "형식"만 안다(비어 있나, 2~12자인가). "이미 쓰는 닉네임인가"는 서버만 안다. 그래서 ViewModel이 `nicknameErrorText`를 들고, `TextFormField`의 `decoration.errorText`에 그대로 연결한다. ViewModel이 상태를 바꿀 때마다 입력창 테두리와 아래 문구가 함께 붉은 에러 상태로 바뀐다.

두 오류가 같은 자리에 겹쳐도 충돌하지 않는다. 이 프로젝트의 Flutter 3.47.5 SDK 소스(`text_form_field.dart`)를 확인하면, validator가 오류를 낼 때만 `errorText`를 그 문구로 덮고, 통과하면 `decoration.errorText`를 그대로 둔다. 즉 로컬 형식 검사를 통과한 뒤에도 서버의 중복 오류는 계속 보인다.

체크 표시(`Icons.check_circle`)는 입력창 안쪽 `suffixIcon`에만 두고, `중복 확인` 버튼은 `Row`의 별도 형제로 8px 띄워 둔다. 둘이 겹쳐 그려지지 않는다.

## 중복 확인 상태를 하나의 값에서 파생하기

`enum CheckStatus { idle, checking, available, duplicated, error }` 하나에서 버튼 활성 여부와 Form 에러가 함께 나온다.

- `idle`: 아직 확인 전이거나, 입력이 바뀌어 이전 결과가 무효화된 상태
- `checking`: 요청 중 (버튼은 인디케이터, 비활성)
- `available`: 서버가 `available: true`
- `duplicated`: 서버가 **정상 응답으로** `available: false` — 서버가 알려 준 사실
- `error`: 통신 자체가 실패(`DioException`, 타임아웃) — 중복인지 아닌지 **모르는** 상태

`duplicated`와 `error`는 문구도 다르고 다음 행동도 다르다. 중복이면 값을 바꿔야 하고(버튼 비활성), 통신 실패면 같은 값으로 다시 눌러 볼 수 있다(버튼 활성). 둘을 같은 "실패"로 뭉치면 서버가 꺼졌을 뿐인데 "이미 사용 중"이라고 말하게 된다.

닉네임과 이메일은 같은 화면에 있어도 상태·요청 번호·"마지막 중복 값"을 **따로** 가진다. 하나의 상태값으로 합치면 이메일 결과가 닉네임 입력칸의 에러를 지우는 일이 생긴다. 구현은 입력칸 하나의 규칙을 `_FieldCheck`에 모으고 닉네임·이메일이 각각 하나씩 가진다.

## 입력 무효화와 늦게 온 응답 버리기

입력값이 바뀌면 이전 확인 결과는 더 이상 이 입력에 대한 답이 아니다.

```
입력값 변경
 ├─ 새 입력값 == 마지막으로 "중복"이 확인된 값 → duplicated와 에러 문구를 즉시 복원 (API 재호출 없음)
 └─ 아니면 → idle로 되돌리고 에러 문구 제거
```

확인을 누른 뒤 응답이 오기 전에 입력을 바꾸면, 늦게 온 이전 응답이 새 입력에 대한 결과처럼 보이는 문제가 생긴다. 요청마다 `_requestVersion`을 올리고 입력이 바뀔 때도 올려서, 응답이 왔을 때 번호나 현재 입력값이 다르면 버린다. `dispose`에서도 번호를 올려 화면이 사라진 뒤 도착한 응답이 `notifyListeners`를 부르지 못하게 한다. 앞뒤 공백만 바뀐 입력은 `trim` 결과가 같으므로 이전 결과를 지우지 않는다.

## Challenge: "마지막으로 확인한 값"과 "마지막으로 중복이었던 값"은 다르다

`수현`(중복) → `케빈`(사용 가능) → 다시 `수현` 순으로 입력하면, 마지막으로 확인한 값은 `케빈`이다. 그런데 사용자가 방금 지운 `수현`은 서버가 이미 중복이라고 답한 값이다. 그래서 "마지막으로 중복이었던 값"(`_duplicated`)을 별도로 기억해야 같은 값이 돌아왔을 때 서버에 다시 묻지 않고 곧바로 에러 상태로 복원할 수 있다.

다만 이 기억은 학습용 최적화다. 그 사이 서버 상태가 바뀌어 `수현`이 비었을 수 있으므로 실제 가입 요청(POST)의 409가 최종 기준이다.

## 목록 조회 API: Loading · Empty · Error · Success

평점 목록은 네 상태를 구분해 그린다.

| 상태 | 원인 | 화면 |
| --- | --- | --- |
| Loading | 요청 중 | 인디케이터 |
| Empty | 200 `[]` — 평점이 아직 없는 회원 | "아직 남긴 평점이 없어요." |
| Error | 400 형식 오류 · 404 없는 회원 · 통신 실패 | 원인별 문구와 `다시 시도` |
| Success | 1개 이상 | 목록 |

빈 배열은 **정상 응답**이다. `isEmpty`를 오류로 취급하면 평점이 없는 회원이 "불러오지 못했어요"를 보게 된다. 오류도 하나로 뭉치지 않는다: 400은 `memberId 형식`, 404는 `존재하지 않는 회원`, 그 밖에는 통신 안내.

## 평점과 영화 정보 묶기 — 주인이 다른 두 데이터

평점(점수·후기·등록일)의 주인은 자체 백엔드이고, 제목·포스터는 TMDB에서 `movieId`로 빌려 온다. 그래서 `RatingWithMovie(rating, movie?)`로 한 쌍을 만들고, TMDB에서 못 찾으면 `movie == null`로 둔다.

- TMDB 영화 상세 조회가 **404**면 `findMovieById`가 null을 돌려준다. 그 영화만 제목·포스터를 placeholder로 그리고 평점·`movieId`는 그대로 보인다.
- 404가 아닌 오류(네트워크·401)는 던져서, ViewModel이 그 영화만 "일시적 실패"로 다룬다.
- 같은 `movieId`는 한 번만 조회한다(`Future.wait` 전에 `toSet()`). 404는 null로 **캐시**해 다시 묻지 않고, 일시적 실패는 **캐시하지 않아** 다음 로딩에서 다시 시도한다.
- 후기가 없으면(`comment == null`) 후기 줄을 그리지 않는다. nullable 필드를 타입에 그대로 반영(`String?`)한다.

## GoRouter: 자식 화면이 하단 NavigationBar를 가리게 하기

`StatefulShellRoute` 안의 `GoRoute`는 `parentNavigatorKey`를 주지 않으면 자기가 속한 shell의 Navigator에 쌓인다. 그러면 `/my/ratings`를 열어도 하단 NavigationBar가 그대로 남는다. `GoRouter(navigatorKey: rootNavigatorKey)`로 root Navigator의 키를 등록하고 `/my/ratings` 라우트에 같은 키를 `parentNavigatorKey`로 주면 앱 전체 Navigator 위에 열려 NavigationBar가 가려진다. 마이페이지에서는 `context.push`로 열어야 마이페이지가 스택에 남아 BackButton으로 되돌아온다(`go`는 스택을 교체한다).

이 프로젝트는 라우터를 `createAppRouter()` 함수로 만들기 때문에 root 키도 함수 안에서 `GlobalKey<NavigatorState>`로 만들어 라우터마다 하나씩 가진다.

## 조회 대상 memberId 1은 "내 계정"이 아니다

화면 이름은 "내가 등록한 평점"이지만 6주차 API에는 로그인이 없다. 조회 대상은 학습용 상수 `sampleMemberId = 1`(시드의 1번 회원)의 **공개 조회**다. 화면에는 이 사실을 안내 문구로 밝히고, "현재 로그인한 사용자의 평점"이라고 말하거나 다른 사람의 데이터를 바꾸는 버튼은 두지 않는다. 실제 회원 식별은 JWT를 도입하는 주차에 토큰에서 꺼내는 방식으로 바뀐다.

## 참고

[TextFormField API](https://api.flutter.dev/flutter/material/TextFormField-class.html), [SizedBox API](https://api.flutter.dev/flutter/widgets/SizedBox-class.html), [Build a form with validation](https://docs.flutter.dev/cookbook/forms/validation), [Dio](https://pub.dev/packages/dio), [Provider](https://pub.dev/packages/provider), [go_router](https://pub.dev/packages/go_router)
