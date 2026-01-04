import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:equb/models/transaction_model.dart';
import 'package:equb/providers/transaction_providers.dart';
import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:equb/ui/theme/theme_constants.dart';

class TxLogScreen extends ConsumerWidget {
  const TxLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionHistoryProvider);
    return ProdScaffold(
      title: 'Transaction Log',
      child: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, _) => Center(child: Text('Error loading transactions: $err')),
        data: (transactions) {
          var creditCount = 0;
          var debitCount = 0;
          for (final tx in transactions) {
            if (tx.toUserId == 'wallet') creditCount++;
            if (tx.fromUserId == 'wallet') debitCount++;
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProdCard(
                child: Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.sm,
                  children: [
                    SmallStat(
                      label: 'Total entries',
                      value: '${transactions.length}',
                    ),
                    SmallStat(label: 'Credits', value: '$creditCount'),
                    SmallStat(label: 'Debits', value: '$debitCount'),
                  ],
                ),
              ),
              Expanded(
                child: ProdCard(
                  child:
                      transactions.isEmpty
                          ? Center(
                            child: Text(
                              'No transactions yet',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                          : ListView.separated(
                            itemCount: transactions.length,
                            separatorBuilder:
                                (_, __) =>
                                    const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final tx = transactions[index];
                              return _TxLogEntry(transaction: tx);
                            },
                          ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TxLogEntry extends StatelessWidget {
  final TransactionModel transaction;

  const _TxLogEntry({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = transaction.toUserId == 'wallet';
    final amountColor = isCredit ? AppColors.success : AppColors.error;
    final amountPrefix = isCredit ? '+' : '-';

    final meta =
        '${transaction.gateway} • ${_formatDate(transaction.timestamp)}';
    final initials =
        transaction.gateway.isNotEmpty
            ? transaction.gateway.substring(0, 2).toUpperCase()
            : 'TX';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadiuses.small,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.surfaceMuted,
            child: Text(initials),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.id,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: AppSpacing.xs * 0.5),
                Text(
                  meta,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$amountPrefix ETB ${transaction.amount.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
