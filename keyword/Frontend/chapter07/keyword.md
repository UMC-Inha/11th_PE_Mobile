# 7주차 프론트엔드 핵심 개념

## CRUD와 HTTP Method: 요청마다 body와 성공 응답이 다르다

| 동작 | 요청 | 요청 body | 성공 | 응답 body | 화면에서 하는 일 |
| --- | --- | --- | --- | --- | --- |
| 회원가입 | `POST /members` | 이메일·비밀번호·닉네임 | 201 | 공통 응답 틀 + `result` 객체 | `memberId`를 세션에 보관 |
| 평점 조회 | `GET /members/{id}/ratings` | 없음 | 200 | **직접 배열** | Loading/Empty/Error/Success |
| 평점 등록 | `POST /members/{id}/ratings` | movieId·score·comment | 201 | 공통 응답 틀 | 성공 뒤 GET으로 확인 |
| 평점 수정 | `PATCH /members/{id}/ratings/{ratingId}` | score·comment | 200 | 공통 응답 틀(`result` 안 씀) | 성공 뒤 GET |
| 평점 삭제 | `DELETE /members/{id}/ratings/{ratingId}` | 없음 | **204** | **없음** | 성공 뒤 GET |

- GET·DELETE는 body를 쓰지 않는 것이 관례다. 그래서 "누가"를 body가 아니라 경로(이번 주) 또는 헤더(다음 주 토큰)에 둔다.
- 성공 본문의 모양이 API마다 다르다(직접 배열 / 공통 틀 / 본문 없음). 그래서 파싱을 한 곳에서 일괄로 하지 않고 **호출마다 그 계약에 맞춰** 한다. 등록은 `statusCode == 201`만 보고, 삭제는 `statusCode == 204`만 본다. 204에 `response.data as Map`을 하면 안 된다(본문이 없다). 테스트에서 본문 없는 204 응답을 만들어 오류 없이 끝나는 것을 확인했다.
- 등록 응답의 `result`가 숫자인지 `null`인지는 서버 문서에도 어긋나 있었다. 계약이 확정되지 않은 값을 `result!`로 강제하지 않고, 등록 뒤에는 GET으로 서버 상태를 다시 읽는다. `result`가 숫자·`null`·객체일 때 모두 성공으로 처리되는 것을 테스트로 확인했다.

## 요청 Model과 응답 Model은 변환 방향이 반대다

| | 방향 | 메서드 | 예 |
| --- | --- | --- | --- |
| 요청 Model | Dart 객체 → JSON Map | `toJson()` | `CreateMemberRequest`, `CreateRatingRequest`, `UpdateRatingRequest` |
| 응답 Model | JSON Map → Dart 객체 | `fromJson()` | `SignUpResult`, `MemberRatingDto`, `CommonResponse<T>` |

- `CommonResponse<T>`의 `result`는 API마다 담기는 값이 달라 제네릭 `T`로 둔다. `fromJson`이 `parseResult` 함수를 받아 호출하는 쪽이 `T`를 정한다. 값이 없거나 실패 응답이면 `result == null`이다.
- **trim은 값의 성격에 따라 다르다.** 이메일·닉네임은 앞뒤 공백이 입력 실수라 `toJson`에서 지운다. 비밀번호는 입력한 문자가 모두 의미 있어서 지우지 않는다(`' Pass 1234! '`가 그대로 나가는 것을 테스트로 고정했다).
- **비밀번호는 toString에서도 가린다.** 요청 객체가 로그나 오류 메시지에 섞여 찍혀도 비밀번호가 나가지 않게 `CreateMemberRequest.toString()`에서 뺐다. 로그 Interceptor가 요청 body를 기록하지 않는다는 것도 테스트(가입 요청이 409로 실패한 로그에 비밀번호 없음)로 확인했다.
- 등록에서 코멘트는 선택 항목이라 비어 있으면 키를 **생략**한다. 수정에서는 반대로 `comment`를 **항상 명시**하고 비어 있으면 `null`을 보낸다. PATCH에서 키를 생략하면 서버에 따라 "건드리지 않음"이 되기도, "후기가 지워짐"이 되기도 해서(워크북의 v6는 지워진다) 클라이언트가 의도를 말로 분명히 해야 한다.

