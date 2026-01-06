import 'package:meta/meta.dart';

enum PayoutStatus {
  pending,
  scheduled,
  processing,
  completed,
  failed,
  cancelled,
}

enum PayoutType {
  regular, // Regular rotation payout
  early, // Early payout (emergency)
  finalPayout, // Final payout when group completes
}

@immutable
class PayoutSchedule {
  const PayoutSchedule({
    required this.id,
    required this.groupId,
    required this.round,
    required this.recipientId,
    required this.amount,
    required this.scheduledDate,
    required this.type,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.transactionId,
    this.failureReason,
    this.metadata = const {},
  });

  final String id;
  final String groupId;
  final int round;
  final String recipientId;
  final double amount;
  final DateTime scheduledDate;
  final PayoutType type;
  final PayoutStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? transactionId;
  final String? failureReason;
  final Map<String, dynamic> metadata;

  bool get isPending => status == PayoutStatus.pending;
  bool get isScheduled => status == PayoutStatus.scheduled;
  bool get isProcessing => status == PayoutStatus.processing;
  bool get isCompleted => status == PayoutStatus.completed;
  bool get isFailed => status == PayoutStatus.failed;
  bool get isCancelled => status == PayoutStatus.cancelled;

  bool get canBeProcessed => isPending || isScheduled;
  bool get isOverdue => scheduledDate.isBefore(DateTime.now()) && !isCompleted;

  factory PayoutSchedule.fromJson(Map<String, dynamic> json) {
    final typeString = json['type']?.toString();
    return PayoutSchedule(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      round: json['round'] as int,
      recipientId: json['recipientId'] as String,
      amount: (json['amount'] as num).toDouble(),
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      type: typeString == 'final'
          ? PayoutType.finalPayout
          : PayoutType.values.firstWhere(
              (e) => e.toString().split('.').last == typeString,
              orElse: () => PayoutType.regular,
            ),
      status: PayoutStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => PayoutStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'] as String)
          : null,
      transactionId: json['transactionId'] as String?,
      failureReason: json['failureReason'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'round': round,
      'recipientId': recipientId,
      'amount': amount,
      'scheduledDate': scheduledDate.toIso8601String(),
      'type': type == PayoutType.finalPayout
          ? 'final'
          : type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'transactionId': transactionId,
      'failureReason': failureReason,
      'metadata': metadata,
    };
  }

  PayoutSchedule copyWith({
    String? id,
    String? groupId,
    int? round,
    String? recipientId,
    double? amount,
    DateTime? scheduledDate,
    PayoutType? type,
    PayoutStatus? status,
    DateTime? createdAt,
    DateTime? processedAt,
    String? transactionId,
    String? failureReason,
    Map<String, dynamic>? metadata,
  }) {
    return PayoutSchedule(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      round: round ?? this.round,
      recipientId: recipientId ?? this.recipientId,
      amount: amount ?? this.amount,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      transactionId: transactionId ?? this.transactionId,
      failureReason: failureReason ?? this.failureReason,
      metadata: metadata ?? this.metadata,
    );
  }
}

@immutable
class WinnerSelectionResult {
  const WinnerSelectionResult({
    required this.groupId,
    required this.round,
    required this.selectedRecipient,
    required this.strategy,
    required this.eligibleMembers,
    required this.selectionTimestamp,
    required this.confidence,
    this.manualOverride = false,
    this.overrideReason,
    this.metadata = const {},
  });

  final String groupId;
  final int round;
  final String selectedRecipient;
  final String strategy; // 'random', 'fixed_order', 'admin_assigned', etc.
  final List<String> eligibleMembers;
  final DateTime selectionTimestamp;
  final double confidence; // 0.0-1.0
  final bool manualOverride;
  final String? overrideReason;
  final Map<String, dynamic> metadata;

  factory WinnerSelectionResult.fromJson(Map<String, dynamic> json) {
    return WinnerSelectionResult(
      groupId: json['groupId'] as String,
      round: json['round'] as int,
      selectedRecipient: json['selectedRecipient'] as String,
      strategy: json['strategy'] as String,
      eligibleMembers: List<String>.from(json['eligibleMembers'] as List),
      selectionTimestamp: DateTime.parse(json['selectionTimestamp'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      manualOverride: json['manualOverride'] as bool? ?? false,
      overrideReason: json['overrideReason'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'round': round,
      'selectedRecipient': selectedRecipient,
      'strategy': strategy,
      'eligibleMembers': eligibleMembers,
      'selectionTimestamp': selectionTimestamp.toIso8601String(),
      'confidence': confidence,
      'manualOverride': manualOverride,
      'overrideReason': overrideReason,
      'metadata': metadata,
    };
  }
}

@immutable
class FundDistributionPlan {
  const FundDistributionPlan({
    required this.groupId,
    required this.round,
    required this.totalPot,
    required this.recipientId,
    required this.distributionAmount,
    required this.feeAmount,
    required this.netAmount,
    required this.distributionMethod,
    required this.createdAt,
    this.reserveAmount = 0,
    this.reserveReason,
    this.metadata = const {},
  });

  final String groupId;
  final int round;
  final double totalPot;
  final String recipientId;
  final double distributionAmount;
  final double feeAmount;
  final double netAmount;
  final String distributionMethod; // 'wallet', 'bank_transfer', etc.
  final DateTime createdAt;
  final double reserveAmount;
  final String? reserveReason;
  final Map<String, dynamic> metadata;

  bool get hasReserve => reserveAmount > 0;
  double get totalAmount => netAmount + reserveAmount;

  factory FundDistributionPlan.fromJson(Map<String, dynamic> json) {
    return FundDistributionPlan(
      groupId: json['groupId'] as String,
      round: json['round'] as int,
      totalPot: (json['totalPot'] as num).toDouble(),
      recipientId: json['recipientId'] as String,
      distributionAmount: (json['distributionAmount'] as num).toDouble(),
      feeAmount: (json['feeAmount'] as num).toDouble(),
      netAmount: (json['netAmount'] as num).toDouble(),
      distributionMethod: json['distributionMethod'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      reserveAmount: (json['reserveAmount'] as num?)?.toDouble() ?? 0,
      reserveReason: json['reserveReason'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'round': round,
      'totalPot': totalPot,
      'recipientId': recipientId,
      'distributionAmount': distributionAmount,
      'feeAmount': feeAmount,
      'netAmount': netAmount,
      'distributionMethod': distributionMethod,
      'createdAt': createdAt.toIso8601String(),
      'reserveAmount': reserveAmount,
      'reserveReason': reserveReason,
      'metadata': metadata,
    };
  }
}

class PayoutProcessingResult {
  const PayoutProcessingResult({
    required this.success,
    required this.payoutSchedule,
    this.transactionId,
    this.errorMessage,
    this.metadata = const {},
  });

  final bool success;
  final PayoutSchedule payoutSchedule;
  final String? transactionId;
  final String? errorMessage;
  final Map<String, dynamic> metadata;
}

