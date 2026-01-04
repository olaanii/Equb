import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:equb/models/transaction_model.dart';
import 'package:equb/providers/transaction_providers.dart';
import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:equb/ui/screens/transactions/tx_json_screen.dart';
import 'package:equb/ui/theme/theme_constants.dart';

class TxDetailScreen extends ConsumerWidget {
  final String txId;
  const TxDetailScreen({super.key, required this.txId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionHistoryProvider);
    return ProdScaffold(
      title: 'Transaction Detail',
      child: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, _) => Center(child: Text('Failed to load transaction: $err')),
        data: (transactions) {
          final transaction = _findTransaction(transactions, txId);
          if (transaction == null) {
            return Center(
              child: Text(
                'Transaction $txId not found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }
          return _TxDetailBody(transaction: transaction);
        },
      ),
    );
  }

  TransactionModel? _findTransaction(
    List<TransactionModel> transactions,
    String id,
  ) {
    for (final tx in transactions) {
      if (tx.id == id) return tx;
    }
    return null;
  }
}

class _TxDetailBody extends StatelessWidget {
  final TransactionModel transaction;

  const _TxDetailBody({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = context.isTablet || context.isDesktop;
    final gatewayLabel = _formatGateway(transaction.gateway);
    final isCredit = transaction.toUserId == 'wallet';
    final typeLabel = isCredit ? 'Deposit' : 'Withdrawal';

    Widget buildCards() {
      final detailCard = ProdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction #${transaction.id}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Processed via $gatewayLabel',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'ETB ${transaction.amount.toStringAsFixed(2)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                SmallStat(label: 'Gateway', value: gatewayLabel),
                SmallStat(label: 'Type', value: typeLabel),
                SmallStat(
                  label: 'Status',
                  value: _statusLabel(transaction.status),
                ),
              ],
            ),
          ],
        ),
      );

      final metaCard = ProdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Metadata',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _MetaRow(
              label: 'Timestamp',
              value: _formatDate(transaction.timestamp),
            ),
            _MetaRow(label: 'From', value: transaction.fromUserId),
            _MetaRow(label: 'To', value: transaction.toUserId),
            _MetaRow(label: 'Gateway ID', value: transaction.gateway),
          ],
        ),
      );

      if (isWide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: detailCard),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: metaCard),
          ],
        );
      }
      return Column(
        children: [detailCard, const SizedBox(height: AppSpacing.md), metaCard],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildCards(),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: isWide ? Alignment.centerRight : Alignment.centerLeft,
          child: SizedBox(
            width: isWide ? 220 : double.infinity,
            child: PrimaryButton(
              label: 'View JSON payload',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TxJsonScreen(txId: transaction.id),
                  ),
                );
              },
              expand: !isWide,
              icon: Icons.code,
            ),
          ),
        ),
      ],
    );
  }

  String _formatGateway(String raw) {
    if (raw.isEmpty) return 'Gateway';
    final normalized = raw.replaceAll('_', ' ').replaceAll('-', ' ');
    final parts = normalized.split(' ');
    return parts
        .map(
          (part) =>
              part.isEmpty
                  ? ''
                  : part[0].toUpperCase() + part.substring(1).toLowerCase(),
        )
        .join(' ')
        .trim();
  }

  String _statusLabel(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.success:
        return 'Success';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs * 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
