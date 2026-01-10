import 'package:equb/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:equb/ui/theme/theme_constants.dart';

class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  final TextEditingController _amountController = TextEditingController();
  int _method = 1;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ProdScaffold(
      title: 'Deposit',
      child: ListView(
        children: [
          ProdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amount',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: 'ETB ',
                    hintText: '320',
                  ),
                ),
              ],
            ),
          ),
          ProdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select method',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                RadioListTile<int>(
                  title: const Text('FenanPay (Test)'),
                  subtitle: Text(
                    'Hosted checkout (sandbox)',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: 1,
                  groupValue: _method,
                  onChanged: (value) => setState(() => _method = value ?? 1),
                ),
              ],
            ),
          ),
          ProdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SummaryRow(
                  label: 'Fees',
                  value: 'ETB 0.00',
                ),
                _SummaryRow(
                  label: 'ETA',
                  value: 'Instant',
                ),
                _SummaryRow(
                  label: 'Destination',
                  value: 'Wallet credit',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: _submitting ? 'Starting checkout…' : 'Proceed to pay',
            onPressed: _submitting ? null : _handlePay,
          ),
        ],
      ),
    );
  }

  Future<void> _handlePay() async {
    final messenger = ScaffoldMessenger.of(context);
    final raw = _amountController.text.trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount < 1) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid amount (min ETB 1).')),
      );
      return;
    }

    final uid = ref.read(currentUserProvider).value?.id;
    if (uid == null || uid.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in required.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final gatewayService = ref.read(gatewayServiceProvider);
      final paymentService = await gatewayService.getAdapter('fenanpay');
      if (paymentService == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('FenanPay gateway is not configured.')),
        );
        return;
      }

      if (!context.mounted) return;

      await paymentService.createPayment(
        fromUserId: uid,
        toUserId: uid,
        amount: amount,
        gateway: 'fenanpay',
        context: context,
      );

      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Checkout opened. Awaiting confirmation.'),
        ),
      );
    } on GatewayCredentialException catch (err) {
      messenger.showSnackBar(
        SnackBar(content: Text('FenanPay API key missing: ${err.message}')),
      );
    } catch (err) {
      messenger.showSnackBar(
        SnackBar(content: Text('Deposit error: $err')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs, top: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
