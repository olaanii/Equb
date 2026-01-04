import 'package:equb/providers/wallet_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeWalletCohortSummary', () {
    test('classifies dormant users when no deposits exist', () {
      final summary = computeWalletCohortSummary(
        WalletUsageMetrics.empty,
        clock: () => DateTime.utc(2025, 1, 1),
      );

      expect(summary.cohort, WalletCohort.dormant);
      expect(summary.depositCount, 0);
      expect(summary.daysSinceLastDeposit, -1);
    });

    test('identifies power users via rolling deposits', () {
      final metrics = WalletUsageMetrics(
        depositCount: 5,
        withdrawCount: 1,
        totalDeposited: 1200,
        totalWithdrawn: 200,
        gatewayBreakdown: const {'telebirr': 5},
        lastDepositAt: DateTime.utc(2025, 1, 10),
        lastWithdrawAt: DateTime.utc(2025, 1, 9),
        rolling7DayDeposits: 600,
        rolling7DayWithdrawals: 50,
        averageDeposit: 240,
      );

      final summary = computeWalletCohortSummary(
        metrics,
        clock: () => DateTime.utc(2025, 1, 11),
      );

      expect(summary.cohort, WalletCohort.power);
      expect(summary.daysSinceLastDeposit, 1);
      expect(summary.totalDeposited, 1200);
    });
  });

  group('buildConversionFunnel', () {
    test('tracks stage transitions', () {
      final acquired = buildConversionFunnel(WalletUsageMetrics.empty);
      expect(acquired.stage, ConversionStage.acquired);

      final activatedMetrics = WalletUsageMetrics(
        depositCount: 1,
        withdrawCount: 0,
        totalDeposited: 50,
        totalWithdrawn: 0,
        gatewayBreakdown: const {'telebirr': 1},
        lastDepositAt: DateTime.utc(2025, 1, 5),
        lastWithdrawAt: null,
        rolling7DayDeposits: 0,
        rolling7DayWithdrawals: 0,
        averageDeposit: 50,
      );
      final activated = buildConversionFunnel(activatedMetrics);
      expect(activated.stage, ConversionStage.activated);

      final loyalMetrics = WalletUsageMetrics(
        depositCount: 4,
        withdrawCount: 2,
        totalDeposited: 400,
        totalWithdrawn: 150,
        gatewayBreakdown: const {'telebirr': 3, 'cbe_birr': 1},
        lastDepositAt: DateTime.utc(2025, 1, 12),
        lastWithdrawAt: DateTime.utc(2025, 1, 11),
        rolling7DayDeposits: 120,
        rolling7DayWithdrawals: 60,
        averageDeposit: 100,
      );
      final loyal = buildConversionFunnel(loyalMetrics);
      expect(loyal.stage, ConversionStage.loyal);
      expect(loyal.isActiveThisWeek, isTrue);
    });
  });
}
