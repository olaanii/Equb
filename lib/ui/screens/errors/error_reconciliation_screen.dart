import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';

class ErrorReconciliationScreen extends StatelessWidget {
  const ErrorReconciliationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Error Reconciliation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resolve gateway mismatches',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Compare incoming payment notifications against wallet transactions. Verify each mismatch and push corrected records to keep ledgers aligned.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._mismatches.map(
            (mismatch) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InfoCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mismatch.reference,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Chip(
                          backgroundColor: AppColors.warning.withAlpha(
                            (0.18 * 255).round(),
                          ),
                          label: Text(
                            mismatch.status,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(mismatch.message, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DiffTile(
                            label: 'Gateway amount',
                            value:
                                'ETB ${mismatch.gatewayAmount.toStringAsFixed(2)}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DiffTile(
                            label: 'Wallet amount',
                            value:
                                'ETB ${mismatch.walletAmount.toStringAsFixed(2)}',
                            highlight:
                                mismatch.walletAmount != mismatch.gatewayAmount,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 12,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('View payload'),
                            onPressed:
                                () => _showSnack(
                                  context,
                                  'Payload viewer coming soon.',
                                ),
                          ),
                          PrimaryButton(
                            text: 'Mark resolved',
                            icon: Icons.check_circle_outline,
                            onPressed:
                                () => _showSnack(
                                  context,
                                  'Resolution workflow coming soon.',
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mismatch {
  const _Mismatch({
    required this.reference,
    required this.message,
    required this.gatewayAmount,
    required this.walletAmount,
    required this.status,
  });

  final String reference;
  final String message;
  final double gatewayAmount;
  final double walletAmount;
  final String status;
}

class _DiffTile extends StatelessWidget {
  const _DiffTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color:
            highlight
                ? AppColors.error.withAlpha((0.12 * 255).round())
                : AppColors.surface.withAlpha((0.35 * 255).round()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

const _mismatches = <_Mismatch>[
  _Mismatch(
    reference: 'TX-483920',
    message: 'Telebirr callback amount differs from wallet ledger entry.',
    gatewayAmount: 1750.00,
    walletAmount: 1500.00,
    status: 'Needs review',
  ),
  _Mismatch(
    reference: 'TX-483945',
    message:
        'Duplicate CBE Birr webhook detected. Ensure idempotency key is respected.',
    gatewayAmount: 950.00,
    walletAmount: 950.00,
    status: 'Awaiting confirmation',
  ),
  _Mismatch(
    reference: 'TX-484001',
    message:
        'Missing payout record. Wallet payout succeeded without gateway receipt.',
    gatewayAmount: 0,
    walletAmount: 4200.00,
    status: 'Escalated',
  ),
];

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
