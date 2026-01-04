import 'dart:async';

import 'package:equb/models/notification_preferences.dart';
import 'package:equb/models/notification_reminder.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@visibleForTesting
final notificationUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(currentUserProvider).value;
});

final notificationPreferencesProvider = Provider<NotificationPreferences>((
  ref,
) {
  final user = ref.watch(notificationUserProvider);
  return user?.notificationPreferences ?? const NotificationPreferences();
});

final reminderSchedulerBindingProvider = Provider<void>((ref) {
  final scheduler = ref.watch(reminderSchedulerServiceProvider);
  final reminderService = ref.watch(notificationReminderServiceProvider);
  final user = ref.watch(notificationUserProvider);
  scheduler.bindUser(user, reminderService);
  ref.onDispose(() => scheduler.dispose());
});

final notificationRemindersProvider =
    StreamProvider<List<NotificationReminder>>((ref) {
      ref.watch(reminderSchedulerBindingProvider);
      final user = ref.watch(notificationUserProvider);
      if (user == null) {
        return const Stream.empty();
      }
      final service = ref.watch(notificationReminderServiceProvider);
      service.seedUpcomingReminders(user);
      return service.remindersStream;
    });

final unreadReminderCountProvider = Provider<int>((ref) {
  final reminders = ref
      .watch(notificationRemindersProvider)
      .maybeWhen(
        data: (value) => value,
        orElse: () => const <NotificationReminder>[],
      );
  return reminders.where((reminder) => !reminder.read).length;
});

final nextReminderProvider = Provider<NotificationReminder?>((ref) {
  final reminders = ref
      .watch(notificationRemindersProvider)
      .maybeWhen(
        data: (value) => value,
        orElse: () => const <NotificationReminder>[],
      );
  if (reminders.isEmpty) return null;
  return reminders.firstWhere(
    (reminder) => !reminder.read,
    orElse: () => reminders.first,
  );
});