## 서버 message는 보여주고, code·상태는 행동을 정한다

같은 404여도 평점 **등록**에서는 "존재하지 않는 유저"이고 **수정·삭제**에서는 "존재하지 않는 평점"이다. `code`만 보고 문구를 새로 만들면 이 차이를 놓친다. 그래서 문구는 서버가 내려 준 `message`를 그대로 쓰고, `code`나 HTTP 상태는 "그다음에 무엇을 할까"를 정하는 데만 쓴다.

| 상태 | 뜻 | 다시 조회? | 화면 |
| --- | --- | --- | --- |
| 400 | 값이 틀림 (별점 범위·형식) | 아니오 | 같은 Dialog에서 값을 고친다 |
| 403 | 내 평점이 아님 | **예** | 화면의 목록이 서버와 어긋났다 |
| 404 | 이미 없음 | **예** | 사라진 항목을 목록에서 치운다 |
| 409 | 이미 등록함 | 아니오 | 같은 화면에서 다시 시도하거나 취소 |

- 서버의 `code` 문자열은 주차마다 다듬어질 수 있다(`COMMON403` → `RATING403_1` 같은 식으로). 그래서 재조회 여부는 code 문자열이 아니라 **HTTP 상태(403·404)** 로 정한다. code가 바뀌어도 같은 동작인 것을 테스트로 고정했다.
- 서버가 공통 틀을 지키지 않는 응답(프록시의 HTML 오류 페이지, 프레임워크 기본 오류 JSON)을 줄 수도 있다. `fromJson`이 던지는 타입 오류가 화면까지 올라오지 않게 파싱 실패는 `null`로 처리하고 기본 문구를 쓴다.
- 응답 자체가 없는 실패(서버 꺼짐, 시간 초과)는 서버 message가 없다. 이때는 "네트워크 상태를 확인하고 다시 시도해 주세요." 같은 원인 문구를 쓴다.
- 회원가입의 400은 두 갈래다. 메시지에 `비밀번호`가 들어 있으면 비밀번호 입력칸의 `errorText`로, 그 밖의 400과 409는 입력칸에 붙일 곳이 없어 Snackbar로 보여준다. 로컬 validator를 통과한 값도 서버가 거부하면 입력칸에 계속 에러로 남는다(로컬 규칙에 없는 72자 상한을 예로 위젯 테스트에서 확인했고, 사용자가 비밀번호를 고치기 시작하면 사라진다).

## 저장 성공과 목록 재조회 실패는 다른 상태다

수정·삭제가 성공하면 서버 목록을 다시 읽어 화면을 맞춘다. 이 GET이 실패했을 때 "저장 실패"로 취급하면 안 된다. 서버에는 이미 저장됐는데 사용자가 같은 요청을 다시 보내면 중복·충돌이 난다.

```
쓰기 요청 ──실패──▶ RatingSaveException(서버 문구)  → Dialog가 문구를 보여주고 입력 유지
    │
   성공
    ▼
GET 재조회 ──실패──▶ refreshWarning                → Dialog는 "성공"으로 닫히고,
    │                 "저장은 완료됐지만 목록을…"      목록 영역에 "조회만 다시" 안내 + 재시도
   성공 → 목록 갱신
```

