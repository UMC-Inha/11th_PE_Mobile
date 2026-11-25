# 9주차 프론트엔드 핵심 개념

> "테스트로 확인"은 가짜 서버(Fake)를 쓴 위젯·ViewModel 테스트에서 본 것이다. 실제 서버(NestJS+MySQL)와 실제 화면(Flutter Web)에서 본 것은 [미션 문서](../../../mission/Frontend/chapter09/mission.md)에 따로 적었다. TMDB는 이 환경에서 가짜 TMDB 서버(`/discover/movie`·`/search/movie`·`/movie/{id}`를 흉내 내는 로컬 서버)로 대신했다. 기기의 보안 저장소(Keychain·Keystore)와 iOS·Android 실기기는 확인하지 못했다(Xcode·Android SDK 없음, 웹만 확인).

## 서버가 준 목록을 "화면에 쓸 목록"으로 바꾸는 일

즐겨찾기 응답(`GET /favorites`)에는 `movieId`와 등록 시각만 있고 제목·포스터가 없다. 제목과 포스터는 TMDB에 있다. 그래서 "내 즐겨찾기" 화면은 요청 두 종류를 순서대로 이어서 쓴다.

1. MovieLog 서버에서 내 즐겨찾기 목록(`movieId` 목록)을 받는다.
2. 각 `movieId`로 TMDB `GET /movie/{id}`를 불러 제목·포스터·평점을 채운다.

- 두 서버의 데이터를 **한 카드 안에서만** 합친다(`FavoriteListItem(favorite, movie)`). 사용자별 데이터(내 즐겨찾기)와 누구에게나 같은 공개 데이터(영화 정보)를 하나의 `Map`에 섞어 캐시하면, 로그아웃 뒤에도 이전 사용자의 정보가 남을 수 있다.
- 영화 정보 한 건이 실패했다고 목록 전체를 실패로 만들지 않는다. 그 카드만 "영화 정보를 불러오지 못했어요 + 다시 조회"가 되고, 다시 조회는 **그 영화 한 건만** 요청한다. 실서버로 한 장만 실패시켜 확인했다(재시도 때 `GET /movie/1003` 한 번만 나갔다).
- 즐겨찾기 경로의 id는 `favoriteId`가 아니라 TMDB의 `movieId`다(`GET·DELETE /favorites/{movieId}`). 서버 문서가 그렇게 정한다.

## `Future.wait`와 "동시에 몇 개까지" — `mapBounded`

`Future.wait(items.map(요청))`은 요청을 **한꺼번에 전부** 보낸다. 즐겨찾기가 100개면 TMDB 요청 100개가 동시에 나간다. 그래서 작업자(worker) 5개가 하나씩 꺼내 처리하는 `mapBounded(values, 5, convert)`를 만들었다.

- 결과는 **입력과 같은 순서**로 돌려준다(먼저 끝난 순서가 아니다). 즐겨찾기 순서(최신 등록 순)를 지켜야 해서다.
- 항목 하나의 실패는 `convert` 안에서 `try/catch`로 "실패한 카드"라는 **값**으로 바꾼다. 예외가 그대로 나가면 `Future.wait`가 전체를 실패시킨다.
- 단위 테스트(`session_and_utils_test`)에서 12개를 넣고 작업을 일부러 끝내지 않은 채 두면 정확히 5개만 시작되고, 하나가 끝날 때마다 하나씩 시작되며 동시 실행이 5를 넘지 않는 것을 확인했다.

## record와 interface, mixin

- **record**: `({List<int>? genreIds, String query})`처럼 이름 있는 값 묶음을 클래스 없이 쓴다. "영화 목록의 현재 조건"(장르+검색어)을 한 값으로 들고 다니다가, 응답이 돌아왔을 때 요청 당시의 조건과 비교하는 데 쓴다.
- **interface**: Dart에서는 모든 클래스가 암묵적인 interface다. `FavoriteApiService`는 따로 `abstract interface`를 만들지 않은 보통 클래스이고, 테스트는 `class FakeFavoriteApiService implements FavoriteApiService`로 같은 모양의 가짜를 만들어 바꿔 끼운다. 서버 없이도 "409가 오면 GET으로 다시 맞춘다" 같은 경로를 확인할 수 있다.
- **mixin**: `SafeNotify`(`ChangeNotifier`에 `with SafeNotify`). 화면이 사라진(dispose) 뒤 늦게 온 응답이 `notifyListeners()`를 부르면 오류가 난다. 이 mixin이 `isDisposed`와 `notifyIfAlive()`를 한곳에 두어 모든 ViewModel이 같은 방식으로 막는다.

