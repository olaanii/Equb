import 'package:equb/ui/responsive.dart';
import 'package:flutter/material.dart';

import 'config/portal_feature_flags_panel.dart';
import 'config/portal_gateways_panel.dart';
import 'config/portal_rules_panel.dart';

class PortalConfigController {
  final ValueNotifier<int> section = ValueNotifier<int>(0);

  void openHome() => section.value = 0;
  void openFeatureFlags() => section.value = 1;
  void openGateways() => section.value = 2;
  void openRules() => section.value = 3;

  void dispose() => section.dispose();
}

class PortalConfigPage extends StatefulWidget {
  const PortalConfigPage({super.key, this.controller});

  final PortalConfigController? controller;

  @override
  State<PortalConfigPage> createState() => _PortalConfigPageState();
}

class _PortalConfigPageState extends State<PortalConfigPage> {
  int _section = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?.section.addListener(_syncFromController);
    _section = widget.controller?.section.value ?? 0;
  }

  @override
  void didUpdateWidget(covariant PortalConfigPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.section.removeListener(_syncFromController);
      widget.controller?.section.addListener(_syncFromController);
      _section = widget.controller?.section.value ?? 0;
    }
  }

  @override
  void dispose() {
    widget.controller?.section.removeListener(_syncFromController);
    super.dispose();
  }

  void _syncFromController() {
    final next = widget.controller?.section.value ?? 0;
    if (next == _section) return;
    if (!mounted) return;
    setState(() => _section = next);
  }

  void _open(int next) {
    widget.controller?.section.value = next;
    setState(() => _section = next);
  }

  void _back() {
    widget.controller?.section.value = 0;
    setState(() => _section = 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_section == 1) {
      return _ConfigFrame(title: 'Feature flags', onBack: _back, child: const PortalFeatureFlagsPanel());
    }
    if (_section == 2) {
      return _ConfigFrame(title: 'Gateways', onBack: _back, child: const PortalGatewaysPanel());
    }
    if (_section == 3) {
      return _ConfigFrame(title: 'Rules', onBack: _back, child: const PortalRulesPanel());
    }

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Config',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Super admin-only operational configuration.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _LinkCard(
                title: 'Feature flags',
                subtitle: 'Toggle product and gateway experiments.',
                icon: Icons.tune,
                onTap: () => _open(1),
              ),
              const SizedBox(height: 12),
              _LinkCard(
                title: 'Gateways',
                subtitle: 'Configure adapters and settings.',
                icon: Icons.settings_outlined,
                onTap: () => _open(2),
              ),
              const SizedBox(height: 12),
              _LinkCard(
                title: 'Rules',
                subtitle: 'Platform rules (JSON).',
                icon: Icons.rule_folder_outlined,
                onTap: () => _open(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigFrame extends StatelessWidget {
  const _ConfigFrame({required this.title, required this.onBack, required this.child});

  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.pagePadding.left,
            12,
            context.pagePadding.right,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: child),
      ],
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.onSurface),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
