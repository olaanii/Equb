import 'package:equb/models/onboarding_state.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaymentSetupStep extends ConsumerStatefulWidget {
  const PaymentSetupStep({
    super.key,
    required this.initialData,
    required this.onDataChanged,
    required this.onNext,
    required this.onPrevious,
  });

  final OnboardingData initialData;
  final Function(OnboardingData) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  ConsumerState<PaymentSetupStep> createState() => _PaymentSetupStepState();
}

class _PaymentSetupStepState extends ConsumerState<PaymentSetupStep> {
  String? _selectedGateway;
  bool _isSettingUp = false;

  final List<Map<String, dynamic>> _availableGateways = [
    {
      'id': 'telebirr',
      'name': 'Telebirr',
      'icon': Icons.phone_android,
      'description': 'Connect your Telebirr account',
      'color': Colors.blue,
    },
    {
      'id': 'cbe_birr',
      'name': 'CBE Birr',
      'icon': Icons.account_balance,
      'description': 'Link your CBE Birr account',
      'color': Colors.green,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: AppSpacing.pagePaddingMobile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment illustration
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.payment,
                size: 60,
                color: scheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Set up payments',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            'Connect your mobile money account for seamless contributions',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Gateway selection
          Text(
            'Choose your payment method',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          ..._availableGateways.map((gateway) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildGatewayOption(gateway),
          )),

          const SizedBox(height: 24),

          // Setup status
          if (widget.initialData.paymentMethodSetup)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Method Connected',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'You can now make and receive payments securely.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.initialData.paymentMethodSetup ? widget.onNext : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Skip option (if no payment method selected)
          if (!widget.initialData.paymentMethodSetup)
            Center(
              child: TextButton(
                onPressed: _skipPaymentSetup,
                child: const Text('Set up later'),
              ),
            ),

          const SizedBox(height: 24),

          // Security note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outline.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your payment information is encrypted and secure. We use bank-level security standards.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Benefits list
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Payment Benefits',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBenefit('Instant transfers between group members'),
                _buildBenefit('Automatic contribution collection'),
                _buildBenefit('Secure payout distribution'),
                _buildBenefit('Transaction history and receipts'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGatewayOption(Map<String, dynamic> gateway) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _selectedGateway == gateway['id'];

    return InkWell(
      onTap: _isSettingUp ? null : () => _selectGateway(gateway['id']),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? gateway['color'].withOpacity(0.1)
              : scheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? gateway['color'].withOpacity(0.3)
                : scheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: gateway['color'].withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                gateway['icon'],
                color: gateway['color'],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gateway['name'],
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gateway['description'],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: gateway['color'],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit(String benefit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              benefit,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectGateway(String gatewayId) async {
    setState(() => _selectedGateway = gatewayId);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect Payment Method'),
        content: Text(
          'This will redirect you to ${gatewayId.toUpperCase()} to authorize the connection. '
          'Make sure you have the ${gatewayId.toUpperCase()} app installed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _setupPaymentMethod(gatewayId);
    } else {
      setState(() => _selectedGateway = null);
    }
  }

  Future<void> _setupPaymentMethod(String gatewayId) async {
    setState(() => _isSettingUp = true);

    try {
      // TODO: Implement actual payment gateway integration
      // For now, simulate setup process
      await Future.delayed(const Duration(seconds: 3));

      // Update onboarding data
      final updatedData = widget.initialData.copyWith(paymentMethodSetup: true);
      widget.onDataChanged(updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${gatewayId.toUpperCase()} connected successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect ${gatewayId.toUpperCase()}: $e')),
        );
        setState(() => _selectedGateway = null);
      }
    } finally {
      if (mounted) {
        setState(() => _isSettingUp = false);
      }
    }
  }

  void _skipPaymentSetup() {
    // Allow skipping payment setup - user can set it up later
    final updatedData = widget.initialData.copyWith(paymentMethodSetup: true);
    widget.onDataChanged(updatedData);
    widget.onNext();
  }
}

