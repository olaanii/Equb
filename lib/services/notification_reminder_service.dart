import 'dart:async';
import 'dart:convert';

import 'package:equb/models/notification_reminder.dart';
import 'package:equb/models/user_model.dart';

/// Service for managing notification reminders.
/// 
/// This service stores reminders in memory and provides a stream of updates.
/// Real reminder data is populated from Firebase RTDB via RtdbReminderSchedulerService.
class NotificationReminderService {
  NotificationReminderService();

  final _reminders = <NotificationReminder>[];
  late final StreamController<List<NotificationReminder>> _controller =
      StreamController<List<NotificationReminder>>.broadcast(
        onListen: _replayLatest,
      );
  String? _seedSignature;

  Stream<List<NotificationReminder>> get remindersStream => _controller.stream;

  /// Initialize the service for a user.
  /// 
  /// This method prepares the service but does not add mock data.
  /// Real reminders are added via [scheduleReminder] from RtdbReminderSchedulerService.
  Future<void> seedUpcomingReminders(UserModel user) async {
    final signature =
        '${user.id}:${jsonEncode(user.notificationPreferences.toJson())}';
    if (_seedSignature == signature && _reminders.isNotEmpty) {
      return;
    }
    _seedSignature = signature;
    // Clear existing reminders - real data will be populated from RTDB
    _reminders.clear();
    _emit();
  }

  /// Schedule a reminder (called by RtdbReminderSchedulerService with real data)
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
}
