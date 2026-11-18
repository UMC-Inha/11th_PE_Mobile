<!-- Notion 개인 미션 페이지에 붙여 넣기용. mission.md와 같은 내용이고, 상대 링크·이미지는 GitHub 주소로 바꿨다.
     링크와 이미지는 brownglasses/week08 브랜치를 푸시한 뒤에 열린다. -->

# 8주차 프론트엔드 미션 — JWT 토큰 기반 로그인 및 세션 복원

- 이름 / 닉네임: 케빈
- [GitHub 실습 저장소](https://github.com/brownglasses/11th_PE_Mobile_Flutter_Practice_Mission/tree/brownglasses/week08)
- Pull Request: [Pull Request #20](https://github.com/UMC-Inha/11th_PE_Mobile_Flutter_Practice_Mission/pull/20)
- [원본 워크북](https://makeus-challenge.notion.site/41cb57f4596b80b1bc6cd94bb9878937)
- [핵심 개념 정리](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/keyword/Frontend/chapter08/keyword.md)
- 같은 주 백엔드 미션: [백엔드 8주차](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Backend/chapter08/mission.md)

> 이 문서에서 **"실서버·실제 화면에서 확인"** 은 Chrome(Flutter Web 390x844)이 실제 NestJS 서버(일회용 DB)를 호출한 것이고, **"테스트로 확인"** 은 가짜 서버(Fake)를 쓴 위젯·ViewModel 테스트에서 본 것이다. **iOS Keychain·Android Keystore는 확인하지 못했다**(이 맥에는 Xcode·Android SDK가 없다). 영상도 없고 정지 화면과 요청 기록만 있다.

## 먼저 알아 둘 것: 이 주차의 서버 계약

7주차 프론트는 6주차 계약(경로에 `memberId`)으로 만들었고, 이번 주에 처음으로 **7주차 이후의 백엔드(JWT)** 와 이어졌다. 그래서:

- 워크북 API는 `https://…/v7/…`지만 우리는 5주차부터 자체 NestJS 서버를 써서 경로에 `/v7`이 없다(`POST /auth/login`, `GET·PATCH /members/me`, `POST /ratings`, `PATCH·DELETE /ratings/{ratingId}`). 워크북의 `/register` 대신 기존 앱의 경로 `/sign-up`을 그대로 썼다.
- **로그인 응답에는 `nickname`과 `accessToken`만 있고 `memberId`가 없다.** 내 정보 응답(`GET /members/me`)도 `email · nickname · createdAt`뿐이다. 그리고 **토큰으로 "내 평점 목록"을 읽는 GET이 없다.** 워크북의 "진행 원칙과 API 한계"가 말한 그대로다. 그래서 JWT의 claim을 추측하지 않았고, 6주차의 공개 조회(`GET /members/{memberId}/ratings`)로 우회하지도 않았다.
- 그 결과 **"내가 등록한 평점"은 이번 로그인에서 등록한 평점만** 보인다. 앱을 다시 켜면 비어 있고, 화면에 "이번 로그인에서 등록한 평점만 보여요. 서버에 내 평점 조회 API가 없어 앱을 다시 켜면 목록이 비어요."를 상시 표시한다. 재시작 뒤 내 평점 전체 복원은 **완료된 기능이 아니다**(서버 계약의 한계이고 프론트 버그가 아니다).

### v6 → v7 변경 표 (제출 양식 항목)

| 항목 | 7주차(v6 계약) | 8주차(v7 계약) |
| --- | --- | --- |
| 회원 식별 | 경로의 `memberId`(가입 응답을 세션에 보관) | `Authorization: Bearer {토큰}` 헤더. 경로·body·쿼리 어디에도 `memberId`가 없다 |
| 등록 | `POST /members/{id}/ratings` → 201, `result`가 숫자 또는 `null` | `POST /ratings` → 201, `result`가 **Rating 객체**(이 객체로 현재 세션 카드를 바로 갱신) |
| 수정 | `PATCH /members/{id}/ratings/{ratingId}` | `PATCH /ratings/{ratingId}`, body는 항상 `score`와 `comment` |
| 삭제 | `DELETE …` → **204**, 본문 없음 | `DELETE /ratings/{ratingId}` → **200** + 공통 응답 틀(`result: null`) |
| 내 평점 조회 | `GET /members/{id}/ratings`(직접 배열) | 토큰 기반 조회 없음 → 세션 한정 목록(`SessionRatings`) |
| 실패 code | 서버 문구·HTTP 상태 중심 | `AUTH401_1·2·3·4`, `RATING403_1`, `RATING409_1`, `MEMBER409_1`, `COMMON400` 등 도메인 code |
| Dio Client | `MovieLogApiService` 하나 | 공개용(로그인·가입·중복 확인·유저별 조회) + 보호용(`AuthInterceptor`가 달린 `RatingApiService`·`MemberApiService`) |

## 구현 결과

| 계층 | 파일 | 8주차 변경 |
| --- | --- | --- |
| 네트워크 | `core/network/api_error.dart` | `apiErrorCode`·`apiErrorMessage`·`isSessionExpiredCode`(AUTH401_2/3/4만 만료) |
| 네트워크 | `core/network/auth_interceptor.dart` | 서버 주소(host·port)와 경로가 모두 보호 대상일 때만 Bearer 부착, 이전 Authorization 제거, 저장소 읽기 실패는 `unknown`으로 중단 |
| 네트워크 | `core/network/movielog_api_client.dart` | 공개용 `createMovieLogApiClient` / 보호용 `createAuthMovieLogApiClient` 분리 |
| 네트워크 | `core/network/log_redaction.dart` | `accessToken`·`password`·`authorization` 키와 JWT 모양 값을 가려서 로그에 남김 |
| 저장 | `core/storage/token_storage.dart` | `TokenStorage` 인터페이스 + `SecureTokenStorage`(`flutter_secure_storage`) |
| 저장 | `core/storage/email_preference.dart` | "이메일 저장"(shared_preferences, **이메일만**) |
| Model | `data/models/login_models.dart`, `member_info.dart` | 로그인 요청·응답(`memberId` 없음), 내 정보(`createdAt` → "2026.11.18 가입") |
| Service | `data/services/auth_api_service.dart`, `member_api_service.dart`, `rating_api_service.dart` | 로그인, GET·PATCH me, 평점 등록·수정·삭제(보호 Client) |
| ViewModel | `view_models/auth_view_model.dart` | `AuthStatus` 5상태, `restoreSession`·`login`·`logout`·`expireSession`·`loadMember`, `sessionVersion`, `statusListenable` |
| ViewModel | `view_models/edit_profile_view_model.dart`, `session_ratings.dart`, `rating_error.dart` | 닉네임 수정(2~12자·409·통신 실패), 이번 세션의 평점, 평점 오류 구분 |
| View | `features/start/.../splash_screen.dart`, `features/auth/.../login_screen.dart` | 토큰 확인 중·재시도 화면, 로그인 Form(이메일 저장, 만료 Snackbar 한 번) |
| View | `features/my_page/.../edit_profile_screen.dart`, `my_page_screen.dart`, `my_ratings_screen.dart` | 프로필 수정(변경 있으면 나가기 확인), 내 정보·로딩·재시도·가입일, 세션 한정 평점 목록 |
| 앱 | `app/app_router.dart`, `app/movie_log_app.dart` | `authRedirect` + `refreshListenable(statusListenable)`, GoRouter는 `initState`에서 한 번만 생성 |

삭제한 것: `learning_member_session.dart`(7주차에 `memberId`를 세션에 보관하던 클래스), `start_screen.dart`(→ `splash_screen.dart`). 패키지는 `flutter_secure_storage ^11.2.0` 하나를 더했다.

## 화면 (실제 NestJS에 연결한 Flutter Web, Chrome 390x844)

### 무엇이 진짜이고 무엇이 대역인가

| 구성 | 정체 |
| --- | --- |
| Flutter 앱 | **진짜.** 저장소의 `lib/` 그대로 debug 모드(`flutter run -d web-server`)로 실행. 한글 글꼴(Pretendard)·viewport meta·가짜 TMDB 주소는 **임시 복사본**에만 넣었고 저장소 코드에는 없다. |
| 백엔드 | **진짜.** `brownglasses/week08` 브랜치를 `git archive`로 풀어 빌드한 NestJS 12 + TypeORM + MySQL. 실행마다 무작위 `JWT_SECRET`. |
| DB | **진짜 MySQL, 일회용 DB**(`umc_movie_test_fe8live`). 끝나고 삭제했고 개발 DB `umc_movie`는 건드리지 않았다. |
| TMDB | **대역.** 이 맥에는 TMDB Token이 없어 로컬 가짜 서버가 영화 7편만 돌려줬다(줄거리는 자리표시). 포스터 이미지는 실제 TMDB 이미지 서버에서 받았다. |
| 네트워크 | 앱 → **기록·실패 주입 프록시** → 백엔드. 요청마다 method·path·status·"Authorization이 있었는가"만 적었다(값은 기록하지 않음). |
| 보안 저장소 | **웹 구현**(WebCrypto + localStorage). Keychain/Keystore **아님**. |

아래 화면의 **통신 실패·느린 응답·503은 프록시가 일부러 만든 것**이고, "서버가 꺼진 상태"와 "서버 JWT 키를 바꿔 기존 토큰을 무효로 만든 것", "`JWT_ACCESS_EXPIRATION=20`(초)으로 실제로 만료시킨 것"은 실제 서버로 만든 상황이다. 요청 기록: [network-auth-header.txt](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/network-auth-header.txt).

### 로그인 · 마이페이지

| 토큰 없이 첫 실행 → 로그인 | 틀린 비밀번호(AUTH401_1) | 통신 실패(다른 문구) |
| --- | --- | --- |
| ![01_cold_start_login.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/01_cold_start_login.jpg) | ![03_login_wrong_password_form_error_only.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/03_login_wrong_password_form_error_only.jpg) | ![04_login_network_failure_different_message.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/04_login_network_failure_different_message.jpg) |

| 가입 → 로그인 화면(이메일만 채워짐) | 로그인 성공 → 홈 | 마이페이지: 닉네임·가입일·이메일 |
| --- | --- | --- |
| ![02_signup_to_login_email_prefilled.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/02_signup_to_login_email_prefilled.jpg) | ![05_login_success_home.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/05_login_success_home.jpg) | ![06_my_page_nickname_email_join_date.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/06_my_page_nickname_email_join_date.jpg) |

- 첫 실행의 주소 흐름은 `/`(시작 화면) → `#/login`뿐이었다. 홈이나 로그인이 먼저 비친 기록은 없다.
- 틀린 비밀번호는 폼 아래 "이메일 또는 비밀번호를 확인해 주세요."만 보이고 만료 Snackbar는 없다. 서버가 꺼졌을 때는 "네트워크 상태를 확인하고 다시 시도해 주세요."로 문구가 다르다.

### 세션 복원 · 만료 · 무효 토큰

| 새로고침: GET me 응답을 기다리는 시작 화면 | 복원 후 홈(로그인 화면은 안 보임) | 응답이 5초를 넘겨 `retryRequired` |
| --- | --- | --- |
| ![07_reload_restore_splash_while_GET_me_pending.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/07_reload_restore_splash_while_GET_me_pending.jpg) | ![09_restore_after_retry_home.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/09_restore_after_retry_home.jpg) | ![08_restore_timeout_retryRequired_token_kept.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/08_restore_timeout_retryRequired_token_kept.jpg) |

| 서버를 실제로 끄고 새로고침 | 무효 토큰(서버 JWT 키 변경) → 로그인 + 만료 Snackbar | 실제 만료(AUTH401_4) → 로그인 + 만료 Snackbar |
| --- | --- | --- |
| ![30_BE_down_reload_retryRequired_token_kept.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/30_BE_down_reload_retryRequired_token_kept.jpg) | ![31_invalid_token_restore_login_with_expiry_snackbar.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/31_invalid_token_restore_login_with_expiry_snackbar.jpg) | ![32_expired_token_protected_request_login_with_snackbar.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/32_expired_token_protected_request_login_with_snackbar.jpg) |

- **네트워크 실패·타임아웃은 토큰을 지우지 않는다.** 두 경우 모두 브라우저 저장소의 토큰 키가 그대로(길이 285) 남았고, 서버를 다시 켠 뒤 [다시 시도]를 누르면 홈으로 복원됐다.
- 무효 토큰은 `GET /members/me` → 401 `AUTH401_3`, 만료는 `POST /ratings` → 401 `AUTH401_4`였다. 두 경로 모두 토큰 키가 삭제되고 "로그인이 만료됐어요. 다시 로그인해 주세요." Snackbar가 **한 번** 떴다. 회원가입 화면에 다녀와도 다시 뜨지 않았다. 직접 로그아웃·로그인 실패에서는 뜨지 않았다.
- 한 번에 여러 보호 요청이 401을 받는 상황은 **실서버에서 만들지 못했다**(아래 "확인하지 못한 것").

### 토큰 기반 평점 등록 · 수정 · 삭제

| 등록(`POST /ratings`, memberId 없음) | 내가 등록한 평점 — 세션 한정 안내와 TMDB 제목·포스터 | 수정 5점(`PATCH`) |
| --- | --- | --- |
| ![10_rating_created_token_only.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/10_rating_created_token_only.jpg) | ![11_my_ratings_session_notice_and_tmdb_join.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/11_my_ratings_session_notice_and_tmdb_join.jpg) | ![12_rating_edited_patch_ok.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/12_rating_edited_patch_ok.jpg) |

| 삭제(200) → 빈 목록 | 같은 영화 재등록 409 | 남의 평점 수정 403(로그아웃 안 됨) |
| --- | --- | --- |
| ![13_rating_deleted_empty_list.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/13_rating_deleted_empty_list.jpg) | ![14_rating_409_duplicate_message_dialog_kept.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/14_rating_409_duplicate_message_dialog_kept.jpg) | ![15_rating_403_other_members_rating_message_no_logout.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/15_rating_403_other_members_rating_message_no_logout.jpg) |

- 등록 요청 body의 key는 `movieId, score`(코멘트가 비면 생략)였고 `memberId`는 어디에도 없었다. 수정은 `score, comment`, 닉네임 수정은 `nickname`이었다.
- `movieId`는 TMDB 영화 id(550)다. 평점 카드는 평점 응답의 `movieId`로 TMDB에서 영화를 조회해(`GET /movie/550`) 제목·포스터를 붙인다. 못 찾으면 `영화 #{id}` 자리표시다(테스트로 확인).
- **403은 하네스가 만든 경로로 확인했다.** 앱 화면에는 내 평점만 있어서 남의 `ratingId`를 고를 방법이 없다. 그래서 프록시가 내 평점의 `PATCH /ratings/3`을 계정 B의 평점 `/ratings/2`로 바꿔 서버에 보냈다. 서버가 403 `RATING403_1`을 줬고 앱은 다이얼로그 안에 "본인이 작성한 평점만 수정하거나 삭제할 수 있습니다."를 보였으며, 로그아웃되지 않았고 취소 뒤 내 평점은 그대로였다.

### 프로필 수정

| 수정 화면(이메일 읽기 전용, 하단 탭 없음) | 같은 닉네임 → 요청 없음 | 중복 닉네임 409, 입력 유지 |
| --- | --- | --- |
| ![16_profile_edit_screen_email_readonly_no_bottom_nav.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/16_profile_edit_screen_email_readonly_no_bottom_nav.jpg) | ![17_profile_same_nickname_no_request_snackbar.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/17_profile_same_nickname_no_request_snackbar.jpg) | ![18_profile_409_duplicate_nickname_input_kept.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/18_profile_409_duplicate_nickname_input_kept.jpg) |

| 2~12자 검증, 요청 없음 | 변경 있음 → 나가기 확인 Dialog | 나가기 → 닉네임 그대로 |
| --- | --- | --- |
| ![19_profile_validation_2to12_no_request.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/19_profile_validation_2to12_no_request.jpg) | ![20_profile_unsaved_changes_confirm_dialog.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/20_profile_unsaved_changes_confirm_dialog.jpg) | ![34_profile_unsaved_leave_returns_to_mypage_unchanged.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/34_profile_unsaved_leave_returns_to_mypage_unchanged.jpg) |

| 정상 저장 → 화면이 닫히고 새 닉네임 | 통신 실패 Snackbar(**수정 전**: 저장 버튼을 가림) | |
| --- | --- | --- |
| ![22_profile_saved_screen_closed_new_nickname.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/22_profile_saved_screen_closed_new_nickname.jpg) | ![21_profile_network_failure_snackbar_covers_save_button.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/21_profile_network_failure_snackbar_covers_save_button.jpg) | |

- 정상 저장은 `PATCH /members/me` 200 → 수정 화면이 닫히고 마이페이지에 새 닉네임. 저장 뒤 `GET /members/me`는 다시 나가지 않았다(성공 응답으로 메모리의 내 정보를 바꾼다).
- `21`은 실서버 확인 중 찾은 문제의 **수정 전** 화면이다(트러블슈팅 No.5). 수정 뒤 화면은 다시 찍지 못했고 위젯 테스트로만 확인했다.

### 로그아웃 · 회원 전환 · Challenge

| 로그아웃 → 로그인 화면(만료 안내 없음) | 계정 B로 로그인 → B의 정보 | B의 평점 목록은 비어 있음(A의 것 안 보임) |
| --- | --- | --- |
| ![23_logout_login_screen_no_expiry_snackbar.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/23_logout_login_screen_no_expiry_snackbar.jpg) | ![25_account_switch_B_mypage_own_data.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/25_account_switch_B_mypage_own_data.jpg) | ![26_account_switch_B_ratings_empty_no_stale_A.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/26_account_switch_B_ratings_empty_no_stale_A.jpg) |

| 마이페이지 로딩(전체 화면 스피너) | GET me 503 → 오류 + 다시 시도(로그아웃 안 됨) | 이메일 저장: 이메일만 채워짐 |
| --- | --- | --- |
| ![24_mypage_loading_spinner_while_GET_me_pending.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/24_mypage_loading_spinner_while_GET_me_pending.jpg) | ![27_mypage_error_retry_after_GET_me_503_still_signed_in.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/27_mypage_error_retry_after_GET_me_503_still_signed_in.jpg) | ![28_remember_email_prefilled_password_empty.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/28_remember_email_prefilled_password_empty.jpg) |

| 이메일 저장 해제 → 모두 비어 있음 | 다중 삭제 중 첫 401 → 세션 정리, Snackbar 한 번 | |
| --- | --- | --- |
| ![29_remember_email_unticked_form_empty.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/29_remember_email_unticked_form_empty.jpg) | ![33_multi_delete_first_401_clears_session_snackbar_once.jpg](https://raw.githubusercontent.com/brownglasses/11th_PE_Mobile/brownglasses/week08/mission/Frontend/chapter08/images/33_multi_delete_first_401_clears_session_snackbar_once.jpg) | |

## 제출 양식

워크북 "제출 양식" 순서 그대로 적었다.

| 항목 | 내용 |
| --- | --- |
| PR 링크 | [Pull Request #20](https://github.com/UMC-Inha/11th_PE_Mobile_Flutter_Practice_Mission/pull/20) |
| 로그인→GET me 증거 | 로그인 성공 [05](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/05_login_success_home.jpg) → 마이페이지 [06](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/06_my_page_nickname_email_join_date.jpg). 요청 기록: `POST /auth/login` 200(Authorization 없음) → `GET /members/me` 200(Bearer 있음). 틀린 비밀번호는 [03](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/03_login_wrong_password_form_error_only.jpg)(401 AUTH401_1, 폼 오류만), 통신 실패는 [04](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/04_login_network_failure_different_message.jpg) |
| 재시작 복원 / 로그아웃 / 만료 증거 | **복원**: 새로고침 → 시작 화면 [07](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/07_reload_restore_splash_while_GET_me_pending.jpg) → 홈 [09](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/09_restore_after_retry_home.jpg), 요청 순서 `GET /members/me` → `GET /movie/popular`, 로그인 화면은 한 번도 안 보임. **복원 실패(통신)**: [08](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/08_restore_timeout_retryRequired_token_kept.jpg)·[30](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/30_BE_down_reload_retryRequired_token_kept.jpg) 토큰 유지. **로그아웃**: [23](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/23_logout_login_screen_no_expiry_snackbar.jpg) 토큰 키 삭제, 만료 안내 없음. **무효/만료**: [31](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/31_invalid_token_restore_login_with_expiry_snackbar.jpg)(AUTH401_3)·[32](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/32_expired_token_protected_request_login_with_snackbar.jpg)(AUTH401_4), 안내 한 번 |
| 닉네임 수정 증거 | 정상 [22](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/22_profile_saved_screen_closed_new_nickname.jpg)(`PATCH /members/me` 200), 중복 409 [18](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/18_profile_409_duplicate_nickname_input_kept.jpg)(입력 유지), 같은 닉네임 [17](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/17_profile_same_nickname_no_request_snackbar.jpg)(요청 없음), 2~12자 [19](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/19_profile_validation_2to12_no_request.jpg), 통신 실패 [21](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/21_profile_network_failure_snackbar_covers_save_button.jpg)(로그아웃 안 함) |
| 평점 v6→v7 변경 표와 동작 영상 | 변경 표는 위 "v6 → v7 변경 표". 동작은 등록 [10](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/10_rating_created_token_only.jpg) → 목록 [11](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/11_my_ratings_session_notice_and_tmdb_join.jpg) → 수정 [12](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/12_rating_edited_patch_ok.jpg) → 삭제 [13](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/13_rating_deleted_empty_list.jpg). **영상은 없다**(정지 화면과 요청 기록만) |
| TMDB id → MovieLog movieId → 영화 정보 결합 증거 | 상세 화면의 TMDB 영화 id 550 → `POST /ratings` body `{movieId: 550, score, …}`(memberId 없음) → 평점 응답의 `movieId`로 `GET /movie/550`(TMDB)을 조회해 카드에 "파이트 클럽"·포스터 [11](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/images/11_my_ratings_session_notice_and_tmdb_join.jpg). `movieId`와 `ratingId`를 구분한다 |
| 401/403/409 처리 | 아래 표 |
| 보안 저장 검증 플랫폼·결과 | **Chrome(Flutter Web)만.** 토큰 키 `FlutterSecureStorage.movielog.access_token`이 평문 JWT(`eyJ`)가 아닌 암호화된 값(285자)으로 저장됨, 로그아웃하면 키 삭제. **iOS/Android는 하지 못했다.** [storage-check.txt](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/storage-check.txt) |
| 토큰/비밀번호 비노출 확인 | Network: 보호 경로에만 Bearer, 위반 0건([network-auth-header.txt](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/network-auth-header.txt)). 콘솔: `eyJ`·테스트 비밀번호 0건, Authorization은 `Bearer ***`([console-log-check.txt](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/console-log-check.txt)). 저장소: 비밀번호 저장 없음, 이메일 저장은 체크했을 때만 |
| 트러블슈팅 | 아래 "트러블슈팅" (No.1~No.5) |

**401 / 403 / 409 처리** (실서버 응답으로 확인한 것)

| 상황 | 요청 | 서버 응답 | 앱 동작 | 이미지 |
| --- | --- | --- | --- | --- |
| 로그인 입력 오류 | `POST /auth/login` | 401 `AUTH401_1` | 폼에 "이메일 또는 비밀번호를 확인해 주세요." 만료 처리·Snackbar 없음 | 03 |
| 토큰 무효 | `GET /members/me` | 401 `AUTH401_3` | 토큰 삭제 → 로그인 화면 + 만료 Snackbar 한 번 | 31 |
| 토큰 만료 | `POST /ratings` | 401 `AUTH401_4` | 같은 처리 | 32 |
| 남의 평점 수정(권한 없음) | `PATCH /ratings/{id}` | 403 `RATING403_1` | 안내만, **로그아웃 안 함**, 내 평점 그대로 | 15 |
| 같은 영화 재등록 | `POST /ratings` | 409 `RATING409_1` | 다이얼로그가 닫히지 않고 서버 문구, 입력 유지 | 14 |
| 닉네임 중복 | `PATCH /members/me` | 409 `MEMBER409_1` | 입력칸 오류 "이미 사용 중인 닉네임이에요.", 입력 유지 | 18 |
| 통신 실패 | 어느 요청이든 | 응답 없음 | 토큰 유지, 로그아웃 없음(복원 중이면 재시도 화면) | 04·08·30 |

**확인하지 못한 것**

| 항목 | 이유 |
| --- | --- |
| **iOS Keychain · Android Keystore** | 이 맥에는 Xcode·Android SDK가 없다. 웹의 `flutter_secure_storage`는 WebCrypto + 브라우저 저장소이고, 암호문과 키로 보이는 값이 **같은 출처의 localStorage**에 있다. 스크립트가 같은 출처에서 돌 수 있다면(예: XSS) 복호화될 수 있어서 웹의 보안 수준을 모바일과 같다고 말하지 않는다. |
| **영상** | 앱 재시작→홈, 토큰 기반 평점 등록→수정→삭제 영상은 만들지 못했다. 정지 화면과 요청 기록으로 대신했다. |
| 동시에 나가는 여러 401 | 실서버에서 만들지 못했다. 다중 삭제가 순차라서 첫 401에서 멈추고 나머지 요청이 나가지 않았다(이미지 33, `DELETE /ratings/{id}` 401이 1건). "한 번만 정리·안내"는 단위 테스트(변이 검사 M12·M13)로만 확인했다. |
| 이미지 요청에 Authorization이 없는지 | 브라우저가 직접 받는 요청이라 프록시로 못 봤다. 앱 코드상 `Image.network`는 Dio(=Interceptor)를 거치지 않는다. |
| 콘솔 로그 전체 | 도구가 보관한 마지막 432건만 검사했다. 앞부분(가입·틀린 비밀번호 로그인)은 로그인 요청 줄이 헤더만 찍는다는 점과 단위 테스트로 보완했다. |
| 서버 500일 때 프로필 저장 문구 | 테스트로만 확인했다(실서버에서는 만들지 않음). |
| 자정~오전 9시(KST) 가입의 가입일 경계 | 확인하지 못했다. 서버가 UTC 순간(`…Z`)으로 내려 주고 앱이 `toLocal()`로 기기 현지 날짜를 보여 준다. 이 맥(KST)에서 `2026.11.18`로 일치했다. 기기 시간대가 다르면 날짜가 다를 수 있다. |
| 실제 TMDB 응답 | Token이 없어 가짜 TMDB를 썼다(포스터만 실제 이미지 서버). |
| 즐겨찾기(백엔드 8주차 기능) 연결 | 이번 프론트 워크북 범위에 없어서 연결하지 않았다. |

## Guided Practice

### A. 로그인부터 내 정보까지

- [x] `flutter_secure_storage`를 추가하고 `TokenStorage`(`SecureTokenStorage`)로 저장·조회·삭제를 한곳에 모았다
- [x] 공개용·보호용 Client로 나누고 보호용에만 `AuthInterceptor`를 등록했다
- [x] 공개 Client로 로그인하고 `accessToken`을 secure storage에 저장했다
- [x] `AuthViewModel`에 초기화·로그인 중·로그인됨·로그아웃·확인 실패 상태(`AuthStatus` 5개)를 정의하고 `login()`을 연결했다
- [x] GoRouter에 `/login`을 추가하고 `redirect` + `refreshListenable`로 상태별 이동을 연결했다
- [x] 탭 화면을 담는 `MainShell`이 처음 열릴 때 `loadMember()`로 `GET /members/me`를 호출해 `AuthViewModel.member`에 보관한다(build 중이 아니라 post-frame)
- [x] 앱 재시작 후 토큰 읽기 → `GET /members/me`(`restoreSession`) → 홈 흐름을 검증했다 (실서버)

### B. 평점 등록 전환

- [x] v6 Service의 `memberId` 인자를 제거했다
- [x] 보호용 Client(`RatingApiService`)로 등록·수정·삭제를 호출하고 유저별 평점 조회는 공개용으로 유지했다
- [x] 등록 요청 body에 `memberId`를 넣지 않는다 (요청 기록으로 확인)
- [x] 등록 result의 Rating 객체로 현재 세션 카드를 갱신한다
- [x] AUTH401_2/3/4는 `expireSession()`으로 세션을 정리하고, 403·409는 안내만 한다

## Required Mission

- [x] 현재 세션에서 생성한 Rating을 PATCH/DELETE로 변경한다
- [x] v7 성공 status/result와 도메인 오류 code로 파서를 바꿨다(삭제 200 + `result: null`)
- [x] 마이페이지에서 `GET /members/me`로 받은 내 정보를 표시하고, `/my/profile/edit`에서 `PATCH /members/me`로 닉네임을 수정한다
- [x] 닉네임 수정 오류를 구분한다: 2~12자 검증, `MEMBER409_1`(입력 유지), 통신 실패(재시도 가능, 로그아웃 없음)
- [x] 앱 재시작 복원·만료·로그아웃·보호 화면 redirect를 완성했다
- [x] 마이페이지 앱바의 로그아웃 버튼으로 토큰과 `member`를 지우고 `/login`으로 이동한다
- [x] 세션 만료로 로그인 화면에 오면 Snackbar로 안내한다. 직접 로그아웃·로그인 실패에서는 표시하지 않는다

## Challenge Mission

- [x] 로그인 화면 "이메일 저장" 체크박스(`shared_preferences`에는 **이메일만**, 비밀번호·토큰은 저장하지 않음) — 이미지 28·29, 저장소에 `saved_login_email` 하나뿐
- [x] 마이페이지가 `memberStatus`를 구독해 불러오는 동안 화면 전체 `CircularProgressIndicator`, 실패하면 재시도 버튼 — 이미지 24·27
- [x] 닉네임 아래 가입일을 "2026.11.18 가입" 형식으로 표시 — 이미지 06
- [x] 프로필 수정에서 변경 내용이 있을 때 뒤로가기 확인 Dialog(확인 → 마이페이지, 아니면 머무름) — 이미지 20·34

## 최종 체크리스트

- [x] 비밀번호를 저장하거나 로그에 남기지 않는다
- [x] 보호 대상 host/path에만 Bearer를 붙인다
- [x] 로그인 401·보호 401·403을 구분한다
- [x] 앱 재시작은 `GET /members/me` 검증 뒤 `signedIn`이 된다. 신규 로그인은 토큰 저장 뒤 `loadMember()`로 내 정보를 불러온다
- [x] 네트워크 실패에 토큰을 자동 삭제하지 않는다
- [x] v7 경로·parser·status·error code를 함께 변경했다(우리 서버에는 `/v7` 접두사가 없다)
- [x] TMDB Token과 MovieLog JWT를 서로 다른 Client에만 보낸다
- [x] 평점 `movieId`로 TMDB 영화 정보를 연결하며 없는 정보는 placeholder 처리한다
- [x] 로그아웃/회원 전환 뒤 이전 응답을 무시한다(`sessionVersion` — 테스트로 확인, 실서버에서는 계정 전환 시 이전 계정 데이터가 남지 않는 것까지 확인)
- [x] 내 평점 전체 복원 계약의 한계를 문서화했다
- [ ] 선택한 실제 플랫폼에서 secure storage를 검증했다 — **Chrome(웹)에서만 했고 iOS/Android는 못 했다.** 그래서 체크하지 않았다
- [x] `flutter analyze`와 Guided/Required 수동 검증 결과를 기록했다([analyze](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/flutter-analyze.txt) No issues found, [test](https://github.com/brownglasses/11th_PE_Mobile/blob/brownglasses/week08/mission/Frontend/chapter08/flutter-test.txt) 374개 통과·3개 건너뜀)

## 진행 과정과 검증

1. 두 워크북(프론트·백엔드)을 읽고 7주차 코드와 비교했다. 7주차 프론트는 가입 응답의 `memberId`를 세션에 들고 다니는 구조라 이번 주에 걷어내는 범위가 컸다.
2. 데이터·저장 계층부터 만들었다(`TokenStorage`, `AuthInterceptor`, 로그인·내 정보·평점 Service). Interceptor는 서버 주소와 경로를 함께 보고, TMDB와 MovieLog Client를 섞지 않게 했다.
3. `AuthViewModel`에 상태 5개와 `sessionVersion`을 두고, 화면 이동은 `authRedirect` 한 함수에 모았다(상태 5 × 위치 9 조합을 테스트로 전부 확인).
4. 로그인·시작·프로필 수정 화면과 평점 쓰기의 토큰 전환을 연결하고, "내가 등록한 평점"을 세션 한정으로 바꿨다.
5. 테스트: `flutter test` **374개 통과, 3개 건너뜀**(7주차 193개에서 증가, 건너뜀은 실서버·실제 TMDB가 필요한 `test/live` 3개). `flutter analyze` No issues found.
6. **가드를 일부러 망가뜨려 테스트가 실제로 실패하는지 확인했다**(14가지, 모두 실패 → 원복 후 전체 통과). 아래 표.
7. 실서버(일회용 DB)와 Flutter Web으로 13개 시나리오를 돌려 화면·요청 기록·저장소·콘솔을 남겼다. 이 과정에서 테스트가 놓친 문제 1건(통신 실패 Snackbar가 저장 버튼을 가림)을 더 찾아 고쳤다.

| # | 망가뜨린 것 | 실패한 테스트 |
| --- | --- | ---: |
| M1 | 재시도 상태에서 토큰 삭제(네트워크 실패 = 로그아웃) | 5 |
| M2 | redirect: 로그인한 사용자가 `/login`에 머묾 | 6 |
| M3 | Interceptor가 모든 요청에 토큰 | 4 |
| M4 | 공개 Client에 Authorization을 심음 | 1 |
| M5 | 403을 만료로 처리(로그아웃) | 5 |
| M6 | AUTH401_1(로그인 입력 오류)도 만료로 취급 | 1 |
| M7 | `sessionVersion` 검사 제거 | 4 |
| M8 | `GET /members/me` 전에 `signedIn` 확정 | 3 |
| M9 | 로그 가림(redaction) 제거 | 2 (처음엔 **0**, 아래 No.4) |
| M10 | Router가 인증 알림마다 새로고침 | 4 |
| M11 | 로그인 화면이 새 `initialEmail` 무시 | 2 |
| M12 | 평점 쓰기 401에서 세션을 정리하지 않음 | 7 |
| M13 | 이전 세션의 늦은 401이 새 로그인을 지움 | 2 |
| M14 | 프로필 저장 500을 "네트워크" 탓으로 표시 | 1 |

- M3·M8은 이 문서를 쓰기 전에 **다시 직접 돌려** 같은 결과(실패)를 확인했고, 마지막에 추가한 Snackbar 수정도 "수정을 지우면 테스트가 실패한다"를 확인했다.

## 트러블슈팅

### ⚡ No.1 회원가입 후 로그인 화면의 이메일이 채워지지 않음

```
인증 상태와 재현 순서: signedOut. 로그인 화면 → "회원가입"(context.push) → 가입 성공 → context.go('/login', extra: email)
요청 종류: 공개(POST /members)
status / code: 201 / COMMON201
예상 AuthStatus: signedOut 유지, 로그인 화면에 이메일이 미리 채워짐
실제 AuthStatus·화면: signedOut은 맞지만 이메일 칸이 비어 있음
원인: 로그인 화면이 회원가입 화면 아래에 그대로 남아 있어서 go 해도 같은 State가 재사용되는데,
      initialEmail을 initState에서만 읽었다.
수정: LoginScreen에 didUpdateWidget을 추가했다(새 이메일이 오면 채우고 비밀번호 칸은 비운다).
재시작·로그아웃·회원 전환 재검증: 위젯 테스트(수정 전 실패 → 후 통과), 변이 M11. 실서버에서도 가입 뒤
      로그인 화면에 이메일이 채워지고 비밀번호는 비어 있었다(images/02_signup_to_login_email_prefilled.jpg).
```

### ⚡ No.2 프로필 닉네임 저장에 성공해도 수정 화면이 닫히지 않음

```
인증 상태와 재현 순서: signedIn. 마이페이지 → 프로필 수정 → 새 닉네임 → 저장
요청 종류: 보호(PATCH /members/me)
status / code: 200 (서버 성공)
예상 AuthStatus: signedIn 유지 + 수정 화면이 pop되어 마이페이지에 새 닉네임
실제 AuthStatus·화면: signedIn 유지, 닉네임은 바뀌었지만 수정 화면이 그대로 남고 Snackbar만 떴다.
원인: AuthViewModel의 모든 notifyListeners(내 정보 갱신 포함)가 refreshListenable로 GoRouter를 새로 고쳤고,
      그 새로 고침이 방금 pop한 위치를 되살렸다. (go_router 내부 코드까지 추적하지는 않았다.
      "상태가 바뀔 때만 새로 고침"으로 바꾼 수정 전후 테스트로 확인했다.)
수정: 인증 상태가 바뀔 때만 알리는 statusListenable(ValueNotifier)을 만들어 refreshListenable로 연결했다.
재시작·로그아웃·회원 전환 재검증: 위젯 테스트 4개(수정 전 실패 → 후 통과), 변이 M10. 실서버에서 저장 뒤
      수정 화면이 닫히고 새 닉네임이 보였다(images/22_profile_saved_screen_closed_new_nickname.jpg).
```

### ⚡ No.3 서버가 500으로 응답했는데 "네트워크 상태를 확인해 주세요"로 안내함

```
인증 상태와 재현 순서: signedIn. 프로필 수정 저장 (테스트에서 서버 500을 재현)
요청 종류: 보호(PATCH /members/me)
status / code: 500 / COMMON500
예상 AuthStatus: signedIn 유지, 서버 오류 안내
실제 AuthStatus·화면: signedIn 유지, 문구가 "네트워크 상태를 확인하고 다시 시도해 주세요."였다.
원인: 400·404·409·401 외의 모든 실패를 하나의 문구로 묶었다. 응답이 있었는지(서버 문제)와 없었는지(통신 문제)를 구분하지 않았다.
수정: 응답이 없을 때만 네트워크 문구, 응답이 있었다면 "요청에 실패했어요. 잠시 후 다시 시도해 주세요."
재시작·로그아웃·회원 전환 재검증: 위젯·ViewModel 테스트, 변이 M14. (실서버에서는 500을 만들지 않았다.)
```

### ⚡ No.4 로그 가림(redaction)을 지워도 테스트가 통과함

```
작업: 로그에 토큰·비밀번호가 남지 않는다는 것을 테스트가 지켜 주는지 확인하려고 가림 코드를 일부러 지웠다(M9)
기대한 상태: 테스트가 실패한다
실제 상태: 처음에는 모든 테스트가 통과했다.
원인: 기존 로그 테스트는 JWT처럼 생긴 값만 썼고, 그 모양은 다른 가림 규칙(maskJwtLike)이 따로 막아 주었다.
      요청 body는 로그에 남지 않아 비밀번호 검사도 공허했다. 그래서 accessToken·password·token·authorization
      "키 이름 기반" 가림은 어떤 테스트에도 물려 있지 않았다.
수정: JWT 모양이 아닌 값, 대소문자가 섞인 키, 중첩 List/Map을 쓰는 테스트 2개를 추가했다.
재검증: 가림을 다시 지워 보니 이번에는 테스트가 실패했다.
```

### ⚡ No.5 프로필 수정에서 통신 실패 Snackbar가 [저장] 버튼을 가림

```
인증 상태와 재현 순서: signedIn. 프로필 수정에서 저장 → 통신 실패(프록시가 연결을 끊음)
요청 종류: 보호(PATCH /members/me)
status / code: 응답 없음
예상 AuthStatus: signedIn 유지, 입력 유지, 바로 다시 저장할 수 있음
실제 AuthStatus·화면: signedIn·입력은 유지됐지만, Snackbar가 화면 맨 아래에 붙어 [저장] 버튼의 아래쪽 절반을
      약 4초 가렸다(images/21_profile_network_failure_snackbar_covers_save_button.jpg).
원인: 기본(fixed) Snackbar는 화면 맨 아래에 붙고, [저장] 버튼도 본문 맨 아래에 있다. 테스트가 "Snackbar가 보인다"까지만
      보고 위치를 보지 않아서 위젯 테스트도 이 문제를 놓쳤다(오히려 그 테스트는 Snackbar가 사라질 때까지 5초를 기다리는
      방식으로 문제를 피하고 있었다).
수정: 실패 Snackbar를 floating으로 하고 아래쪽 margin(96 = 본문 padding 24 + 버튼 52 + 간격 20)을 줘서 버튼 위에 뜨게 했다.
재시작·로그아웃·회원 전환 재검증: 위젯 테스트가 Snackbar 영역의 bottom ≤ 저장 버튼의 top을 확인하고, 기다리지 않고 바로
      다시 저장한다. floating 설정을 지우면 이 테스트가 실패한다(Snackbar 776~844 vs 버튼 768~820).
      **실제 화면(브라우저)에서는 수정 뒤를 다시 찍지 못했다.**
```

> 검증 도구(하네스) 쪽에서 만난 것은 앱 문제가 아니라서 위 목록에 넣지 않았다. 프록시로 끊은 `POST /auth/login`을 Chrome이 한 번 다시 보내 첫 시도에서는 통신 실패 대신 AUTH401_1 문구가 나왔다(끊는 횟수를 늘려 해결). 브라우저 창이 숨겨져 있으면 Flutter가 첫 그리기를 하지 않아 스크린샷을 찍어야 화면이 진행됐고, 그래서 첫 시도에서는 무효 토큰 Snackbar를 놓쳤다(연속 촬영으로 재확인). 이 때문에 시작 화면의 시간 값은 믿을 수 없고 **화면 이동의 순서만** 근거로 썼다.

### 관찰했지만 고치지 않은 것

- 로그인에 실패한 뒤 입력을 고쳐도 다음 제출 전까지 실패 문구가 남아 있다.
- 새로고침하면 어떤 보호 화면에 있었든 복원 뒤에는 홈으로 간다.
- 평점의 403·409는 Snackbar가 아니라 **평점 다이얼로그 안의 문구**로 보인다. 워크북은 Snackbar라고 했지만, 다이얼로그가 열린 채 입력을 유지하므로 그 자리에 보여 주는 쪽이 낫다고 판단했다.
- 닉네임을 바꾸지 않고 저장해도 "프로필을 수정했어요." Snackbar가 뜬다(요청은 나가지 않는다).
- 웹의 secure storage는 암호문과 암호화 키로 보이는 값이 같은 localStorage에 있다(위 "확인하지 못한 것").

## 8주차 회고

이번 주에 가장 크게 배운 것은 **"토큰이 있다"와 "로그인되어 있다"가 다르다**는 점이다. 저장소에 토큰 문자열이 있다는 이유로 `signedIn`을 확정하면 만료된 토큰으로 보호 화면에 들어갔다가 뒤늦게 401을 받는다. 그래서 `GET /members/me`가 성공해야 로그인 상태가 되고, 서버가 안 닿는 것은 "만료"가 아니라 "확인하지 못함"(`retryRequired`)이라 토큰을 지우지 않는다. 이 두 갈래를 실서버에서 서버를 끄고, JWT 키를 바꾸고, 만료 시간을 20초로 줄여 가며 직접 만들어 본 뒤에야 "통신 실패"와 "401"이 서로 다른 일이라는 것이 와닿았다.

테스트에 대해서도 두 번 배웠다. 첫째, **통과하는 테스트가 곧 지켜 주는 테스트는 아니다.** 로그 가림을 지워도 통과하던 테스트(No.4)와, Snackbar가 버튼을 가리는데도 "Snackbar가 보인다"만 확인하던 테스트(No.5)가 그랬다. 가드를 일부러 망가뜨려 보는 방식이 이 구멍을 드러냈다. 둘째, 테스트로 찾은 문제(가입 뒤 이메일 미채움, 저장 뒤 화면이 안 닫힘)를 실제 화면에서도 다시 확인한 것이 서로를 보완했다. 반대로 실서버에서만 보인 문제(Snackbar가 저장 버튼을 가림)는 테스트로는 위치를 재야 잡혔다.

아쉬운 점은 **기기의 보안 저장소를 확인하지 못한 것**이다. 웹 구현은 Keychain/Keystore가 아니고 암호문과 키가 같은 저장소에 있어서, "토큰이 안전하게 저장된다"는 말을 웹에서의 확인으로는 할 수 없다. 영상이 없고, 동시에 여러 401이 오는 상황을 실서버에서 못 만든 것도 남은 숙제다. 또 서버에 "내 평점 조회"가 없어서 재시작하면 평점 목록이 비는 한계는 프론트만으로 풀 수 없고, 다음 주차에 서버 계약이 바뀌는지 확인하고 싶다.
