import 'package:flutter/foundation.dart';

@immutable
class NotificationPreferences {
  const NotificationPreferences({
    this.contributionRemindersEnabled = true,
    this.payoutRemindersEnabled = true,
    this.reminderLeadTimeHours = 6,
    this.quietHoursEnabled = false,
    this.quietHoursStartHour = 22,
    this.quietHoursEndHour = 7,
    this.muteUntil,
  });

  final bool contributionRemindersEnabled;
  final bool payoutRemindersEnabled;
  final int reminderLeadTimeHours;
  final bool quietHoursEnabled;
  final int quietHoursStartHour;
  final int quietHoursEndHour;
  final DateTime? muteUntil;

  NotificationPreferences copyWith({
    bool? contributionRemindersEnabled,
    bool? payoutRemindersEnabled,
    int? reminderLeadTimeHours,
    bool? quietHoursEnabled,
    int? quietHoursStartHour,
    int? quietHoursEndHour,
    DateTime? muteUntil,
  }) {
    return NotificationPreferences(
      contributionRemindersEnabled:
          contributionRemindersEnabled ?? this.contributionRemindersEnabled,
      payoutRemindersEnabled:
          payoutRemindersEnabled ?? this.payoutRemindersEnabled,
      reminderLeadTimeHours:
          reminderLeadTimeHours ?? this.reminderLeadTimeHours,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStartHour: quietHoursStartHour ?? this.quietHoursStartHour,
      quietHoursEndHour: quietHoursEndHour ?? this.quietHoursEndHour,
      muteUntil: muteUntil ?? this.muteUntil,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contributionRemindersEnabled': contributionRemindersEnabled,
      'payoutRemindersEnabled': payoutRemindersEnabled,
      'reminderLeadTimeHours': reminderLeadTimeHours,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStartHour': quietHoursStartHour,
      'quietHoursEndHour': quietHoursEndHour,
      'muteUntil': muteUntil?.toIso8601String(),
    };
  }

  factory NotificationPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const NotificationPreferences();
    }
    return NotificationPreferences(
      contributionRemindersEnabled:
          json['contributionRemindersEnabled'] as bool? ?? true,
      payoutRemindersEnabled: json['payoutRemindersEnabled'] as bool? ?? true,
      reminderLeadTimeHours: json['reminderLeadTimeHours'] as int? ?? 6,
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
      quietHoursStartHour: json['quietHoursStartHour'] as int? ?? 22,
      quietHoursEndHour: json['quietHoursEndHour'] as int? ?? 7,
      muteUntil:
          json['muteUntil'] != null
              ? DateTime.tryParse(json['muteUntil'] as String)
              : null,
    );
  }
}
