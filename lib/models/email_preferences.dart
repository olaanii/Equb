import 'package:meta/meta.dart';

enum EmailFrequency {
  immediate,
  daily,
  weekly,
  never,
}

extension EmailFrequencyX on EmailFrequency {
  String get label {
    switch (this) {
      case EmailFrequency.immediate:
        return 'Immediately';
      case EmailFrequency.daily:
        return 'Daily Digest';
      case EmailFrequency.weekly:
        return 'Weekly Summary';
      case EmailFrequency.never:
        return 'Never';
    }
  }
}

@immutable
class EmailPreferences {
  const EmailPreferences({
    this.contributionReminders = EmailFrequency.immediate,
    this.payoutNotifications = EmailFrequency.immediate,
    this.groupInvitations = EmailFrequency.immediate,
    this.transactionConfirmations = EmailFrequency.immediate,
    this.weeklySummaries = EmailFrequency.weekly,
    this.marketingEmails = false,
    this.lowBalanceWarnings = EmailFrequency.daily,
    this.systemUpdates = EmailFrequency.weekly,
  });

  final EmailFrequency contributionReminders;
  final EmailFrequency payoutNotifications;
  final EmailFrequency groupInvitations;
  final EmailFrequency transactionConfirmations;
  final EmailFrequency weeklySummaries;
  final bool marketingEmails;
  final EmailFrequency lowBalanceWarnings;
  final EmailFrequency systemUpdates;

  factory EmailPreferences.fromJson(Map<String, dynamic> json) {
    return EmailPreferences(
      contributionReminders: EmailFrequency.values.firstWhere(
        (e) => e.toString().split('.').last == json['contributionReminders'],
        orElse: () => EmailFrequency.immediate,
      ),
      payoutNotifications: EmailFrequency.values.firstWhere(
        (e) => e.toString().split('.').last == json['payoutNotifications'],
        orElse: () => EmailFrequency.immediate,
      ),
      groupInvitations: EmailFrequency.values.firstWhere(
        (e) => e.toString().split('.').last == json['groupInvitations'],
        orElse: () => EmailFrequency.immediate,
      ),
      transactionConfirmations: EmailFrequency.values.firstWhere(
        (e) => e.toString().split('.').last == json['transactionConfirmations'],
        orElse: () => EmailFrequency.immediate,
      ),
      weeklySummaries: EmailFrequency.values.firstWhere(
        (e) => e.toString().split('.').last == json['weeklySummaries'],
        orElse: () => EmailFrequency.weekly,
      ),
      marketingEmails: json['marketingEmails'] as bool? ?? false,
      lowBalanceWarnings: EmailFrequency.values.firstWhere(
        (e) => e.toString().split('.').last == json['lowBalanceWarnings'],
        orElse: () => EmailFrequency.daily,
      ),
      systemUpdates: EmailFrequency.values.firstWhere(
        (e) => e.toString().split('.').last == json['systemUpdates'],
        orElse: () => EmailFrequency.weekly,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contributionReminders': contributionReminders.toString().split('.').last,
      'payoutNotifications': payoutNotifications.toString().split('.').last,
      'groupInvitations': groupInvitations.toString().split('.').last,
      'transactionConfirmations': transactionConfirmations.toString().split('.').last,
      'weeklySummaries': weeklySummaries.toString().split('.').last,
      'marketingEmails': marketingEmails,
      'lowBalanceWarnings': lowBalanceWarnings.toString().split('.').last,
      'systemUpdates': systemUpdates.toString().split('.').last,
    };
  }

  EmailPreferences copyWith({
    EmailFrequency? contributionReminders,
    EmailFrequency? payoutNotifications,
    EmailFrequency? groupInvitations,
    EmailFrequency? transactionConfirmations,
    EmailFrequency? weeklySummaries,
    bool? marketingEmails,
    EmailFrequency? lowBalanceWarnings,
    EmailFrequency? systemUpdates,
  }) {
    return EmailPreferences(
      contributionReminders: contributionReminders ?? this.contributionReminders,
      payoutNotifications: payoutNotifications ?? this.payoutNotifications,
      groupInvitations: groupInvitations ?? this.groupInvitations,
      transactionConfirmations: transactionConfirmations ?? this.transactionConfirmations,
      weeklySummaries: weeklySummaries ?? this.weeklySummaries,
      marketingEmails: marketingEmails ?? this.marketingEmails,
      lowBalanceWarnings: lowBalanceWarnings ?? this.lowBalanceWarnings,
      systemUpdates: systemUpdates ?? this.systemUpdates,
    );
  }

  /// Check if a specific email type should be sent based on frequency and timing
  bool shouldSendEmail(EmailType type, {DateTime? lastSent, DateTime? currentTime}) {
    final now = currentTime ?? DateTime.now();
    final EmailFrequency frequency = _getFrequencyForType(type);

    if (frequency == EmailFrequency.never) return false;

    if (lastSent == null) return true; // Never sent before, so send

    switch (frequency) {
      case EmailFrequency.immediate:
        return true; // Always send immediate notifications
      case EmailFrequency.daily:
        return now.difference(lastSent).inHours >= 24;
      case EmailFrequency.weekly:
        return now.difference(lastSent).inDays >= 7;
      case EmailFrequency.never:
        return false;
    }
  }

  EmailFrequency _getFrequencyForType(EmailType type) {
    switch (type) {
      case EmailType.contributionReminder:
        return contributionReminders;
      case EmailType.payoutNotification:
        return payoutNotifications;
      case EmailType.groupInvitation:
        return groupInvitations;
      case EmailType.transactionConfirmation:
        return transactionConfirmations;
      case EmailType.weeklySummary:
        return weeklySummaries;
      case EmailType.lowBalanceWarning:
        return lowBalanceWarnings;
      case EmailType.systemUpdate:
        return systemUpdates;
      case EmailType.marketing:
        return marketingEmails ? EmailFrequency.immediate : EmailFrequency.never;
    }
  }
}

enum EmailType {
  contributionReminder,
  payoutNotification,
  groupInvitation,
  transactionConfirmation,
  weeklySummary,
  lowBalanceWarning,
  systemUpdate,
  marketing,
}

extension EmailTypeX on EmailType {
  String get label {
    switch (this) {
      case EmailType.contributionReminder:
        return 'Contribution Reminders';
      case EmailType.payoutNotification:
        return 'Payout Notifications';
      case EmailType.groupInvitation:
        return 'Group Invitations';
      case EmailType.transactionConfirmation:
        return 'Transaction Confirmations';
      case EmailType.weeklySummary:
        return 'Weekly Summaries';
      case EmailType.lowBalanceWarning:
        return 'Low Balance Warnings';
      case EmailType.systemUpdate:
        return 'System Updates';
      case EmailType.marketing:
        return 'Marketing Emails';
    }
  }