## 늦게 도착한 응답이 새 상태를 덮어쓰지 못하게 — "요청 세대(generation)"

네트워크 응답은 보낸 순서대로 오지 않는다. 장르를 "액션"→"모험"으로 빠르게 바꿨는데 "액션" 응답이 더 늦게 오면, 화면이 "모험" 선택인데 목록은 "액션"이 되는 버그가 생긴다.

- `PagedMoviesViewModel`은 새 조건(장르·검색어·새로고침)으로 첫 page를 요청할 때마다 `_requestGeneration`을 올린다. 요청은 보낼 때의 번호를 기억했다가, 응답·오류·`finally`에서 **지금 번호와 같을 때만** 반영한다. 다르면 조용히 버린다.
- HTTP 요청 자체는 취소되지 않을 수 있다. 응답은 오지만 **반영하지 않는** 방식이다.
- 실서버에서 확인: 가짜 TMDB가 "액션" 응답만 4초 늦게 주도록 하고 "액션"→"모험"을 연달아 눌렀다. 서버 기록에서 "모험"(0ms)이 먼저, "액션"(4002ms)이 나중에 끝났지만 화면은 계속 "모험"이었다.
- 로그인 세션에도 같은 문제가 있다. `SessionGuard`가 로그인(검증)할 때마다 번호를 올리고 계정(이메일)을 기억한다. 요청을 보낼 때의 번호·계정과 응답이 왔을 때의 값이 다르면 그 응답은 **이전 세션의 것**이라 버린다. 이전 계정의 늦은 401이 새 계정을 로그아웃시키지 못한다.

## `ValueKey`로 "이 화면은 이 계정의 것"을 강제한다

사용자별 ViewModel(내 즐겨찾기)을 위젯 트리에서 `ValueKey('${member.email}:${guard.generation}')`로 만든다. 계정이나 세션이 바뀌면 key가 달라져 Flutter가 이전 State·ViewModel을 버리고 새로 만든다. 계정 B로 로그인했을 때 A의 목록이 한 프레임이라도 남지 않는다. 실서버에서 A(4건)로 보다가 로그아웃 → B 로그인 → 내 즐겨찾기를 열면 B의 1건만 나왔다.

- `MemberSessionGate`가 "내 정보가 준비됐고 세션과 일치하는가"를 먼저 확인한다. 주소로 바로 들어와도(마이페이지 탭을 거치지 않아도) 내 정보를 한 번 요청하고, 실패하면 로딩만 돌리지 않고 다시 시도 버튼을 보여 준다.

## 목록을 이어 붙이는 페이지네이션

TMDB `page`는 1부터 시작하고 `total_pages`가 마지막이다.

- 첫 page는 목록을 **교체**하고, 다음 page는 **append**한다.
- `nextPage`는 **응답을 반영한 뒤에만** 올린다. 요청을 보낼 때 올리면, 실패했을 때 다음 시도가 page를 건너뛴다. 실패하면 같은 page를 다시 요청한다(실서버에서 page 2를 503으로 한 번 실패시키고 재시도 → page 2가 이어 붙었다, "20편 → 40편").
- 같은 `movieId`는 건너뛴다(`_dedupe`). TMDB는 page가 바뀌는 사이 순위가 움직여 같은 영화를 다시 줄 수 있다.
- TMDB의 page 상한은 500이다. 서버가 `total_pages`를 500보다 크게 줘도 500으로 자른다(501은 요청하지 않는다).
- 요청한 page와 응답의 `page`가 다르면 이어 붙이지 않고 오류로 본다.
- 마지막 page에서는 "더 보기" 버튼 대신 "더 이상 불러올 영화가 없어요."를 보여 준다(실서버에서 `total_pages`를 3으로 줄여 확인했다, 60편).
- 다음 page 실패는 **기존 목록을 지우지 않고** 하단에 오류와 "다시 시도"만 보인다. 화면 전체를 오류 화면으로 바꾸면 이미 읽던 목록이 사라진다.

