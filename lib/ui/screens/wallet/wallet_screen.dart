import 'package:equb/models/transaction_model.dart';
import 'package:equb/providers/gateway_providers.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/providers/transaction_providers.dart';
import 'package:equb/providers/wallet_providers.dart';
import 'package:equb/services/gateway_service.dart';
import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(walletSummaryProvider);
    final transactionsAsync = ref.watch(transactionHistoryProvider);
    final gatewaysAsync = ref.watch(gatewayConfigsProvider);

    final gatewayConfigs = gatewaysAsync.maybeWhen(
      data: (value) => value,
      orElse: () => const <PaymentGatewayConfig>[],
    );
    final activeGateways = gatewayConfigs
        .where((config) => config.enabled)
        .toList(growable: false);
    final gatewayLookup = <String, PaymentGatewayConfig>{
      for (final config in gatewayConfigs) config.id.toLowerCase(): config,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (summary) {
          final overviewCard = _buildOverviewCard(context, summary);
          final quickActions = _buildQuickActions(context, ref, activeGateways);
          final activityCard = _buildActivityCard(
            context,
            ref,
            summary,
            transactionsAsync,
            gatewayLookup,
          );

          Widget layout;
          if (context.isDesktop) {
            layout = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      overviewCard,
                      const SizedBox(height: AppSpacing.lg),
                      quickActions,
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(flex: 2, child: activityCard),
              ],
            );
          } else if (context.isTablet) {
            layout = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: overviewCard),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: quickActions),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                activityCard,
              ],
            );
          } else {
            layout = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                overviewCard,
                const SizedBox(height: AppSpacing.lg),
                quickActions,
                const SizedBox(height: AppSpacing.lg),
                activityCard,
              ],
            );
          }

          return SingleChildScrollView(
            padding: context.pagePadding,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
                child: layout,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(BuildContext context, WalletSummary summary) {
    final theme = Theme.of(context);
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Wallet overview', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          BalanceDisplay(
            label: 'Available balance',
            amount: 'ETB ${summary.available.toStringAsFixed(2)}',
            amountColor: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Locked for payouts',
                  value: 'ETB ${summary.locked.toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Lifetime deposits',
                  value: 'ETB ${summary.lifetimeDeposits.toStringAsFixed(2)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Lifetime payouts',
                  value: 'ETB ${summary.lifetimePayouts.toStringAsFixed(2)}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Deposits made',
                  value: '${summary.depositCount}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    BuildContext context,
    WidgetRef ref,
    WalletSummary summary,
    AsyncValue<List<TransactionModel>> transactionsAsync,
    Map<String, PaymentGatewayConfig> gatewayLookup,
  ) {
    final theme = Theme.of(context);
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent activity',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showScheduleDetails(context),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Schedule'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildUpcomingSection(context, summary),
          const SizedBox(height: 16),
          transactionsAsync.when(
            loading:
                () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            error:
                (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Unable to load activity: $error'),
                ),
            data:
                (transactions) => _buildTransactionsList(
                  context,
                  transactions,
                  gatewayLookup,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingSection(BuildContext context, WalletSummary summary) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surface.withAlpha((0.35 * 255).round()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upcoming contribution',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text('Auto-debit every Friday at 08:00'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Deposits made: ${summary.depositCount}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Text(
                  'Withdrawals completed: ${summary.withdrawCount}',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(
    BuildContext context,
    List<TransactionModel> transactions,
    Map<String, PaymentGatewayConfig> gatewayLookup,
  ) {
    if (transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No wallet activity yet.'),
      );
    }

    final preview = transactions.take(5).toList(growable: false);
    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: preview.length,
          separatorBuilder: (_, __) => const Divider(height: 20),
          itemBuilder: (context, index) {
            final tx = preview[index];
            final normalizedKey = tx.gateway.toLowerCase();
            final config = gatewayLookup[normalizedKey];
            final label = config?.name ?? _formatGatewayLabel(tx.gateway);
            final env = config?.environment;
            return _TransactionRow(
              transaction: tx,
              gatewayLabel: label,
              gatewayEnvironment: env,
            );
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _openFullHistory(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open full history'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    List<PaymentGatewayConfig> gateways,
  ) {
    final quickActions = [
      _QuickActionConfig(
        title: 'Deposit funds',
        subtitle:
            gateways.isEmpty
                ? 'Enable a gateway to accept deposits'
                : 'Instant top-up via ${_primaryGatewayLabel(gateways)}',
        icon: Icons.download_rounded,
        accent: AppColors.primary,
        onTap:
            gateways.isEmpty
                ? () => _showNoGatewayDialog(context)
                : () => _showDepositSheet(context, ref, gateways),
      ),
      _QuickActionConfig(
        title: 'Withdraw cash',
        subtitle: 'Send funds to your preferred channel',
        icon: Icons.upload_rounded,
        accent: AppColors.success,
        onTap: () => _showWithdrawSheet(context, ref),
      ),
      _QuickActionConfig(
        title: 'Auto top-up',
        subtitle: 'Keep balance above your safe threshold',
        icon: Icons.repeat_rounded,
        accent: AppColors.secondary,
        onTap: () => _showAutoTopUpSheet(context, ref),
      ),
      _QuickActionConfig(
        title: 'Export statement',
        subtitle: 'Download your full transaction history',
        icon: Icons.file_download_rounded,
        accent: AppColors.grey4,
        onTap: () => _exportStatement(context),
      ),
    ];

    return InfoCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (context.isMobile) {
            return Column(
              children: [
                for (var i = 0; i < quickActions.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == quickActions.length - 1 ? 0 : 12,
                    ),
                    child: _QuickActionTile(config: quickActions[i]),
                  ),
              ],
            );
          }

          const spacing = 12.0;
          final columns = constraints.maxWidth >= 720 ? 3 : 2;
          final tileWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final action in quickActions)
                SizedBox(
                  width: tileWidth,
                  child: _QuickActionTile(config: action),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showNoGatewayDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('No gateways enabled'),
            content: const Text(
              'Enable Telebirr or CBE Birr from Admin > Feature Flags before accepting wallet deposits.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  String _primaryGatewayLabel(List<PaymentGatewayConfig> gateways) {
    if (gateways.isEmpty) return 'available gateways';
    final primary = gateways.first;
    return '${primary.name} (${_formatEnvironmentLabel(primary.environment)})';
  }

  String _formatEnvironmentLabel(String environment) {
    if (environment.isEmpty) return 'Custom';
    return environment[0].toUpperCase() + environment.substring(1);
  }

  String _formatGatewayLabel(String raw) {
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

  void _showDepositSheet(
    BuildContext context,
    WidgetRef ref,
    List<PaymentGatewayConfig> gateways,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final amountController = TextEditingController();
        String? method = gateways.isNotEmpty ? gateways.first.id : null;
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: MediaQuery.of(
                context,
              ).viewInsets.add(const EdgeInsets.all(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deposit funds',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount (ETB)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                    ),
                    items:
                        gateways
                            .map(
                              (config) => DropdownMenuItem(
                                value: config.id,
                                child: Text(
                                  '${config.name} (${_formatEnvironmentLabel(config.environment)})',
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => setState(() => method = value),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: 'Deposit now',
                    icon: Icons.download_rounded,
                    onPressed:
                        method == null
                            ? null
                            : () async {
                              final amount = double.tryParse(
                                amountController.text.trim(),
                              );
                              if (amount == null || amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enter a valid amount.'),
                                  ),
                                );
                                return;
                              }

                              final user = ref.read(currentUserProvider).value;
                              if (user == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('User not found.'),
                                  ),
                                );
                                return;
                              }

                              final selectedConfig = gateways.firstWhere(
                                (g) => g.id == method,
                                orElse:
                                    () => PaymentGatewayConfig(
                                      id: method!,
                                      name: _formatGatewayLabel(method!),
                                      enabled: true,
                                      environment: 'custom',
                                    ),
                              );
                              final display =
                                  '${selectedConfig.name} (${_formatEnvironmentLabel(selectedConfig.environment)})';

                              try {
                                await ref
                                    .read(walletRepositoryProvider)
                                    .deposit(
                                      user.id,
                                      amount,
                                      selectedConfig.id,
                                    );
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Deposited ETB ${amount.toStringAsFixed(2)} via $display.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Deposit failed: $e')),
                                );
                              }
                            },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWithdrawSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final amountController = TextEditingController();
        final noteController = TextEditingController();
        String destination = 'Telebirr Wallet';
        return Padding(
          padding: MediaQuery.of(
            context,
          ).viewInsets.add(const EdgeInsets.all(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Withdraw funds',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount (ETB)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: destination,
                decoration: const InputDecoration(labelText: 'Destination'),
                items: const [
                  DropdownMenuItem(
                    value: 'Telebirr Wallet',
                    child: Text('Telebirr wallet'),
                  ),
                  DropdownMenuItem(
                    value: 'Bank Account',
                    child: Text('Bank account (ACH)'),
                  ),
                  DropdownMenuItem(
                    value: 'Cash Pickup',
                    child: Text('Cash pickup partner'),
                  ),
                ],
                onChanged: (value) => destination = value ?? destination,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Memo (optional)'),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                text: 'Request withdrawal',
                icon: Icons.upload,
                onPressed: () async {
                  final amount = double.tryParse(amountController.text.trim());
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid amount.')),
                    );
                    return;
                  }

                  final user = ref.read(currentUserProvider).value;
                  if (user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User not found.')),
                    );
                    return;
                  }

                  try {
                    await ref
                        .read(walletRepositoryProvider)
                        .withdraw(user.id, amount, destination);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Withdrawal of ETB ${amount.toStringAsFixed(2)} queued to $destination.',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Withdrawal failed: $e')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showAutoTopUpSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        bool enabled = true;
        String cadence = 'Weekly';
        final amountController = TextEditingController(text: '750');
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: MediaQuery.of(
                context,
              ).viewInsets.add(const EdgeInsets.all(24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto top-up plan',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: enabled,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable auto top-up'),
                    onChanged: (value) => setState(() => enabled = value),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount per cycle (ETB)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: cadence,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    items: const [
                      DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                        value: 'Bi-weekly',
                        child: Text('Bi-weekly'),
                      ),
                      DropdownMenuItem(
                        value: 'Monthly',
                        child: Text('Monthly'),
                      ),
                    ],
                    onChanged:
                        (value) => setState(() => cadence = value ?? cadence),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: 'Save preferences',
                    icon: Icons.save_outlined,
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            enabled
                                ? 'Auto top-up of ETB ${amountController.text} scheduled $cadence.'
                                : 'Auto top-up disabled.',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _exportStatement(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (!context.mounted) return;
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Statement exported and emailed to you.'),
              ),
            );
          }
        });
        return AlertDialog(
          title: const Text('Preparing statement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Generating PDF with your last 90 days activity...'),
            ],
          ),
        );
      },
    );
  }

  void _showScheduleDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Contribution schedule'),
          content: const Text(
            'Your weekly contribution of ETB 750 will auto-debit every Friday at 08:00\n Reminder SMS and push notifications are sent 24 hours before each debit',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _openFullHistory(BuildContext context) {
    Navigator.of(context).pushNamed('/transactions');
  }
}

