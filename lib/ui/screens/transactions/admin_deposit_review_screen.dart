import 'dart:convert';

import 'package:equb/models/transaction_model.dart';
import 'package:equb/providers/admin_providers.dart';
import 'package:equb/providers/transaction_providers.dart';
import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminDepositReviewScreen extends ConsumerWidget {
  const AdminDepositReviewScreen({
    super.key,
    required this.item,
  });

  final PendingDepositItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(
      adminDepositTransactionProvider((userId: item.userId, txId: item.txId)),
    );

    return ProdScaffold(
      title: 'Review deposit',
      child: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load deposit: $e')),
        data: (tx) {
          if (tx == null) {
            return Center(
              child: Text(
                'Transaction ${item.txId} not found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }

          return _Body(item: item, tx: tx);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.item, required this.tx});

  final PendingDepositItem item;
  final TransactionModel tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isWide = context.isTablet || context.isDesktop;

    final jsonText = const JsonEncoder.withIndent('  ').convert(tx.toJson());

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
            'This will credit the user wallet balance and points and mark the deposit as successful.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      await runWithLoading(() async {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'adminReviewDeposit',
        );
        await callable.call(<String, dynamic>{
          'targetUserId': item.userId,
          'txId': item.txId,
          'action': 'approve',
        });
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deposit approved')),
      );
      ref.invalidate(pendingDepositsProvider);
      ref.invalidate(transactionHistoryProvider);
      Navigator.of(context).pop();
    }

    Future<void> reject() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject deposit?'),
          content: const Text('This will mark the deposit as failed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reject'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      await runWithLoading(() async {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'adminReviewDeposit',
        );
        await callable.call(<String, dynamic>{
          'targetUserId': item.userId,
          'txId': item.txId,
          'action': 'reject',
        });
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deposit rejected')),
      );
      ref.invalidate(pendingDepositsProvider);
      Navigator.of(context).pop();
    }

    Widget detailCard() {
      return ProdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deposit details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                SmallStat(label: 'User', value: item.userId),
                SmallStat(label: 'Tx', value: item.txId),
                SmallStat(label: 'Gateway', value: item.gateway),
                SmallStat(
                  label: 'Amount',
                  value: 'ETB ${item.amount.toStringAsFixed(2)}',
                ),
                SmallStat(
                  label: 'Fee',
                  value: 'ETB ${item.feeAmount.toStringAsFixed(2)}',
                ),
                SmallStat(
                  label: 'Net',
                  value: 'ETB ${item.netAmount.toStringAsFixed(2)}',
                ),
              ],
            ),
            if ((item.screenshotUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Proof',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SelectableText(
                item.screenshotUrl!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget actionsCard() {
      return ProdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Decision',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: isWide ? 220 : double.infinity,
                child: PrimaryButton(
                  label: 'Copy JSON payload',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: jsonText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JSON copied')),
                    );
                  },
                  icon: Icons.copy,
                  expand: !isWide,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: detailCard()),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: actionsCard()),
        ],
      );
    }

    return Column(
      children: [
        detailCard(),
        const SizedBox(height: AppSpacing.md),
        actionsCard(),
      ],
    );
  }
}
