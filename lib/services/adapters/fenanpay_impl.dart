import 'dart:convert';

import 'package:equb/models/transaction_model.dart';
import 'package:equb/services/payment_service.dart';
import 'package:equb/ui/screens/payment/fenanpay_checkout_screen.dart';
import 'package:equb/utils/open_url.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FenanPayImpl implements PaymentService {
  FenanPayImpl({
    required this.apiKey,
    this.intentEndpoint,
    String? returnUrl,
    this.callbackUrl,
    this.expireInSeconds = 3600,
    this.commissionPaidByCustomer = false,
    this.methods = const <String>[],
    this.currency = 'ETB',
  }) : returnUrl = (returnUrl?.trim().isNotEmpty == true)
            ? returnUrl!.trim()
            : _defaultReturnUrl;

  final String apiKey;
  final String? intentEndpoint;
  final String returnUrl;
  final String? callbackUrl;
  final int expireInSeconds;
  final bool commissionPaidByCustomer;
  final List<String> methods;
  final String currency;

  static const String _defaultReturnUrl = 'https://fenanpay.com';

  @override
  Future<TransactionModel> createPayment({
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String gateway,
    required BuildContext context,
  }) async {
    final paymentIntentUniqueId = _uniqueId();

    final pendingTx = TransactionModel(
      id: paymentIntentUniqueId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      status: TransactionStatus.pending,
      gateway: gateway,
    );

    final endpoint = intentEndpoint?.trim().isNotEmpty == true
        ? intentEndpoint!.trim()
        : 'https://api.fenanpay.com/api/v1/payment/sandbox/intent';

    final body = <String, dynamic>{
      'amount': amount,
      'currency': currency,
      'paymentIntentUniqueId': paymentIntentUniqueId,
      'methods': methods,
      'returnUrl': returnUrl,
      'expireIn': expireInSeconds,
      'commissionPaidByCustomer': commissionPaidByCustomer,
      // optional
      if (callbackUrl != null && callbackUrl!.trim().isNotEmpty)
        'callbackUrl': callbackUrl!.trim(),
      'customerInfo': {
        'name': fromUserId,
      },
    };

    // Web browsers often block cross-origin POSTs to third-party APIs due to
    // CORS. Prefer a Firebase callable proxy (server-side) on web.
    String checkoutUrl = '';
    if (kIsWeb) {
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'fenanpayCreateIntent',
        );
        final result = await callable.call(<String, dynamic>{
          'amount': amount,
          'currency': currency,
          'paymentIntentUniqueId': paymentIntentUniqueId,
          'methods': methods,
          'returnUrl': returnUrl,
          'expireIn': expireInSeconds,
          'commissionPaidByCustomer': commissionPaidByCustomer,
          if (callbackUrl != null && callbackUrl!.trim().isNotEmpty)
            'callbackUrl': callbackUrl!.trim(),
        });

        final data = result.data;
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          checkoutUrl = (map['checkoutUrl'] as String?)?.trim() ?? '';
        }
      } catch (_) {
        // Fall back to direct call (may still fail with CORS, but keeps mobile
        // behavior and supports environments without the callable deployed).
        checkoutUrl = '';
      }
    }

    if (checkoutUrl.isEmpty) {
      late final http.Response resp;
      try {
        resp = await http
            .post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json',
                'apiKey': apiKey,
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 12));
      } catch (e) {
        if (kIsWeb) {
          throw Exception(
            'Top up from web browser failed (network/CORS). '
            'Deploy the Firebase callable `fenanpayCreateIntent` to proxy this request, '
            'or run on Android/iOS. Details: $e',
          );
        }
        rethrow;
      }

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception(
          'FenanPay intent failed: ${resp.statusCode} ${resp.body}',
        );
      }

      final decoded = jsonDecode(resp.body);
      checkoutUrl = _extractCheckoutUrl(decoded);
    }
    if (checkoutUrl.isEmpty) {
      throw Exception('FenanPay response missing checkout URL');
    }

    // On Flutter web, avoid webview and do a hard navigation.
    if (kIsWeb) {
      await openUrl(checkoutUrl);
      return pendingTx;
    }

    if (!context.mounted) {
      return pendingTx;
    }

    // Open hosted checkout inside WebView. We treat completion as pending and
    // rely on webhook/callback integration for final settlement.
    await Navigator.of(context).push<FenanPayCheckoutResult?>(
      MaterialPageRoute(
        builder: (_) => FenanPayCheckoutScreen(
          checkoutUrl: checkoutUrl,
          returnUrl: returnUrl,
        ),
      ),
    );

    return pendingTx;
  }

  @override
  Future<TransactionModel> verifyPayment(String transactionId) async {
    // FenanPay verification is typically done via webhook/callback. If you
    // add a status endpoint later, implement it here.
    return TransactionModel(
      id: transactionId,
      fromUserId: 'unknown',
      toUserId: 'unknown',
      amount: 0,
      status: TransactionStatus.pending,
      gateway: 'fenanpay',
    );
  }

  String _uniqueId() {
    // Unique enough for sandbox/testing.
    final ms = DateTime.now().millisecondsSinceEpoch;
    return 'fenan-$ms';
  }

  String _extractCheckoutUrl(dynamic decoded) {
    if (decoded is! Map) return '';
    final root = Map<String, dynamic>.from(decoded);

    // Common patterns:
    // - { content: "https://..." }
    // - { content: { checkoutUrl: "https://..." } }
    // - { content: { url: "https://..." } }
    final content = root['content'];
    if (content is String) {
      return content.trim();
    }

    if (content is Map) {
      final map = Map<String, dynamic>.from(content);
      for (final key in const <String>[
        'checkoutUrl',
        'checkout_url',
        'url',
        'redirectUrl',
        'redirect_url',
        'paymentUrl',
        'payment_url',
      ]) {
        final v = map[key];
        if (v is String && v.trim().isNotEmpty) {
          return v.trim();
        }
      }
    }

    // Fallback: sometimes the root includes a direct url field.
    for (final key in const <String>[
      'checkoutUrl',
      'url',
      'redirectUrl',
      'paymentUrl',
    ]) {
      final v = root[key];
      if (v is String && v.trim().isNotEmpty) {
        return v.trim();
      }
    }

    return '';
  }
}
