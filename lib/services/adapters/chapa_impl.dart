import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:equb/models/transaction_model.dart';
import 'package:equb/services/adapters/chapa_sdk_bridge.dart';
import 'package:equb/services/payment_service.dart';
import 'package:equb/utils/money_mathematics.dart';
import 'package:equb/utils/open_url.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChapaImpl implements PaymentService {
  ChapaImpl({
    required this.secretKey,
    this.publicKey,
    this.initializeEndpoint,
    String? returnUrl,
    this.callbackUrl,
    this.currency = 'ETB',
  }) : returnUrl =
           (returnUrl?.trim().isNotEmpty == true)
               ? returnUrl!.trim()
               : _defaultReturnUrl;

  final String secretKey;
  final String? publicKey;
  final String? initializeEndpoint;
  final String returnUrl;
  final String? callbackUrl;
  final String currency;

  static const String _defaultReturnUrl = 'https://chapa.co';

  @override
  Future<TransactionModel> createPayment({
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String gateway,
    String? customerPhone,
    required BuildContext context,
  }) async {
    final txRef = _uniqueId(fromUserId);

    final feeAmount = MoneyMathematics.calculateFee(amount);
    final netAmount = amount - feeAmount;

    final pendingTx = TransactionModel(
      id: txRef,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      status: TransactionStatus.pending,
      gateway: gateway,
      feeAmount: feeAmount,
      netAmount: netAmount,
    );

    // Persist the pending transaction so it can be confirmed server-side.
    // Webhooks/callback verification will update this record to success/failed.
    try {
      final txRefDb = FirebaseDatabase.instance.ref(
        'users/$fromUserId/transactions/$txRef',
      );
      final nowMs = ServerValue.timestamp;
      await txRefDb.set(
        pendingTx.toJson()
          ..['timestampMs'] = nowMs
          ..['verificationStatus'] = 'pending',
      );
    } catch (_) {
      // Don't block checkout if local persistence fails; server verification
      // may still succeed but user history might be missing.
    }

    if (!context.mounted) {
      return pendingTx;
    }

    final endpoint =
        (initializeEndpoint?.trim().isNotEmpty == true)
            ? initializeEndpoint!.trim()
            : 'https://api.chapa.co/v1/transaction/initialize';

    final auth = FirebaseAuth.instance;
    final email = (auth.currentUser?.email ?? '').trim();

    // Chapa requires an email. Prefer the signed-in user's real email if
    // available; otherwise, use a deterministic placeholder.
    final effectiveEmail =
        email.isNotEmpty ? email : 'noemail+$fromUserId@equb.local';

    // Prefer the official Chapa Flutter SDK on Android/iOS (native checkout),
    // when a public key is available. The SDK is not web-safe.
    final pk = (publicKey ?? '').trim();
    final phone = (customerPhone ?? '').trim();
    if (!kIsWeb && pk.isNotEmpty && phone.isNotEmpty) {
      try {
        await startChapaCheckoutWithSdk(
          context: context,
          publicKey: pk,
          currency: currency,
          amount: amount.toStringAsFixed(2),
          email: effectiveEmail,
          phone: phone,
          firstName: fromUserId,
          lastName: toUserId,
          txRef: txRef,
          title: toUserId == 'wallet' ? 'Wallet top up' : 'Payment',
          description: 'Equb payment',
        );
        return pendingTx;
      } catch (_) {
        // Fall back to the hosted initialize flow below.
      }
    }

    final body = <String, dynamic>{
      'amount': amount.toStringAsFixed(2),
      'currency': currency,
      'email': effectiveEmail,
      'first_name': fromUserId,
      'last_name': toUserId,
      'tx_ref': txRef,
      'return_url': returnUrl,
      if (callbackUrl != null && callbackUrl!.trim().isNotEmpty)
        'callback_url': callbackUrl!.trim(),
      if ((customerPhone ?? '').trim().isNotEmpty)
        'phone_number': customerPhone!.trim(),
    };

    String checkoutUrl = '';

    // Use Firebase callable initialize when:
    // - running on web (CORS), OR
    // - secret key isn't available on device (we keep it server-side).
    final shouldUseCallableInitialize = kIsWeb || secretKey.trim().isEmpty;

    if (shouldUseCallableInitialize) {
      const useEmulators = bool.fromEnvironment(
        'USE_FIREBASE_EMULATORS',
        defaultValue: false,
      );

      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'chapaInitializePayment',
          options: HttpsCallableOptions(timeout: Duration(seconds: 90)),
        );

        final result = await callable.call(<String, dynamic>{
          'amount': amount,
          'currency': currency,
          'txRef': txRef,
          'returnUrl': returnUrl,
          if (callbackUrl != null && callbackUrl!.trim().isNotEmpty)
            'callbackUrl': callbackUrl!.trim(),
          'email': effectiveEmail,
          'firstName': fromUserId,
          'lastName': toUserId,
          if ((customerPhone ?? '').trim().isNotEmpty)
            'phoneNumber': customerPhone!.trim(),
          if (useEmulators && secretKey.trim().isNotEmpty)
            'secretKey': secretKey,
        });

        final data = result.data;
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          checkoutUrl = (map['checkoutUrl'] as String?)?.trim() ?? '';
        }
      } catch (e) {
        if (e is FirebaseFunctionsException) {
          final msg =
              (e.message?.trim().isNotEmpty == true) ? e.message!.trim() : '';
          throw Exception(
            'Chapa intent failed via Firebase callable `chapaInitializePayment` '
            '(${useEmulators ? 'emulator' : 'deployed'}). '
            'code=${e.code}${msg.isNotEmpty ? ' $msg' : ''}',
          );
        }

        throw Exception(
          'Chapa intent failed via Firebase callable `chapaInitializePayment`. Details: $e',
        );
      }
    }

    if (shouldUseCallableInitialize && checkoutUrl.isEmpty) {
      throw Exception(
        'Payment initialization requires the Firebase callable `chapaInitializePayment`. '
        'No checkoutUrl was returned.',
      );
    }

    if (checkoutUrl.isEmpty) {
      final sk = secretKey.trim();
      if (sk.isEmpty) {
        throw Exception(
          'Chapa secretKey is required for direct hosted checkout initialization. '
          'Configure the Cloud Function `chapaInitializePayment` with the server-side secret, '
          'or use the SDK with `gateway.chapa.publicKey`.',
        );
      }
      late final http.Response resp;
      try {
        resp = await http
            .post(
              Uri.parse(endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $sk',
              },
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        if (kIsWeb) {
          throw Exception(
            'Payment from web browser failed (network/CORS). '
            'Deploy the Firebase callable `chapaInitializePayment` to proxy this request. '
            'Details: $e',
          );
        }
        rethrow;
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(resp.body);
      } catch (_) {
        decoded = null;
      }

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        final message =
            (decoded is Map && decoded['message'] is String)
                ? (decoded['message'] as String).trim()
                : '';
        throw Exception(
          'Chapa payment init failed: ${resp.statusCode}${message.isNotEmpty ? ' $message' : ''}',
        );
      }

      if (decoded is Map) {
        final data = decoded['data'];
        if (data is Map) {
          checkoutUrl = (data['checkout_url'] as String?)?.trim() ?? '';
        }
      }

      if (checkoutUrl.isEmpty) {
        throw Exception('Chapa response missing checkout_url');
      }
    }

    // Open Chapa checkout in the browser.
    await openUrl(checkoutUrl);

    return pendingTx;
  }

  @override
  Future<TransactionModel> verifyPayment(String transactionId) async {
    // Verification is typically done server-side (webhook/verify endpoint).
    // For now, keep as pending.
    return TransactionModel(
      id: transactionId,
      fromUserId: 'system',
      toUserId: 'system',
      amount: 0,
      status: TransactionStatus.pending,
    );
  }

  String _uniqueId(String userId) {
    final ms = DateTime.now().millisecondsSinceEpoch;
    // Encode userId into the txRef so server-side webhook can locate
    // the user's transaction record without a separate index.
    return 'chapa~$userId~$ms';
  }
}
