import 'package:equb/utils/firestore_helpers.dart';

enum TransactionStatus { pending, success, failed }

class TransactionModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final double amount;
  final DateTime timestamp;
  final TransactionStatus status;
  final String gateway; // e.g., telebirr, cbe_birr
  final double feeAmount;
  final double netAmount;
  final String? screenshotUrl;
  final TransactionStatus verificationStatus;

  TransactionModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    DateTime? timestamp,
    this.status = TransactionStatus.pending,
    this.gateway = 'unknown',
    this.feeAmount = 0.0,
    double? netAmount,
    this.screenshotUrl,
    TransactionStatus? verificationStatus,
  }) : timestamp = timestamp ?? DateTime.now(),
       netAmount = netAmount ?? amount,
       verificationStatus = verificationStatus ?? status;

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      fromUserId: json['fromUserId'] as String,
      toUserId: json['toUserId'] as String,
      amount: (json['amount'] as num).toDouble(),
      timestamp: FirestoreHelpers.parseDateTime(json['timestamp']),
      status: TransactionStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => TransactionStatus.pending,
      ),
      gateway: json['gateway'] as String? ?? 'unknown',
      feeAmount: (json['feeAmount'] as num?)?.toDouble() ?? 0.0,
      netAmount:
          (json['netAmount'] as num?)?.toDouble() ??
          (json['amount'] as num).toDouble(),
      screenshotUrl: json['screenshotUrl'] as String?,
      verificationStatus:
          json['verificationStatus'] != null
              ? TransactionStatus.values.firstWhere(
                (e) =>
                    e.toString().split('.').last == json['verificationStatus'],
                orElse: () => TransactionStatus.pending,
              )
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'status': status.toString().split('.').last,
      'gateway': gateway,
      'feeAmount': feeAmount,
      'netAmount': netAmount,
      'screenshotUrl': screenshotUrl,
      'verificationStatus': verificationStatus.toString().split('.').last,
    };
  }

  TransactionModel copyWith({
    String? id,
    String? fromUserId,
    String? toUserId,
    double? amount,
    DateTime? timestamp,
    TransactionStatus? status,
    String? gateway,
    double? feeAmount,
    double? netAmount,
    String? screenshotUrl,
    TransactionStatus? verificationStatus,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      fromUserId: fromUserId ?? this.fromUserId,
      toUserId: toUserId ?? this.toUserId,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      gateway: gateway ?? this.gateway,
      feeAmount: feeAmount ?? this.feeAmount,
      netAmount: netAmount ?? this.netAmount,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
    );
  }
}