- 재시도 버튼은 GET만 다시 보낸다. 위젯 테스트에서 재시도 뒤에도 PATCH가 한 번뿐인 것을 확인했다. 실제 서버 앞에 실패 주입 프록시를 두고 같은 흐름의 요청 기록을 남긴 결과는 [미션 기록](../../../mission/Frontend/chapter07/mission.md)에 있다.
- 쓰기 직후의 재조회는 `load(silent: true)`로 목록을 로딩 표시로 바꾸지 않는다. 안 그러면 저장할 때마다 목록이 사라졌다 나타난다(테스트에서 로딩 상태를 거치지 않는 것을 확인).
- 워크북이 "등록 성공 뒤 409"를 자주 나는 오류로 드는 이유도 같다. GET이 실패했다고 POST를 다시 보내면 서버에는 이미 평점이 있어 409가 난다. 서버 오류가 아니라 저장 단계와 조회 단계를 화면 상태로 나누지 않아 생기는 현상이다.

## Dialog 안에서 API를 부를 때: 상태를 Dialog가 관리한다

저장 로직을 Dialog를 연 화면이 아니라 Dialog에 `onSubmit` 콜백으로 넘기고, 저장 중 상태(`_isSubmitting`)를 Dialog가 직접 가진다. 그래야 로딩 버튼·입력 잠금·이탈 방지·실패 시 입력 유지를 한곳에서 다룰 수 있다.

| 상황 | 처리 |
| --- | --- |
| 저장 중 확인 버튼 | `MovieLogButton(isLoading: _isSubmitting)` — 인디케이터만, 눌리지 않음 |
| 저장 중 입력 | 별점·코멘트·취소 버튼 비활성 |
| 저장 중 시스템 뒤로가기 | `PopScope(canPop: !_isSubmitting)` |
| 저장 중 바깥 탭 | `showDialog(barrierDismissible: false)` |
| 실패 | `_isSubmitting = false`로 되돌리고 서버 문구 표시, **입력은 그대로** |
| 취소 | `onSubmit`을 부르지 않고 `false` 반환 → 요청 없음 |

- `PopScope`만 걸면 바깥을 탭해서 닫히고, `barrierDismissible: false`만 걸면 시스템 뒤로가기로 닫힌다. **둘을 함께** 써야 저장 중 이탈이 완전히 막힌다(두 경우를 각각 테스트).
- Dialog의 반환값은 `true`(저장까지 끝남) / `false`(취소) / `null`(아무 일도 안 일어남)이다. 화면은 `saved == true`일 때만 성공 Snackbar를 띄운다. `await` 뒤에는 화면이 사라졌을 수 있으므로 `context.mounted`를 다시 확인한다.
- 이 앱은 `MaterialApp.router`라서 시스템 뒤로가기를 `WidgetsApp.didPopRoute`가 아니라 **Router의 `backButtonDispatcher`** 가 받는다. 처음에는 `didPopRoute`로 확인하려다 항상 `false`가 나왔고, `Router.of(context).backButtonDispatcher.invokeCallback(...)`으로 바꿔서 "막으면 true, 나갈 수 있으면 false"를 확인했다.
- 로딩 인디케이터는 계속 돌기 때문에 저장 중 구간의 위젯 테스트는 `pumpAndSettle`이 끝나지 않는다. 시간을 정해 `pump`한다.

## TextEditingController는 State가 한 번 만들고 dispose한다

`build()` 안에서 `TextEditingController(text: …)`를 만들면, 별점을 고를 때마다 `setState`로 다시 빌드되면서 컨트롤러가 새로 생겨 **입력하던 코멘트가 사라지고 커서가 맨 앞으로 돌아간다.** `late final`로 State 필드에 두면 State가 살아 있는 동안 한 번만 만들어진다. 대신 직접 만든 것이므로 `dispose()`에서 정리해야 한다. 별점을 바꿔도 코멘트가 유지되는 것을 테스트로 고정했다.

## memberId는 인증이 아니다

회원가입 응답의 `memberId`를 `LearningMemberSession`(ChangeNotifier)에 보관하고, 영화 상세(평점 등록)와 마이페이지(조회·수정·삭제)가 같은 값을 읽는다. 앱 최상단 `MultiProvider`에 둔 이유는 서로 다른 Route가 함께 쓰기 때문이다.

