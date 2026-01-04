import 'package:equb/models/transaction_model.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/providers/transaction_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WalletSummary {
  const WalletSummary({
    required this.available,
    required this.locked,
    required this.lifetimeDeposits,
    required this.lifetimePayouts,
    required this.depositCount,
    required this.withdrawCount,
  });

  final double available;
  final double locked;
  final double lifetimeDeposits;
  final double lifetimePayouts;
  final int depositCount;
  final int withdrawCount;
}

class WalletUsageMetrics {
  const WalletUsageMetrics({
    required this.depositCount,
    required this.withdrawCount,
    required this.totalDeposited,
    required this.totalWithdrawn,
    required this.gatewayBreakdown,
    required this.lastDepositAt,
    required this.lastWithdrawAt,
    required this.rolling7DayDeposits,
    required this.rolling7DayWithdrawals,
    required this.averageDeposit,
  });

  static const WalletUsageMetrics empty = WalletUsageMetrics(
    depositCount: 0,
    withdrawCount: 0,
    totalDeposited: 0,
    totalWithdrawn: 0,
    gatewayBreakdown: <String, int>{},
    lastDepositAt: null,
    lastWithdrawAt: null,
    rolling7DayDeposits: 0,
    rolling7DayWithdrawals: 0,
    averageDeposit: 0,
  );

  final int depositCount;
  final int withdrawCount;
  final double totalDeposited;
  final double totalWithdrawn;
  final Map<String, int> gatewayBreakdown;
  final DateTime? lastDepositAt;
  final DateTime? lastWithdrawAt;
  final double rolling7DayDeposits;
  final double rolling7DayWithdrawals;
  final double averageDeposit;
}

enum WalletCohort { dormant, returning, engaged, power }

class WalletCohortSummary {
  const WalletCohortSummary({
    required this.cohort,
    required this.depositCount,
    required this.totalDeposited,
    required this.averageDeposit,
    required this.rolling7DayDeposits,
    required this.daysSinceLastDeposit,
  });

  final WalletCohort cohort;
  final int depositCount;
  final double totalDeposited;
  final double averageDeposit;
  final double rolling7DayDeposits;
  final int daysSinceLastDeposit;

  static const WalletCohortSummary empty = WalletCohortSummary(
    cohort: WalletCohort.dormant,
    depositCount: 0,
    totalDeposited: 0,
    averageDeposit: 0,
    rolling7DayDeposits: 0,
    daysSinceLastDeposit: -1,
  );
}

enum ConversionStage { acquired, activated, retained, loyal }

class ConversionFunnelMetrics {
  const ConversionFunnelMetrics({
    required this.stage,
    required this.hasDeposited,
    required this.hasWithdrawn,
    required this.isActiveThisWeek,
    required this.depositCount,
    required this.withdrawCount,
    required this.totalDeposited,
    required this.totalWithdrawn,
  });

  final ConversionStage stage;
  final bool hasDeposited;
  final bool hasWithdrawn;
  final bool isActiveThisWeek;
  final int depositCount;
  final int withdrawCount;
  final double totalDeposited;
  final double totalWithdrawn;

  static const ConversionFunnelMetrics empty = ConversionFunnelMetrics(
    stage: ConversionStage.acquired,
    hasDeposited: false,
    hasWithdrawn: false,
    isActiveThisWeek: false,
    depositCount: 0,
    withdrawCount: 0,
    totalDeposited: 0,
    totalWithdrawn: 0,
  );
}

@visibleForTesting
final walletMetricsUserProvider = FutureProvider<UserModel?>((ref) async {
  return ref.watch(currentUserProvider.future);
});

final walletUsageMetricsProvider = FutureProvider<WalletUsageMetrics>((
  ref,
) async {
  final user = await ref.watch(walletMetricsUserProvider.future);
  if (user == null) {
    return WalletUsageMetrics.empty;
  }

  final transactions = await ref.watch(transactionHistoryProvider.future);
  if (transactions.isEmpty) {
    return WalletUsageMetrics.empty;
  }

  return buildWalletUsageMetrics(transactions, userId: user.id);
});

