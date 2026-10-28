# 5주차 프론트엔드 핵심 개념

## MVVM: View · ViewModel · Model

MVVM은 데이터(Model), 화면(View), 화면의 상태와 로직(ViewModel)을 나누는 구조다.

- **View**: Widget을 그린다. 상태를 읽어 보여주고 사용자 입력을 ViewModel 메서드 호출로 넘긴다. API를 부르거나 JSON을 해석하지 않는다.
- **ViewModel**: 화면마다 하나. Loading/Success/Empty/Error와 그 화면에 필요한 데이터만 들고, 입력에 따라 Service를 불러 상태를 바꾼 뒤 `notifyListeners()`.
- **Model**: 값만 담는 데이터 구조(`TmdbMovieDto` 등). 어디서 왔는지, 어떻게 그려지는지 모른다.

MovieLog에서는 `MovieHomeViewModel`(인기 5개), `MovieListViewModel`(30개·장르), `MovieDetailViewModel`, `MyRatingsViewModel`, `SignUpViewModel`이 각 화면을 맡는다.

## UI Layer와 Data Layer를 나누는 이유

UI Layer(View·ViewModel)는 Data Layer(Client·Service·DTO)가 돌려주는 타입만 안다. 그래서 같은 요청을 여러 화면이 재사용하고, 응답 형식이 바뀌어도 DTO·Service만 고치면 된다. 테스트에서는 Service 자리에 가짜를 끼워 Token 없이도 30개 수집·장르 재요청·재시도를 검증할 수 있었다(테스트 48개). Widget 안에서 Dio를 직접 부르면 build 때마다 요청이 섞이고 이런 교체가 불가능하다.

## Service는 stateless

`TmdbMovieService`는 요청을 보내고 JSON을 DTO로 바꿀 뿐 결과를 저장하지 않는다. 호출할 때마다 새 응답을 돌려주므로 여러 ViewModel이 인스턴스 하나를 안전하게 공유한다. "앞 5개", "최대 30개", "선택한 장르"는 화면마다 다른 정책이라 ViewModel에 둔다.

## .env와 .gitignore, 그리고 한계

`flutter_dotenv`로 `TMDB_ACCESS_TOKEN`을 `.env`에서 읽고, `.env`는 `.gitignore`에 넣어 커밋되지 않게 했다. `.env.example`에는 키 이름만 둔다. `dotenv.load()`는 `runApp()` 전에 `await`해야 빈 값을 읽지 않는다.

다만 `.env`는 Flutter asset이라 빌드 결과물에 그대로 들어간다(이번 Web 빌드의 `build/web/assets/.env`로 확인). Git 유출은 막지만 배포 앱에서의 비밀은 지켜주지 못하므로, 실제 서비스에서는 백엔드 Proxy가 Token을 들고 대신 호출해야 한다.

## Dio Client와 Interceptor

TMDB(Bearer Token)와 자체 API(이후 JWT)는 인증 방식이 달라 Client를 둘로 나눴다. Interceptor를 Client에 한 번 등록하면 그 Client를 거치는 모든 요청·응답·오류가 같은 형식으로 기록된다. 민감한 `Authorization`은 `Bearer ***`로 가리고, `kDebugMode`일 때만 등록해 release에서는 로그가 남지 않게 했다. Interceptor는 기록만 하고 화면 표시는 하지 않는다. [Dio](https://pub.dev/packages/dio)

## DTO와 페이지 응답

JSON은 `poster_path`(snake_case), Dart는 `posterPath`(lowerCamelCase)라 key를 하나씩 연결한다. `vote_average`가 `8`처럼 정수로 와도 `num`으로 받아 `toDouble()`, 비거나 null인 값은 기본값으로 바꾼다. Popular·Discover는 `results`와 `page`·`total_pages`를 함께 주므로 `TmdbMoviePageDto`로 묶어야 다음 페이지 여부를 판단할 수 있다. `total_results`는 전체 탐색 개수일 뿐 전부 받는다는 뜻이 아니다.

## 최대 30개 만들기

한 페이지 개수(20)를 코드에 박지 않고 "30개가 되거나 더 이상 페이지가 없을 때까지" page를 늘린다. TMDB `id`를 Map key로 써서 페이지 사이 중복을 하나로 줄인다. 30개보다 적으면 있는 만큼만 보여주고 오류로 보지 않는다. 실제로는 page 1·2 두 번에 30개가 찼다.

## with_genres 재요청과 늦게 온 응답

장르를 바꾸면 받은 30개를 로컬로 거르지 않고 Discover에 `with_genres`를 붙여 page 1부터 다시 부른다. 여러 장르는 `|`(OR)로 잇는다: `28|12` = 액션 또는 모험. 빠르게 장르를 바꾸면 이전 요청의 응답이 늦게 와 최신 화면을 덮을 수 있어, 요청마다 번호(`_requestVersion`)를 올리고 응답이 왔을 때 번호가 다르면 버린다. dispose 뒤에도 같은 검사로 `notifyListeners`를 막는다.

## Provider: MultiProvider · ChangeNotifierProvider · read / watch / Consumer

- `MultiProvider`: 여러 Route가 같이 쓰는 객체(Service)를 `MaterialApp.router` 바깥 최상단에 등록한다. GoRouter는 Route마다 Widget Tree를 새로 만들기 때문에 특정 화면 아래에 두면 다른 Route에서 찾지 못한다.
- `ChangeNotifierProvider`: Route 안에서 ViewModel을 만들고(`..loadPopular()`로 첫 요청 한 번) 화면이 사라질 때 dispose한다.
- `context.watch`: `build()` 안에서 구독, 그 Widget의 build 전체가 다시 실행된다(상세 화면).
- `Consumer`: builder 범위만 다시 그린다(목록 화면 body, 필터 버튼만 따로).
- `context.read`: 버튼 탭처럼 한 번 호출할 때. build 안에서 구독용으로 쓰지 않는다.

[Provider](https://pub.dev/packages/provider), [ChangeNotifier](https://api.flutter.dev/flutter/foundation/ChangeNotifier-class.html)

## 포스터 이미지

`poster_path`는 `/abc.jpg` 같은 경로만 오므로 `https://image.tmdb.org/t/p/{size}{path}`로 조합한다. null이면 placeholder, 로드 실패는 `errorBuilder`, 받는 중은 `frameBuilder`(첫 프레임 전) 회색 자리로 처리한다. `loadingBuilder`는 첫 응답 조각 전에는 progress가 null이라 빈 칸이 되는 것을 이번에 확인했다. [TMDB Image Basics](https://developer.themoviedb.org/docs/image-basics)
