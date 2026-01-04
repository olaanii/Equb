import 'package:equb/models/transaction_model.dart';
import 'package:equb/providers/wallet_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildWalletUsageMetrics', () {
    test('aggregates deposits and withdrawals for user', () {
      final now = DateTime.utc(2025, 1, 15);
      final transactions = [
        TransactionModel(
          id: 'd1',
          fromUserId: 'user-1',
          toUserId: 'wallet',
          amount: 250,
          timestamp: now.subtract(const Duration(days: 2)),
          status: TransactionStatus.success,
          gateway: 'telebirr',
        ),
        TransactionModel(
          id: 'w1',
          fromUserId: 'wallet',
          toUserId: 'user-1',
          amount: 100,
          timestamp: now.subtract(const Duration(days: 1)),
          status: TransactionStatus.success,
          gateway: 'bank',
        ),
        TransactionModel(
          id: 'other',
          fromUserId: 'other-user',
          toUserId: 'wallet',
          amount: 500,
          timestamp: now.subtract(const Duration(days: 1)),
          status: TransactionStatus.success,
          gateway: 'telebirr',
        ),
      ];

      final metrics = buildWalletUsageMetrics(
        transactions,
        userId: 'user-1',
        clock: () => now,
      );

      expect(metrics.depositCount, 1);
      expect(metrics.withdrawCount, 1);
      expect(metrics.totalDeposited, 250);
      expect(metrics.totalWithdrawn, 100);
      expect(metrics.gatewayBreakdown['telebirr'], 1);
      expect(metrics.gatewayBreakdown['bank'], 1);
      expect(metrics.rolling7DayDeposits, 250);
      expect(metrics.rolling7DayWithdrawals, 100);
    });

    test('returns empty metrics when no relevant transactions', () {
      final metrics = buildWalletUsageMetrics(const [], userId: 'user-123');

      expect(metrics, WalletUsageMetrics.empty);
    });
  });
}
