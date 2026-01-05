import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:equb/models/transaction_model.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/providers/transaction_providers.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

class _TxDetailBody extends ConsumerWidget {
  final TransactionModel transaction;

  const _TxDetailBody({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isWide = context.isTablet || context.isDesktop;
    final gatewayLabel = _formatGateway(transaction.gateway);
    final isCredit = transaction.toUserId == 'wallet';
    final typeLabel = isCredit ? 'Deposit' : 'Withdrawal';

    final user = ref.watch(currentUserProvider).value;
    final canReview =
        user != null &&
        (user.role == UserRole.equbAdmin || user.role == UserRole.superAdmin);
    final isPendingDeposit =
        canReview &&
        isCredit &&
        transaction.status == TransactionStatus.pending;

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
        if (isPendingDeposit)
          _PendingDepositReviewActions(
            userId: transaction.fromUserId,
            txId: transaction.id,
          ),
        if (isPendingDeposit) const SizedBox(height: AppSpacing.lg),
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

class _PendingDepositReviewActions extends ConsumerWidget {
  final String userId;
  final String txId;

  const _PendingDepositReviewActions({required this.userId, required this.txId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = context.isTablet || context.isDesktop;

    Future<void> runWithLoading(Future<void> Function() op) async {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        await op();
      } finally {
        if (context.mounted) Navigator.of(context).pop();
      }
    }

    Future<void> approve() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Approve deposit?'),
          content: const Text(
            'This will mark the deposit as successful and credit the wallet balance and points.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
          ],
        ),
      );
      if (confirmed != true) return;

      await runWithLoading(() async {
        final callable = FirebaseFunctions.instance.httpsCallable('adminReviewDeposit');
        await callable.call(<String, dynamic>{
          'targetUserId': userId,
          'txId': txId,
          'action': 'approve',
        });
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deposit approved')),
      );
      ref.invalidate(transactionHistoryProvider);
      ref.invalidate(currentUserProvider);
    }

    Future<void> reject() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject deposit?'),
          content: const Text('This will mark the deposit as failed.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
          ],
        ),
      );
      if (confirmed != true) return;

      await runWithLoading(() async {
        final callable = FirebaseFunctions.instance.httpsCallable('adminReviewDeposit');
        await callable.call(<String, dynamic>{
          'targetUserId': userId,
          'txId': txId,
          'action': 'reject',
        });
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deposit rejected')),
      );
      ref.invalidate(transactionHistoryProvider);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Admin actions',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (isWide)
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Approve deposit',
                  onPressed: approve,
                  icon: Icons.check_circle_outline,
                  expand: true,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: reject,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Reject deposit'),
                ),
              ),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton(
                label: 'Approve deposit',
                onPressed: approve,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: reject,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Reject deposit'),
              ),
            ],
          ),
      ],
    );
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