final walletSummaryProvider = StreamProvider<WalletSummary>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final metricsAsync = ref.watch(walletUsageMetricsProvider);

  return userAsync.when(
    data: (user) {
      final metrics = metricsAsync.maybeWhen(
        data: (value) => value,
        orElse: () => WalletUsageMetrics.empty,
      );

      if (user == null) {
        return Stream.value(
          const WalletSummary(
            available: 0,
            locked: 0,
            lifetimeDeposits: 0,
            lifetimePayouts: 0,
            depositCount: 0,
            withdrawCount: 0,
          ),
        );
      }

      return Stream.value(
        WalletSummary(
          available: user.walletBalance,
          locked: 0,
          lifetimeDeposits: metrics.totalDeposited,
          lifetimePayouts: metrics.totalWithdrawn,
          depositCount: metrics.depositCount,
          withdrawCount: metrics.withdrawCount,
        ),
      );
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

final walletCohortSummaryProvider = FutureProvider<WalletCohortSummary>((
  ref,
) async {
  final metrics = await ref.watch(walletUsageMetricsProvider.future);
  return computeWalletCohortSummary(metrics);
});

final conversionFunnelProvider = FutureProvider<ConversionFunnelMetrics>((
  ref,
) async {
  final metrics = await ref.watch(walletUsageMetricsProvider.future);
  return buildConversionFunnel(metrics);
});

@visibleForTesting
WalletUsageMetrics buildWalletUsageMetrics(
  List<TransactionModel> transactions, {
  required String userId,
  DateTime Function()? clock,
}) {
  var depositCount = 0;
  var withdrawCount = 0;
  var totalDeposited = 0.0;
  var totalWithdrawn = 0.0;
  DateTime? lastDepositAt;
  DateTime? lastWithdrawAt;
  final gatewayBreakdown = <String, int>{};
  final now = (clock ?? DateTime.now)();
  final rollingWindowStart = now.subtract(const Duration(days: 7));
  var rollingDeposits = 0.0;
  var rollingWithdrawals = 0.0;

  for (final tx in transactions) {
    final isDeposit = tx.fromUserId == userId && tx.toUserId == 'wallet';
    final isWithdraw = tx.fromUserId == 'wallet' && tx.toUserId == userId;
    if (!isDeposit && !isWithdraw) continue;

    gatewayBreakdown[tx.gateway] = (gatewayBreakdown[tx.gateway] ?? 0) + 1;

    if (isDeposit) {
      depositCount++;
      totalDeposited += tx.amount;
      final last = lastDepositAt;
      if (last == null || tx.timestamp.isAfter(last)) {
        lastDepositAt = tx.timestamp;
      }
      if (tx.timestamp.isAfter(rollingWindowStart)) {
        rollingDeposits += tx.amount;
      }
    } else {
      withdrawCount++;
      totalWithdrawn += tx.amount;
      final last = lastWithdrawAt;
      if (last == null || tx.timestamp.isAfter(last)) {
        lastWithdrawAt = tx.timestamp;
      }
      if (tx.timestamp.isAfter(rollingWindowStart)) {
        rollingWithdrawals += tx.amount;
      }
    }
  }

  if (depositCount == 0 && withdrawCount == 0) {
    return WalletUsageMetrics.empty;
  }

  return WalletUsageMetrics(
    depositCount: depositCount,
    withdrawCount: withdrawCount,
    totalDeposited: totalDeposited,
    totalWithdrawn: totalWithdrawn,
    gatewayBreakdown: Map.unmodifiable(gatewayBreakdown),
    lastDepositAt: lastDepositAt,
    lastWithdrawAt: lastWithdrawAt,
    rolling7DayDeposits: rollingDeposits,
    rolling7DayWithdrawals: rollingWithdrawals,
    averageDeposit: depositCount == 0 ? 0 : totalDeposited / depositCount,
  );
}

@visibleForTesting
WalletCohortSummary computeWalletCohortSummary(
  WalletUsageMetrics metrics, {
  DateTime Function()? clock,
}) {
  if (metrics == WalletUsageMetrics.empty) {
    return WalletCohortSummary.empty;
  }

  final now = (clock ?? DateTime.now)();
  final lastDeposit = metrics.lastDepositAt;
  final daysSinceLast =
      lastDeposit == null ? -1 : now.difference(lastDeposit).inDays;

  final cohort = _classifyCohort(metrics, daysSinceLastDeposit: daysSinceLast);

  return WalletCohortSummary(
    cohort: cohort,
    depositCount: metrics.depositCount,
    totalDeposited: metrics.totalDeposited,
    averageDeposit: metrics.averageDeposit,
    rolling7DayDeposits: metrics.rolling7DayDeposits,
    daysSinceLastDeposit: daysSinceLast,
  );
}

WalletCohort _classifyCohort(
  WalletUsageMetrics metrics, {
  required int daysSinceLastDeposit,
}) {
  if (metrics.depositCount == 0 || daysSinceLastDeposit > 30) {
    return WalletCohort.dormant;
  }
  if (metrics.depositCount <= 2) {
    return WalletCohort.returning;
  }
  final isPowerUser =
      metrics.rolling7DayDeposits >= 500 || metrics.averageDeposit >= 250;
  if (isPowerUser) {
    return WalletCohort.power;
  }
  return WalletCohort.engaged;
}

@visibleForTesting
ConversionFunnelMetrics buildConversionFunnel(WalletUsageMetrics metrics) {
  if (metrics == WalletUsageMetrics.empty) {
    return ConversionFunnelMetrics.empty;
  }

  final hasDeposited = metrics.depositCount > 0;
  final hasWithdrawn = metrics.withdrawCount > 0;
  final activeThisWeek =
      metrics.rolling7DayDeposits > 0 || metrics.rolling7DayWithdrawals > 0;

  final stage = _determineStage(
    hasDeposited: hasDeposited,
    hasWithdrawn: hasWithdrawn,
    activeThisWeek: activeThisWeek,
  );

  return ConversionFunnelMetrics(
    stage: stage,
    hasDeposited: hasDeposited,
    hasWithdrawn: hasWithdrawn,
    isActiveThisWeek: activeThisWeek,
    depositCount: metrics.depositCount,
    withdrawCount: metrics.withdrawCount,
    totalDeposited: metrics.totalDeposited,
    totalWithdrawn: metrics.totalWithdrawn,
  );
}

ConversionStage _determineStage({
  required bool hasDeposited,
  required bool hasWithdrawn,
  required bool activeThisWeek,
}) {
  if (!hasDeposited) {
    return ConversionStage.acquired;
  }
  if (!hasWithdrawn && !activeThisWeek) {
    return ConversionStage.activated;
  }
  if (hasWithdrawn && !activeThisWeek) {
    return ConversionStage.retained;
  }
  return ConversionStage.loyal;
}
