import 'package:equb/models/transaction_model.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/models/user_notification.dart';
import 'package:equb/services/repository_exception.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:equb/utils/money_mathematics.dart';
import 'package:firebase_database/firebase_database.dart';

import 'wallet_repository.dart';

class RtdbWalletRepository implements WalletRepository {
  RtdbWalletRepository({
    FirebaseDatabase? database,
    SystemLogService? logService,
  }) : _db = database ?? FirebaseDatabase.instance,
       _logService = logService;

  final FirebaseDatabase _db;
  final SystemLogService? _logService;

  DatabaseReference get _usersRef => _db.ref('users');

  DatabaseReference _userRef(String userId) => _usersRef.child(userId);

  DatabaseReference _txRef(String userId) => _userRef(userId).child('transactions');

  Future<void> approvePendingDeposit(String userId, String txId) async {
    try {
      final nowMs = ServerValue.timestamp;
      final pointsLedgerId = _userRef(userId).child('points_ledger').push().key;
      final notificationId = _userRef(userId).child('notifications').push().key;

      final result = await _userRef(userId).runTransaction((currentData) {
        if (currentData == null || currentData is! Map) {
          return Transaction.abort();
        }

        final data = Map<String, dynamic>.from(currentData);
        final transactions =
            (data['transactions'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        final txRaw = transactions[txId];
        if (txRaw == null || txRaw is! Map) {
          return Transaction.abort();
        }

        final tx = Map<String, dynamic>.from(txRaw);
        final status = tx['status']?.toString();
        if (status == 'success') {
          return Transaction.success(data);
        }
        if (status != 'pending') {
          return Transaction.abort();
        }

        final netAmount = (tx['netAmount'] as num?)?.toDouble();
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final fee = (tx['feeAmount'] as num?)?.toDouble();
        if (netAmount == null) {
          return Transaction.abort();
        }

        final currentBalance =
            (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
        final currentPoints = (data['points'] as int?) ?? 0;
        final points = MoneyMathematics.calculatePoints(amount, 'deposit');

        data['walletBalance'] = currentBalance + netAmount;
        data['points'] = currentPoints + points;

        tx['status'] = 'success';
        tx['approvedAtMs'] = nowMs;
        tx['approvedBy'] = userId;
        transactions[txId] = tx;
        data['transactions'] = transactions;

        if (pointsLedgerId != null && pointsLedgerId.isNotEmpty && points > 0) {
          final ledger =
              (data['points_ledger'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
          ledger[pointsLedgerId] = <String, dynamic>{
            'delta': points,
            'action': 'deposit_approved',
            'createdAtMs': nowMs,
            'relatedTransactionId': txId,
            'metadata': <String, dynamic>{
              'amount': amount,
              'fee': fee,
              'net': netAmount,
            },
          };
          data['points_ledger'] = ledger;
        }

        if (notificationId != null && notificationId.isNotEmpty) {
          final notifications =
              (data['notifications'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
          notifications[notificationId] = <String, dynamic>{
            'id': notificationId,
            'userId': userId,
            'title': 'Deposit approved',
            'body':
                'Your deposit of ETB ${amount.toStringAsFixed(2)} has been approved.',
            'type': 'success',
            'isRead': false,
            'createdAt': DateTime.now().toIso8601String(),
            'createdAtMs': nowMs,
            'metadata': <String, dynamic>{'transactionId': txId},
          };
          data['notifications'] = notifications;
        }

        return Transaction.success(data);
      });

      if (!result.committed) {
        throw RepositoryException(
          code: 'not-committed',
          message: 'Unable to approve pending deposit',
        );
      }
    } catch (e) {
      _logService?.log(
        LogLevel.error,
        'RtdbWalletRepository.approvePendingDeposit',
        'Approval failed',
        context: {'userId': userId, 'txId': txId, 'error': e.toString()},
      );
      if (e is RepositoryException) rethrow;
      throw RepositoryException(
        code: 'approval-failed',
        message: 'Unable to approve deposit',
        cause: e,
      );
    }
  }

  Future<void> rejectPendingDeposit(
    String userId,
    String txId, {
    String? reason,
  }) async {
    try {
      final nowMs = ServerValue.timestamp;
      final notificationId = _userRef(userId).child('notifications').push().key;

      final result = await _userRef(userId).runTransaction((currentData) {
        if (currentData == null || currentData is! Map) {
          return Transaction.abort();
        }

        final data = Map<String, dynamic>.from(currentData);
        final transactions =
            (data['transactions'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        final txRaw = transactions[txId];
        if (txRaw == null || txRaw is! Map) {
          return Transaction.abort();
        }

        final tx = Map<String, dynamic>.from(txRaw);
        final status = tx['status']?.toString();
        if (status == 'failed') {
          return Transaction.success(data);
        }
        if (status != 'pending') {
          return Transaction.abort();
        }

        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        tx['status'] = 'failed';
        tx['rejectedAtMs'] = nowMs;
        tx['rejectedBy'] = userId;
        if (reason != null && reason.trim().isNotEmpty) {
          tx['rejectionReason'] = reason.trim();
        }

        transactions[txId] = tx;
        data['transactions'] = transactions;

        if (notificationId != null && notificationId.isNotEmpty) {
          final notifications =
              (data['notifications'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
          notifications[notificationId] = <String, dynamic>{
            'id': notificationId,
            'userId': userId,
            'title': 'Deposit rejected',
            'body':
                'Your deposit of ETB ${amount.toStringAsFixed(2)} was rejected.',
            'type': 'error',
            'isRead': false,
            'createdAt': DateTime.now().toIso8601String(),
            'createdAtMs': nowMs,
            'metadata': <String, dynamic>{
              'transactionId': txId,
              if (reason != null && reason.trim().isNotEmpty)
                'reason': reason.trim(),
            },
          };
          data['notifications'] = notifications;
        }

        return Transaction.success(data);
      });

      if (!result.committed) {
        throw RepositoryException(
          code: 'not-committed',
          message: 'Unable to reject pending deposit',
        );
      }
    } catch (e) {
      _logService?.log(
        LogLevel.error,
        'RtdbWalletRepository.rejectPendingDeposit',
        'Rejection failed',
        context: {
          'userId': userId,
          'txId': txId,
          'reason': reason,
          'error': e.toString(),
        },
      );
      if (e is RepositoryException) rethrow;
      throw RepositoryException(
        code: 'rejection-failed',
        message: 'Unable to reject deposit',
        cause: e,
      );
    }
  }

  String _notificationType(NotificationType type) =>
      type.toString().split('.').last;

  @override
  Future<TransactionModel> deposit(
    String userId,
    double amount,
    String gateway, {
    String? screenshotUrl,
  }) async {
    final isManual = screenshotUrl != null;
    try {
      final fee = MoneyMathematics.calculateFee(amount);
      final net = amount - fee;
      final points = MoneyMathematics.calculatePoints(amount, 'deposit');

      final txId = _txRef(userId).push().key;
      if (txId == null || txId.isEmpty) {
        throw RepositoryException(code: 'id-generation-failed', message: 'Failed to generate transaction id');
      }

      final tx = TransactionModel(
        id: txId,
        fromUserId: userId,
        toUserId: 'wallet',
        amount: amount,
        status: isManual ? TransactionStatus.pending : TransactionStatus.success,
        gateway: gateway,
        timestamp: DateTime.now(),
        feeAmount: fee,
        netAmount: net,
        screenshotUrl: screenshotUrl,
      );

      final nowMs = ServerValue.timestamp;
      final payload = tx.toJson()
        ..['timestampMs'] = nowMs
        ..['requiresReview'] = isManual;

      final notificationId = _userRef(userId).child('notifications').push().key;
      final pointsLedgerId = !isManual && points > 0
          ? _userRef(userId).child('points_ledger').push().key
          : null;

      final result = await _userRef(userId).runTransaction((currentData) {
        if (currentData == null || currentData is! Map) {
          return Transaction.abort();
        }

        final data = Map<String, dynamic>.from(currentData);
        final currentBalance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
        final currentPoints = (data['points'] as int?) ?? 0;

        final updatedBalance = isManual ? currentBalance : (currentBalance + net);
        final updatedPoints =
            isManual ? currentPoints : (currentPoints + points);

        data['walletBalance'] = updatedBalance;
        data['points'] = updatedPoints;

        final transactions = (data['transactions'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        transactions[txId] = payload;
        data['transactions'] = transactions;

        if (pointsLedgerId != null) {
          final ledger = (data['points_ledger'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
          ledger[pointsLedgerId] = <String, dynamic>{
            'delta': points,
            'action': 'deposit',
            'createdAtMs': nowMs,
            'relatedTransactionId': txId,
            'metadata': <String, dynamic>{
              'amount': amount,
              'fee': fee,
              'net': net,
              'gateway': gateway,
              'manual': isManual,
            },
          };
          data['points_ledger'] = ledger;
        }

        if (notificationId != null) {
          final notifications =
              (data['notifications'] as Map?)?.cast<String, dynamic>() ??
                  <String, dynamic>{};

          notifications[notificationId] = <String, dynamic>{
            'id': notificationId,
            'userId': userId,
            'title': isManual ? 'Deposit submitted' : 'Deposit successful',
            'body':
                isManual
                    ? 'Your deposit is pending review.'
                    : 'Your wallet was credited.',
            'type': _notificationType(NotificationType.transaction),
            'isRead': false,
            'createdAt': DateTime.now().toIso8601String(),
            'createdAtMs': nowMs,
            'metadata': <String, dynamic>{
              'transactionId': txId,
              'amount': amount,
              'fee': fee,
              'net': net,
              'gateway': gateway,
              'status': isManual ? 'pending' : 'success',
            },
          };

          data['notifications'] = notifications;
        }

        return Transaction.success(data);
      });

      if (!result.committed) {
        throw RepositoryException(code: 'user-not-found', message: 'User $userId not found');
      }

      // For manual deposits, also enqueue for admin review.
      if (isManual) {
        final queueId = '${userId}_$txId';
        try {
          await _db.ref('review_queue/deposits/$queueId').set({
            'id': queueId,
            'userId': userId,
            'txId': txId,
            'amount': amount,
            'feeAmount': fee,
            'netAmount': net,
            'gateway': gateway,
            'screenshotUrl': screenshotUrl,
            'status': 'pending',
            'createdAtMs': ServerValue.timestamp,
          });
        } catch (e) {
          // Don't fail the deposit creation if queue write fails.
          _logService?.log(
            LogLevel.warning,
            'RtdbWalletRepository.deposit',
            'Failed to enqueue manual deposit for review',
            context: {'userId': userId, 'txId': txId, 'error': e.toString()},
          );
        }
      }

      return tx;
    } catch (e) {
      _logService?.log(
        LogLevel.error,
        'RtdbWalletRepository.deposit',
        'Deposit failed',
        context: {'userId': userId, 'error': e.toString()},
      );
      if (e is RepositoryException) rethrow;
      throw RepositoryException(code: 'deposit-failed', message: 'Deposit failed', cause: e);
    }
  }

  @override
  Future<WalletSummary> getWalletSummary(String userId) async {
    try {
      final snapshot = await _userRef(userId).get();
      if (!snapshot.exists || snapshot.value == null) {
        return const WalletSummary(available: 0);
      }
      final raw = snapshot.value;
      if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        final balance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
        return WalletSummary(available: balance);
      }
      return const WalletSummary(available: 0);
    } catch (e) {
      _logService?.log(
        LogLevel.warning,
        'RtdbWalletRepository.getWalletSummary',
        'Failed to load wallet summary',
        context: {'userId': userId, 'error': e.toString()},
      );
      return const WalletSummary(available: 0);
    }
  }

  @override
  Future<void> withdraw(String userId, double amount, String destination) async {
    try {
      final txId = _txRef(userId).push().key;
      if (txId == null || txId.isEmpty) {
        throw RepositoryException(code: 'id-generation-failed', message: 'Failed to generate transaction id');
      }

      final tx = TransactionModel(
        id: txId,
        fromUserId: userId,
        toUserId: destination,
        amount: amount,
        status: TransactionStatus.success,
        gateway: 'withdrawal',
        timestamp: DateTime.now(),
      );

      final nowMs = ServerValue.timestamp;
      final payload = tx.toJson()..['timestampMs'] = nowMs;

      final notificationId = _userRef(userId).child('notifications').push().key;

      final result = await _userRef(userId).runTransaction((currentData) {
        if (currentData == null || currentData is! Map) {
          return Transaction.abort();
        }

        final data = Map<String, dynamic>.from(currentData);
        final currentBalance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
        if (currentBalance + 1e-9 < amount) {
          // Abort so callers see a non-committed result.
          return Transaction.abort();
        }

        data['walletBalance'] = currentBalance - amount;

        final transactions = (data['transactions'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
        transactions[txId] = payload;
        data['transactions'] = transactions;

        if (notificationId != null) {
          final notifications =
              (data['notifications'] as Map?)?.cast<String, dynamic>() ??
                  <String, dynamic>{};

          notifications[notificationId] = <String, dynamic>{
            'id': notificationId,
            'userId': userId,
            'title': 'Withdrawal successful',
            'body': 'Funds were withdrawn from your wallet.',
            'type': _notificationType(NotificationType.transaction),
            'isRead': false,
            'createdAt': DateTime.now().toIso8601String(),
            'createdAtMs': nowMs,
            'metadata': <String, dynamic>{
              'transactionId': txId,
              'amount': amount,
              'destination': destination,
              'status': 'success',
            },
          };

          data['notifications'] = notifications;
        }

        return Transaction.success(data);
      });

      if (!result.committed) {
        // Could be missing user OR insufficient funds.
        // Re-check quickly for clearer error.
        final snapshot = await _userRef(userId).get();
        if (!snapshot.exists || snapshot.value == null) {
          throw RepositoryException(code: 'user-not-found', message: 'User $userId not found');
        }
        throw RepositoryException(code: 'insufficient-funds', message: 'Insufficient funds');
      }
    } catch (e) {
      _logService?.log(
        LogLevel.error,
        'RtdbWalletRepository.withdraw',
        'Withdraw failed',
        context: {'userId': userId, 'error': e.toString()},
      );
      if (e is RepositoryException) rethrow;
      throw RepositoryException(code: 'withdraw-failed', message: 'Withdraw failed', cause: e);
    }
  }

  @override
  Future<List<TransactionModel>> getTransactions(String userId) async {
    try {
      final query = _txRef(userId).orderByChild('timestampMs').limitToLast(50);
      final snapshot = await query.get();
      final raw = snapshot.value;
      if (raw == null) return <TransactionModel>[];
      if (raw is! Map) return <TransactionModel>[];

      final txs = <TransactionModel>[];
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final data = Map<String, dynamic>.from(value);
        data['id'] = data['id'] ?? entry.key.toString();
        txs.add(TransactionModel.fromJson(data));
      }
      txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return txs;
    } catch (e) {
      throw RepositoryException(code: 'get-failed', message: 'Unable to fetch transactions', cause: e);
    }
  }

  @override
  Stream<List<TransactionModel>> getTransactionStream(String userId) {
    final query = _txRef(userId).orderByChild('timestampMs').limitToLast(50);
    return query.onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null || raw is! Map) return <TransactionModel>[];

      final txs = <TransactionModel>[];
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final data = Map<String, dynamic>.from(value);
        data['id'] = data['id'] ?? entry.key.toString();
        txs.add(TransactionModel.fromJson(data));
      }
      txs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return txs;
    });
  }

  @override
  Stream<UserModel> getUserStream(String userId) {
    return _userRef(userId).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null || raw is! Map) {
        throw RepositoryException(code: 'user-not-found', message: 'User $userId not found');
      }
      return UserModel.fromJson({...Map<String, dynamic>.from(raw), 'id': userId});
    });
  }
}
