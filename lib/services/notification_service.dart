import 'package:equb/models/notification_reminder.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      // Windows/Web specific setup or skip
      return;
    }

    try {
      // Request permission
      await _fcm.requestPermission();

      // Init local notifications
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _localNotifications.initialize(settings);

      // Foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showNotification(message);
      });
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  Future<String?> getToken() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) return null;
    try {
      return await _fcm.getToken();
    } catch (e) {
      return null;
    }
  }

  Future<void> _showNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
          ),
        ),
      );
    }
  }

  Future<void> showLocalReminder(NotificationReminder reminder) async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return;
    }
    await _localNotifications.show(
      reminder.id.hashCode,
      reminder.title,
      reminder.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Reminder Notifications',
          importance: Importance.high,
        ),
      ),
    );
  }
}
