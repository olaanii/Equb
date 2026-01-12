import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/superadmin_portal/widgets/portal_command_palette.dart';
import 'package:equb/ui/superadmin_portal/widgets/portal_kpi_tile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/portal_config_page.dart';
import 'pages/portal_management_page.dart';
import 'pages/portal_observability_page.dart';
import 'pages/portal_operations_page.dart';
import 'pages/portal_overview_page.dart';
import 'services/portal_notification_service.dart';
import 'widgets/portal_notification_center.dart';

class SuperAdminPortalShell extends StatefulWidget {
  const SuperAdminPortalShell({super.key});

  @override
  State<SuperAdminPortalShell> createState() => _SuperAdminPortalShellState();
}

class _SuperAdminPortalShellState extends State<SuperAdminPortalShell> {
  int _index = 0;
  bool _sidebarCollapsed = false;

  late final PortalConfigController _configController = PortalConfigController();
  late final PortalNotificationService _notificationService =
      PortalNotificationService();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _configController.dispose();
    _notificationService.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  void _openCommandPalette(List<_PortalDestination> destinations) {
    final commands = <PortalCommand>[
      for (var i = 0; i < destinations.length; i++)
        PortalCommand(
          title: 'Go to ${destinations[i].label}',
          subtitle: 'Open ${destinations[i].label} section',
          icon: destinations[i].icon,
          run: () => setState(() {
            _index = i;
          }),
        ),
      PortalCommand(
        title: 'Config: Feature flags',
        subtitle: 'Open portal feature flags editor',
        icon: Icons.tune,
        run: () => setState(() {
          _index = destinations.length - 1;
          _configController.openFeatureFlags();
        }),
      ),
      PortalCommand(
        title: 'Config: Gateways',
        subtitle: 'Open portal gateway controls',
        icon: Icons.settings_outlined,
        run: () => setState(() {
          _index = destinations.length - 1;
          _configController.openGateways();
        }),
      ),
      PortalCommand(
        title: 'Config: Rules',
        subtitle: 'Open rules JSON editor',
        icon: Icons.rule_folder_outlined,
        run: () => setState(() {
          _index = destinations.length - 1;
          _configController.openRules();
        }),
      ),
    ];

    showPortalCommandPalette(context, commands: commands);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = context.isTablet || context.isDesktop;

    final destinations = <_PortalDestination>[
      _PortalDestination(
        label: 'Overview',
        icon: Icons.dashboard_outlined,
        builder: (_) => const PortalOverviewPage(),
      ),
      _PortalDestination(
        label: 'Operations',
        icon: Icons.precision_manufacturing_outlined,
        builder: (_) => const PortalOperationsPage(),
      ),
      _PortalDestination(
        label: 'Management',
        icon: Icons.account_tree_outlined,
        builder: (_) => const PortalManagementPage(),
      ),
      _PortalDestination(
        label: 'Observability',
        icon: Icons.monitor_heart_outlined,
        builder: (_) => const PortalObservabilityPage(),
      ),
      _PortalDestination(
        label: 'Config',
        icon: Icons.tune_outlined,
        builder: (_) => PortalConfigPage(controller: _configController),
      ),
    ];

    final safeIndex = _index.clamp(0, destinations.length - 1);
    final selected = destinations[safeIndex];

    final child = isWide
        ? _buildWide(context, destinations, safeIndex, selected)
        : _buildMobile(context, destinations, safeIndex, selected);

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
            const _OpenCommandPaletteIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK):
            const _OpenCommandPaletteIntent(),
      },
      child: Actions(
        actions: {
          _OpenCommandPaletteIntent: CallbackAction<_OpenCommandPaletteIntent>(
            onInvoke: (_) {
              _openCommandPalette(destinations);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }

  Widget _buildMobile(
    BuildContext context,
    List<_PortalDestination> destinations,
    int safeIndex,
    _PortalDestination selected,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Super Admin • ${selected.label}'),
        actions: [
          PortalNotificationCenter(service: _notificationService),
          IconButton(
            tooltip: 'Command palette',
            onPressed: () => _openCommandPalette(destinations),
            icon: const Icon(Icons.search_outlined),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: SafeArea(child: selected.builder(context)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }

  Widget _buildWide(
    BuildContext context,
    List<_PortalDestination> destinations,
    int safeIndex,
    _PortalDestination selected,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final expandedWidth = context.isDesktop ? 312.0 : 260.0;
    final sidebarWidth = _sidebarCollapsed ? 84.0 : expandedWidth;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: sidebarWidth,
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  right: BorderSide(
                    color: scheme.outlineVariant.withOpacity(0.35),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: _SidebarCollapseButton(
                            collapsed: _sidebarCollapsed,
                            onPressed: () => setState(
                              () => _sidebarCollapsed = !_sidebarCollapsed,
                            ),
                          ),
                        ),
                        if (!_sidebarCollapsed) ...[
                          const SizedBox(height: 8),
                          Text(
                            'SUPER ADMIN PORTAL',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _sidebarCollapsed
                                  ? Icon(
                                      Icons.shield_outlined,
                                      color: scheme.primary,
                                    )
                                  : Text(
                                      'Operations & Services',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                        if (!_sidebarCollapsed) ...[
                          const SizedBox(height: 12),
                          const Row(
                            children: [
                              Expanded(
                                child: PortalKpiTile(
                                  label: 'Services',
                                  value: '—',
                                  hint: 'Live status',
                                  icon: Icons.hub_outlined,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: PortalKpiTile(
                                  label: 'Incidents',
                                  value: '—',
                                  hint: 'Open today',
                                  icon: Icons.warning_amber_outlined,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          _SidebarItem(
                            icon: destinations[i].icon,
                            label: destinations[i].label,
                            selected: i == safeIndex,
                            collapsed: _sidebarCollapsed,
                            onTap: () => setState(() => _index = i),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(selected.label),
                  automaticallyImplyLeading: false,
                  actions: [
                    PortalNotificationCenter(service: _notificationService),
                    IconButton(
                      tooltip: 'Command palette',
                      onPressed: () => _openCommandPalette(destinations),
                      icon: const Icon(Icons.search_outlined),
                    ),
                    IconButton(
                      tooltip: 'Logout',
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_outlined),
                    ),
                  ],
                ),
                body: SafeArea(child: selected.builder(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}

class _PortalDestination {
  final String label;
  final IconData icon;
  final Widget Function(BuildContext) builder;

  const _PortalDestination({
    required this.label,
    required this.icon,
    required this.builder,
  });
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final bg = selected
        ? scheme.primary.withOpacity(0.14)
        : scheme.surface.withOpacity(0);
    final fg = selected ? scheme.primary : scheme.onSurface.withOpacity(0.85);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Tooltip(
            message: label,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 10 : 12,
                vertical: 10,
              ),
              child: Row(
                mainAxisAlignment:
                    collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  Icon(icon, color: fg),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: fg,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.chevron_right,
                        color: fg,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarCollapseButton extends StatelessWidget {
  const _SidebarCollapseButton({
    required this.collapsed,
    required this.onPressed,
  });

  final bool collapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      child: IconButton(
        onPressed: onPressed,
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        icon: Icon(
          // Matches the provided “sidebar” glyph closely.
          collapsed ? CupertinoIcons.sidebar_right : CupertinoIcons.sidebar_left,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
