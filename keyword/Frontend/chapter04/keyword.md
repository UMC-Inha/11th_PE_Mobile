# 4주차 프론트엔드 핵심 개념

## 동기·비동기, Future, async/await

동기는 앞 작업의 결과를 받은 후 다음 코드를 실행한다. 비동기 함수는 완료 전에도 Future를 반환해 화면 그리기와 입력 처리를 계속할 수 있게 한다. `Future<T>`는 나중에 T 값 또는 오류로 한 번 완료되는 결과이며, 여러 값을 전달하는 Stream과 다르다.

`async`는 함수에서 비동기 작업을 사용하게 하고 `await`는 현재 함수의 다음 줄을 결과가 나올 때까지 미룬다. 앱 전체를 멈추거나 작업을 별도 스레드로 옮긴다는 뜻은 아니다. `fetchMovies()`만 호출하면 Future를 받지만 `await fetchMovies()`는 완료된 목록을 받는다. 비동기 함수를 기다릴 수 있도록 반환 타입을 `Future<void>` 또는 `Future<T>`로 명시한다. [Dart 비동기 문서](https://dart.dev/language/async)

```dart
Future<String> title() async {
  await Future<void>.delayed(const Duration(seconds: 1));
  return '별빛 아래 우리';
}
// await 없이: 시작 → 요청 → 다음 줄 → 완료
// await 사용: 시작 → 요청 → 완료 → 다음 줄
```

## try-catch-finally

`try`에서 기다린 작업의 오류를 `catch`로 처리한다. `on`으로 예외 종류를 제한하고 `rethrow`로 원래 스택을 유지해 상위 UI에 전달한다. `finally`는 성공·실패에 관계없이 실행된다. Future를 await하지 않으면 그 Future의 나중 오류가 현재 try-catch를 벗어날 수 있다. 구현의 `_fetch`는 `MovieLoadException`을 디버그 로그에 기록하고 다시 전달하며, 화면에는 안내와 재시도만 보여 준다. [Dart Futures](https://dart.dev/libraries/async/async-await)

## FutureBuilder와 AsyncSnapshot

FutureBuilder는 전달받은 Future의 상태로 Widget을 만들며 직접 요청을 반복하는 도구가 아니다. `AsyncSnapshot`에는 `connectionState`, `data`, `hasData`, `error`, `hasError`, `stackTrace`가 있다. `done`은 성공을 보장하지 않으므로 waiting → error → 데이터의 빈 목록 → 성공 순서로 검사한다. 빈 배열은 오류가 아닌 정상 완료다. [FutureBuilder API](https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html)

| ConnectionState | 의미 | 화면 |
| --- | --- | --- |
| none | Future와 연결 전 | 초기 상태 |
| waiting | 완료 대기 | Skeleton Loading |
| active | 주로 Stream의 진행 중 값 | 이번 Future에서는 사용하지 않음 |
| done | 값 또는 오류로 완료 | Success / Empty / Error |

Future는 `initState`에서 한 번 만들고 필드로 보관한다. build는 필터·부모·크기 변경 때도 실행되므로 그 안에서 요청을 만들면 불필요한 재요청과 Loading 반복이 생긴다. 재시도·새로고침에서는 새로운 Future를 필드에 할당하고 setState로 FutureBuilder에 전달한다.

## mounted와 비동기 초기화

await 뒤에는 화면이 이미 제거됐을 수 있다. State의 setState나 context 사용 직전에 `mounted`를 확인하고, 전달된 BuildContext에는 `context.mounted`를 확인한다. 한 번 제거된 context는 다시 유효해지지 않는다. 이번 구현은 목록과 설정 읽기를 `Future.wait`로 동시에 시작하며, 초기 결과 반영 전에 mounted를 확인한다. 서로 의존하는 작업은 순차 await해야 한다. [mounted API](https://api.flutter.dev/flutter/widgets/State/mounted.html), [Future API](https://api.dart.dev/dart-async/Future-class.html)

## SharedPreferencesAsync와 보안 저장소

SharedPreferences는 int, double, bool, String, List<String> 같은 작은 설정에 적합하다. 새 구현은 캐시 대신 비동기 플랫폼 읽기를 제공하는 SharedPreferencesAsync를 사용한다. 장르와 정렬만 저장하며 영화 객체·JWT·비밀번호를 넣지 않는다. 쓰기 완료를 기다리더라도 중요한 데이터의 디스크 영속성을 보장하는 DB는 아니다. [패키지 공식 문서](https://pub.dev/packages/shared_preferences)

민감한 토큰에는 플랫폼 보안 저장소를 사용하는 flutter_secure_storage가 필요하다. iOS Keychain 값은 앱 재설치 후 남을 수 있다. 재설치 시 로그아웃하는 정책이라면 앱 시작 시 SharedPreferences의 `installation_initialized`가 없을 때 이전 secure storage를 정리하고 Flag를 설정한 다음 로그인 상태를 읽는다. 이 정책은 모든 앱의 필수 규칙이 아니며 이번 미션에는 토큰 기능 자체가 없다. [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)

## 심화 적용

RefreshIndicator의 onRefresh는 완료를 기다릴 Future를 반환한다. 짧은/빈 목록에도 AlwaysScrollableScrollPhysics를 사용한다. `Future.timeout`은 정해진 시간 뒤 다른 Future를 오류로 완료시키며 원래 작업을 자동 취소하지 않는다. Skeleton은 기존 카드의 배치에 맞춘다. 장르·정렬 변경은 받은 목록만 다시 필터링하며 네트워크 작업을 추가하지 않는다.
