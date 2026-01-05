import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import 'notification_service.dart';

class DeviceTokenRegistrar {
  DeviceTokenRegistrar({
    required FirebaseDatabase database,
    required NotificationService notificationService,
  }) : _db = database,
       _notificationService = notificationService;

  final FirebaseDatabase _db;
  final NotificationService _notificationService;

  DatabaseReference _userRef(String userId) => _db.ref('users/$userId');

  Future<void> registerIfNeeded(UserModel user) async {
    // Only meaningful on supported platforms and when user opted-in.
    if (!user.pushEnabled) return;

    final token = await _notificationService.getToken();
    if (token == null || token.isEmpty) return;

    // Best-effort; do not throw—push tokens are optional.
    try {
      final nowMs = ServerValue.timestamp;
      await _userRef(user.id).update({
        'fcmToken': token,
        'fcmTokenUpdatedAtMs': nowMs,
        // Keep an allow-list style node for future multi-device support.
        'deviceTokens/$token': true,
      });
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }
}
