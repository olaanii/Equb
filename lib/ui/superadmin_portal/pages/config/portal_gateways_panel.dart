import 'package:equb/providers/providers.dart';
import 'package:equb/services/gateway_service.dart';
import 'package:equb/ui/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PortalGatewaysPanel extends ConsumerStatefulWidget {
  const PortalGatewaysPanel({super.key});

  @override
  ConsumerState<PortalGatewaysPanel> createState() => _PortalGatewaysPanelState();
}

class _PortalGatewaysPanelState extends ConsumerState<PortalGatewaysPanel> {
  Future<List<PaymentGatewayConfig>>? _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(gatewayServiceProvider).listGateways();
  }

  void _refresh() {
    setState(() {
      _future = ref.read(gatewayServiceProvider).listGateways();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gatewayService = ref.watch(gatewayServiceProvider);

    return FutureBuilder<List<PaymentGatewayConfig>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: context.pagePadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load gateways',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_outlined),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }

        final gateways = snapshot.data!;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: context.pagePadding,
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Gateways',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Refresh',
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enable/disable payment rails and control their public metadata.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    context.pagePadding.left,
                    0,
                    context.pagePadding.right,
                    context.pagePadding.bottom,
                  ),
                  sliver: SliverList.separated(
                    itemCount: gateways.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final gateway = gateways[index];
                      return _GatewayCard(
                        gateway: gateway,
                        onSave: (updated) async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await gatewayService.upsertGateway(updated);
                            messenger.showSnackBar(
                              SnackBar(content: Text('${updated.name} saved')),
                            );
                            _refresh();
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Save failed: $e')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GatewayCard extends StatefulWidget {
  const _GatewayCard({required this.gateway, required this.onSave});

  final PaymentGatewayConfig gateway;
  final ValueChanged<PaymentGatewayConfig> onSave;

  @override
  State<_GatewayCard> createState() => _GatewayCardState();
}

class _GatewayCardState extends State<_GatewayCard> {
  late bool _enabled = widget.gateway.enabled;
  late String _environment = widget.gateway.environment;

  @override
  void didUpdateWidget(covariant _GatewayCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gateway.id != widget.gateway.id) {
      _enabled = widget.gateway.enabled;
      _environment = widget.gateway.environment;
    }
  }

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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.gateway.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.gateway.id,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Environment',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                DropdownButton<String>(
                  value: _environment,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _environment = value);
                  },
                  items: const [
                    DropdownMenuItem(value: 'mock', child: Text('mock')),
                    DropdownMenuItem(value: 'sandbox', child: Text('sandbox')),
                    DropdownMenuItem(value: 'production', child: Text('production')),
                    DropdownMenuItem(value: 'manual', child: Text('manual')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () {
                  widget.onSave(
                    widget.gateway.copyWith(
                      enabled: _enabled,
                      environment: _environment,
                    ),
                  );
                },
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
