import 'package:equb/ui/responsive.dart';
import 'package:flutter/material.dart';

import '../../models/portal_models.dart';
import '../../widgets/portal_status_badge.dart';

class PortalOperationsCockpitPanel extends StatelessWidget {
  const PortalOperationsCockpitPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final queuesMaxHeight = (context.screenSize.height * 0.32)
      .clamp(180.0, context.isDesktop ? 360.0 : 300.0);
    final alertsMaxHeight = (context.screenSize.height * 0.28)
      .clamp(160.0, context.isDesktop ? 300.0 : 260.0);

    final services = <PortalServiceHealth>[
      const PortalServiceHealth(
        name: 'Payments',
        status: PortalServiceStatus.up,
        detail: 'Webhooks processing normally',
      ),
      const PortalServiceHealth(
        name: 'Wallet',
        status: PortalServiceStatus.degraded,
        detail: 'Backlog elevated',
      ),
      const PortalServiceHealth(
        name: 'Notifications',
        status: PortalServiceStatus.up,
        detail: 'Push queue steady',
      ),
    ];

    final queues = <_QueueKpi>[
      const _QueueKpi(
        title: 'Pending deposits',
        value: '12',
        hint: 'Needs review',
        icon: Icons.payments_outlined,
      ),
      const _QueueKpi(
        title: 'Failed payments',
        value: '3',
        hint: 'Retry candidates',
        icon: Icons.error_outline,
      ),
      const _QueueKpi(
        title: 'Support open',
        value: '7',
        hint: 'Triage queue',
        icon: Icons.support_agent_outlined,
      ),
      const _QueueKpi(
        title: 'Fraud flags',
        value: '1',
        hint: 'Needs investigation',
        icon: Icons.flag_outlined,
      ),
    ];

    final alerts = <_AlertItem>[
      _AlertItem(
        title: 'Wallet backlog elevated',
        body: 'Processing latency increased (UI demo).',
        severity: _AlertSeverity.warning,
      ),
      _AlertItem(
        title: 'Retry window expiring',
        body: '3 payments approaching max retry age (UI demo).',
        severity: _AlertSeverity.info,
      ),
    ];

    final crossAxisCount = context.isDesktop
        ? 4
        : context.isTablet
            ? 2
            : 1;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Operations cockpit',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.dashboard_outlined, color: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Quick view of queues, health, and alerts (UI-first).',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _SectionHeader(title: 'Health'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in services)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheme.outlineVariant.withOpacity(0.7),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PortalStatusBadge(status: s.status),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              s.detail,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionHeader(title: 'Queues'),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: queuesMaxHeight),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: context.isDesktop ? 2.3 : 2.6,
                ),
                itemCount: queues.length,
                itemBuilder: (context, index) => _QueueTile(kpi: queues[index]),
              ),
            ),
            const SizedBox(height: 16),
            _SectionHeader(title: 'Quick actions'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('UI-only: open pending deposits'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.inbox_outlined),
                  label: const Text('Pending deposits'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('UI-only: open failed payments'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.sync_problem_outlined),
                  label: const Text('Failed payments'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('UI-only: export reconciliation'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Export reconciliation'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionHeader(title: 'Alerts'),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: scheme.surfaceVariant,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: alertsMaxHeight),
                child: ListView.separated(
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final a = alerts[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        switch (a.severity) {
                          _AlertSeverity.info => Icons.info_outline,
                          _AlertSeverity.warning => Icons.warning_amber_outlined,
                          _AlertSeverity.critical =>
                            Icons.report_gmailerrorred_outlined,
                        },
                        color: scheme.onSurfaceVariant,
                      ),
                      title: Text(
                        a.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(a.body),
                      trailing: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('UI-only: alert details not wired'),
                            ),
                          );
                        },
                        child: const Text('Details'),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({required this.kpi});

  final _QueueKpi kpi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.7),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withOpacity(0.7),
              ),
            ),
            child: Icon(kpi.icon, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kpi.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  kpi.hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            kpi.value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueKpi {
  const _QueueKpi({
    required this.title,
    required this.value,
    required this.hint,
    required this.icon,
  });

  final String title;
  final String value;
  final String hint;
  final IconData icon;
}

enum _AlertSeverity { info, warning, critical }

class _AlertItem {
  _AlertItem({
    required this.title,
    required this.body,
    required this.severity,
  });

  final String title;
  final String body;
  final _AlertSeverity severity;
}
