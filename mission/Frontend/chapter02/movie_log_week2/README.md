# MovieLog Week 2

UMC 11기 PE 2주차 회원가입 Form 미션 프로젝트입니다.

## Run

```bash
flutter pub get
flutter test
flutter run
```

## Architecture

- `lib/app`: 앱 진입 화면과 전역 테마 조립
- `lib/core`: 공용 색상·테마 토큰
- `lib/features/sign_up`: 회원가입 입력, 검증, 약관, 제출 상태
- `lib/features/rating`: 별점 입력 미니 실습

API 연결은 미션 범위 밖이므로 로컬 상태만 사용합니다. API가 추가되면 해당 feature 아래에 data·domain 계층을 확장합니다.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
