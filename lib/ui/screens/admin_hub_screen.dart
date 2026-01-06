import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/admin_navigation_rail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:equb/ui/screens/admin_screen.dart';
import 'package:equb/ui/screens/gateways_screen.dart';
import 'package:equb/ui/screens/transactions/tx_history_screen.dart';
import 'package:equb/ui/screens/super_admin_screen.dart';
import 'package:equb/ui/screens/admin/advanced_admin_dashboard.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/models/user_model.dart';

class AdminHubScreen extends ConsumerStatefulWidget {
  const AdminHubScreen({super.key});

  @override
  ConsumerState<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends ConsumerState<AdminHubScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isWide = context.isTablet || context.isDesktop;

    final user = ref.watch(currentUserProvider).value;
    final isSuperAdmin = user != null && user.role == UserRole.superAdmin;

    final items = <_AdminNavItem>[
      _AdminNavItem(
        title: 'Feature Flags',
        subtitle: 'Control platform and gateway experiments',
        icon: Icons.tune,
        builder: (_) => const AdminScreen(embedded: true),
      ),
      _AdminNavItem(
        title: 'Gateways',
        subtitle: 'Configure gateway adapters and settings',
        icon: Icons.settings_outlined,
        builder: (_) => const GatewaysScreen(embedded: true),
      ),
      _AdminNavItem(
        title: 'Transactions',
        subtitle: 'Review history, filter pending deposits',
        icon: Icons.receipt_long_outlined,
        builder: (_) => const TxHistoryScreen(embedded: true),
      ),
      if (isSuperAdmin)
        _AdminNavItem(
          title: 'Advanced Admin',
          subtitle: 'Bulk operations, audit logs, and compliance',
          icon: Icons.admin_panel_settings,
          builder: (_) => const AdvancedAdminDashboard(),
        ),
      if (isSuperAdmin)
        _AdminNavItem(
          title: 'Super Admin',
          subtitle: 'Gateways, logs, and rules',
          icon: Icons.security_outlined,
          builder: (_) => const SuperAdminScreen(embedded: true),
        ),
    ];

    if (isWide) {
      final safeIndex = _selectedIndex.clamp(0, items.length - 1);
      final selected = items[safeIndex];
      final content = selected.builder(context);

      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: SafeArea(
          child: Row(
            children: [
              AdminNavigationRail(
                title: 'Admin',
                selectedIndex: safeIndex,
                onDestinationSelected:
                    (value) => setState(() => _selectedIndex = value),
                destinations: [
                  for (final item in items)
                    AdminRailDestination(label: item.title, icon: item.icon),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: context.pagePadding,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Console',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Manage operational settings and reviews.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _AdminList(items: items),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminGrid extends StatelessWidget {
  final List<_AdminNavItem> items;
  const _AdminGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = context.isDesktop ? 2 : 1;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: AppSpacing.lg,
      mainAxisSpacing: AppSpacing.lg,
      childAspectRatio: context.isDesktop ? 2.6 : 2.9,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final item in items)
          _AdminCard(
            item: item,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => item.builder(ctx)),
            ),
          ),
      ],
    );
  }
}

class _AdminList extends StatelessWidget {
  final List<_AdminNavItem> items;
  const _AdminList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          _AdminCard(
            item: item,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => item.builder(ctx)),
            ),
          ),
      ],
    );
  }
}

class _AdminCard extends StatelessWidget {
  final _AdminNavItem item;
  final VoidCallback onOpen;

  const _AdminCard({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadiuses.medium,
        side: BorderSide(color: scheme.outlineVariant.withOpacity(0.55)),
      ),
      child: InkWell(
        borderRadius: AppRadiuses.medium,
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Icon(item.icon, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminNavItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget Function(BuildContext) builder;

  const _AdminNavItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });
}
