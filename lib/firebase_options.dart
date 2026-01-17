// Firebase options for each supported platform.
//
// CI note:
// - Do NOT import local/ignored secrets files here.
// - Values are read from compile-time `--dart-define` (works in CI).
// - When values are missing, Firebase initialization will fail at runtime and
//   the app shows a configuration error (see main.dart).
//
// Example:
//   flutter run \
//     --dart-define=FIREBASE_ANDROID_API_KEY=... \
//     --dart-define=FIREBASE_ANDROID_APP_ID=... \
//     --dart-define=FIREBASE_PROJECT_ID=...
//
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  // Shared
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'REPLACE_ME',
  );

  static const String _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'REPLACE_ME',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos. '
          'Re-run FlutterFire CLI for macOS support.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux. '
          'Re-run FlutterFire CLI for Linux support.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_WEB_API_KEY',
      defaultValue: 'REPLACE_ME',
    ),
    appId: String.fromEnvironment(
      'FIREBASE_WEB_APP_ID',
      defaultValue: 'REPLACE_ME',
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: 'REPLACE_ME',
    ),
    projectId: _projectId,
    authDomain: String.fromEnvironment(
      'FIREBASE_WEB_AUTH_DOMAIN',
      defaultValue: 'REPLACE_ME',
    ),
    storageBucket: _storageBucket,
    measurementId: String.fromEnvironment(
      'FIREBASE_WEB_MEASUREMENT_ID',
      defaultValue: 'REPLACE_ME',
    ),
    databaseURL: String.fromEnvironment(
      'FIREBASE_DATABASE_URL',
      defaultValue: 'REPLACE_ME',
    ),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_IOS_API_KEY',
      defaultValue: 'REPLACE_ME',
    ),
    appId: String.fromEnvironment(
      'FIREBASE_IOS_APP_ID',
      defaultValue: 'REPLACE_ME',
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: 'REPLACE_ME',
    ),
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
      defaultValue: 'REPLACE_ME',
    ),
    databaseURL: String.fromEnvironment(
      'FIREBASE_DATABASE_URL',
      defaultValue: 'REPLACE_ME',
    ),
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
      defaultValue: 'REPLACE_ME',
    ),
    appId: String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
      defaultValue: 'REPLACE_ME',
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: 'REPLACE_ME',
    ),
    projectId: _projectId,
    storageBucket: _storageBucket,
    databaseURL: String.fromEnvironment(
      'FIREBASE_DATABASE_URL',
      defaultValue: 'REPLACE_ME',
    ),
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_WINDOWS_API_KEY',
      defaultValue: 'REPLACE_ME',
    ),
    appId: String.fromEnvironment(
      'FIREBASE_WINDOWS_APP_ID',
      defaultValue: 'REPLACE_ME',
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: 'REPLACE_ME',
    ),
    projectId: _projectId,
    authDomain: String.fromEnvironment(
      'FIREBASE_WINDOWS_AUTH_DOMAIN',
      defaultValue: 'REPLACE_ME',
    ),
    storageBucket: _storageBucket,
    measurementId: String.fromEnvironment(
      'FIREBASE_WINDOWS_MEASUREMENT_ID',
      defaultValue: 'REPLACE_ME',
    ),
    databaseURL: String.fromEnvironment(
      'FIREBASE_DATABASE_URL',
      defaultValue: 'REPLACE_ME',
    ),
  );
}
