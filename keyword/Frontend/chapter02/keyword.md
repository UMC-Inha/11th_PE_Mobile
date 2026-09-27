# 2주차 프론트엔드 키워드 정리: 레이아웃과 사용자 입력

> 실습 대상: MovieLog 회원가입 Form과 별점 입력 Widget

## 1. Flutter의 크기 결정 방식

Flutter 레이아웃은 부모가 자식에게 줄 수 있는 크기 범위(constraints)를 전달하고, 자식이 그 범위 안에서 크기를 정하는 방식으로 동작한다. 따라서 회원가입 화면의 높이와 너비를 고정값으로만 구성하면 작은 기기나 키보드가 열린 상태에서 overflow가 생기기 쉽다.

이번 구현에서는 화면 전체의 고정 높이를 두지 않고, 폼을 `SingleChildScrollView` 안에 배치했다. 넓은 화면에서만 `ConstrainedBox(maxWidth: 560)`으로 폼 폭을 제한했다.

## 2. Stack, Expanded, Flexible

- `Stack`: 여러 Widget을 앞뒤로 겹쳐 배치한다. 프로필 이미지 위의 인증 배지처럼 레이어가 필요한 경우에 적합하다.
- `Positioned`: `Stack` 안에서 `top`, `bottom`, `left`, `right`로 위치를 지정한다. 양쪽 방향을 함께 지정하면 남은 영역만큼 늘어날 수 있다.
- `Expanded`: `Row` 또는 `Column`의 남은 공간을 반드시 채운다. `FlexFit.tight`와 같은 동작이다.
- `Flexible`: 남은 공간 안에서 필요한 만큼만 사용한다. 기본값은 `FlexFit.loose`다.

입력창과 작은 보조 버튼을 한 줄에 배치한다면 입력창에는 `Expanded`, 짧은 버튼에는 `Flexible`을 선택할 수 있다. 하지만 이번 회원가입 폼은 모바일 가독성을 위해 세로 배치를 사용했다.

## 3. SingleChildScrollView와 키보드

`Column`은 스크롤 기능이 없다. 입력 항목, 약관, 버튼, 별점 카드가 화면보다 길어질 수 있는 Form에서는 다음과 같은 구조가 안전하다.

```text
Scaffold
└─ SafeArea
   └─ LayoutBuilder
      └─ Center
         └─ ConstrainedBox
            └─ SingleChildScrollView
               └─ Form
```

`keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag`를 설정하면 사용자가 화면을 끌어 스크롤할 때 키보드를 닫을 수 있다. 고정 높이 컨테이너를 남발하지 않는 것이 overflow 방지의 핵심이다.

## 4. Logical Pixel, MediaQuery, LayoutBuilder

Flutter에서 `padding: 16`, `width: 100` 같은 값은 물리 픽셀이 아니라 **Logical Pixel**이다. 기기마다 밀도가 달라도 Flutter가 논리 단위를 실제 화면에 맞게 변환한다.

| 구분 | MediaQuery | LayoutBuilder |
| --- | --- | --- |
| 기준 | 앱 창 전체 | 부모가 현재 Widget에 허용한 공간 |
| 대표 값 | `MediaQuery.sizeOf(context).width` | `constraints.maxWidth` |
| 적합한 상황 | 창 크기, 키보드 inset 확인 | 재사용 Widget 또는 특정 영역의 반응형 배치 |

이번 과제에서는 폼이 실제로 받을 수 있는 너비를 기준으로 넓은 화면을 판단해야 하므로 `LayoutBuilder`를 사용했다. `constraints.maxWidth >= 700`일 때만 폼을 가운데 정렬하고 최대 560 Logical Pixel로 제한한다.

## 5. StatefulWidget과 생명주기

입력 문자열, 약관 동의, 비밀번호 표시 여부, 별점은 화면이 살아 있는 동안 유지되어야 하는 상태다. 그래서 회원가입 화면을 `StatefulWidget`으로 만들었다.

- `initState`: State가 처음 생성될 때 한 번 호출된다.
- `build`: 현재 상태를 바탕으로 UI를 다시 만든다.
- `setState`: 상태 변경을 Flutter에 알려 `build`를 다시 호출하게 한다.
- `dispose`: `TextEditingController`, `FocusNode`처럼 직접 만든 리소스를 해제한다.

`TextEditingController`와 `FocusNode`를 `build` 안에서 만들면 rebuild 때 입력값이나 포커스가 초기화될 수 있다. 따라서 State 필드로 만들고 `dispose`에서 해제했다.

## 6. TextEditingController와 FocusNode

`TextEditingController`는 입력값을 읽고 변경한다. `onChanged`에서 `setState`를 호출하면 컨트롤러의 입력 변화에 맞춰 가입 버튼 활성화 상태도 다시 계산할 수 있다.

`FocusNode`는 다음 입력창으로 포커스를 옮기는 데 사용한다. 닉네임 입력 완료 시 이메일로, 이메일 입력 완료 시 비밀번호로 이동하게 구현했다. 마지막 비밀번호 입력창에서는 유효한 상태일 때 가입 처리를 시도한다.

## 7. Form과 TextFormField

`Form`은 여러 입력을 하나의 단위로 검증한다. `GlobalKey<FormState>`로 `validate()`를 호출하면 모든 `TextFormField.validator`가 다시 실행된다.

이번 구현의 검증 규칙은 다음과 같다.

| 입력값 | 조건 | 오류 메시지 |
| --- | --- | --- |
| 닉네임 | 2글자 이상 | `닉네임은 두 글자 이상 입력해주세요.` |
| 이메일 | 기본 이메일 형식 | `올바른 이메일 형식을 입력해주세요.` |
| 비밀번호 | 8자 이상 | `비밀번호는 8자 이상 입력해주세요.` |

`autovalidateMode: AutovalidateMode.onUserInteraction`으로 사용자가 입력한 뒤 오류를 보여 준다. 버튼 활성화용 빠른 조건 검사와 버튼 클릭 시의 `validate()`는 역할이 다르므로 둘 다 사용했다.

## 8. Checkbox와 버튼 활성화

약관 동의는 `bool _agreedToTerms` 상태로 관리한다. `CheckboxListTile.onChanged`에서 `setState`로 이 값을 갱신한다.

가입 버튼은 닉네임·이메일·비밀번호·약관의 빠른 조건이 모두 맞을 때만 `onPressed`에 함수를 전달한다. 그렇지 않으면 `onPressed: null`이 되어 Material 버튼이 비활성화된다.

## 9. 별점 입력 상태

추가 미니 실습으로 `flutter_rating_bar`의 `RatingBar.builder`를 사용했다. 별점은 부모 화면의 `double _rating` 상태로 관리하며, 0점일 때는 저장 버튼을 비활성화한다. 별점이 선택되면 상태가 갱신되고 저장 버튼이 활성화된다.

## 참고 자료

- [UMC 11기 PE 2주차 - 레이아웃과 사용자 입력 (1)](https://makeus-challenge.notion.site/2-1-3e3b57f4596b80e591a5ebab81d52b68?source=copy_link)
- [Flutter - Build a form with validation](https://docs.flutter.dev/cookbook/forms/validation)
- [Flutter API - LayoutBuilder](https://api.flutter.dev/flutter/widgets/LayoutBuilder-class.html)
- [Flutter API - SingleChildScrollView](https://api.flutter.dev/flutter/widgets/SingleChildScrollView-class.html)
- [Flutter API - TextEditingController](https://api.flutter.dev/flutter/widgets/TextEditingController-class.html)
- [Flutter API - Focus and text fields](https://docs.flutter.dev/cookbook/forms/focus)
