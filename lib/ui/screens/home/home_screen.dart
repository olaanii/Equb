import 'package:equb/providers/providers.dart';
import 'package:equb/models/equb_model.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/providers/app_providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider).asData?.value;
    final groupsAsync = ref.watch(equbGroupsProvider);

    final recent = const <_HomeTransactionItem>[
      _HomeTransactionItem(
        title: 'Transfer to Jason',
        subtitle: 'Today',
        amount: '- 120.00',
        isPositive: false,
      ),
      _HomeTransactionItem(
        title: 'Salary',
        subtitle: 'Yesterday',
        amount: '+ 2,500.00',
        isPositive: true,
      ),
      _HomeTransactionItem(
        title: 'Top up',
        subtitle: 'Yesterday',
        amount: '+ 200.00',
        isPositive: true,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.account_balance_wallet,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Equb'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifications',
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) async {
              if (value == 'sign_out') {
                await ref.read(authServiceProvider).signOut();
              }
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(value: 'sign_out', child: Text('Sign out')),
                ],
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.pagePaddingMobile,
        children: [
          _BalanceCard(
            name: user?.name ?? 'User',
            balance: '1,459.70',
            points: (user?.points ?? 0).toString(),
          ),
          const SizedBox(height: 16),
          _MyEqubsSection(groupsAsync: groupsAsync, user: user),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.north_east_rounded),
                  label: const Text('Transfer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.south_west_rounded),
                  label: const Text('Withdraw'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const _QuickActionsGrid(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent transaction',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton(onPressed: () {}, child: const Text('Show more')),
            ],
          ),
          const SizedBox(height: 12),
          ...recent.map((t) => _TransactionTile(item: t)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.name,
    required this.balance,
    required this.points,
  });

  final String name;
  final String balance;
  final String points;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Neo cash main balance',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.visibility_outlined),
                  tooltip: 'Toggle visibility',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'ETB $balance',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: scheme.outline.withOpacity(0.25)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _InfoPair(
                    label: 'NeoPay number',
                    value: '•••• •••• 5324',
                  ),
                ),
                const SizedBox(width: 12),
                _InfoPair(label: 'Neo points', value: '$points points'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Hi, $name',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyEqubsSection extends ConsumerWidget {
  const _MyEqubsSection({required this.groupsAsync, required this.user});

  final AsyncValue<List<EqubGroup>> groupsAsync;
  final UserModel? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('My Equbs', style: theme.textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(selectedTabIndexProvider.notifier).state = 2;
                  },
                  child: const Text('Open'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return Text(
                    'Join or create a group to start saving together.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: schemeOnSurfaceMuted(context),
                    ),
                  );
                }
                final shown = groups.take(3).toList(growable: false);
                return Column(
                  children: [
                    for (final g in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MyEqubTile(group: g, user: user),
                      ),
                  ],
                );
              },
              loading:
                  () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error:
                  (err, _) => Text(
                    'Failed to load groups: $err',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color schemeOnSurfaceMuted(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return scheme.onSurface.withOpacity(0.7);
  }
}

class _MyEqubTile extends StatelessWidget {
  const _MyEqubTile({required this.group, required this.user});

  final EqubGroup group;
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final uid = user?.id;
    final requiredAmount = group.contributionAmount;
    final contributed =
        uid == null
            ? 0.0
            : (group.rotationState.contributionProgress[uid] ?? 0.0);
    final paid =
        requiredAmount <= 0 ? true : contributed + 1e-8 >= requiredAmount;
    final statusColor = paid ? AppColors.success : scheme.error;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primary.withOpacity(0.15),
              foregroundColor: scheme.primary,
              child: const Icon(Icons.group_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    'Next payout ${_formatDate(group.rotationState.nextPayoutDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                paid ? 'Paid' : 'Not paid',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: statusColor.withOpacity(0.10),
              visualDensity: VisualDensity.compact,
              side: BorderSide(color: statusColor.withOpacity(0.35)),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return '$day/$month/$year';
  }
}

class _InfoPair extends StatelessWidget {
  const _InfoPair({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface.withOpacity(0.65),
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        _QuickAction(icon: Icons.qr_code_scanner_rounded, label: 'Scan'),
        _QuickAction(icon: Icons.wifi_rounded, label: 'Internet'),
        _QuickAction(icon: Icons.shopping_bag_outlined, label: 'Shopping'),
        _QuickAction(icon: Icons.receipt_long_outlined, label: 'Ticket'),
        _QuickAction(icon: Icons.currency_bitcoin_rounded, label: 'Crypto'),
        _QuickAction(icon: Icons.phone_android_rounded, label: 'Airtime'),
        _QuickAction(icon: Icons.savings_outlined, label: 'Equb'),
        _QuickAction(icon: Icons.more_horiz_rounded, label: 'Other'),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline.withOpacity(0.35)),
          ),
          child: Icon(icon, color: scheme.onSurface.withOpacity(0.75)),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _HomeTransactionItem {
  const _HomeTransactionItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isPositive,
  });

  final String title;
  final String subtitle;
  final String amount;
  final bool isPositive;
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item});

  final _HomeTransactionItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amountColor = item.isPositive ? AppColors.success : scheme.onSurface;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withOpacity(0.18),
          child: Icon(Icons.swap_horiz_rounded, color: scheme.primary),
        ),
        title: Text(item.title),
        subtitle: Text(item.subtitle),
        trailing: Text(
          item.amount,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: amountColor,
          ),
        ),
      ),
    );
  }
}
