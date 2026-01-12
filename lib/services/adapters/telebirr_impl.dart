import 'package:equb/models/transaction_model.dart';
import 'package:equb/services/payment_service.dart';
import 'package:equb/services/telebirr_api_service.dart';
import 'package:flutter/material.dart';
import 'package:equb/ui/screens/payment/telebirr_payment_screen.dart';

class TelebirrImpl implements PaymentService {
  TelebirrImpl({
    required String baseUrl,
    required String apiKey,
    String? privateKeyPem,
    Duration? requestTimeout,
    String? callbackUrl,
    String? authUrl,
    String? authClientId,
    String? authClientSecret,
    Map<String, String>? authHeaders,
    Map<String, dynamic>? authPayloadOverrides,
    String? authGrantType,
    String? tokenFieldOverride,
    String? expiresInFieldOverride,
    String? expiresAtFieldOverride,
    Duration? tokenClockSkew,
    bool includeApiKeyInAuth = true,
  }) : _apiService = TelebirrApiService(
         baseUrl: baseUrl,
         apiKey: apiKey,
         privateKeyPem: privateKeyPem,
         requestTimeout: requestTimeout ?? const Duration(seconds: 12),
         authUrl: authUrl,
         authClientId: authClientId,
         authClientSecret: authClientSecret,
         authHeaders: authHeaders ?? const <String, String>{},
         authPayloadOverrides:
             authPayloadOverrides ?? const <String, dynamic>{},
         authGrantType: authGrantType,
         tokenFieldOverride: tokenFieldOverride,
         expiresInFieldOverride: expiresInFieldOverride,
         expiresAtFieldOverride: expiresAtFieldOverride,
         tokenClockSkew: tokenClockSkew ?? const Duration(seconds: 30),
         includeApiKeyInAuth: includeApiKeyInAuth,
       ),
       _callbackUri = Uri.tryParse(callbackUrl ?? '') ?? _defaultCallbackUri;

  final TelebirrApiService _apiService;
  final Uri _callbackUri;

  static final Uri _defaultCallbackUri = Uri.parse(
    'app://equb/payments/telebirr',
  );

  @override
  Future<TransactionModel> createPayment({
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String gateway,
    String? customerPhone,
    required BuildContext context,
  }) async {
    final merchantOrderId = DateTime.now().millisecondsSinceEpoch.toString();
    // Prepare a pending transaction as a safe fallback if the caller
    // widget is disposed while we perform network work.
    final pendingTx = TransactionModel(
      id: merchantOrderId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      status: TransactionStatus.pending,
      gateway: gateway,
    );

    final response = await _apiService.createOrder(
      fromUserId: fromUserId,
      amount: amount,
      merchantOrderId: merchantOrderId,
      callbackUrl: _callbackUri.toString(),
    );

    // If the widget that initiated the payment has been disposed, abort and
    // return a pending transaction to avoid using a stale BuildContext.
    if (!context.mounted) {
      return pendingTx;
    }

    final prepayId = response['prepayId'] as String?;
    if (prepayId == null || prepayId.isEmpty) {
      throw Exception(
        'Telebirr response missing prepayId for order $merchantOrderId',
      );
    }
    final paymentUrl = _apiService.buildCheckoutUri(prepayId).toString();

    final result = await Navigator.push<TelebirrPaymentResult?>(
      context,
      MaterialPageRoute(
        builder:
            (context) => TelebirrPaymentScreen(
              paymentUrl: paymentUrl,
              callbackUri: _callbackUri,
              merchantOrderId: merchantOrderId,
            ),
      ),
    );

    if (result == null) {
      return pendingTx;
    }

    switch (result.status) {
      case TelebirrPaymentStatus.success:
        try {
          return await verifyPayment(result.merchantOrderId ?? merchantOrderId);
        } catch (_) {
          return TransactionModel(
            id: merchantOrderId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            amount: amount,
            status: TransactionStatus.success,
            gateway: gateway,
          );
        }
      case TelebirrPaymentStatus.failure:
        return TransactionModel(
          id: merchantOrderId,
          fromUserId: fromUserId,
          toUserId: toUserId,
          amount: amount,
          status: TransactionStatus.failed,
          gateway: gateway,
        );
      case TelebirrPaymentStatus.cancelled:
        return pendingTx;
    }
  }

  @override
  Future<TransactionModel> verifyPayment(String transactionId) async {
    final response = await _apiService.queryOrder(transactionId);
    final status = (response['status'] as String?)?.toLowerCase() ?? 'pending';
    final txStatus =
        status == 'success' || status == 'completed'
            ? TransactionStatus.success
            : (status == 'failed'
                ? TransactionStatus.failed
                : TransactionStatus.pending);

    return TransactionModel(
      id: transactionId,
      fromUserId: response['payer']?['id'] ?? 'unknown',
      toUserId: response['payee']?['id'] ?? 'unknown',
      amount: (response['amount'] as num?)?.toDouble() ?? 0.0,
      status: txStatus,
      gateway: 'telebirr',
    );
  }
}
