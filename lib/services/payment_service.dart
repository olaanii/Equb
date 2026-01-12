import 'package:equb/models/transaction_model.dart';
import 'package:flutter/material.dart';

abstract class PaymentService {
  Future<TransactionModel> createPayment({
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String gateway,
    String? customerPhone,
    required BuildContext context,
  });

  Future<TransactionModel> verifyPayment(String transactionId);
}

/// Dummy implementation that simulates success/failure and logs transactions.
class DummyPaymentService implements PaymentService {
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
    final tx = TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      status: TransactionStatus.success,
      gateway: gateway,
    );
    // In real implementation, persist to ledger and return pending while awaiting webhook
    return tx;
  }

  @override
  Future<TransactionModel> verifyPayment(String transactionId) async {
    // simulate verification
    await Future.delayed(const Duration(milliseconds: 500));
    return TransactionModel(
      id: transactionId,
      fromUserId: 'system',
      toUserId: 'system',
      amount: 0,
      status: TransactionStatus.success,
    );
  }
}
