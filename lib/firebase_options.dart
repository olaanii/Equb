// Firebase options for each supported platform.
//
// This project keeps the raw values in `lib/config/firebase_secrets.dart` which
// is intentionally gitignored. Copy
// `lib/config/firebase_secrets.example.dart` -> `lib/config/firebase_secrets.dart`
// and fill in your Firebase project values.
//
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members

import 'package:equb/config/firebase_secrets.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
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
    apiKey: FirebaseSecrets.webApiKey,
    appId: FirebaseSecrets.webAppId,
    messagingSenderId: FirebaseSecrets.webMessagingSenderId,
    projectId: FirebaseSecrets.webProjectId,
    authDomain: FirebaseSecrets.webAuthDomain,
    storageBucket: FirebaseSecrets.webStorageBucket,
    measurementId: FirebaseSecrets.webMeasurementId,
    databaseURL: FirebaseSecrets.webDatabaseUrl,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: FirebaseSecrets.iosApiKey,
    appId: FirebaseSecrets.iosAppId,
    messagingSenderId: FirebaseSecrets.iosMessagingSenderId,
    projectId: FirebaseSecrets.iosProjectId,
    storageBucket: FirebaseSecrets.iosStorageBucket,
    iosBundleId: FirebaseSecrets.iosBundleId,
    databaseURL: FirebaseSecrets.iosDatabaseUrl,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: FirebaseSecrets.androidApiKey,
    appId: FirebaseSecrets.androidAppId,
    messagingSenderId: FirebaseSecrets.androidMessagingSenderId,
    projectId: FirebaseSecrets.androidProjectId,
    storageBucket: FirebaseSecrets.androidStorageBucket,
    databaseURL: FirebaseSecrets.androidDatabaseUrl,
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: FirebaseSecrets.windowsApiKey,
    appId: FirebaseSecrets.windowsAppId,
    messagingSenderId: FirebaseSecrets.windowsMessagingSenderId,
    projectId: FirebaseSecrets.windowsProjectId,
    authDomain: FirebaseSecrets.windowsAuthDomain,
    storageBucket: FirebaseSecrets.windowsStorageBucket,
    measurementId: FirebaseSecrets.windowsMeasurementId,
    databaseURL: FirebaseSecrets.windowsDatabaseUrl,
  );
}
