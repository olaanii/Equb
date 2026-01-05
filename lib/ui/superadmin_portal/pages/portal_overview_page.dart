import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/superadmin_portal/widgets/portal_kpi_tile.dart';
import 'package:equb/ui/superadmin_portal/widgets/portal_status_badge.dart';
import 'package:flutter/material.dart';

import '../models/portal_models.dart';

class PortalOverviewPage extends StatelessWidget {
  const PortalOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'System overview',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'High-level status across core services. Data wiring will be added later.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _KpiGrid(),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Microservices status',
                subtitle:
                    'Service health board (UI-first). Backend will provide live signals later.',
                child: _ServiceHealthBoard(
                  services: const [
                    PortalServiceHealth(
                      name: 'Transactions',
                      status: PortalServiceStatus.unknown,
                      detail: 'Awaiting health feed',
                    ),
                    PortalServiceHealth(
                      name: 'Wallet',
                      status: PortalServiceStatus.unknown,
                      detail: 'Awaiting health feed',
                    ),
                    PortalServiceHealth(
                      name: 'Points',
                      status: PortalServiceStatus.unknown,
                      detail: 'Awaiting health feed',
                    ),
                    PortalServiceHealth(
                      name: 'Support',
                      status: PortalServiceStatus.unknown,
                      detail: 'Awaiting health feed',
                    ),
                    PortalServiceHealth(
                      name: 'Notifications',
                      status: PortalServiceStatus.unknown,
                      detail: 'Awaiting health feed',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Recent activity',
                subtitle: 'Audit/event stream placeholder.',
                child: Column(
                  children: const [
                    _EventRow(title: 'Portal initialized', detail: 'UI skeleton ready', time: 'now'),
                    _EventRow(title: 'Awaiting backend wiring', detail: 'health feed + ops metrics', time: 'next'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isWide = context.isTablet || context.isDesktop;

    final tiles = const <PortalKpiTile>[
      PortalKpiTile(
        label: 'Transactions',
        value: '—',
        hint: 'Pending / failed today',
        icon: Icons.receipt_long_outlined,
      ),
      PortalKpiTile(
        label: 'Wallet',
        value: '—',
        hint: 'Ledger health',
        icon: Icons.account_balance_wallet_outlined,
      ),
      PortalKpiTile(
        label: 'Points',
        value: '—',
        hint: 'Adjustments needed',
        icon: Icons.stars_outlined,
      ),
      PortalKpiTile(
        label: 'Support',
        value: '—',
        hint: 'Open tickets',
        icon: Icons.support_agent_outlined,
      ),
    ];

    if (!isWide) {
      return Column(
        children: [
          for (final tile in tiles) ...[
            tile,
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    return GridView.count(
      crossAxisCount: context.isDesktop ? 4 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: tiles,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ServiceHealthBoard extends StatelessWidget {
  const _ServiceHealthBoard({required this.services});

  final List<PortalServiceHealth> services;

  @override
  Widget build(BuildContext context) {
    final isWide = context.isTablet || context.isDesktop;

    if (!isWide) {
      return Column(
        children: [
          for (final service in services) ...[
            _ServiceCard(service: service),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    return GridView.count(
      crossAxisCount: context.isDesktop ? 3 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final service in services) _ServiceCard(service: service),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final PortalServiceHealth service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PortalStatusBadge(status: service.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              service.detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Open logs for ${service.name} (TODO)')),
                    );
                  },
                  icon: const Icon(Icons.subject_outlined),
                  label: const Text('Logs'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Open module ${service.name} (TODO)')),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.title,
    required this.detail,
    required this.time,
  });

  final String title;
  final String detail;
  final String time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        detail,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        time,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
