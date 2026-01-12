import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:equb/models/equb_model.dart';
import 'package:equb/models/transaction_model.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/providers/transaction_providers.dart';
import 'package:equb/providers/wallet_providers.dart';
import 'package:equb/ui/screens/wallet/deposit_screen.dart';

class WalletTabScreen extends ConsumerStatefulWidget {
  const WalletTabScreen({super.key});

  @override
  ConsumerState<WalletTabScreen> createState() => _WalletTabScreenState();
}

class _WalletTabScreenState extends ConsumerState<WalletTabScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groupsAsync = ref.watch(equbGroupsProvider);
    final user = ref.watch(currentUserProvider).value;
    final summaryAsync = ref.watch(walletSummaryProvider);
    final transactionsAsync = ref.watch(transactionHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: 'More',
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.pagePaddingMobile,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available balance',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  summaryAsync.when(
                    loading:
                        () => Text(
                          'ETB —',
                          style: Theme.of(
                            context,
                          ).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    error:
                        (_, __) => Text(
                          'ETB —',
                          style: Theme.of(
                            context,
                          ).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    data:
                        (summary) => Text(
                          'ETB ${summary.available.toStringAsFixed(2)}',
                          style: Theme.of(
                            context,
                          ).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DepositScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Top up'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.north_east_rounded),
                          label: const Text('Send'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Overview')),
              ButtonSegment(value: 1, label: Text('Transactions')),
            ],
            selected: {_segment},
            onSelectionChanged: (s) => setState(() => _segment = s.first),
          ),
          const SizedBox(height: 16),
          if (_segment == 0) ...[
            _EqubWalletOverview(groupsAsync: groupsAsync, user: user),
          ] else ...[
            transactionsAsync.when(
              loading:
                  () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error:
                  (err, _) => Text(
                    'Failed to load transactions: $err',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
              data: (txs) {
                final uid = user?.id;
                if (uid == null) {
                  return Text(
                    'Sign in to see your transactions.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
                  );
                }

                final chapa =
                    txs
                        .where(
                          (t) =>
                              t.gateway.toLowerCase() == 'chapa' &&
                              (t.status == TransactionStatus.success ||
                                  t.verificationStatus ==
                                      TransactionStatus.success),
                        )
                        .toList(growable: false)
                      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                if (chapa.isEmpty) {
                  return Text(
                    'No Chapa transactions yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final t in chapa.take(20))
                      _WalletTxTile(transaction: t, currentUserId: uid),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _EqubWalletOverview extends StatelessWidget {
  const _EqubWalletOverview({required this.groupsAsync, required this.user});

  final AsyncValue<List<EqubGroup>> groupsAsync;
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return groupsAsync.when(
      data: (groups) {
        final uid = user?.id;
        final requiredLocked = groups.fold<double>(0.0, (sum, g) {
          if (uid == null) return sum;
          final required = g.contributionAmount;
          final contributed = g.rotationState.contributionProgress[uid] ?? 0.0;
          final missing = (required - contributed).clamp(0.0, required);
          return sum + missing;
        });

        EqubGroup? nextPayoutGroup;
        if (uid != null) {
          for (final g in groups) {
            final queue = g.rotationState.payoutQueue;
            if (queue.isNotEmpty && queue.first == uid) {
              nextPayoutGroup = g;
              break;
            }
          }
        }

        return Column(
          children: [
            _WalletOverviewCard(
              title: 'Locked in Equb',
              value: requiredLocked.toStringAsFixed(0),
              subtitle: 'Remaining to pay this cycle',
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 12),
            _WalletOverviewCard(
              title: 'Upcoming payout',
              value:
                  nextPayoutGroup == null
                      ? '—'
                      : nextPayoutGroup!.poolAmountPerCycle.toStringAsFixed(0),
              subtitle:
                  nextPayoutGroup == null
                      ? 'Not next in any group'
                      : '${nextPayoutGroup!.name} • ${_formatDate(nextPayoutGroup!.rotationState.nextPayoutDate)}',
              icon: Icons.emoji_events_outlined,
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primary.withOpacity(0.18),
                  child: Icon(Icons.info_outline, color: scheme.primary),
                ),
                title: const Text('Transaction tagging'),
                subtitle: Text(
                  'Equb contributions and payouts are tagged automatically when coming from Equb flows.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (err, _) => Text(
            'Failed to load Equb wallet summary: $err',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$day/$month/$year';
  }
}

class _WalletOverviewCard extends StatelessWidget {
  const _WalletOverviewCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withOpacity(0.18),
          child: Icon(icon, color: scheme.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _WalletTxTile extends StatelessWidget {
  const _WalletTxTile({required this.transaction, required this.currentUserId});

  final TransactionModel transaction;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final isDeposit =
      transaction.fromUserId == currentUserId &&
      transaction.toUserId == 'wallet';
    final isWithdraw =
      transaction.fromUserId == 'wallet' &&
      transaction.toUserId == currentUserId;
    final isPositive = isDeposit;

    final title =
      isDeposit
        ? 'Top up'
        : (isWithdraw ? 'Withdraw' : 'Transaction');
    final sign = isDeposit ? '+' : (isWithdraw ? '-' : '');
    final amountText = '$sign ${transaction.amount.toStringAsFixed(2)}';
    final subtitle =
      '${_formatShortDate(transaction.timestamp)} • ${transaction.gateway}';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.surfaceVariant,
          child: Icon(
            isPositive ? Icons.call_received_rounded : Icons.call_made_rounded,
            color: scheme.onSurface.withOpacity(0.7),
          ),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          amountText,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: isPositive ? AppColors.success : scheme.onSurface,
          ),
        ),
      ),
    );
  }

  static String _formatShortDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$day/$month/$year';
  }
}