## 실패의 종류마다 하는 일이 다르다

| 상황 | 앱이 하는 일 |
| --- | --- |
| `AUTH401_2/3/4` (토큰 없음·무효·만료) | 현재 세션을 **한 번만** 정리하고 로그인 화면 + 안내. 같은 세션의 다른 요청이 줄줄이 401을 받아도 한 번이다 |
| 403, 5xx, 네트워크·timeout | 로그아웃하지 않는다. 안내와 다시 시도 |
| `FAVORITE409_1`(이미 등록) · `FAVORITE404_1`(이미 없음) | 같은 요청을 반복하지 않고 `GET /favorites/{movieId}`로 서버의 현재 값에 화면을 맞춘다 |
| 등록·해제 요청의 timeout | **같은 POST를 자동으로 다시 보내지 않는다.** 서버는 이미 처리했을 수 있다 |

- 즐겨찾기 버튼은 optimistic update(응답 전에 먼저 바꾸기)를 하지 않는다. 서버가 확인한 뒤에 북마크를 바꾼다.
- 실서버로 만든 "서버는 지웠는데 앱은 timeout을 본" 경우: 상세 화면의 북마크는 잠시 예전 값(등록됨)으로 남지만, 목록으로 돌아오면 `GET /favorites`를 다시 받아 서버의 값(해제됨)으로 맞춰졌다. **한 화면 안에서 즉시 맞춰지지는 않는다.**
- 서버가 만료 토큰에 주는 코드를 실제로 확인했다: 키를 바꿔 다시 띄우면 `AUTH401_3`, 토큰 유효시간 3초로 띄우고 4.5초 뒤에 요청하면 `AUTH401_4`(둘 다 401).

## Challenge A — 입력할 때마다 요청하지 않기: debounce와 `Timer`

검색창에 "인터스텔라"를 치면 글자마다 요청이 나가는 것은 낭비다. **마지막 입력 뒤 500ms가 지나야** 한 번만 요청한다.

- 입력 이벤트(`onChanged`)마다 이전 `Timer`를 `cancel()`하고 새 `Timer(500ms)`를 만든다. 타이머가 실제로 실행되는 시점에야 `search()`를 부른다.
- 타이머 콜백 안에서 `if (!mounted) return;`으로 화면이 사라졌는지 먼저 본다. `dispose()`에서도 `_debounce?.cancel()`을 부른다. 화면을 나간 뒤에 대기 중이던 검색이 실행되면 안 된다.
- 키보드의 검색 키(제출)는 기다리지 않고 바로 검색하고, 대기 중이던 타이머는 취소한다. 안 그러면 같은 검색어가 두 번 나간다.
- 빈 검색어(공백만)는 서버로 보내지 않는다.
- 이것은 요청 **횟수**를 줄이는 장치이고, 늦게 도착한 응답을 버리는 일은 별개다. 그래서 위 "요청 세대(generation)"도 그대로 필요하다.
- 실서버로 확인: 10글자를 이어서 입력하자 `/search/movie` 요청이 **1건**만 나갔다. 응답을 느리게 만든 검색어 뒤에 새 검색어를 입력하면 새 결과가 먼저 보이고, 늦은 응답이 나중에 도착해도 화면은 바뀌지 않았다.
- 테스트: 위젯 테스트에서 `tester.pump(Duration)`으로 시간을 흘려 확인했다. debounce를 0ms로 바꾸는 변이 검사에서는 12개 테스트가 실패했다.

## Challenge B — 무한 스크롤: `ScrollController`와 `extentAfter`

"더 보기" 버튼 대신 스크롤이 끝에 가까워지면 다음 page를 자동으로 요청한다.

