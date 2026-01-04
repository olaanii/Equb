import 'dart:async';
import 'dart:convert';

import 'package:equb/models/notification_preferences.dart';
import 'package:equb/models/notification_reminder.dart';
import 'package:equb/models/user_model.dart';

class NotificationReminderService {
  NotificationReminderService({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final _reminders = <NotificationReminder>[];
  late final StreamController<List<NotificationReminder>> _controller =
      StreamController<List<NotificationReminder>>.broadcast(
        onListen: _replayLatest,
      );
  String? _seedSignature;

  Stream<List<NotificationReminder>> get remindersStream => _controller.stream;

  Future<void> seedUpcomingReminders(UserModel user) async {
    final signature =
        '${user.id}:${jsonEncode(user.notificationPreferences.toJson())}';
    if (_seedSignature == signature && _reminders.isNotEmpty) {
      return;
    }
    _seedSignature = signature;
    _reminders
      ..clear()
      ..addAll(_mockReminders(user.notificationPreferences));
    _emit();
  }

  void scheduleReminder(NotificationReminder reminder) {
    _reminders.removeWhere((existing) => existing.id == reminder.id);
    _reminders.add(reminder);
    _emit();
  }

  void markAsRead(String id) {
    final index = _reminders.indexWhere((element) => element.id == id);
    if (index == -1) return;
    _reminders[index] = _reminders[index].copyWith(read: true);
    _emit();
  }

  void markAllRead() {
    for (var i = 0; i < _reminders.length; i++) {
      _reminders[i] = _reminders[i].copyWith(read: true);
    }
    _emit();
  }

  int unreadCount({NotificationReminderType? type}) {
    return _reminders.where((reminder) {
      if (reminder.read) return false;
      if (type == null) return true;
      return reminder.type == type;
    }).length;
  }

  List<NotificationReminder> get currentReminders =>
      List.unmodifiable(_reminders);

  void dispose() {
    _controller.close();
  }

  void _emit() {
    _reminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    _controller.add(List.unmodifiable(_reminders));
  }

  void _replayLatest() {
    if (_reminders.isEmpty) return;
    _controller.add(List.unmodifiable(_reminders));
  }

  List<NotificationReminder> _mockReminders(NotificationPreferences prefs) {
    final now = _clock();
    final reminders = <NotificationReminder>[];
    final lead = Duration(hours: prefs.reminderLeadTimeHours);

    if (prefs.contributionRemindersEnabled) {
      reminders.add(
        NotificationReminder(
          id: 'contribution-${now.millisecondsSinceEpoch}',
          type: NotificationReminderType.contribution,
          title: 'Contribution due in ${prefs.reminderLeadTimeHours}h',
          body:
              'Your weekly contribution will be auto-charged soon. Top up your wallet to avoid delays.',
          scheduledAt: now.add(lead),
          category: 'contribution',
        ),
      );
      reminders.add(
        NotificationReminder(
          id:
              'contribution-${now.add(const Duration(days: 7)).millisecondsSinceEpoch}',
          type: NotificationReminderType.contribution,
          title: 'Next cycle reminder',
          body:
              'Get ready for next week\'s contribution. You can snooze from Settings.',
          scheduledAt: now.add(const Duration(days: 6, hours: 12)),
          category: 'contribution',
        ),
      );
    }

    if (prefs.payoutRemindersEnabled) {
      reminders.add(
        NotificationReminder(
          id: 'payout-${now.add(const Duration(days: 1)).millisecondsSinceEpoch}',
          type: NotificationReminderType.payout,
          title: 'Payout scheduled tomorrow',
          body:
              'We will process your payout tomorrow at 10:00 AM. Make sure your bank info is up to date.',
          scheduledAt: now.add(const Duration(days: 1)),
          category: 'payout',
        ),
      );
    }

    if (!prefs.quietHoursEnabled) {
      reminders.add(
        NotificationReminder(
          id: 'system-${now.millisecondsSinceEpoch + 99}',
          type: NotificationReminderType.system,
          title: 'Weekly digest ready',
          body: 'A summary of wallet activity is ready inside the app.',
          scheduledAt: now.add(const Duration(hours: 2)),
          category: 'system',
        ),
      );
    }

    if (prefs.muteUntil != null && prefs.muteUntil!.isAfter(now)) {
      return reminders
          .map((reminder) => reminder.copyWith(read: true))
          .toList(growable: false);
    }

    return reminders;
  }
}
