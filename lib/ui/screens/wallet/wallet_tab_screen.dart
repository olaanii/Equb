import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';

class WalletTabScreen extends StatefulWidget {
  const WalletTabScreen({super.key});

  @override
  State<WalletTabScreen> createState() => _WalletTabScreenState();
}

class _WalletTabScreenState extends State<WalletTabScreen> {
  int _segment = 0;

  final _tx = const <_WalletTxItem>[
    _WalletTxItem(title: 'Top up', date: 'Mar 18, 2024', amount: '+ 200.00'),
    _WalletTxItem(title: 'Transfer', date: 'Mar 18, 2024', amount: '- 120.00'),
    _WalletTxItem(title: 'Fee', date: 'Mar 17, 2024', amount: '- 2.50'),
    _WalletTxItem(title: 'Refund', date: 'Mar 16, 2024', amount: '+ 25.00'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz_rounded),
            tooltip: 'More',
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.pagePaddingMobile,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available balance',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface.withOpacity(0.7),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ETB 1,459.70',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Top up'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.north_east_rounded),
                          label: const Text('Send'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Overview')),
              ButtonSegment(value: 1, label: Text('Transactions')),
            ],
            selected: {_segment},
            onSelectionChanged: (s) => setState(() => _segment = s.first),
          ),
          const SizedBox(height: 16),
          if (_segment == 0) ...[
            _WalletOverviewCard(
              title: 'Spending',
              value: '127.96',
              subtitle: 'This week',
              icon: Icons.bar_chart_rounded,
            ),
            const SizedBox(height: 12),
            _WalletOverviewCard(
              title: 'Income',
              value: '494.54',
              subtitle: 'This week',
              icon: Icons.trending_up_rounded,
            ),
          ] else ...[
            ..._tx.map((t) => _WalletTxTile(item: t)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _WalletOverviewCard extends StatelessWidget {
  const _WalletOverviewCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primary.withOpacity(0.18),
          child: Icon(icon, color: scheme.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _WalletTxItem {
  const _WalletTxItem({
    required this.title,
    required this.date,
    required this.amount,
  });

  final String title;
  final String date;
  final String amount;
}

class _WalletTxTile extends StatelessWidget {
  const _WalletTxTile({required this.item});

  final _WalletTxItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPositive = item.amount.trimLeft().startsWith('+');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.surfaceVariant,
          child: Icon(
            isPositive ? Icons.call_received_rounded : Icons.call_made_rounded,
            color: scheme.onSurface.withOpacity(0.7),
          ),
        ),
        title: Text(item.title),
        subtitle: Text(item.date),
        trailing: Text(
          item.amount,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: isPositive ? AppColors.success : scheme.onSurface,
              ),
        ),
      ),
    );
  }
}
