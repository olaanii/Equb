import 'package:meta/meta.dart';

enum AutoTopupFrequency {
  daily,
  weekly,
  biWeekly,
  monthly,
}

enum AutoTopupStatus {
  active,
  paused,
  suspended,
  cancelled,
}

extension AutoTopupFrequencyX on AutoTopupFrequency {
  String get label {
    switch (this) {
      case AutoTopupFrequency.daily:
        return 'Daily';
      case AutoTopupFrequency.weekly:
        return 'Weekly';
      case AutoTopupFrequency.biWeekly:
        return 'Bi-weekly';
      case AutoTopupFrequency.monthly:
        return 'Monthly';
    }
  }

  Duration get interval {
    switch (this) {
      case AutoTopupFrequency.daily:
        return const Duration(days: 1);
      case AutoTopupFrequency.weekly:
        return const Duration(days: 7);
      case AutoTopupFrequency.biWeekly:
        return const Duration(days: 14);
      case AutoTopupFrequency.monthly:
        return const Duration(days: 30);
    }
  }
}

@immutable
class AutoTopupRule {
  const AutoTopupRule({
    required this.id,
    required this.userId,
    required this.enabled,
    required this.thresholdAmount,
    required this.topupAmount,
    required this.frequency,
    required this.nextScheduledAt,
    required this.paymentMethod,
    required this.createdAt,
    this.status = AutoTopupStatus.active,
    this.lastExecutedAt,
    this.lastExecutionResult,
    this.failureCount = 0,
    this.maxFailures = 3,
    this.pausedUntil,
    this.metadata = const {},
  });

  final String id;
  final String userId;
  final bool enabled;
  final double thresholdAmount;
  final double topupAmount;
  final AutoTopupFrequency frequency;
  final DateTime nextScheduledAt;
  final String paymentMethod; // Gateway ID
  final DateTime createdAt;
  final AutoTopupStatus status;
  final DateTime? lastExecutedAt;
  final String? lastExecutionResult;
  final int failureCount;
  final int maxFailures;
  final DateTime? pausedUntil;
  final Map<String, dynamic> metadata;

  bool get isActive => enabled && status == AutoTopupStatus.active;
  bool get isPaused => status == AutoTopupStatus.paused || (pausedUntil?.isAfter(DateTime.now()) ?? false);
  bool get shouldExecute => isActive && !isPaused;
  bool get hasExceededFailures => failureCount >= maxFailures;

  factory AutoTopupRule.fromJson(Map<String, dynamic> json) {
    return AutoTopupRule(
      id: json['id'] as String,
      userId: json['userId'] as String,
      enabled: json['enabled'] as bool,
      thresholdAmount: (json['thresholdAmount'] as num).toDouble(),
      topupAmount: (json['topupAmount'] as num).toDouble(),
      frequency: AutoTopupFrequency.values.firstWhere(
        (e) => e.toString().split('.').last == json['frequency'],
        orElse: () => AutoTopupFrequency.weekly,
      ),
      nextScheduledAt: DateTime.parse(json['nextScheduledAt'] as String),
      paymentMethod: json['paymentMethod'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: AutoTopupStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => AutoTopupStatus.active,
      ),
      lastExecutedAt: json['lastExecutedAt'] != null
          ? DateTime.parse(json['lastExecutedAt'] as String)
          : null,
      lastExecutionResult: json['lastExecutionResult'] as String?,
      failureCount: json['failureCount'] as int? ?? 0,
      maxFailures: json['maxFailures'] as int? ?? 3,
      pausedUntil: json['pausedUntil'] != null
          ? DateTime.parse(json['pausedUntil'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'enabled': enabled,
      'thresholdAmount': thresholdAmount,
      'topupAmount': topupAmount,
      'frequency': frequency.toString().split('.').last,
      'nextScheduledAt': nextScheduledAt.toIso8601String(),
      'paymentMethod': paymentMethod,
      'createdAt': createdAt.toIso8601String(),
      'status': status.toString().split('.').last,
      'lastExecutedAt': lastExecutedAt?.toIso8601String(),
      'lastExecutionResult': lastExecutionResult,
      'failureCount': failureCount,
      'maxFailures': maxFailures,
      'pausedUntil': pausedUntil?.toIso8601String(),
      'metadata': metadata,
    };
  }

  AutoTopupRule copyWith({
    String? id,
    String? userId,
    bool? enabled,
    double? thresholdAmount,
    double? topupAmount,
    AutoTopupFrequency? frequency,
    DateTime? nextScheduledAt,
    String? paymentMethod,
    DateTime? createdAt,
    AutoTopupStatus? status,
    DateTime? lastExecutedAt,
    String? lastExecutionResult,
    int? failureCount,
    int? maxFailures,
    DateTime? pausedUntil,
    Map<String, dynamic>? metadata,
  }) {
    return AutoTopupRule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      enabled: enabled ?? this.enabled,
      thresholdAmount: thresholdAmount ?? this.thresholdAmount,
      topupAmount: topupAmount ?? this.topupAmount,
      frequency: frequency ?? this.frequency,
      nextScheduledAt: nextScheduledAt ?? this.nextScheduledAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
      lastExecutionResult: lastExecutionResult ?? this.lastExecutionResult,
      failureCount: failureCount ?? this.failureCount,
      maxFailures: maxFailures ?? this.maxFailures,
      pausedUntil: pausedUntil ?? this.pausedUntil,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Calculate the next execution time based on frequency
  DateTime getNextExecutionTime() {
    return lastExecutedAt?.add(frequency.interval) ?? nextScheduledAt;
  }
}

@immutable
class AutoTopupExecution {
  const AutoTopupExecution({
    required this.id,
    required this.ruleId,
    required this.userId,
    required this.executedAt,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    this.transactionId,
    this.errorMessage,
    this.metadata = const {},
  });

  final String id;
  final String ruleId;
  final String userId;
  final DateTime executedAt;
  final double amount;
  final String paymentMethod;
  final String status; // 'success', 'failed', 'pending'
  final String? transactionId;
  final String? errorMessage;
  final Map<String, dynamic> metadata;

  bool get isSuccess => status == 'success';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending';

  factory AutoTopupExecution.fromJson(Map<String, dynamic> json) {
    return AutoTopupExecution(
      id: json['id'] as String,
      ruleId: json['ruleId'] as String,
      userId: json['userId'] as String,
      executedAt: DateTime.parse(json['executedAt'] as String),
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] as String,
      status: json['status'] as String,
      transactionId: json['transactionId'] as String?,
      errorMessage: json['errorMessage'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ruleId': ruleId,
      'userId': userId,
      'executedAt': executedAt.toIso8601String(),
      'amount': amount,
      'paymentMethod': paymentMethod,
      'status': status,
      'transactionId': transactionId,
      'errorMessage': errorMessage,
      'metadata': metadata,
    };
  }
}

@immutable
class BalanceThresholdCheck {
  const BalanceThresholdCheck({
    required this.userId,
    required this.currentBalance,
    required this.thresholdAmount,
    required this.needsTopup,
    required this.recommendedAmount,
  });

  final String userId;
  final double currentBalance;
  final double thresholdAmount;
  final bool needsTopup;
  final double recommendedAmount;

  double get deficit => thresholdAmount - currentBalance;
}