- 이 값은 **메모리에만** 있어 앱을 다시 시작하면 사라진다.
- `memberId`만 알면 누구든 그 번호로 요청할 수 있다. 서버가 "요청자가 정말 그 회원인지"를 확인하지 않기 때문이다. 이것은 로그인이 아니다.
- 세션이 비어 있으면(가입 전) 평점 등록 버튼을 비활성화하고 가입 화면으로 안내하며, 마이페이지의 평점 화면은 조회를 시작하지 않는다.
- 다음 주차에 로그인(JWT)이 붙으면 이 값 대신 서버가 토큰으로 회원을 식별하고 경로에서 `memberId`가 사라진다.

## 평점은 1~5 정수: 조용히 자르지 않는다

서버 `score`는 1~5 정수다. 별점 위젯을 `allowHalfRating: false`로 두면 사용자는 별 한 개 단위로만 고른다. 그래도 `RatingBar`는 값을 항상 `double`로 돌려주므로, 요청을 만들 때 `validateServerScore(double)`가 한 번 더 확인한다.

- `3.5.toInt()`는 에러 없이 `3`이 된다. 사용자가 고른 값과 서버에 저장된 값이 달라지는 버그를 조용히 만든다. 그래서 반 점이면 `ArgumentError`로 막는다(`0.5`, `3.5`, `0`, `6`을 테스트).
- 별을 고르기 전에는 코멘트를 입력했더라도 저장 버튼을 누를 수 없다(점수 없이 코멘트만 보내는 요청이 없다).

## 다중 삭제: 순회 중에 컬렉션을 바꾸지 않는다

선택한 평점을 하나씩 지우는 `for` 안에서 같은 `Set`에서 `remove`하면 `ConcurrentModificationError`가 난다. `selectedRatingIds.toList()`로 **복사본을 돈다**. 복사하지 않도록 바꿔 보면 다중 삭제 테스트 두 개가 실제로 실패하는 것을 확인했다.

| 결과 | 처리 |
| --- | --- |
| 성공한 항목 | 선택 Set에서 지우고 목록에서 사라진다 |
| 실패한 항목 | 선택 상태를 **유지**해 바로 다시 시도할 수 있다 |
| 일부만 실패 | 성공 N개·실패 M개를 세어 Snackbar로 "M개 항목을 삭제하지 못했습니다" |
| 전부 성공 | 편집 모드를 끝내고 기본 목록으로 돌아간다 |
| 재조회 실패 | 삭제 결과와 분리해 `refreshWarning`으로 안내 |

- 단건 삭제는 확인 Dialog가 요청이 끝날 때까지 유지되지만, 다중 삭제는 확인 Dialog가 **바로 닫히고** 그 뒤 요청과 로딩을 화면이 이어받는다. 그래서 로딩은 Dialog가 아니라 화면 위 `Stack`의 오버레이다(어두운 `ModalBarrier` + 가운데 흰 인디케이터, 문구·카드 없음).
- 오버레이는 **터치만** 막는다. 화면을 나가는 것은 바깥 `PopScope(canPop: !isDeletingSelected)`가 막는다. 둘이 서로 다른 일을 한다.
- 삭제 중에는 다시 호출해도, 편집 모드를 바꾸거나 선택을 바꿔도 무시된다.

## 참고

- [Dio](https://pub.dev/packages/dio) · [Provider](https://pub.dev/packages/provider) · [flutter_rating_bar](https://pub.dev/packages/flutter_rating_bar)
- [PopScope](https://api.flutter.dev/flutter/widgets/PopScope-class.html) · [showDialog](https://api.flutter.dev/flutter/material/showDialog.html)
- [HTTP 상태 코드 (MDN)](https://developer.mozilla.org/ko/docs/Web/HTTP/Status)
