import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:equb/models/notification_preferences.dart';
import 'package:equb/models/notification_reminder.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/services/system_log_service.dart';

class PushNotificationScheduler {
  PushNotificationScheduler({
    required this.firestore,
    required this.functions,
    required this.logService,
  });

  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final SystemLogService logService;

  /// Schedule contribution reminders for all active groups
  Future<void> scheduleContributionReminders() async {
    try {
      logService.log(LogLevel.info, 'push_scheduler', 'Starting contribution reminder scheduling');

      // Get all active groups
      final groupsSnapshot = await firestore.collection('groups').get();
      final groups = groupsSnapshot.docs;

      for (final groupDoc in groups) {
        final groupData = groupDoc.data();
        final groupId = groupDoc.id;

        // Check if group has active contributions
        final nextPayoutDate = groupData['nextPayoutDate'];
        if (nextPayoutDate == null) continue;

        final nextPayout = DateTime.parse(nextPayoutDate);
        final now = DateTime.now();

        // Only schedule for future payouts
        if (nextPayout.isBefore(now)) continue;

        // Get group members
        final members = groupData['members'] as List<dynamic>? ?? [];
        final contributionAmount = groupData['contributionAmount'] as num? ?? 0;

        for (final memberId in members) {
          await _scheduleMemberContributionReminder(
            memberId.toString(),
            groupId,
            groupData['name'] ?? 'Savings Group',
            contributionAmount.toDouble(),
            nextPayout,
          );
        }
      }

      logService.log(LogLevel.info, 'push_scheduler', 'Contribution reminder scheduling completed');
    } catch (e) {
      logService.log(LogLevel.error, 'push_scheduler', 'Failed to schedule contribution reminders', context: {'error': e.toString()});
    }
  }

  /// Schedule payout notifications for upcoming payouts
  Future<void> schedulePayoutNotifications() async {
    try {
      logService.log(LogLevel.info, 'push_scheduler', 'Starting payout notification scheduling');

      // Get pending payouts from the payout_schedules collection
      final payoutsSnapshot = await firestore
          .collection('payout_schedules')
          .where('status', isEqualTo: 'scheduled')
          .where('scheduledDate', isGreaterThan: DateTime.now())
          .get();

      for (final payoutDoc in payoutsSnapshot.docs) {
        final payoutData = payoutDoc.data();
        final recipientId = payoutData['recipientId'] as String?;
        final amount = payoutData['amount'] as num? ?? 0;
        final scheduledDate = (payoutData['scheduledDate'] as Timestamp?)?.toDate();

        if (recipientId == null || scheduledDate == null) continue;

        await _schedulePayoutNotification(
          recipientId,
          amount.toDouble(),
          scheduledDate,
        );
      }

      logService.log(LogLevel.info, 'push_scheduler', 'Payout notification scheduling completed');
    } catch (e) {
      logService.log(LogLevel.error, 'push_scheduler', 'Failed to schedule payout notifications', context: {'error': e.toString()});
    }
  }

  /// Schedule a single contribution reminder for a user
  Future<void> _scheduleMemberContributionReminder(
    String userId,
    String groupId,
    String groupName,
    double amount,
    DateTime nextPayout,
  ) async {
    try {
      // Get user's notification preferences
      final userPrefs = await _getUserNotificationPreferences(userId);
      if (!userPrefs.contributionRemindersEnabled) return;

      // Calculate reminder time (default 24 hours before)
      final reminderTime = nextPayout.subtract(Duration(hours: userPrefs.reminderLeadTimeHours));
      final now = DateTime.now();

      // Don't schedule if reminder time is in the past
      if (reminderTime.isBefore(now)) return;

      // Check if notification already exists
      final existingNotification = await _checkExistingNotification(
        userId,
        'contribution_reminder_$groupId',
        reminderTime,
      );

      if (existingNotification) return;

      // Schedule the notification
      await _schedulePushNotification(
        userId: userId,
        title: 'Contribution Reminder',
        body: 'Your contribution of ETB ${amount.toStringAsFixed(0)} for $groupName is due soon',
        scheduledTime: reminderTime,
        notificationType: 'contribution_reminder',
        data: {
          'groupId': groupId,
          'groupName': groupName,
          'amount': amount,
          'type': 'contribution_reminder',
        },
      );

    } catch (e) {
      logService.log(LogLevel.error, 'push_scheduler', 'Failed to schedule member contribution reminder',
        context: {'userId': userId, 'groupId': groupId, 'error': e.toString()});
    }
  }

