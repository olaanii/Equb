import 'package:equb/models/transaction_model.dart';
import 'package:equb/services/payment_service.dart';
import 'package:flutter/material.dart';

class CbeAdapter implements PaymentService {
  final Map<String, dynamic> config;
  CbeAdapter(this.config);

  @override
  Future<TransactionModel> createPayment({
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String gateway,
    String? customerPhone,
    required BuildContext context,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      status: TransactionStatus.pending,
      gateway: 'cbe_birr',
    );
  }

  @override
  Future<TransactionModel> verifyPayment(String transactionId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return TransactionModel(
      id: transactionId,
      fromUserId: 'system',
      toUserId: 'system',
      amount: 0,
      status: TransactionStatus.success,
      gateway: 'cbe_birr',
    );
  }
}
