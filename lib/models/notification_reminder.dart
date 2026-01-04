import 'package:flutter/foundation.dart';

enum NotificationReminderType { contribution, payout, system, chat }

@immutable
class NotificationReminder {
  const NotificationReminder({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.category,
    this.read = false,
  });

  final String id;
  final NotificationReminderType type;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String category;
  final bool read;

  NotificationReminder copyWith({bool? read}) {
    return NotificationReminder(
      id: id,
      type: type,
      title: title,
      body: body,
      scheduledAt: scheduledAt,
      category: category,
      read: read ?? this.read,
    );
  }
}
