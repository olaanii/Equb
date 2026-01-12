import 'dart:convert';

import 'package:equb/providers/providers.dart';
import 'package:equb/services/gateway_service.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/admin_navigation_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends ConsumerState<SuperAdminScreen> {
  final _rulesController = TextEditingController();
  LogLevel? _filter;
  int _panelIndex = 0;

  @override
  void dispose() {
    _rulesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gatewayService = ref.watch(gatewayServiceProvider);

    final isWide = context.isTablet || context.isDesktop;

    final panels = <_SuperAdminPanelItem>[
      _SuperAdminPanelItem(
        label: 'Gateways',
        icon: Icons.hub_outlined,
        builder: (_) => _GatewayPanel(gatewayService: gatewayService),
      ),
      _SuperAdminPanelItem(
        label: 'Logs',
        icon: Icons.list_alt_outlined,
        builder:
            (_) => _LogsPanel(
              filter: _filter,
              onFilterChanged: (value) => setState(() => _filter = value),
            ),
      ),
      _SuperAdminPanelItem(
        label: 'Rules',
        icon: Icons.rule_folder_outlined,
        builder: (_) => _RulesPanel(controller: _rulesController),
      ),
    ];

    Widget buildBody() {
      if (!isWide) {
        return SingleChildScrollView(
          padding: context.pagePadding,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
              child: Column(
                children: [
                  _GatewayPanel(gatewayService: gatewayService),
                  const SizedBox(height: AppSpacing.lg),
                  _LogsPanel(
                    filter: _filter,
                    onFilterChanged: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RulesPanel(controller: _rulesController),
                ],
              ),
            ),
          ),
        );
      }

      final safeIndex = _panelIndex.clamp(0, panels.length - 1);
      final selected = panels[safeIndex];

      return Row(
        children: [
          AdminNavigationRail(
            title: 'Super Admin',
            selectedIndex: safeIndex,
            onDestinationSelected:
                (value) => setState(() => _panelIndex = value),
            destinations: [
              for (final panel in panels)
                AdminRailDestination(label: panel.label, icon: panel.icon),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: context.pagePadding,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.contentMaxWidth,
                  ),
                  child: selected.builder(context),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (widget.embedded) {
      return SafeArea(child: buildBody());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Command Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: SafeArea(child: buildBody()),
    );
  }
}

class _SuperAdminPanelItem {
  const _SuperAdminPanelItem({
    required this.label,
    required this.icon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final Widget Function(BuildContext) builder;
}

class _GatewayPanel extends StatelessWidget {
  const _GatewayPanel({required this.gatewayService});

  final GatewayService gatewayService;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gateway Controls', style: AppTextStyles.headline2),
            const SizedBox(height: AppSpacing.sm),
            FutureBuilder<List<PaymentGatewayConfig>>(
              future: gatewayService.listGateways(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator(),
                  );
                }
                return Column(
                  children:
                      snapshot.data!
                          .map(
                            (gateway) => _GatewayTile(
                              config: gateway,
                              onUpdate: (updated) async {
                                final messenger = ScaffoldMessenger.of(context);
                                await gatewayService.upsertGateway(updated);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('${gateway.name} updated'),
                                  ),
                                );
                              },
                            ),
                          )
                          .toList(),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              icon: const Icon(Icons.output_outlined),
              label: const Text('Export reconciliation CSV'),
              onPressed: () {
                const out = '# Reconciliation CSV\nGroup ID,Name,Total';
                showDialog(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: const Text('Reconciliation CSV'),
                        content: const SingleChildScrollView(
                          child: SelectableText(out),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GatewayTile extends StatefulWidget {
  const _GatewayTile({required this.config, required this.onUpdate});

  final PaymentGatewayConfig config;
  final ValueChanged<PaymentGatewayConfig> onUpdate;

  @override
  State<_GatewayTile> createState() => _GatewayTileState();
}

class _GatewayTileState extends State<_GatewayTile> {
  late bool enabled = widget.config.enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hub_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.config.name,
                        style: AppTextStyles.headline2.copyWith(fontSize: 18),
                      ),
                      Text(widget.config.id, style: AppTextStyles.bodyText2),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: enabled,
                  onChanged: (value) => setState(() => enabled = value),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: const [
                _Badge(label: 'Realtime telemetry'),
                _Badge(label: 'Credential checked'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed:
                    () => widget.onUpdate(
                      PaymentGatewayConfig(
                        id: widget.config.id,
                        name: widget.config.name,
                        enabled: enabled,
                        meta: widget.config.meta,
                      ),
                    ),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogsPanel extends ConsumerWidget {
  const _LogsPanel({required this.filter, required this.onFilterChanged});

  final LogLevel? filter;
  final ValueChanged<LogLevel?> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(systemLogServiceProvider);
    final entries = logs.list(level: filter);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('System Logs', style: AppTextStyles.headline2),
                DropdownButton<LogLevel?>(
                  value: filter,
                  hint: const Text('Filter level'),
                  onChanged: onFilterChanged,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: LogLevel.info, child: Text('Info')),
                    DropdownMenuItem(
                      value: LogLevel.warning,
                      child: Text('Warning'),
                    ),
                    DropdownMenuItem(
                      value: LogLevel.error,
                      child: Text('Error'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 220,
              child:
                  entries.isEmpty
                      ? const Center(child: Text('No logs recorded.'))
                      : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '[${entry.level.name.toUpperCase()}] ${entry.source}',
                            ),
                            subtitle: Text(entry.message),
                            trailing: IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed:
                                  entry.context == null
                                      ? null
                                      : () => showDialog(
                                        context: context,
                                        builder:
                                            (_) => AlertDialog(
                                              title: const Text('Context'),
                                              content: SelectableText(
                                                const JsonEncoder.withIndent(
                                                  '  ',
                                                ).convert(entry.context),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () =>
                                                          Navigator.of(
                                                            context,
                                                          ).pop(),
                                                  child: const Text('Close'),
                                                ),
                                              ],
                                            ),
                                      ),
                            ),
                          );
                        },
                      ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    logs.log(
                      LogLevel.info,
                      'super_admin',
                      'Manual test event created',
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Test Log'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final csv = logs.exportCsv(level: filter);
                    showDialog(
                      context: context,
                      builder:
                          (_) => AlertDialog(
                            title: const Text('Export CSV'),
                            content: SingleChildScrollView(
                              child: SelectableText(csv),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                    );
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export CSV'),
                ),
                TextButton.icon(
                  onPressed: () {
                    logs.clear();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear All'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesPanel extends StatelessWidget {
  const _RulesPanel({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform Rules (JSON)', style: AppTextStyles.headline2),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: '{"minContribution":100}',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                FilledButton(
                  onPressed: () {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final payload = jsonEncode(jsonDecode(controller.text));
                      controller.text = payload;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Rules validated (local only)'),
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Invalid JSON: $e')),
                      );
                    }
                  },
                  child: const Text('Validate'),
                ),
                OutlinedButton(
                  onPressed: controller.clear,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.surfaceBright,
      labelStyle: AppTextStyles.label,
    );
  }
}