  /// Schedule a payout notification for a user
  Future<void> _schedulePayoutNotification(
    String userId,
    double amount,
    DateTime payoutDate,
  ) async {
    try {
      // Get user's notification preferences
      final userPrefs = await _getUserNotificationPreferences(userId);
      if (!userPrefs.payoutRemindersEnabled) return;

      // Calculate reminder time (default 24 hours before)
      final reminderTime = payoutDate.subtract(const Duration(hours: 24));
      final now = DateTime.now();

      // Don't schedule if reminder time is in the past
      if (reminderTime.isBefore(now)) return;

      // Check if notification already exists
      final existingNotification = await _checkExistingNotification(
        userId,
        'payout_notification',
        reminderTime,
      );

      if (existingNotification) return;

      // Schedule the notification
      await _schedulePushNotification(
        userId: userId,
        title: 'Payout Notification',
        body: 'Your payout of ETB ${amount.toStringAsFixed(0)} is scheduled for tomorrow',
        scheduledTime: reminderTime,
        notificationType: 'payout_notification',
        data: {
          'amount': amount,
          'payoutDate': payoutDate.toIso8601String(),
          'type': 'payout_notification',
        },
      );

    } catch (e) {
      logService.log(LogLevel.error, 'push_scheduler', 'Failed to schedule payout notification',
        context: {'userId': userId, 'error': e.toString()});
    }
  }

  /// Schedule a push notification via Firebase Cloud Functions
  Future<void> _schedulePushNotification({
    required String userId,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String notificationType,
    Map<String, dynamic>? data,
  }) async {
    try {
      final callable = functions.httpsCallable('schedulePushNotification');

      await callable.call({
        'userId': userId,
        'title': title,
        'body': body,
        'scheduledTime': scheduledTime.toIso8601String(),
        'notificationType': notificationType,
        'data': data ?? {},
      });

      logService.log(LogLevel.info, 'push_scheduler', 'Push notification scheduled',
        context: {
          'userId': userId,
          'type': notificationType,
          'scheduledTime': scheduledTime.toIso8601String(),
        });

    } catch (e) {
      logService.log(LogLevel.error, 'push_scheduler', 'Failed to schedule push notification',
        context: {'userId': userId, 'error': e.toString()});
      rethrow;
    }
  }

  /// Get user's notification preferences
  Future<NotificationPreferences> _getUserNotificationPreferences(String userId) async {
    try {
      final doc = await firestore.collection('user_notification_preferences').doc(userId).get();

      if (doc.exists) {
        final data = doc.data()!;
        return NotificationPreferences.fromJson(data);
      }

      // Return default preferences
      return const NotificationPreferences();
    } catch (e) {
      logService.log(LogLevel.warning, 'push_scheduler', 'Failed to get user notification preferences, using defaults',
        context: {'userId': userId, 'error': e.toString()});
      return const NotificationPreferences();
    }
  }

  /// Check if a notification of the same type already exists for the given time window
  Future<bool> _checkExistingNotification(String userId, String notificationId, DateTime scheduledTime) async {
    try {
      // Check scheduled notifications collection
      final query = await firestore
          .collection('scheduled_notifications')
          .where('userId', isEqualTo: userId)
          .where('notificationId', isEqualTo: notificationId)
          .where('scheduledTime', isGreaterThan: scheduledTime.subtract(const Duration(hours: 1)))
          .where('scheduledTime', isLessThan: scheduledTime.add(const Duration(hours: 1)))
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      // If check fails, assume no existing notification to be safe
      return false;
    }
  }

  /// Cancel scheduled notifications for a user
  Future<void> cancelUserNotifications(String userId, {String? notificationType}) async {
    try {
      final callable = functions.httpsCallable('cancelScheduledNotifications');

      await callable.call({
        'userId': userId,
        'notificationType': notificationType,
      });

      logService.log(LogLevel.info, 'push_scheduler', 'User notifications cancelled',
        context: {'userId': userId, 'type': notificationType});

    } catch (e) {
      logService.log(LogLevel.error, 'push_scheduler', 'Failed to cancel user notifications',
        context: {'userId': userId, 'error': e.toString()});
    }
  }

  /// Send immediate notification (not scheduled)
  Future<void> sendImmediateNotification({
    required String userId,
    required String title,
    required String body,
    String? notificationType,
    Map<String, dynamic>? data,
  }) async {
    try {
      final callable = functions.httpsCallable('sendImmediateNotification');

      await callable.call({
        'userId': userId,
        'title': title,
        'body': body,
        'notificationType': notificationType ?? 'immediate',
        'data': data ?? {},
      });

      logService.log(LogLevel.info, 'push_scheduler', 'Immediate notification sent',
        context: {'userId': userId, 'type': notificationType});

    } catch (e) {
      logService.log(LogLevel.error, 'push_scheduler', 'Failed to send immediate notification',
        context: {'userId': userId, 'error': e.toString()});
      rethrow;
    }
  }
}

