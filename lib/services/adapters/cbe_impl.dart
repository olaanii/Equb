import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:equb/models/transaction_model.dart';
import 'package:equb/services/payment_service.dart';
import 'package:flutter/material.dart';

class CbeImpl implements PaymentService {
  final String baseUrl;
  final String clientId;
  final String clientSecret;

  CbeImpl({
    required this.baseUrl,
    required this.clientId,
    required this.clientSecret,
  });

  Future<String> _getAccessToken() async {
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/oauth/token'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'grant_type': 'client_credentials',
              'client_id': clientId,
              'client_secret': clientSecret,
            },
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        return data['access_token'];
      }
      throw Exception('CBE token failure: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      throw Exception('CBE token error: $e');
    }
  }

  @override
  Future<TransactionModel> createPayment({
    required String fromUserId,
    required String toUserId,
    required double amount,
    required String gateway,
    String? customerPhone,
    required BuildContext context,
  }) async {
    final token = await _getAccessToken();
    final body = jsonEncode({
      'orderId': DateTime.now().millisecondsSinceEpoch.toString(),
      'amount': amount,
      'payerId': fromUserId,
      'payeeId': toUserId,
    });
    try {
      final resp = await http
          .post(
            Uri.parse('$baseUrl/payments'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        final id =
            data['orderId'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        return TransactionModel(
          id: id,
          fromUserId: fromUserId,
          toUserId: toUserId,
          amount: amount,
          status: TransactionStatus.pending,
          gateway: 'cbe_birr',
        );
      }
      throw Exception(
        'CBE createPayment failed: ${resp.statusCode} ${resp.body}',
      );
    } catch (e) {
      throw Exception('CBE createPayment error: $e');
    }
  }

  @override
  Future<TransactionModel> verifyPayment(String transactionId) async {
    final token = await _getAccessToken();
    try {
      final resp = await http
          .get(
            Uri.parse('$baseUrl/payments/$transactionId'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body);
        final state = (data['state'] as String?)?.toLowerCase() ?? 'pending';
        final txStatus =
            state == 'completed'
                ? TransactionStatus.success
                : (state == 'failed'
                    ? TransactionStatus.failed
                    : TransactionStatus.pending);
        return TransactionModel(
          id: transactionId,
          fromUserId: data['payerId'] ?? 'unknown',
          toUserId: data['payeeId'] ?? 'unknown',
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          status: txStatus,
          gateway: 'cbe_birr',
        );
      }
      throw Exception('CBE verify failed: ${resp.statusCode} ${resp.body}');
    } catch (e) {
      throw Exception('CBE verify error: $e');
    }
  }
}
