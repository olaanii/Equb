import 'package:equb/models/notification_preferences.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/services/notification_reminder_service.dart';
import 'package:equb/services/reminder_scheduler_service.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReminderSchedulerService', () {
    late FakeFirebaseFirestore firestore;
    late NotificationReminderService reminderService;
    late List notifications;
    late ReminderSchedulerService scheduler;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      reminderService = NotificationReminderService(
        clock: () => DateTime.utc(2025, 1, 1, 21),
      );
      notifications = [];
      scheduler = ReminderSchedulerService(
        firestore: firestore,
        clock: () => DateTime.utc(2025, 1, 1, 23),
        onReminderDispatched: (reminder) async {
          notifications.add(reminder);
        },
        logService: SystemLogService(),
      );
    });

    tearDown(() async {
      await scheduler.dispose();
      reminderService.dispose();
    });

    test('shifts reminders out of quiet hours', () async {
      final user = UserModel(
        id: 'user-1',
        name: 'Tester',
        notificationPreferences: const NotificationPreferences(
          quietHoursEnabled: true,
          quietHoursStartHour: 22,
          quietHoursEndHour: 7,
        ),
      );

      await firestore
          .collection('users')
          .doc(user.id)
          .collection('reminder_jobs')
          .doc('job-1')
          .set({
            'type': 'contribution',
            'title': 'Pay soon',
            'body': 'Top up your wallet',
            'scheduledAt': DateTime.utc(2025, 1, 1, 23).toIso8601String(),
            'category': 'contribution',
          });

      await scheduler.bindUser(user, reminderService);
      await Future<void>.delayed(Duration.zero);

      final reminder = reminderService.currentReminders.single;
      expect(reminder.scheduledAt.hour, 7);
      expect(notifications.single.id, 'job-1');
    });

    test('suppresses delivery when muted', () async {
      final user = UserModel(
        id: 'user-2',
        name: 'Muted Tester',
        notificationPreferences: NotificationPreferences(
          muteUntil: DateTime.utc(2025, 1, 2),
        ),
      );

      await firestore
          .collection('users')
          .doc(user.id)
          .collection('reminder_jobs')
          .doc('job-2')
          .set({
            'type': 'payout',
            'title': 'Payout soon',
            'body': 'We will process tomorrow',
            'scheduledAt': DateTime.utc(2025, 1, 1, 12).toIso8601String(),
            'category': 'payout',
          });

      await scheduler.bindUser(user, reminderService);
      await Future<void>.delayed(Duration.zero);

      final reminder = reminderService.currentReminders.single;
      expect(reminder.read, isTrue);
      expect(notifications, isEmpty);
    });
  });
}
