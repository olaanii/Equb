import 'dart:async';

import 'package:equb/models/notification_preferences.dart';
import 'package:equb/models/notification_reminder.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/services/notification_reminder_service.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:equb/utils/firestore_helpers.dart';
import 'package:firebase_database/firebase_database.dart';

class RtdbReminderSchedulerService {
  RtdbReminderSchedulerService({
    FirebaseDatabase? database,
    DateTime Function()? clock,
    Future<void> Function(NotificationReminder reminder)? onReminderDispatched,
    SystemLogService? logService,
  }) : _db = database ?? FirebaseDatabase.instance,
       _notify = onReminderDispatched,
       _logService = logService,
       _clock = clock ?? DateTime.now;

  final FirebaseDatabase _db;
  final Future<void> Function(NotificationReminder reminder)? _notify;
  final SystemLogService? _logService;
  final DateTime Function() _clock;

  StreamSubscription<DatabaseEvent>? _subscription;
  String? _activeUserId;

  Future<void> bindUser(
    UserModel? user,
    NotificationReminderService reminderService,
  ) async {
    if (_activeUserId == user?.id) return;

    await _subscription?.cancel();
    _subscription = null;
    _activeUserId = user?.id;

    if (user == null) return;

    final prefs = user.notificationPreferences;
    final query = _db
        .ref('users/${user.id}/reminder_jobs')
        .orderByChild('scheduledAtMs');

    _subscription = query.onValue.listen(
      (event) => _applyJobs(event, reminderService, prefs),
      onError: (error) {
        _logService?.log(
          LogLevel.error,
          'RtdbReminderSchedulerService',
          'Failed to sync reminder jobs',
          context: {'error': '$error'},
        );
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  void _applyJobs(
    DatabaseEvent event,
    NotificationReminderService reminderService,
    NotificationPreferences prefs,
  ) {
    final now = _clock();
    final isMuted = prefs.muteUntil != null && prefs.muteUntil!.isAfter(now);

    final raw = event.snapshot.value;
    if (raw == null || raw is! Map) return;

    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map) continue;

      final data = <String, dynamic>{};
      for (final pair in value.entries) {
        data[pair.key.toString()] = pair.value;
      }
      data['id'] = data['id'] ?? entry.key.toString();

      final reminder = _mapReminder(data, prefs, isMuted: isMuted);
      if (reminder == null) continue;

      reminderService.scheduleReminder(reminder);
      if (!reminder.read) {
        final notify = _notify;
        if (notify != null) {
          unawaited(notify(reminder));
        }
      }
    }
  }

  NotificationReminder? _mapReminder(
    Map<String, dynamic> data,
    NotificationPreferences prefs, {
    required bool isMuted,
  }) {
    final scheduledRaw = data['scheduledAt'];
    final scheduledAt =
        FirestoreHelpers.parseDateTime(scheduledRaw) ?? DateTime.now();

    final typeRaw = data['type'] as String?;
    final type = NotificationReminderType.values.firstWhere(
      (t) => t.name == typeRaw,
      orElse: () => NotificationReminderType.system,
    );

    final read = (data['read'] as bool?) ?? false;

    return NotificationReminder(
      id: data['id'] as String? ?? '',
      type: type,
      title: (data['title'] as String?) ?? 'Reminder',
      body: (data['body'] as String?) ?? '',
      scheduledAt: scheduledAt,
      category: (data['category'] as String?) ?? type.name,
      read: isMuted ? true : read,
    );
  }
}
