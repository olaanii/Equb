import 'package:flutter/material.dart';

import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:equb/ui/theme/theme_constants.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final TextEditingController _amountController = TextEditingController();
  int _method = 1;

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
                  title: const Text('Telebirr'),
                  subtitle: Text(
                    'Instant mobile payment',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: 1,
                  groupValue: _method,
                  onChanged: (value) => setState(() => _method = value ?? 1),
                ),
                RadioListTile<int>(
                  title: const Text('CBE Birr'),
                  subtitle: Text(
                    'Bank transfer • settlement ~5m',
                    style: theme.textTheme.bodySmall,
                  ),
                  value: 2,
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
                  value: _method == 1 ? 'ETB 0.00' : 'ETB 5.00',
                ),
                _SummaryRow(
                  label: 'ETA',
                  value: _method == 1 ? 'Instant' : '5-10 min',
                ),
                _SummaryRow(
                  label: 'Destination',
                  value: _method == 1 ? 'Wallet credit' : 'CBE Birr account',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: 'Proceed to pay', onPressed: () {}),
        ],
      ),
    );
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
