import 'package:equb/models/transaction_model.dart';
import 'package:equb/providers/gateway_providers.dart';
import 'package:equb/providers/transaction_providers.dart';
import 'package:equb/services/gateway_service.dart';
import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/screens/transactions/tx_detail_screen.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TxHistoryScreen extends ConsumerStatefulWidget {
  const TxHistoryScreen({super.key});

  @override
  ConsumerState<TxHistoryScreen> createState() => _TxHistoryScreenState();
}

class _TxHistoryScreenState extends ConsumerState<TxHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  TransactionStatus? _statusFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transactionsAsync = ref.watch(transactionHistoryProvider);
    final gatewayConfigsAsync = ref.watch(gatewayConfigsProvider);
    final gatewayLookup = gatewayConfigsAsync.maybeWhen(
      data:
          (configs) => {
            for (final config in configs) config.id.toLowerCase(): config,
          },
      orElse: () => const <String, PaymentGatewayConfig>{},
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (transactions) {
          final filtered =
              transactions.where(_matchesFilter).toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          final totalIn = filtered
              .where((tx) => tx.status == TransactionStatus.success)
              .fold<double>(0, (sum, tx) => sum + tx.amount);
          final totalPending = filtered
              .where((tx) => tx.status == TransactionStatus.pending)
              .fold<double>(0, (sum, tx) => sum + tx.amount);

          return Padding(
            padding: context.pagePadding,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Search by ID or gateway',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            children:
                                TransactionStatus.values
                                    .map(
                                      (status) => FilterChip(
                                        selected: _statusFilter == status,
                                        label: Text(_statusLabel(status)),
                                        onSelected: (selected) {
                                          setState(() {
                                            _statusFilter =
                                                selected ? status : null;
                                          });
                                        },
                                      ),
                                    )
                                    .toList(),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryTile(
                                  label: 'Successful',
                                  value: 'ETB ${totalIn.toStringAsFixed(2)}',
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: _SummaryTile(
                                  label: 'Pending',
                                  value:
                                      'ETB ${totalPending.toStringAsFixed(2)}',
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Expanded(
                      child:
                          filtered.isEmpty
                              ? Center(
                                child: InfoCard(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.receipt_long_outlined,
                                        size: 40,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        'No transactions match your filters',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Try adjusting the status chips or search terms.',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder:
                                    (_, __) =>
                                        const SizedBox(height: AppSpacing.md),
                                itemBuilder: (context, index) {
                                  final tx = filtered[index];
                                  final isCredit = tx.toUserId == 'wallet';
                                  final amountPrefix = isCredit ? '+' : '-';
                                  final amountColor =
                                      isCredit
                                          ? AppColors.success
                                          : AppColors.error;
                                  final gatewayLabel = _gatewayDisplayLabel(
                                    tx.gateway,
                                    gatewayLookup,
                                  );
                                  final gatewayEnvSuffix =
                                      _gatewayEnvironmentSuffix(
                                        tx.gateway,
                                        gatewayLookup,
                                      );
                                  return InfoCard(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder:
                                              (_) =>
                                                  TxDetailScreen(txId: tx.id),
                                        ),
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppColors.surface,
                                          child: Text(
                                            gatewayLabel.isNotEmpty
                                                ? gatewayLabel[0]
                                                : '?',
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                tx.id,
                                                style: theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.xs,
                                              ),
                                              Text(
                                                '$gatewayLabel$gatewayEnvSuffix • ${_formatDate(tx.timestamp)}',
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color:
                                                          AppColors
                                                              .textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '$amountPrefix ETB ${tx.amount.toStringAsFixed(2)}',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    color: amountColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(
                                              height: AppSpacing.xs,
                                            ),
                                            _StatusBadge(status: tx.status),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _matchesFilter(TransactionModel tx) {
    if (_statusFilter != null && tx.status != _statusFilter) return false;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return tx.id.toLowerCase().contains(query) ||
        tx.gateway.toLowerCase().contains(query);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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

  String _gatewayDisplayLabel(
    String rawGateway,
    Map<String, PaymentGatewayConfig> lookup,
  ) {
    final config = lookup[rawGateway.toLowerCase()];
    if (config != null && config.name.isNotEmpty) {
      return config.name;
    }
    return _formatGatewayLabel(rawGateway);
  }

  String _gatewayEnvironmentSuffix(
    String rawGateway,
    Map<String, PaymentGatewayConfig> lookup,
  ) {
    final config = lookup[rawGateway.toLowerCase()];
    if (config == null || config.environment.isEmpty) {
      return '';
    }
    return ' (${_formatEnvironmentLabel(config.environment)})';
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

  String _formatEnvironmentLabel(String environment) {
    if (environment.isEmpty) return 'Custom';
    return environment[0].toUpperCase() + environment.substring(1);
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withAlpha((0.08 * 255).round()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

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
