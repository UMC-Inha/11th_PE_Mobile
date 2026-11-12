# 7주차 프론트엔드 미션 — 회원가입과 평점 CRUD 확장하기

- 이름 / 닉네임: 케빈
- [GitHub 실습 저장소](https://github.com/brownglasses/11th_PE_Mobile_Flutter_Practice_Mission/tree/brownglasses/week07)
- Pull Request: [Pull Request #17](https://github.com/UMC-Inha/11th_PE_Mobile_Flutter_Practice_Mission/pull/17)
- [원본 워크북](https://makeus-challenge.notion.site/7-CRUD-1-416b57f4596b808583c5e859f0b964c9)
- [핵심 개념 정리](../../../keyword/Frontend/chapter07/keyword.md)
- 같은 주 백엔드 미션: [백엔드 7주차](../../Backend/chapter07/mission.md)

## 먼저 알아 둘 것: 이 주차의 서버 계약

프론트 워크북은 **6주차 계약**(경로에 `memberId`, 평점 삭제 204)을 전제로 한다. 같은 주 백엔드 워크북은 토큰(JWT)을 도입하며 그 경로를 없애지만(`POST /ratings`, 삭제 200), 프론트 워크북 본문에도 "다음 JWT 주차에는 회원 식별을 토큰으로 전환한다"고 되어 있어 프론트의 토큰 전환은 **다음 주차**다. 그래서:

- 프론트는 워크북대로 6주차 계약으로 만들고, 검증도 **6주차 시점의 백엔드**(`brownglasses/week06`)를 띄워서 했다. 7주차 백엔드에는 `/members/{memberId}/ratings` 쓰기 경로가 더 이상 없어(404) 그대로는 연결되지 않는다.
- 워크북 API는 `https://…/v6/…`지만 우리는 5주차부터 자체 NestJS 서버를 쓰고 있어 경로에 `/v6`가 없다(`/members`, `/members/{id}/ratings`). 이름도 워크북의 `SignUpService`·`RatingApiService` 대신 기존 `MovieLogApiService` 하나를 유지했다(6주차와 같은 선택).
- 서버가 내려 주는 실패 `code`는 주차마다 다듬어진다(워크북은 `COMMON403`·`COMMON404`, 우리 서버는 `RATING4031`, 7주차 서버는 `RATING403_1`). 그래서 재조회 여부는 code 문자열이 아니라 **HTTP 상태(403·404)** 로 판단하고, 문구는 서버 `message`를 그대로 보여준다.

## 구현 결과

6주차 위에 회원가입 POST, 평점 등록(영화 상세), 평점 수정·삭제(마이페이지)를 더했다.

| 계층 | 파일 | 7주차 변경 |
| --- | --- | --- |
| Model | `data/models/common_response.dart` | 공통 응답 틀 `CommonResponse<T>` (새 파일) |
| Model | `data/models/create_member_request.dart`, `sign_up_models.dart` | 가입 요청(`toJson`) / 가입 결과 `SignUpResult`(`fromJson`) (새 파일) |
| Model | `data/models/movielog_dtos.dart` | `CreateRatingRequest`(빈 코멘트 생략), `UpdateRatingRequest`(코멘트 항상 명시), `validateServerScore` |
| Service | `data/services/movielog_api_service.dart` | `signUp`, `createRating`(201), `updateRating`, `deleteRating`(204, 본문 파싱 안 함), `parseErrorResponse`, `shouldRefreshAfterRatingError` |
| ViewModel | `view_models/learning_member_session.dart` | 가입 결과 `memberId` 보관(메모리, 인증 아님) (새 파일) |
| ViewModel | `view_models/submit_status.dart`, `write_error_message.dart` | `SubmitStatus`, `RatingSaveException`, 서버 message 기반 문구 (새 파일) |
| ViewModel | `view_models/sign_up_view_model.dart` | `submit`: 400(비밀번호) → `passwordErrorText`, 그 밖의 400·409 → Snackbar, 409면 사용 가능 확인 해제 |
| ViewModel | `view_models/movie_detail_view_model.dart` | `createRating`, 가입 전 안내 |
| ViewModel | `view_models/my_ratings_view_model.dart` | `updateRating`·`deleteRating`, 저장 성공/재조회 실패 분리(`refreshWarning`), 편집 모드·다중 선택 삭제 |
| View | `features/rating/.../movie_rating_dialog.dart` | 등록·수정 공용 Dialog(코멘트, 로딩, 이탈 방지, 실패 시 입력 유지) |
| View | `features/my_page/.../my_ratings_screen.dart`, `widgets/delete_rating_dialogs.dart` | 카드별 수정·삭제 버튼, 삭제 확인 Dialog, "편집" 모드, 선택한 N개 삭제 |
| View | `features/sign_up/.../sign_up_screen.dart` | 제출 연동, 로딩 버튼, 제출 중 이탈 방지, 서버 비밀번호 오류 |
| View | `features/movies/.../movie_detail_screen.dart` | 평점 등록 연동, 가입 전 비활성화 |
| 공용 Widget | `widgets/loading_overlay.dart` | `ModalBarrier` + 흰 인디케이터 오버레이 (새 파일) |
| 앱 | `app/movie_log_app.dart`, `app/app_router.dart` | `LearningMemberSession` Provider, `/my/ratings`가 세션의 memberId를 읽음 |

영화 상세는 5주차에 이미 Route의 TMDB `movieId`로 조회하고 목록에서 넘긴 DTO(`extra`)가 있으면 재사용하는 구조(`MovieDetailViewModel.loadIfNeeded`)라서, 워크북의 `MovieDetailLoader`/`FutureBuilder`를 새로 만들지 않고 그 구조에 이어 붙였다.

## 화면 (실제 NestJS에 연결한 Flutter Web, Chrome 390x844)

### 무엇이 진짜이고 무엇이 대역인가

| 구성 | 정체 |
| --- | --- |
| Flutter 앱 | **진짜.** 저장소의 `lib/` 그대로 `flutter build web`. 한글 글꼴(Pretendard)·TMDB 주소·가짜 토큰은 **임시 복사본**에만 넣었고 저장소 코드에는 없다. |
| 백엔드 | **진짜.** `brownglasses/week06` 커밋을 그대로 실행(6주차 계약). 7주차 백엔드는 쓰지 않았다. |
| DB | **진짜 MySQL, 일회용 DB.** 끝나고 삭제했다. 개발 DB `umc_movie`는 읽기만 했고 전후 모두 회원 2·평점 3이다. |
| TMDB | **대역.** 이 맥에는 TMDB Token이 없어 로컬 가짜 서버가 4개 API(`popular`, `discover`, `genre`, `movie/{id}`)만 흉내 냈다. 영화 id·제목·포스터 경로는 실제 TMDB 값이고, 줄거리·평점은 직접 정한 값이다. 포스터 이미지는 실제 TMDB 이미지 서버에서 불러왔다. |
| 프록시 | 앱 → **실패 주입 프록시** → 백엔드. 요청을 그대로 통과시키되 "조회만 실패", "쓰기 지연", "특정 삭제만 실패"를 만들고 요청 기록을 남긴다. |

아래 화면의 **지연·실패(3.5초 가입 지연, 재조회 503, 삭제 500)는 프록시가 일부러 만든 것**이다. 서버가 꺼졌을 때처럼 실제로 만들기 어려운 상황을 재현하는 용도다. 요청 기록 전체: [network-write-flow.txt](network-write-flow.txt). 비밀번호는 기록에서 `***`로 가렸고 화면에서는 입력칸이 점으로만 보인다.

### 회원가입

| 닉네임·이메일 "사용 가능" | 닉네임을 고치면 이전 결과 사라짐 | 서버 400 → 비밀번호 칸 에러(Snackbar 없음) |
| --- | --- | --- |
| ![01a_signup_both_available.jpg](images/01a_signup_both_available.jpg) | ![01b_signup_edit_invalidates_nickname.jpg](images/01b_signup_edit_invalidates_nickname.jpg) | ![02a_server_400_password_errortext.jpg](images/02a_server_400_password_errortext.jpg) |

| 비밀번호를 고치면 서버 오류 사라짐 | 최종 409 Snackbar + 확인 해제 | 다시 확인 → 이미 가입된 이메일 |
| --- | --- | --- |
| ![02b_password_edit_clears_error.jpg](images/02b_password_edit_clears_error.jpg) | ![03a_final_409_snackbar_and_checks_reset.jpg](images/03a_final_409_snackbar_and_checks_reset.jpg) | ![03b_final_409_then_recheck_email_duplicated.jpg](images/03b_final_409_then_recheck_email_duplicated.jpg) |

| 가입 요청 중(버튼 인디케이터만) | 가입 성공 → 영화 목록 | |
| --- | --- | --- |
| ![04a_signup_in_flight_spinner_only.jpg](images/04a_signup_in_flight_spinner_only.jpg) | ![04b_signup_success_lands_on_movies.jpg](images/04b_signup_success_lands_on_movies.jpg) | |

- `02a`의 비밀번호는 로컬 규칙(대·소문자·숫자·특수문자 포함 8자 이상)은 통과하지만 서버의 72자 상한을 넘는 값이다(72자를 넘는 값). 서버 400이 Snackbar가 아니라 **입력칸 아래**에 붙는다.
- `03a`의 "확인 직후 누군가 먼저 가입"은 사용 가능 확인 뒤에 **터미널의 curl로** 같은 이메일을 먼저 가입시켜 만들었다. 이때 사용 가능 표시가 풀리고 가입 버튼이 꺼진다.

### 평점 등록·조회

| 상세: TMDB 영화 ID 550 | Dialog: 코멘트 칸, 별 선택 전 저장 비활성 | 4점 + 코멘트 → 저장 활성 |
| --- | --- | --- |
| ![05a_detail_tmdb_id_550.jpg](images/05a_detail_tmdb_id_550.jpg) | ![05b_dialog_comment_field_save_disabled.jpg](images/05b_dialog_comment_field_save_disabled.jpg) | ![05c_dialog_4stars_comment_save_enabled.jpg](images/05c_dialog_4stars_comment_save_enabled.jpg) |

| 등록 성공 Snackbar | 같은 영화 재등록 409, 입력 유지 | 마이페이지 → 내가 등록한 평점(재조회) |
| --- | --- | --- |
| ![05d_rating_saved_snackbar.jpg](images/05d_rating_saved_snackbar.jpg) | ![06_duplicate_409_input_kept.jpg](images/06_duplicate_409_input_kept.jpg) | ![07_my_ratings_list_with_edit_delete.jpg](images/07_my_ratings_list_with_edit_delete.jpg) |

### 수정 · 저장 성공 후 재조회 실패

| 수정 Dialog: 기존 값 채움 | 수정 저장 → 목록 재조회 | 저장 성공 + 재조회 실패(수정 전 빌드) |
| --- | --- | --- |
| ![08a_edit_dialog_prefilled.jpg](images/08a_edit_dialog_prefilled.jpg) | ![08b_edit_saved_list_refreshed.jpg](images/08b_edit_saved_list_refreshed.jpg) | ![09a_save_ok_but_get_failed_retry_get_only.jpg](images/09a_save_ok_but_get_failed_retry_get_only.jpg) |

| 다시 시도 → GET만 나가 복구 | 같은 상황, 버그 B 수정 후 | 가입 전 새 세션의 평점 화면 |
| --- | --- | --- |
| ![09b_retry_get_only_list_restored.jpg](images/09b_retry_get_only_list_restored.jpg) | ![09c_after_fix_error_state_average_is_dash.jpg](images/09c_after_fix_error_state_average_is_dash.jpg) | ![12_my_ratings_before_signup_requires_signup.jpg](images/12_my_ratings_before_signup_requires_signup.jpg) |

- `09a`는 수정 전 빌드라 "남긴 평점"은 `-`인데 "평균 점수"가 낡은 값으로 남아 있다(트러블슈팅 No.2). `09c`가 수정 후다.

### 삭제

| 삭제 확인 Dialog | 삭제 성공 → 목록 갱신 | 마지막 항목 삭제 → Empty |
| --- | --- | --- |
| ![10a_delete_confirm_dialog.jpg](images/10a_delete_confirm_dialog.jpg) | ![10b_delete_confirmed_item_removed.jpg](images/10b_delete_confirmed_item_removed.jpg) | ![10c_delete_last_empty_screen.jpg](images/10c_delete_last_empty_screen.jpg) |

### Challenge — 편집 · 다중 선택 삭제

| 편집 모드, 선택 0개(삭제 비활성) | 3개 선택 → 삭제 활성 | 삭제 중 오버레이(수정 전 빌드) |
| --- | --- | --- |
| ![11a_edit_mode_checkboxes_delete_disabled.jpg](images/11a_edit_mode_checkboxes_delete_disabled.jpg) | ![11b_three_selected_delete_enabled.jpg](images/11b_three_selected_delete_enabled.jpg) | ![11c_multi_delete_overlay_spinner.jpg](images/11c_multi_delete_overlay_spinner.jpg) |

| 삭제 후 기본 목록 | 버그 A(수정 전): 삭제 중 두 번째 확인 Dialog | 버그 A 수정 후: 하단 바 비활성 |
| --- | --- | --- |
| ![11d_multi_delete_done_normal_list.jpg](images/11d_multi_delete_done_normal_list.jpg) | ![11e_bug_second_confirm_opens_while_deleting.jpg](images/11e_bug_second_confirm_opens_while_deleting.jpg) | ![11h_after_fix_bottom_bar_disabled_while_deleting.jpg](images/11h_after_fix_bottom_bar_disabled_while_deleting.jpg) |

| 일부 실패 Snackbar, 선택 유지 | 취소 → 기본 목록 | |
| --- | --- | --- |
| ![11f_partial_failure_snackbar_selection_kept.jpg](images/11f_partial_failure_snackbar_selection_kept.jpg) | ![11g_cancel_returns_to_normal_list.jpg](images/11g_cancel_returns_to_normal_list.jpg) | |

- `11c`와 `11e`는 하단 "선택한 N개 삭제" 바가 삭제 중에도 활성처럼 보이는 **수정 전** 화면이다(트러블슈팅 No.1). `11h`가 수정 후이며 바가 회색으로 비활성이다.
- `11f`는 평점 하나(5번)만 서버가 500으로 거부하도록 프록시가 만든 일부 실패 상황이다. 성공한 두 개는 사라지고 실패한 하나는 체크가 유지된다.


## 제출 양식

워크북 "제출 양식" 순서 그대로 적었다.

| 항목 | 내용 |
| --- | --- |
| PR 링크 | [Pull Request #17](https://github.com/UMC-Inha/11th_PE_Mobile_Flutter_Practice_Mission/pull/17) |
| 생성한 본인 테스트 계정(비밀번호 제외) | 일회용 DB에 가입한 학습용 회원 **#5** `케빈7` / `kevin7c@umc.com`(평점 시연), **#6** `케빈8` / `kevin8@umc.com`(수정 후 재확인). #3·#4(`선점자7`, `선점자7b`)는 "확인 직후 먼저 가입한 사람"을 만들려고 터미널 curl로 가입시킨 계정이다. 비밀번호는 일회용 값이고 어디에도 기록하지 않았다. DB는 검증 후 삭제했다. |
| 닉네임/이메일 확인과 입력 변경 무효화 | 화면 [01a](images/01a_signup_both_available.jpg) → 닉네임을 한 글자 고치자 이전 확인(체크·문구)이 사라짐 [01b](images/01b_signup_edit_invalidates_nickname.jpg). 위젯·단위 테스트(`sign_up_view_model_test.dart`, `sign_up_duplicate_check_test.dart`)로도 고정 |
| 회원가입 결과와 최종 409 | 성공 → 영화 목록 [04b](images/04b_signup_success_lands_on_movies.jpg)(`POST /members` 201, 응답의 `memberId` 5를 세션에 보관해 이후 요청이 `/members/5/ratings`로 나감). 최종 409 [03a](images/03a_final_409_snackbar_and_checks_reset.jpg): `POST /members` 409, Snackbar "이미 사용 중인 이메일입니다.", 사용 가능 표시 해제, 가입 버튼 꺼짐 → 다시 확인하면 [03b](images/03b_final_409_then_recheck_email_duplicated.jpg) "이미 가입된 이메일이에요." |
| 선택한 TMDB id → MovieLog movieId 증거 | 상세 화면 `TMDB 영화 ID 550` [05a](images/05a_detail_tmdb_id_550.jpg) → 요청 `POST /members/5/ratings` body `{"movieId":550,"score":4,"comment":"반전이 좋았다"}` → 201. `movieId`가 영화 배열 index가 아니라 TMDB id이고, body에 `memberId`가 없다(회원은 경로에 있다). [요청 기록](network-write-flow.txt) 5번 |
| 등록→조회→수정→조회→삭제→조회 증거 | 등록 201 [05d](images/05d_rating_saved_snackbar.jpg) → 조회 200 [07](images/07_my_ratings_list_with_edit_delete.jpg) → 수정 `PATCH …/4` 200 + 조회 200 [08a](images/08a_edit_dialog_prefilled.jpg)·[08b](images/08b_edit_saved_list_refreshed.jpg) → 삭제 확인 [10a](images/10a_delete_confirm_dialog.jpg)(취소 때는 `DELETE` 요청 0건) → `DELETE` 204 + 조회 200 [10b](images/10b_delete_confirmed_item_removed.jpg) → 마지막 항목 삭제 후 Empty [10c](images/10c_delete_last_empty_screen.jpg). 끝 상태는 화면 Empty = `GET /members/5/ratings` → `[]` = DB의 해당 회원 평점 0건으로 대조했다. |
| 오류 code 처리 증거 | **400**(비밀번호): [02a](images/02a_server_400_password_errortext.jpg) 입력칸 에러, Snackbar 없음. **409**(최종 중복): [03a](images/03a_final_409_snackbar_and_checks_reset.jpg) Snackbar. **409**(같은 영화 재등록): [06](images/06_duplicate_409_input_kept.jpg) Dialog 안에 서버 문구, 별점·코멘트 유지, 저장 버튼 복구. **403·404**는 화면에서 만들 수 없어(내 평점만 보이므로) `rating_write_view_model_test.dart`로 확인했다: 서버 문구를 그대로 던지고 목록을 다시 조회한다. 400·409는 다시 조회하지 않는다. |
| 저장 성공/재조회 실패 분리 증거 | 요청 기록 9번: `PATCH …/6` **200** → `GET` **503**(프록시가 주입) → (다시 시도) `GET` 200. **PATCH는 정확히 1번**이다. 화면 [09a](images/09a_save_ok_but_get_failed_retry_get_only.jpg): Dialog는 성공으로 닫히고 "평점을 수정했어요." Snackbar, 목록 영역에 "저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요." + 다시 시도 → [09b](images/09b_retry_get_only_list_restored.jpg) 목록 복구 |
| 트러블슈팅 | 아래 "트러블슈팅" (No.1~No.6) |
| 미검증 항목 | 아래 표 |

**수동 검증 결과 요약** — 프록시 요청 기록 기준 상태 코드

| 흐름 | 요청 | 상태 |
| --- | --- | --- |
| 중복 확인 | `GET /members/nickname/…`, `/email/…` | 200 (같은 URL을 다시 확인하면 브라우저 캐시 재검증으로 304) |
| 서버가 비밀번호 거부 | `POST /members` | **400** |
| 최종 중복 | `POST /members` | **409** |
| 가입 성공 | `POST /members` | **201** |
| 평점 등록 / 같은 영화 재등록 | `POST /members/5/ratings` | **201** / **409** |
| 수정 | `PATCH /members/5/ratings/{id}` → `GET` | **200** → 200 |
| 저장 성공 + 재조회 실패 | `PATCH` → `GET` → `GET` | 200 → **503(주입)** → 200 |
| 삭제 | `DELETE /members/5/ratings/{id}` → `GET` | **204** → 200 |
| 다중 삭제 3건 | `DELETE` ×3(순차) → `GET` **1번** | 204, 204, 204 → 200 |
| 다중 삭제 일부 실패 | `DELETE` ×3 → `GET` | 204, **500(주입)**, 204 → 200 |

**미검증 항목**

| 항목 | 이유 |
| --- | --- |
| iOS/Android 실기기·시뮬레이터 | 하지 않았다. Chrome(Flutter Web, 390x844)에서만 확인했다. |
| 실제 TMDB 응답 | Token이 없어 로컬 가짜 서버로 대체했다. 실제 TMDB의 제목·줄거리가 평점 카드에 붙는 화면은 확인하지 못했다. |
| **영상** | 워크북 스터디 인증의 영상(등록→재조회, 수정→재조회, 저장 성공/재조회 실패의 GET 재시도)은 **정지 화면 캡처와 요청 기록으로만** 남겼다. 영상 파일은 없다. |
| 가입 제출 중 시스템 뒤로가기 차단 | 웹에서는 브라우저 뒤로가기로 정확히 재현되지 않아 실제 브라우저로는 보지 못했다. 위젯 테스트(`sign_up_submit_test.dart`)가 `PopScope.canPop`과 Router의 뒤로가기 처리 결과를 확인한다. 브라우저에서는 요청 중 버튼이 로딩·비활성인 것([04a](images/04a_signup_in_flight_spinner_only.jpg))까지 봤다. |
| 7주차 백엔드(JWT)와의 연동 | 하지 않았다. 이 프론트는 6주차 계약(`memberId` 경로)이라 7주차 백엔드와는 붙지 않는다. JWT 전환은 다음 주차 몫이다. |
| 로그에 비밀번호가 남지 않음 | 라이브 웹 빌드는 `kDebugMode`가 꺼져 Dio 로그가 꺼져 있었다. 단위 테스트(`write_api_test.dart`)로만 확인했다. |
| 스크린샷 속 로딩 인디케이터 모양 | 이 환경에서는 회전 애니메이션이 실제보다 작게 찍힌다(점·짧은 호). 라벨 교체·비활성·오버레이 같은 동작은 정확하다. |


## Guided Practice

### A. 회원가입

- [x] `CommonResponse<T>`와 `SignUpResult` 작성 (`write_api_test.dart`)
- [x] `MovieLogApiService.signUp` (6주차 `checkNickname`·`checkEmail`은 그대로 두고 메서드만 추가)
- [x] `SignUpViewModel`에 `submitStatus(idle/submitting/success/error)`
- [x] 비밀번호 형식 위반으로 확인된 400은 `passwordErrorText`로, 다른 400과 409는 `snackbarMessage`로 나눠 담기
- [x] 제출 버튼 콜백에서 성공하면 `/movies`로 이동, 실패하면 Snackbar
- [x] 닉네임·이메일 입력을 바꾸면 이전 중복 확인 결과와 서버 오류를 함께 무효화
- [x] 로컬 Form validator와 서버 400 응답이 동시에 작동하도록 `errorText` 연결

### B. 영화 상세에서 평점 등록

- [x] 5주차 목록에서 선택한 `TmdbMovieDto`를 GoRouter `extra`로 전달(이미 있던 구조)
- [x] `RatingDialog`(`MovieRatingDialog`)로 별점과 코멘트 입력
- [x] `MovieDetailViewModel.createRating`으로 등록 요청
- [x] 성공/실패에 따라 Snackbar·Dialog 문구가 다르다(성공: Snackbar, 실패: Dialog 안에 서버 문구)
- [x] 저장 중에는 확인 버튼을 다시 누르지 못한다

## Required Mission

- [x] 닉네임·이메일 중복 확인이 모두 통과해야 가입하기 버튼이 활성화된다
- [x] 회원가입 성공 시 `result.memberId`를 확인할 수 있다(세션에 보관)
- [x] 400 중 비밀번호 형식 오류는 비밀번호 입력칸의 `errorText`로, 그 외 400과 409는 Snackbar로 구분한다
- [x] 제출 중에는 중복 탭을 막는다
- [x] 평점 수정: 카드의 수정 버튼 → 기존 값이 채워진 Dialog → 성공 후 목록 재조회, 요청 중에는 Dialog를 닫거나 화면을 벗어날 수 없다
- [x] 평점 삭제: 확인 Dialog(취소하면 요청 없음), DELETE 204는 본문을 파싱하지 않는다, 성공 후 재조회, 마지막 항목을 지우면 Empty
- [x] 예외 흐름: 400/403/404/409를 구별하고, 연속 탭을 막고, 실패 시 입력을 보존하고, 화면 이탈 뒤 이전 요청 결과를 반영하지 않는다

## Challenge Mission

- [x] 회원가입 제출 중에는 화면을 벗어날 수 없다(`PopScope`), 성공하거나 실패해서 제출이 끝나면 다시 나갈 수 있다
- [x] 내가 등록한 평점: 상단 "편집" → 카드마다 체크박스, "취소"로 선택 해제, 선택이 1개 이상일 때만 "선택한 N개 삭제" 활성화
- [x] 확인하면 선택한 ratingId마다 삭제 API를 호출하고, 요청 중에는 로딩 오버레이와 이탈 방지를 유지한다
- [x] 다중 삭제의 확인 Dialog는 바로 닫히고(단건 삭제는 요청 중 Dialog 유지)
- [x] 일부만 실패하면 성공한 항목만 목록에서 사라지고, 실패 개수를 Snackbar로 알린다(실패한 항목은 선택 유지)

## 최종 체크리스트

- [x] 닉네임·이메일 확인 상태가 입력 변경 후 무효화된다
- [x] 확인 true/false와 통신 실패, 최종 가입 409를 구분한다
- [x] 요청 Model과 응답 Model을 구분했다(`toJson` / `fromJson`)
- [x] 정수 score 1~5만 전송한다(`allowHalfRating: false` + `validateServerScore`)
- [x] `movieId`는 5주차 `TmdbMovieDto.id`이며 영화 배열 index나 임의 번호가 아니다
- [x] `movieId`와 `ratingId`를 구분한다
- [x] TMDB 제목·포스터와 MovieLog 평점 응답을 `movieId`로 연결한다(6주차 `RatingWithMovie`)
- [x] 직접 배열 / 공통 응답 틀 / 204를 각각 처리한다
- [x] 저장 실패와 재조회 실패를 구분한다(`refreshWarning`)
- [x] 비밀번호와 타인 데이터를 기록하지 않았다(`CreateMemberRequest.toString`, 로그 Interceptor, 캡처에서 비밀번호 가림)
- [x] 등록·수정·삭제 뒤 서버 목록을 확인했다
- [x] `flutter analyze`와 Guided/Required 수동 검증 항목을 확인했다

## 진행 과정과 검증

1. 두 워크북을 읽고 5·6주차 코드와 비교했다. 6주차에 이미 `MovieLogButton`(`isLoading`)과 `SignUpViewModel`의 `CheckStatus`, `MyRatingsViewModel`이 있어서 새 파일을 늘리기보다 **그 위에 이어 붙이는** 쪽으로 정했다.
2. 데이터 계층부터 만들고(`CommonResponse`, 요청·응답 Model, 쓰기 API 4개) 요청 모양과 상태 코드 처리(201/204)를 가짜 HTTP 어댑터 테스트로 고정했다.
3. `SignUpViewModel.submit`과 화면을 연결했다. 가입 직후 같은 값이 쓰이는 경우(최종 409)가 있어서, 409를 받으면 "사용 가능"으로 확인했던 결과를 풀어 다시 확인하게 했다.
4. 평점 Dialog를 먼저 만들고(코멘트 입력, 로딩, 이탈 방지, 실패 시 입력 유지), 영화 상세(등록)와 마이페이지(수정)가 같은 Dialog를 쓰게 했다.
5. `MyRatingsViewModel`에 수정·삭제를 더하면서 **저장 성공과 재조회 실패를 다른 상태**로 나눴다. 이어서 Challenge(편집 모드, 다중 삭제, 로딩 오버레이)를 붙였다.
6. 테스트: `flutter test` 193개 통과(실제 TMDB를 쓰는 3개는 Token이 없어 건너뜀, [결과](flutter-test.txt)), 6주차 100개에서 늘었다. `flutter analyze` No issues found.
7. 핵심 방어 코드를 일부러 망가뜨려 테스트가 실제로 실패하는지 확인했다(원본 Set을 그대로 순회, 403·404 재조회 제거, 저장 실패 뒤에도 로딩 유지, 제출 중 `PopScope` 해제, 바깥 탭 허용, 쓰기 직후 로딩 화면 표시, 409 뒤 확인 해제 제거, PATCH에서 comment 제거, 비밀번호 로컬 규칙 완화). 아홉 가지 모두 테스트가 잡았고 이후 원복했다.
8. 실제 서버(6주차 백엔드 + 일회용 DB)로 확인하고 요청 기록과 화면을 남겼다. 이 과정에서 테스트가 놓친 버그 2건을 찾아 고쳤다(트러블슈팅 No.1·No.2). `flutter analyze`는 [No issues found](flutter-analyze.txt).

## 트러블슈팅

### ⚡ No.1 다중 삭제가 도는 중에도 하단 "선택한 N개 삭제" 바가 눌린다 (버그 A)

```
작업: Challenge — 평점 3개 선택 → 선택한 3개 삭제 → 확인 (프록시가 쓰기를 2.5초씩 지연)
기대한 상태: 삭제가 끝날 때까지 화면의 모든 조작이 막힌다
실제 상태 및 응답: 로딩 오버레이가 떠 있는데 하단 "선택한 3개 삭제" 바를 누르면 두 번째 확인 Dialog가 열렸다
      (images/11e_bug_second_confirm_opens_while_deleting.jpg). 확인해도 재진입 가드가 막아 이중 삭제는
      없었지만 아무 안내 없이 끝나 혼란스러웠다. 요청 기록상 DELETE는 선택한 3건뿐이었다.
원인: LoadingOverlay는 본문(body)만 덮는다. 하단 바는 Scaffold.bottomNavigationBar라 오버레이 밖에 있는데,
      바의 onPressed가 "선택이 있는가"만 보고 isDeletingSelected는 보지 않았다.
      PopScope는 화면 이탈만 막으므로 이 버튼과는 상관이 없다. 단위·위젯 테스트는 오버레이·PopScope·편집 토글만 확인했다.
수정: 바의 onPressed를 selectedRatingIds.isEmpty || isDeletingSelected이면 null로.
재검증: 수정 전에 실패하는 위젯 테스트("삭제 중에는 하단 삭제 버튼도 비활성…")를 먼저 쓰고 통과시켰다.
      브라우저에서도 삭제 중 바가 회색 비활성이고 눌러도 Dialog가 열리지 않으며 DELETE는 2건뿐이었다
      (images/11h_after_fix_bottom_bar_disabled_while_deleting.jpg).
```

### ⚡ No.2 조회가 실패했는데 "평균 점수"만 낡은 값으로 남는다 (버그 B)

```
작업: 평점 수정 저장 성공 → 목록 재조회(GET)만 실패(프록시가 503 주입)
기대한 상태: "남긴 평점"과 "평균 점수"가 함께 "-"
실제 상태 및 응답: "남긴 평점"은 -인데 "평균 점수"는 이전 평균 4.0이 그대로 보였다
      (images/09a_save_ok_but_get_failed_retry_get_only.jpg)
원인: _StatsRow가 평점 수는 loaded ? ... : '-'로 가렸지만 평균은 viewModel.averageScore를 상태와 무관하게 읽었다.
      재조회가 실패해도 이전 목록(ratings)은 일부러 지우지 않으므로 평균이 계산돼 남는다.
      6주차부터 있던 불일치지만 7주차의 "저장 성공 + 재조회 실패" 상태에서 눈에 띄게 됐다.
수정: final average = loaded ? viewModel.averageScore : null;
재검증: 수정 전에 실패하는 위젯 테스트를 먼저 쓰고 통과시켰고, 브라우저에서 같은 상황이 둘 다 "-"로 보였다
      (images/09c_after_fix_error_state_average_is_dash.jpg).
```

### ⚡ No.3 시스템 뒤로가기 테스트가 항상 "막히지 않음"으로 나옴

```
작업: 회원가입 제출 중 시스템 뒤로가기가 막히는지 위젯 테스트로 확인
기대한 상태: 제출 중에는 뒤로가기를 화면이 삼킨다(true), 끝나면 나갈 수 있다(false)
실제 상태 및 응답: WidgetsApp.didPopRoute()가 PopScope(canPop: false)인 상태에서도 항상 false
원인: 이 앱은 MaterialApp.router다. 라우터 앱에서는 WidgetsApp.didPopRoute가 곧바로 false를 돌려주고,
      시스템 뒤로가기는 Router의 backButtonDispatcher가 받는다.
수정: Router.of(context).backButtonDispatcher!.invokeCallback(Future.value(false))로 보내
      "막으면 true, 나갈 수 있으면 false"를 확인했다.
재검증: 제출 중 true, 끝난 뒤 false. PopScope(canPop: true)로 바꿔 보면 이 테스트가 실패한다.
```

### ⚡ No.4 평점 Dialog를 저장하는 동안의 테스트가 끝나지 않음

```
작업: 저장 중(로딩) 상태에서 바깥 탭·뒤로가기가 막히는지 확인
실제 상태 및 응답: pumpAndSettle timed out
원인: 저장 중에는 MovieLogButton의 CircularProgressIndicator가 계속 돈다. pumpAndSettle은 더 그릴 프레임이
      없을 때까지 기다리므로 영원히 끝나지 않는다(앱 버그가 아니라 테스트 방법의 문제).
수정: 저장 중 구간은 pump(Duration)으로 시간만 흘려보내고, 요청이 끝난 뒤에만 pumpAndSettle을 쓴다.
```

### ⚡ No.5 한글이 `ë‹¤ì‹œ…`처럼 깨져 DB에 들어감

```
작업: 일회용 DB에 시드 SQL을 넣고 앱에서 조회
실제 상태 및 응답: 한글 닉네임·코멘트가 이중 인코딩된 글자로 저장돼 화면에 깨져 보였다
원인: mysql 명령행 클라이언트가 SQL 파일을 기본 문자셋(latin1)으로 읽어 UTF-8 바이트를 한 번 더 변환했다.
수정: --default-character-set=utf8mb4 로 일회용 DB를 지우고 다시 시드했다.
```

### ⚡ No.6 시드 SQL이 DB 이름 `umc_movie`를 직접 써서 개발 DB에 들어갈 뻔함

```
작업: 일회용 DB(umc_movie_w7fe)에 schema.sql·seed.sql 실행
상황: 두 파일 안에 CREATE DATABASE / USE umc_movie 가 하드코딩돼 있어, 그대로 실행하면 일회용 DB가 아니라
      개발 DB에 시드가 들어간다.
수정: DB 이름을 바꾼 사본을 만들고, 원래 이름이 남아 있지 않은지 grep으로 확인한 뒤에 실행했다.
재검증: 검증 전후 개발 DB의 회원·평점 수가 그대로(2·3)다.
```

> 검증하면서 만난 것 중 스크린샷이 동작보다 1~3초 늦게 그려져 Snackbar·가입 직후 화면을 첫 시도에서 놓치거나 이전 프레임이 찍힌 일이 있었다. 앱 문제가 아니라 캡처 방법의 한계라 동작 뒤 3초 기다리고 다시 찍었다.

## 7주차 회고

이번 주에 가장 크게 배운 것은 **단위·위젯 테스트가 다 통과해도 실제 화면에서 처음 드러나는 버그가 있다**는 점이다. 다중 삭제 중에 하단 바가 눌리는 버그(A)는 오버레이·`PopScope`·편집 토글을 모두 테스트했는데도 숨어 있었다. 오버레이가 덮는 범위와 버튼이 놓인 위치가 다르다는 것은 코드만 읽어서는 놓쳤고, 프록시로 삭제를 느리게 만들고 실제로 눌러 본 뒤에야 보였다. 평균 점수가 낡은 값으로 남는 버그(B)도 "저장 성공 + 재조회 실패"라는 새 상태를 만들고서야 눈에 띄었다.

"저장 성공과 재조회 실패를 다른 상태로 나눈다"는 말은 워크북에서 읽을 때는 당연해 보였는데, 프록시로 GET만 503을 주입해 보니 PATCH가 정확히 한 번만 나가고 사용자에게는 "조회만 다시"를 안내하는 흐름이 어떤 것인지 분명해졌다. 반대로 나누지 않았다면 같은 쓰기를 다시 보내 409가 났을 것이다. 서버의 `code` 문자열은 주차마다 바뀔 수 있어서(워크북의 `COMMON403`과 우리 서버의 `RATING4031`) 문구는 서버 `message`를, 동작은 HTTP 상태를 기준으로 삼은 것도 이번에 정한 원칙이다.

아쉬운 점은 TMDB Token이 없어 로컬 가짜 서버로 대신했고 영상이 없다는 것이다. 또 프론트는 6주차 서버 계약으로 만들었고 같은 주 백엔드는 토큰으로 바뀌어, 두 쪽이 아직 한 번도 이어져 있지 않다. 다음 주차에 로그인(JWT)이 프론트에 붙으면 이번에 `memberId`를 세션에 보관한 부분이 어디까지 그대로 쓰이는지 다시 확인하고 싶다.

