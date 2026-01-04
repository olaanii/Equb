import 'dart:async';

import 'package:equb/models/transaction_model.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/providers/transaction_providers.dart';
import 'package:equb/providers/wallet_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('walletUsageMetricsProvider aggregates recent deposits', () async {
    final now = DateTime.now();
    final sample = [
      TransactionModel(
        id: 'tx_1',
        fromUserId: 'user_1',
        toUserId: 'wallet',
        amount: 100,
        timestamp: now.subtract(const Duration(hours: 1)),
        status: TransactionStatus.success,
        gateway: 'telebirr',
      ),
      TransactionModel(
        id: 'tx_2',
        fromUserId: 'user_1',
        toUserId: 'wallet',
        amount: 50,
        timestamp: now.subtract(const Duration(days: 10)),
        status: TransactionStatus.success,
        gateway: 'cbe_birr',
      ),
      TransactionModel(
        id: 'tx_3',
        fromUserId: 'wallet',
        toUserId: 'user_1',
        amount: 20,
        timestamp: now,
        status: TransactionStatus.success,
        gateway: 'payout',
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith(
          (ref) => Stream.value(
            UserModel(id: 'user_1', name: 'Test User', walletBalance: 500),
          ),
        ),
        transactionHistoryProvider.overrideWith((ref) => Stream.value(sample)),
      ],
    );
    addTearDown(container.dispose);

    // Use container.listen and a Completer to wait for the first non-empty WalletUsageMetrics value
    final completer = Completer<WalletUsageMetrics>();
    container.listen(
      walletUsageMetricsProvider,
      (previous, next) {
        if (next.hasValue && !completer.isCompleted) {
          completer.complete(next.value!);
        }
      },
      fireImmediately:
          true, // Ensure the listener is called with the initial value
    );

    final metrics = await completer.future.timeout(
      const Duration(seconds: 10),
    ); // Wait for the metrics to be computed

    expect(metrics.depositCount, 2);
    expect(metrics.totalDeposited, 150);
    expect(metrics.averageDeposit, 75);
    expect(metrics.gatewayBreakdown['telebirr'], 1);
    expect(metrics.gatewayBreakdown['cbe_birr'], 1);
    expect(metrics.lastDepositAt, sample.first.timestamp);
    expect(metrics.rolling7DayDeposits, 100);
  });
}
