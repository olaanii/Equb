import 'package:equb/models/notification_preferences.dart';
import 'package:equb/models/notification_reminder.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/services/notification_reminder_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationReminderService', () {
    test('seeds reminders respecting user preferences', () async {
      final service = NotificationReminderService(
        clock: () => DateTime.utc(2025, 1, 1, 12),
      );
      final user = UserModel(
        id: 'u1',
        name: 'Test User',
        notificationPreferences: const NotificationPreferences(
          contributionRemindersEnabled: true,
          payoutRemindersEnabled: false,
          reminderLeadTimeHours: 2,
        ),
      );

      final streamFuture = service.remindersStream.first;
      await service.seedUpcomingReminders(user);
      final reminders = await streamFuture;

      expect(reminders, isNotEmpty);
      expect(
        reminders.every(
          (reminder) => reminder.type != NotificationReminderType.payout,
        ),
        true,
      );
      expect(
        reminders
            .where((r) => r.type == NotificationReminderType.contribution)
            .length,
        greaterThanOrEqualTo(1),
      );
    });

    test('markAsRead updates unread counts and stream listeners', () async {
      final service = NotificationReminderService(
        clock: () => DateTime.utc(2025, 1, 1, 12),
      );
      final user = UserModel(id: 'user', name: 'Demo');
      final emissions = <List<NotificationReminder>>[];
      final sub = service.remindersStream.listen(emissions.add);

      await service.seedUpcomingReminders(user);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.unreadCount(), greaterThan(0));
      final firstReminder = emissions.first.first;

      service.markAsRead(firstReminder.id);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.unreadCount(), lessThan(emissions.first.length));
      expect(
        emissions.last.firstWhere((r) => r.id == firstReminder.id).read,
        isTrue,
      );
      await sub.cancel();
    });
  });
}