  String get description {
    switch (this) {
      case EmailType.contributionReminder:
        return 'Get reminded about upcoming contributions';
      case EmailType.payoutNotification:
        return 'Receive notifications when you get payouts';
      case EmailType.groupInvitation:
        return 'Get notified when invited to groups';
      case EmailType.transactionConfirmation:
        return 'Confirmations for deposits and withdrawals';
      case EmailType.weeklySummary:
        return 'Weekly summary of your activity';
      case EmailType.lowBalanceWarning:
        return 'Alerts when your balance is low';
      case EmailType.systemUpdate:
        return 'Important system updates and maintenance';
      case EmailType.marketing:
        return 'Promotional offers and new features';
    }
  }
}

@immutable
class EmailNotification {
  const EmailNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.subject,
    required this.content,
    required this.sentAt,
    this.deliveredAt,
    this.openedAt,
    this.clickedAt,
    this.metadata = const {},
  });

  final String id;
  final String userId;
  final EmailType type;
  final String subject;
  final String content;
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final DateTime? openedAt;
  final DateTime? clickedAt;
  final Map<String, dynamic> metadata;

  bool get wasDelivered => deliveredAt != null;
  bool get wasOpened => openedAt != null;
  bool get wasClicked => clickedAt != null;

  factory EmailNotification.fromJson(Map<String, dynamic> json) {
    return EmailNotification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: EmailType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      subject: json['subject'] as String,
      content: json['content'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'] as String)
          : null,
      openedAt: json['openedAt'] != null
          ? DateTime.parse(json['openedAt'] as String)
          : null,
      clickedAt: json['clickedAt'] != null
          ? DateTime.parse(json['clickedAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toString().split('.').last,
      'subject': subject,
      'content': content,
      'sentAt': sentAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'openedAt': openedAt?.toIso8601String(),
      'clickedAt': clickedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  EmailNotification copyWith({
    String? id,
    String? userId,
    EmailType? type,
    String? subject,
    String? content,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? openedAt,
    DateTime? clickedAt,
    Map<String, dynamic>? metadata,
  }) {
    return EmailNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      subject: subject ?? this.subject,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      openedAt: openedAt ?? this.openedAt,
      clickedAt: clickedAt ?? this.clickedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

