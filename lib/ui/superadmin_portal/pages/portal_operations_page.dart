import 'package:equb/ui/responsive.dart';
import 'package:flutter/material.dart';

import 'operations/portal_operations_cockpit_panel.dart';
import 'operations/portal_support_inbox_panel.dart';

class PortalOperationsPage extends StatelessWidget {
  const PortalOperationsPage({super.key});

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
                'Operations',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Run day-to-day operational workflows (transactions, wallet, points, support).',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const PortalOperationsCockpitPanel(),
              const SizedBox(height: 12),
              _StubCard(
                title: 'Transactions',
                bullets: const [
                  'Pending deposits queue',
                  'Failed payments / retries',
                  'Reconciliation exports',
                ],
              ),
              const SizedBox(height: 12),
              _StubCard(
                title: 'Points',
                bullets: const [
                  'Ledger view',
                  'Manual adjustments (requires backend)',
                  'Fraud flags',
                ],
              ),
              const SizedBox(height: 12),
              const PortalSupportInboxPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StubCard extends StatelessWidget {
  const _StubCard({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

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
            const SizedBox(height: 10),
            for (final bullet in bullets)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bullet,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
