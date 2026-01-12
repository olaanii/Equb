import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:equb/models/transaction_model.dart';
import 'package:equb/services/secure_storage_service.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:firebase_database/firebase_database.dart';

const bool _kUseFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);

class PaymentRecoveryService {
  final FirebaseDatabase database;
  final FirebaseFunctions functions;
  final SecureStorageService secureStorage;
  final SystemLogService logService;

  final Map<String, DateTime> _attemptedAtByTxRef = {};

  PaymentRecoveryService({
    required this.database,
    required this.functions,
    required this.secureStorage,
    required this.logService,
  });

  Future<void> recoverLatestPendingChapaTx({required String userId}) async {
    final txRef = await _findLatestPendingChapaTxRef(userId: userId);
    if (txRef == null) return;

    if (!_shouldAttempt(txRef)) return;
    _attemptedAtByTxRef[txRef] = DateTime.now();

    try {
      final callable = functions.httpsCallable('chapaVerifyAndFinalize');

      final payload = <String, dynamic>{'txRef': txRef};
      if (_kUseFirebaseEmulators) {
        final secret = (await secureStorage.read('gateway.chapa.secretKey'))
            ?.trim();
        if (secret != null && secret.isNotEmpty) {
          payload['secretKey'] = secret;
        }
      }

      await callable.call(payload);

      logService.log(
        LogLevel.info,
        'payments.recovery',
        'Triggered server verification for pending Chapa tx',
        context: {'userId': userId, 'txRef': txRef},
      );
    } catch (e) {
      logService.log(
        LogLevel.warning,
        'payments.recovery',
        'Failed to verify pending Chapa tx',
        context: {'userId': userId, 'txRef': txRef, 'error': '$e'},
      );
    }
  }

  bool _shouldAttempt(String txRef) {
    final last = _attemptedAtByTxRef[txRef];
    if (last == null) return true;
    return DateTime.now().difference(last) > const Duration(minutes: 2);
  }

  Future<String?> _findLatestPendingChapaTxRef({required String userId}) async {
    try {
      final ref = database
          .ref('users/$userId/transactions')
          .limitToLast(50);
      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.value == null) return null;

      if (snapshot.value is! Map) return null;

      final raw = Map<Object?, Object?>.from(snapshot.value as Map);
      final transactions = <TransactionModel>[];

      for (final entry in raw.entries) {
        final key = entry.key?.toString();
        final value = entry.value;
        if (key == null || value is! Map) continue;

        final json = Map<String, dynamic>.from(value);
        json.putIfAbsent('id', () => key);

        try {
          transactions.add(TransactionModel.fromJson(json));
        } catch (_) {
          // Ignore malformed rows.
        }
      }

      final pending = transactions
          .where(
            (tx) =>
                tx.gateway == 'chapa' && tx.status == TransactionStatus.pending,
          )
          .toList();

      if (pending.isEmpty) return null;

      pending.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return pending.first.id;
    } catch (e) {
      logService.log(
        LogLevel.warning,
        'payments.recovery',
        'Failed to scan pending transactions',
        context: {'userId': userId, 'error': '$e'},
      );
      return null;
    }
  }
}
