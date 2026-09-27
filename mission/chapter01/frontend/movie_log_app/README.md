# Movie Log App

UMC 1주차 프론트엔드 제출용 Flutter 프로젝트입니다. 영화 기록 서비스의 프로필 화면을 구현했습니다.

## 폴더 구조

```text
lib/
├── main.dart                              # 앱 실행 진입점
├── app/
│   └── movie_log_app.dart                 # MaterialApp·전역 테마 설정
├── core/
│   └── theme/app_colors.dart              # 여러 기능에서 재사용할 색상 토큰
└── features/
    └── profile/
        └── presentation/
            ├── profile_screen.dart        # 프로필 화면 조합
            └── widgets/                   # 프로필 전용 UI 조각
```

화면이 하나뿐인 현재 단계에서는 네트워크·저장소·상태 관리 계층을 만들지 않았다. 프로필 수정이나 서버 연동이 생길 때만 `data`, `domain`, `application` 계층을 해당 `features/profile` 아래에 추가한다. 이렇게 하면 초기 과제에 불필요한 추상화를 피하면서도 기능이 늘어날 때 독립적으로 확장할 수 있다.

## 실행

```bash
cd mission/chapter01/frontend/movie_log_app
flutter pub get
flutter test
```

플랫폼 폴더가 필요한 환경에서는 아래 명령으로 iOS·Android 실행 대상을 생성한 뒤 실행합니다.

```bash
flutter create --platforms=ios,android .
flutter run
```

`lib/app/movie_log_app.dart`의 `fontFamily`는 `Manrope`를 지정합니다. 실제 기기에서 해당 글꼴을 적용하려면 폰트 파일을 `assets/fonts`에 추가하고 `pubspec.yaml`에 등록해야 합니다.

## 구현 범위

- 프로필 이미지, 닉네임, 소개 문구
- 본 영화·평점·즐겨찾기 통계 카드
- 선호 장르 칩
- 프로필 수정 버튼 UI

현재 프로필 수정 버튼은 화면 구현 범위에 맞춰 동작을 연결하지 않았습니다.
