import 'package:equb/domain/feature_flags.dart';
import 'package:equb/domain/gateway_feature_flag.dart';
import 'package:equb/services/feature_flag_service.dart';
import 'package:equb/ui/responsive.dart';
import 'package:flutter/material.dart';

class PortalFeatureFlagsPanel extends StatefulWidget {
  const PortalFeatureFlagsPanel({super.key});

  @override
  State<PortalFeatureFlagsPanel> createState() => _PortalFeatureFlagsPanelState();
}

class _PortalFeatureFlagsPanelState extends State<PortalFeatureFlagsPanel> {
  final _service = FeatureFlagService();

  FeatureFlags? _flags;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final flags = await _service.load();
      if (!mounted) return;
      setState(() {
        _flags = flags;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final flags = _flags;
    if (flags == null) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.save(flags);
      messenger.showSnackBar(
        const SnackBar(content: Text('Feature flags saved')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to save flags: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: context.pagePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text('Failed to load flags', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('$_error', style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final flags = _flags ?? const FeatureFlags();

    final gateways = const [
      (id: 'telebirr', title: 'Telebirr'),
      (id: 'cbe_birr', title: 'CBE Birr'),
    ];

    Widget gatewayFlagEditor({required String id, required String title}) {
      final current = flags.gatewayFlagFor(id);
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
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: current.enabled,
                    onChanged: (value) {
                      setState(() {
                        _flags = flags.copyWith(
                          gatewayFlags: {
                            ...flags.gatewayFlags,
                            id: current.copyWith(enabled: value),
                          },
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Environment',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  DropdownButton<GatewayEnvironment>(
                    value: current.environment,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _flags = flags.copyWith(
                          gatewayFlags: {
                            ...flags.gatewayFlags,
                            id: current.copyWith(environment: value),
                          },
                        );
                      });
                    },
                    items: [
                      for (final env in GatewayEnvironment.values)
                        DropdownMenuItem(
                          value: env,
                          child: Text(env.name),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Stored in RTDB at config/feature_flags.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
        child: ListView.builder(
          padding: context.pagePadding,
          itemCount: 4 + gateways.length,
          itemBuilder: (context, index) {
            // 0: header row
            if (index == 0) {
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      'Feature flags',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                ],
              );
            }

            // 1: subtitle
            if (index == 1) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Control platform and gateway experiments for all clients.',
                  style: theme.textTheme.bodyMedium,
                ),
              );
            }

            // 2: spacing
            if (index == 2) {
              return const SizedBox(height: 16);
            }

            // 3: global flag card
            if (index == 3) {
              return Card(
                elevation: 0,
                child: SwitchListTile.adaptive(
                  title: Text(
                    'Gemini 2.5 Pro enabled',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Global flag for advanced inference. (Portal-only control)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: flags.gemini25ProEnabled,
                  onChanged: (value) {
                    setState(() {
                      _flags = flags.copyWith(gemini25ProEnabled: value);
                    });
                  },
                ),
              );
            }

            // gateway cards (with spacing)
            final gatewayIndex = index - 4;
            final gateway = gateways[gatewayIndex];

            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: gatewayFlagEditor(id: gateway.id, title: gateway.title),
            );
          },
        ),
      ),
    );
  }
}
