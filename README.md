# Equb

A collaborative rotating savings (Ethiopian Equb) mobile app built with Flutter and Firebase Auth.

## Features

- Phone/email authentication (Firebase Auth)
- Modern home dashboard with quick actions
- Wallet tab with overview + transaction history
- Equb groups:
  - Group list
  - In-group chat (mock realtime)
  - Winner rotation by rounds (Season/round view)
  - Semantics: first round winner = borrower, last round winner = saver
- ID scan screen (UI placeholder)
- Profile screen

## Run locally

1) Install prerequisites
- Flutter (stable)
- Dart (bundled with Flutter)

2) Configure Firebase (required)

- Android: place `google-services.json` in `android/app/` (do not commit it)
- iOS: place `GoogleService-Info.plist` in `ios/Runner/` (do not commit it)

This repo uses a local secrets file to keep Firebase options out of git:

- Copy `lib/config/firebase_secrets.example.dart` → `lib/config/firebase_secrets.dart`
- Fill in values from your Firebase project

3) Install deps and run

```powershell
flutter pub get
flutter run
```

## Notes

- Firebase client API keys are not the same as Admin keys; do not add service-account JSON to a Flutter app.
- Security must be enforced with Firebase rules and server-side validation where applicable.
