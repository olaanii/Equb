import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equb/models/notification_preferences.dart';
import 'package:equb/models/notification_reminder.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/services/notification_reminder_service.dart';
import 'package:equb/services/system_log_service.dart';

class ReminderSchedulerService {
  ReminderSchedulerService({
    FirebaseFirestore? firestore,
    DateTime Function()? clock,
    Future<void> Function(NotificationReminder reminder)? onReminderDispatched,
    SystemLogService? logService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _notify = onReminderDispatched,
       _logService = logService,
       _clock = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final Future<void> Function(NotificationReminder reminder)? _notify;
  final SystemLogService? _logService;
  final DateTime Function() _clock;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _activeUserId;

  Future<void> bindUser(
    UserModel? user,
    NotificationReminderService reminderService,
  ) async {
    if (_activeUserId == user?.id) {
      return;
    }
    await _subscription?.cancel();
    _subscription = null;
    _activeUserId = user?.id;
    if (user == null) {
      return;
    }

    final prefs = user.notificationPreferences;
    final query = _firestore
        .collection('users')
        .doc(user.id)
        .collection('reminder_jobs')
        .orderBy('scheduledAt');

    _subscription = query.snapshots().listen(
      (snapshot) => _applyJobs(snapshot, reminderService, prefs),
      onError: (error, stack) {
        _logService?.log(
          LogLevel.error,
          'ReminderSchedulerService',
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
    QuerySnapshot<Map<String, dynamic>> snapshot,
    NotificationReminderService reminderService,
    NotificationPreferences prefs,
  ) {
    final now = _clock();
    final isMuted = prefs.muteUntil != null && prefs.muteUntil!.isAfter(now);
    if (isMuted) {
      _logService?.log(
        LogLevel.info,
        'ReminderSchedulerService',
        'Muted until ${prefs.muteUntil?.toIso8601String()} – suppressing push delivery',
      );
    }

    for (final doc in snapshot.docs) {
      final reminder = _mapReminder(doc, prefs, isMuted: isMuted);
      if (reminder == null) {
        continue;
      }
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
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    NotificationPreferences prefs, {
    required bool isMuted,
  }) {
    final data = doc.data();
    final scheduledRaw = data['scheduledAt'];
    final scheduled = _parseDateTime(scheduledRaw);
    if (scheduled == null) {
      _logService?.log(
        LogLevel.warning,
        'ReminderSchedulerService',
        'Reminder job missing scheduledAt',
        context: {'jobId': doc.id, 'scheduledAt': '$scheduledRaw'},
      );
      return null;
    }

    final adjusted = _respectQuietHours(scheduled, prefs, jobId: doc.id);
    final reminderType = _decodeType(data['type'] as String?);
    if (reminderType == null) {
      _logService?.log(
        LogLevel.warning,
        'ReminderSchedulerService',
        'Reminder job missing type',
        context: {'jobId': doc.id},
      );
      return null;
    }

    return NotificationReminder(
      id: doc.id,
      type: reminderType,
      title: data['title'] as String? ?? 'Reminder',
      body: data['body'] as String? ?? '',
      scheduledAt: adjusted,
      category: data['category'] as String? ?? 'system',
      read: isMuted,
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  DateTime _respectQuietHours(
    DateTime scheduled,
    NotificationPreferences prefs, {
    required String jobId,
  }) {
    if (!prefs.quietHoursEnabled) {
      return scheduled;
    }
    final startHour = prefs.quietHoursStartHour % 24;
    final endHour = prefs.quietHoursEndHour % 24;
    final crossesMidnight = endHour <= startHour;
    final ts = scheduled;
    final inQuietWindow = _isWithinQuietHours(
      ts,
      startHour,
      endHour,
      crossesMidnight,
    );
    if (!inQuietWindow) {
      return scheduled;
    }
    final adjustmentDay =
        (crossesMidnight && ts.hour >= startHour)
            ? ts.add(const Duration(days: 1))
            : ts;
    final shifted = DateTime(
      adjustmentDay.year,
      adjustmentDay.month,
      adjustmentDay.day,
      endHour,
      ts.minute,
      ts.second,
      ts.millisecond,
      ts.microsecond,
    );
    _logService?.log(
      LogLevel.info,
      'ReminderSchedulerService',
      'Reminder shifted out of quiet hours',
      context: {
        'jobId': jobId,
        'original': scheduled.toIso8601String(),
        'shifted': shifted.toIso8601String(),
      },
    );
    return shifted;
  }

  bool _isWithinQuietHours(
    DateTime ts,
    int startHour,
    int endHour,
    bool crossesMidnight,
  ) {
    if (!crossesMidnight) {
      return ts.hour >= startHour && ts.hour < endHour;
    }
    return ts.hour >= startHour || ts.hour < endHour;
  }

  NotificationReminderType? _decodeType(String? raw) {
    if (raw == null) return null;
    return NotificationReminderType.values.firstWhere(
      (type) => type.name == raw,
      orElse: () => NotificationReminderType.system,
    );
  }
}