class _QuickActionConfig {
  const _QuickActionConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.config});

  final _QuickActionConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradientStart = config.accent.withOpacity(0.16);
    final gradientEnd = config.accent.withOpacity(0.05);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: config.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [gradientStart, gradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: config.accent.withOpacity(0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: config.accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(config.icon, color: config.accent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: config.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surface.withAlpha((0.35 * 255).round()),
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

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.gatewayLabel,
    this.gatewayEnvironment,
  });

  final TransactionModel transaction;
  final String gatewayLabel;
  final String? gatewayEnvironment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = transaction.toUserId == 'wallet';
    final amountPrefix = isCredit ? '+' : '-';
    final amountColor = isCredit ? AppColors.success : AppColors.error;

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: AppColors.surface.withAlpha((0.3 * 255).round()),
          child: Text(gatewayLabel.isNotEmpty ? gatewayLabel[0] : '?'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.id,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_gatewayDetailLabel()} • ${_formatTimestamp(transaction.timestamp)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$amountPrefix ETB ${transaction.amount.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            _StatusPill(status: transaction.status),
          ],
        ),
      ],
    );
  }

  String _gatewayDetailLabel() {
    if (gatewayEnvironment == null || gatewayEnvironment!.isEmpty) {
      return gatewayLabel;
    }
    final env = _formatEnvironment(gatewayEnvironment!);
    return '$gatewayLabel • $env';
  }

  String _formatEnvironment(String environment) {
    if (environment.isEmpty) return 'Custom';
    return environment[0].toUpperCase() + environment.substring(1);
  }

  String _formatTimestamp(DateTime timestamp) {
    final day = timestamp.day.toString().padLeft(2, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final year = timestamp.year;
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$day/$month/$year • $hour:$minute';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;
    switch (status) {
      case TransactionStatus.pending:
        color = AppColors.warning;
        label = 'Pending';
        break;
      case TransactionStatus.success:
        color = AppColors.success;
        label = 'Success';
        break;
      case TransactionStatus.failed:
        color = AppColors.error;
        label = 'Failed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.16 * 255).round()),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
