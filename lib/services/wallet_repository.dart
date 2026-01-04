import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equb/models/transaction_model.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/services/repository_exception.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:equb/services/analytics_service.dart';
import 'package:equb/utils/money_mathematics.dart';

abstract class WalletRepository {
  Future<void> deposit(
    String userId,
    double amount,
    String gateway, {
    String? screenshotUrl,
  });
  Future<void> withdraw(String userId, double amount, String destination);
  Future<List<TransactionModel>> getTransactions(String userId);
  Stream<List<TransactionModel>> getTransactionStream(String userId);
  Stream<UserModel> getUserStream(String userId);
}

class FirestoreWalletRepository implements WalletRepository {
  final FirebaseFirestore _firestore;
  final SystemLogService? _logService;
  final AnalyticsService? _analyticsService;

  FirestoreWalletRepository({
    FirebaseFirestore? firestore,
    SystemLogService? logService,
    AnalyticsService? analyticsService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _logService = logService,
       _analyticsService = analyticsService;

  @override
  Future<void> deposit(
    String userId,
    double amount,
    String gateway, {
    String? screenshotUrl,
  }) {
    return _guard(
      'deposit',
      () async {
        final fee = MoneyMathematics.calculateFee(amount);
        final net = amount - fee;
        final points = MoneyMathematics.calculatePoints(amount, 'deposit');
        final isManual = screenshotUrl != null;

        final tx = await _firestore.runTransaction<TransactionModel>((
          transaction,
        ) async {
          final userRef = _firestore.collection('users').doc(userId);
          final userDoc = await transaction.get(userRef);

          if (!userDoc.exists) {
            throw RepositoryException(
              code: 'user-not-found',
              message: 'User $userId not found',
            );
          }

          final txRef = _firestore.collection('transactions').doc();
          final tx = TransactionModel(
            id: txRef.id,
            fromUserId: userId,
            toUserId: 'wallet',
            amount: amount,
            status:
                isManual
                    ? TransactionStatus.pending
                    : TransactionStatus.success,
            gateway: gateway,
            timestamp: DateTime.now(),
            feeAmount: fee,
            netAmount: net,
            screenshotUrl: screenshotUrl,
          );

          if (!isManual) {
            final currentBalance =
                (userDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
            final currentPoints = (userDoc.data()?['points'] as int?) ?? 0;

            transaction.update(userRef, {
              'walletBalance': currentBalance + net,
              'points': currentPoints + points,
            });
          }

          transaction.set(txRef, tx.toJson());
          return tx;
        });
        await _trackDeposit(
          userId: userId,
          amount: amount,
          gateway: gateway,
          transactionId: tx.id,
        );
      },
      context: {'userId': userId, 'gateway': gateway, 'amount': amount},
      friendlyMessage: 'Unable to deposit at this time',
    );
  }

  @override
  Future<void> withdraw(String userId, double amount, String destination) {
    return _guard(
      'withdraw',
      () async {
        final fee = MoneyMathematics.calculateFee(amount);
        final totalDeduction = amount + fee;

        final tx = await _firestore.runTransaction<TransactionModel>((
          transaction,
        ) async {
          final userRef = _firestore.collection('users').doc(userId);
          final userDoc = await transaction.get(userRef);

          if (!userDoc.exists) {
            throw RepositoryException(
              code: 'user-not-found',
              message: 'User $userId not found',
            );
          }

          final currentBalance =
              (userDoc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
          if (currentBalance + 1e-9 < totalDeduction) {
            throw RepositoryException(
              code: 'insufficient-funds',
              message: 'Balance too low for withdrawal (including fees)',
            );
          }

          final newBalance = currentBalance - totalDeduction;

          final txRef = _firestore.collection('transactions').doc();
          final tx = TransactionModel(
            id: txRef.id,
            fromUserId: 'wallet',
            toUserId: userId,
            amount: amount,
            status: TransactionStatus.success,
            gateway: destination,
            timestamp: DateTime.now(),
            feeAmount: fee,
            netAmount: amount, // For withdrawal, user gets exactly 'amount'
          );

          transaction.update(userRef, {'walletBalance': newBalance});
          transaction.set(txRef, tx.toJson());
          return tx;
        });
        await _trackWithdrawal(
          userId: userId,
          amount: amount,
          destination: destination,
          transactionId: tx.id,
        );
      },
      context: {'userId': userId, 'destination': destination, 'amount': amount},
      friendlyMessage: 'Unable to withdraw at this time',
    );
  }

  @override
  Future<List<TransactionModel>> getTransactions(String userId) {
    return _guard('getTransactions', () async {
      final snapshot =
          await _firestore
              .collection('transactions')
              .where(
                Filter.or(
                  Filter('fromUserId', isEqualTo: userId),
                  Filter('toUserId', isEqualTo: userId),
                ),
              )
              .orderBy('timestamp', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromJson(doc.data()))
          .toList();
    }, context: {'userId': userId});
  }

  @override
  Stream<List<TransactionModel>> getTransactionStream(String userId) {
    return _firestore
        .collection('transactions')
        .where(
          Filter.or(
            Filter('fromUserId', isEqualTo: userId),
            Filter('toUserId', isEqualTo: userId),
          ),
        )
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => TransactionModel.fromJson(doc.data()))
                  .toList(),
        );
  }

  @override
  Stream<UserModel> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) {
        final error = RepositoryException(
          code: 'user-not-found',
          message: 'User $userId not found',
        );
        _logService?.log(
          LogLevel.warning,
          'FirestoreWalletRepository.getUserStream',
          error.message,
          context: {'userId': userId},
        );
        throw error;
      }
      return UserModel.fromJson(doc.data()!);
    });
  }

  Future<void> _trackDeposit({
    required String userId,
    required double amount,
    required String gateway,
    required String transactionId,
  }) async {
    if (_analyticsService == null) return;
    await _analyticsService.trackDeposit(
      userId: userId,
      amount: amount,
      gateway: gateway,
      transactionId: transactionId,
    );
  }

  Future<void> _trackWithdrawal({
    required String userId,
    required double amount,
    required String destination,
    required String transactionId,
  }) async {
    if (_analyticsService == null) return;
    await _analyticsService.trackWithdrawal(
      userId: userId,
      amount: amount,
      destination: destination,
      transactionId: transactionId,
    );
  }

  Future<T> _guard<T>(
    String operation,
    Future<T> Function() action, {
    Map<String, dynamic>? context,
    String? friendlyMessage,
  }) async {
    try {
      return await action();
    } on RepositoryException catch (error) {
      _logService?.log(
        LogLevel.warning,
        'FirestoreWalletRepository.$operation',
        error.message,
        context: _buildContext(operation, context, {'code': error.code}),
      );
      rethrow;
    } on FirebaseException catch (error, stack) {
      final wrapped = RepositoryException(
        code: error.code,
        message: friendlyMessage ?? 'Unable to complete $operation',
        cause: error,
        stackTrace: stack,
      );
      _logService?.log(
        LogLevel.error,
        'FirestoreWalletRepository.$operation',
        error.message ?? error.code,
        context: _buildContext(operation, context, {
          'firebaseCode': error.code,
        }),
      );
      throw wrapped;
    } catch (error, stack) {
      final wrapped = RepositoryException(
        code: 'unexpected',
        message: friendlyMessage ?? 'Unexpected failure during $operation',
        cause: error,
        stackTrace: stack,
      );
      _logService?.log(
        LogLevel.error,
        'FirestoreWalletRepository.$operation',
        error.toString(),
        context: _buildContext(operation, context),
      );
      throw wrapped;
    }
  }

  Map<String, dynamic> _buildContext(
    String operation,
    Map<String, dynamic>? context, [
    Map<String, dynamic>? extra,
  ]) {
    return {
      'operation': operation,
      if (context != null) ...context,
      if (extra != null) ...extra,
    };
  }
}
