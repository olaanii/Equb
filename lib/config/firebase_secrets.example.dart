/// Template for Firebase keys/config values.
///
/// 1) Copy this file to `firebase_secrets.dart`
/// 2) Fill in values from your Firebase project
///
/// IMPORTANT:
/// - Do not commit `firebase_secrets.dart`.
/// - For Flutter web, these values ship to clients and are not truly secret.
///   Security must be enforced via Firebase rules and backend validation.
class FirebaseSecrets {
  // Web
  static const webApiKey = 'REPLACE_ME';
  static const webAppId = 'REPLACE_ME';
  static const webMessagingSenderId = 'REPLACE_ME';
  static const webProjectId = 'REPLACE_ME';
  static const webAuthDomain = 'REPLACE_ME';
  static const webStorageBucket = 'REPLACE_ME';
  static const webMeasurementId = 'REPLACE_ME';
  static const webDatabaseUrl = 'https://REPLACE_ME-default-rtdb.firebaseio.com';

  // iOS
  static const iosApiKey = 'REPLACE_ME';
  static const iosAppId = 'REPLACE_ME';
  static const iosMessagingSenderId = 'REPLACE_ME';
  static const iosProjectId = 'REPLACE_ME';
  static const iosStorageBucket = 'REPLACE_ME';
  static const iosBundleId = 'REPLACE_ME';
  static const iosDatabaseUrl = 'https://REPLACE_ME-default-rtdb.firebaseio.com';

  // Android
  static const androidApiKey = 'REPLACE_ME';
  static const androidAppId = 'REPLACE_ME';
  static const androidMessagingSenderId = 'REPLACE_ME';
  static const androidProjectId = 'REPLACE_ME';
  static const androidStorageBucket = 'REPLACE_ME';
  static const androidDatabaseUrl = 'https://REPLACE_ME-default-rtdb.firebaseio.com';

  // Windows
  static const windowsApiKey = 'REPLACE_ME';
  static const windowsAppId = 'REPLACE_ME';
  static const windowsMessagingSenderId = 'REPLACE_ME';
  static const windowsProjectId = 'REPLACE_ME';
  static const windowsAuthDomain = 'REPLACE_ME';
  static const windowsStorageBucket = 'REPLACE_ME';
  static const windowsMeasurementId = 'REPLACE_ME';
  static const windowsDatabaseUrl = 'https://REPLACE_ME-default-rtdb.firebaseio.com';
}
