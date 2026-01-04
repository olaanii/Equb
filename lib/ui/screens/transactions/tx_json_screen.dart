import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:equb/models/transaction_model.dart';
import 'package:equb/providers/transaction_providers.dart';
import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:equb/ui/theme/theme_constants.dart';

class TxJsonScreen extends ConsumerWidget {
  final String txId;

  const TxJsonScreen({super.key, required this.txId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionHistoryProvider);
    return ProdScaffold(
      title: 'Transaction (JSON)',
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

          final jsonText = const JsonEncoder.withIndent(
            '  ',
          ).convert(transaction.toJson());
          final theme = Theme.of(context);
          return ProdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Raw payload',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadiuses.small,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: SelectableText(
                        jsonText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'SpaceMono',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: 220,
                  child: PrimaryButton(
                    label: 'Copy JSON',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: jsonText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('JSON copied to clipboard'),
                        ),
                      );
                    },
                    icon: Icons.copy,
                  ),
                ),
              ],
            ),
          );
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
