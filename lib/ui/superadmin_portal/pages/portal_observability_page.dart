import 'package:equb/ui/responsive.dart';
import 'package:flutter/material.dart';

import '../models/portal_models.dart';
import '../widgets/portal_audit_timeline.dart';

class PortalObservabilityPage extends StatefulWidget {
  const PortalObservabilityPage({super.key});

  @override
  State<PortalObservabilityPage> createState() => _PortalObservabilityPageState();
}

class _PortalObservabilityPageState extends State<PortalObservabilityPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final demoAudit = <PortalAuditEvent>[
      PortalAuditEvent(
        at: DateTime.now().subtract(const Duration(minutes: 3)),
        actor: 'superadmin',
        action: 'Opened',
        target: 'Observability',
        meta: const {'source': 'portal'},
        icon: Icons.monitor_heart_outlined,
      ),
      PortalAuditEvent(
        at: DateTime.now().subtract(const Duration(minutes: 1)),
        actor: 'superadmin',
        action: 'Viewed',
        target: 'Audit timeline',
        meta: const {'mode': 'ui-only'},
        icon: Icons.history_outlined,
      ),
    ];

    return Padding(
      padding: context.pagePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Observability',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Monitor logs and audit events across microservices (UI-first).',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabs,
                labelColor: scheme.primary,
                unselectedLabelColor: scheme.onSurfaceVariant,
                indicatorColor: scheme.primary,
                tabs: const [
                  Tab(text: 'Logs'),
                  Tab(text: 'Audit'),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    SingleChildScrollView(
                      child: Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Logs',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Connect to backend log source later (Cloud Logging / RTDB log sink).',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'No logs yet.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      child: Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Audit timeline',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'UI-first timeline of privileged actions. Backend wiring can stream immutable audit events later.',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              PortalAuditTimeline(events: demoAudit),
                            ],
                          ),
                        ),
                      ),
                    ),
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