- `ScrollController`에 `addListener(_onScroll)`을 달고, `position.extentAfter`(보이는 영역 아래에 남은 스크롤 길이)가 **300 이하**이면 다음 page를 요청한다. `dispose()`에서 `removeListener`와 `dispose()`를 부른다. 컨트롤러를 정리하지 않으면 사라진 화면의 리스너가 계속 불린다.
- 이미 요청 중이거나(`isLoadingMore`) 받을 page가 없으면(`!hasMore`) 아무것도 하지 않는다. 스크롤 이벤트는 초당 여러 번 와서 이 조건이 없으면 같은 page를 여러 번 요청한다. ViewModel도 같은 조건을 한 번 더 막는다.
- **실패 뒤에는 자동으로 반복하지 않는다.** 스크롤이 끝에 있는 채로 실패하면 곧바로 다시 요청이 나가고, 서버가 고장 난 동안 요청이 쉬지 않고 나가게 된다. 실패하면 footer에 오류와 "다시 시도"를 보이고, 사용자가 누를 때만 같은 page를 요청한다(자동 재요청을 하게 바꾸자 테스트 1개가 실패했다). 실서버에서 page 2를 503으로 실패시켰을 때 요청이 **한 번만** 나갔고, 다시 시도를 누르자 20편이 더 붙어 40편이 됐다.
- 한 page가 화면을 다 채우지 못하면 스크롤 자체가 안 생긴다. 그래서 그릴 때마다(`addPostFrameCallback`) 끝에 가까운지 다시 본다.
- 격자와 리스트를 바꾸는 프레임에는 같은 컨트롤러에 `position`이 둘 붙어 있을 수 있어서, `positions.length == 1`일 때만 읽는다.
- 마지막 page에서는 "더 이상 불러올 영화가 없어요."를 보여 주고 요청하지 않는다.

## Challenge C — 평점과 즐겨찾기를 한 번에: `POST /movie-records`

평점 Dialog의 "즐겨찾기에도 추가"를 체크하고 저장하면 평점과 즐겨찾기를 **서버가 한 번에** 처리한다. 두 요청을 앱이 차례로 보내면 하나만 성공하는 중간 상태가 생길 수 있다.

- 서버가 둘을 함께 처리하므로 즐겨찾기가 이미 있으면(`FAVORITE409_1`) **평점도 저장되지 않는다.** 그래서 이미 즐겨찾기한 영화의 평점 Dialog에는 체크박스를 보이지 않는다(보이게 바꾸는 변이 검사에서 테스트 3개가 실패했다).
- Dialog는 저장 로직을 `onSubmit` 콜백으로 받아 **Dialog 안에서** 실행한다. 저장 중 상태(로딩 버튼, 입력 잠금, 바깥 탭·뒤로가기 막기)와 실패했을 때의 입력 유지를 Dialog가 직접 관리하려는 것이다.
- 실패의 두 갈래: 다시 눌러 볼 만한 실패(5xx 등)는 Dialog를 **열어 둔 채** 문구를 보이고 별점·코멘트·체크 상태를 그대로 둔다. 다시 눌러도 소용없는 `FAVORITE409_1`·`RATING409_1` 같은 실패는 Dialog를 닫고 사유를 Snackbar로 알린다.
- 실서버로 확인: 체크하고 저장하면 `POST /movie-records` 한 번으로 평점과 즐겨찾기가 함께 생겼고 상세의 북마크가 채워졌다. 일부러 503으로 한 번 실패시키면(프록시가 만든 실패) Dialog가 열린 채 별점·체크가 남았고, 같은 Dialog에서 다시 저장하자 201이었으며 평점은 한 건만 생겼다.
- 확인하지 못한 것: 응답을 8초 늦추면 앱은 timeout 없이 8초 뒤 성공을 받았다. 웹에서 body가 있는 POST에는 Dio의 `receiveTimeout`이 동작하지 않은 것으로 보이지만 **원인은 확인하지 못했다.** 그래서 이 요청의 timeout 동작은 실서버로 확인했다고 말할 수 없다.

## 참고

- [Dart: Future.wait](https://api.dart.dev/stable/dart-async/Future/wait.html) · [Dart: Records](https://dart.dev/language/records) · [Dart: Mixins](https://dart.dev/language/mixins) · [Flutter: Keys](https://api.flutter.dev/flutter/foundation/Key-class.html) · [TMDB: Discover/Search](https://developer.themoviedb.org/reference/discover-movie)
