import 'package:flutter/material.dart';

import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:equb/ui/theme/theme_constants.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  int _selectedDestination = 1; // 1: Bank transfer

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProdScaffold(
      title: 'Withdraw',
      child: ListView(
        children: [
          ProdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amount',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: 'ETB ',
                    hintText: '150',
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
                  'Destination',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<int>(
                  value: _selectedDestination,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Select destination',
                  ),
                  items: const [
                    DropdownMenuItem<int>(
                      value: 1,
                      child: Text('Bank transfer • CBE Birr ****1234'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedDestination = value);
                  },
                ),
              ],
            ),
          ),
          ProdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SummaryRow(label: 'Fee', value: 'ETB 3.00'),
                _SummaryRow(label: 'ETA', value: 'Same day • before 18:00'),
                _SummaryRow(
                  label: 'Settlement account',
                  value: 'CBE Birr ****1234',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: 'Request withdrawal', onPressed: () {}),
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
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
