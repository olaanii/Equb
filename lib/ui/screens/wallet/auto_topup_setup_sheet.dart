import 'package:equb/models/auto_topup.dart';
import 'package:equb/providers/gateway_providers.dart';
import 'package:equb/services/auto_topup_service.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AutoTopupSetupSheet extends ConsumerStatefulWidget {
  const AutoTopupSetupSheet({
    super.key,
    required this.existingRule,
    required this.userId,
    required this.autoTopupService,
  });

  final AutoTopupRule? existingRule;
  final String userId;
  final AutoTopupService autoTopupService;

  @override
  ConsumerState<AutoTopupSetupSheet> createState() => _AutoTopupSetupSheetState();
}

class _AutoTopupSetupSheetState extends ConsumerState<AutoTopupSetupSheet> {
  final _thresholdController = TextEditingController();
  final _amountController = TextEditingController();
  bool _enabled = true;
  AutoTopupFrequency _frequency = AutoTopupFrequency.weekly;
  String? _paymentMethod;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    if (widget.existingRule != null) {
      final rule = widget.existingRule!;
      _enabled = rule.enabled;
      _thresholdController.text = rule.thresholdAmount.toStringAsFixed(2);
      _amountController.text = rule.topupAmount.toStringAsFixed(2);
      _frequency = rule.frequency;
      _paymentMethod = rule.paymentMethod;
    } else {
      // Default values
      _thresholdController.text = '500.00';
      _amountController.text = '750.00';
    }
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gatewaysAsync = ref.watch(gatewayConfigsProvider);
    final availableGateways = gatewaysAsync.maybeWhen(
      data: (gateways) => gateways.where((g) => g.enabled).toList(),
      orElse: () => const <PaymentGatewayConfig>[],
    );

    return Padding(
      padding: MediaQuery.of(context).viewInsets.add(const EdgeInsets.all(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existingRule != null ? 'Edit Auto Top-up' : 'Set up Auto Top-up',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          // Enable/disable toggle
          SwitchListTile.adaptive(
            value: _enabled,
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable auto top-up'),
            subtitle: const Text('Automatically top up when balance drops below threshold'),
            onChanged: (value) => setState(() => _enabled = value),
          ),

          const SizedBox(height: 16),

          // Threshold amount
          TextField(
            controller: _thresholdController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Balance threshold (ETB)',
              hintText: 'Minimum balance to maintain',
            ),
            enabled: _enabled,
          ),

          const SizedBox(height: 12),

          // Top-up amount
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Top-up amount (ETB)',
              hintText: 'Amount to add when threshold is reached',
            ),
            enabled: _enabled,
          ),

          const SizedBox(height: 12),

          // Frequency
          DropdownButtonFormField<AutoTopupFrequency>(
            value: _frequency,
            decoration: const InputDecoration(labelText: 'Frequency'),
            items: AutoTopupFrequency.values.map((frequency) {
              return DropdownMenuItem(
                value: frequency,
                child: Text(frequency.label),
              );
            }).toList(),
            onChanged: _enabled
                ? (value) => setState(() => _frequency = value!)
                : null,
          ),

          const SizedBox(height: 12),

          // Payment method
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: availableGateways.map((gateway) {
              return DropdownMenuItem(
                value: gateway.id,
                child: Text('${gateway.name} (${gateway.environment})'),
              );
            }).toList(),
            onChanged: _enabled
                ? (value) => setState(() => _paymentMethod = value)
                : null,
            hint: const Text('Select payment method'),
          ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              if (widget.existingRule != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : _deleteRule,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: (_isSubmitting || !_isValidInput(availableGateways))
                      ? null
                      : _saveRule,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.existingRule != null ? 'Update' : 'Create'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  bool _isValidInput(List<PaymentGatewayConfig> availableGateways) {
    if (!_enabled) return true;

    final threshold = double.tryParse(_thresholdController.text);
    final amount = double.tryParse(_amountController.text);

    return threshold != null &&
           amount != null &&
           threshold > 0 &&
           amount > 0 &&
           _paymentMethod != null &&
           availableGateways.any((g) => g.id == _paymentMethod);
  }

  Future<void> _saveRule() async {
    setState(() => _isSubmitting = true);

    try {
      final threshold = double.parse(_thresholdController.text);
      final amount = double.parse(_amountController.text);

      if (widget.existingRule != null) {
        // Update existing rule
        final updatedRule = widget.existingRule!.copyWith(
          enabled: _enabled,
          thresholdAmount: threshold,
          topupAmount: amount,
          frequency: _frequency,
          paymentMethod: _paymentMethod!,
        );

        await widget.autoTopupService.updateRule(widget.existingRule!.id, updatedRule);
      } else {
        // Create new rule
        await widget.autoTopupService.createRule(
          userId: widget.userId,
          thresholdAmount: threshold,
          topupAmount: amount,
          frequency: _frequency,
          paymentMethod: _paymentMethod!,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingRule != null
                  ? 'Auto top-up rule updated successfully'
                  : 'Auto top-up rule created successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save rule: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteRule() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Auto Top-up Rule'),
        content: const Text(
          'Are you sure you want to delete this auto top-up rule? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.autoTopupService.deleteRule(widget.existingRule!.id);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto top-up rule deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete rule: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

