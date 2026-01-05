import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/screens/home/home_screen.dart';
import 'package:equb/ui/screens/scan/id_scan_screen.dart';
import 'package:equb/ui/screens/wallet/wallet_tab_screen.dart';
import 'package:equb/ui/screens/groups_list_screen.dart';
import 'package:equb/ui/screens/profile/profile_screen.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/custom_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:equb/providers/app_providers.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _pages = const <Widget>[
    HomeScreen(),
    WalletTabScreen(),
    GroupsListScreen(),
    IdScanScreen(),
    ProfileScreen(),
  ];

  static const _navItems = [
    _NavItem('Home', Icons.home_outlined, Icons.home_rounded),
    _NavItem(
      'Wallet',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
    ),
    _NavItem('Groups', Icons.group_outlined, Icons.group_rounded),
    _NavItem(
      'Scan',
      Icons.qr_code_scanner_outlined,
      Icons.qr_code_scanner_rounded,
    ),
    _NavItem('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  // Keyboard Shortcuts are wired via Shortcuts/Actions below.

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(selectedTabIndexProvider);
    final navDestinations =
        _navItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList();

    final content = _ContentContainer(
      child: IndexedStack(index: index, children: _pages),
    );

    final shell = _buildShellLayout(context, index, content, navDestinations);

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _NextTabIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _PrevTabIntent(),
        LogicalKeySet(LogicalKeyboardKey.digit1): const _GoTabIntent(0),
        LogicalKeySet(LogicalKeyboardKey.digit2): const _GoTabIntent(1),
        LogicalKeySet(LogicalKeyboardKey.digit3): const _GoTabIntent(2),
        LogicalKeySet(LogicalKeyboardKey.digit4): const _GoTabIntent(3),
        LogicalKeySet(LogicalKeyboardKey.digit5): const _GoTabIntent(4),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyD,
        ): const _GoTabIntent(0),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyW,
        ): const _GoTabIntent(1),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyG,
        ): const _GoTabIntent(2),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyS,
        ): const _GoTabIntent(3),
        LogicalKeySet(
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyP,
        ): const _GoTabIntent(4),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NextTabIntent: CallbackAction<_NextTabIntent>(
            onInvoke: (_) {
              ref.read(selectedTabIndexProvider.notifier).state =
                  (index + 1) % _pages.length;
              return null;
            },
          ),
          _PrevTabIntent: CallbackAction<_PrevTabIntent>(
            onInvoke: (_) {
              ref.read(selectedTabIndexProvider.notifier).state =
                  (index - 1 + _pages.length) % _pages.length;
              return null;
            },
          ),
          _GoTabIntent: CallbackAction<_GoTabIntent>(
            onInvoke: (intent) {
              ref.read(selectedTabIndexProvider.notifier).state = intent.index
                  .clamp(0, _pages.length - 1);
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: shell),
      ),
    );
  }

  Widget _buildShellLayout(
    BuildContext context,
    int index,
    Widget content,
    List<NavigationDestination> navDestinations,
  ) {
    if (context.isDesktop) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _DesktopRail(
                index: index,
                onSelect:
                    (i) =>
                        ref.read(selectedTabIndexProvider.notifier).state = i,
                items: _navItems,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    if (context.isTablet) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _DesktopRail(
                index: index,
                onSelect:
                    (i) =>
                        ref.read(selectedTabIndexProvider.notifier).state = i,
                items: _navItems,
                extended: false,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: content),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: index,
        onDestinationSelected:
            (value) =>
                ref.read(selectedTabIndexProvider.notifier).state = value,
        items: _navItems
            .map(
              (item) => CustomNavItem(
                label: item.label,
                icon: item.icon,
                selectedIcon: item.selectedIcon,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _NextTabIntent extends Intent {
  const _NextTabIntent();
}

class _PrevTabIntent extends Intent {
  const _PrevTabIntent();
}

class _GoTabIntent extends Intent {
  final int index;
  const _GoTabIntent(this.index);
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({
    required this.index,
    required this.onSelect,
    required this.items,
    this.extended = true,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final List<_NavItem> items;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      extended: extended,
      minWidth: extended ? 200 : 80,
      selectedIndex: index,
      onDestinationSelected: onSelect,
      destinations:
          items
              .map(
                (item) => NavigationRailDestination(
                  icon: Tooltip(message: item.label, child: Icon(item.icon)),
                  selectedIcon: Tooltip(
                    message: item.label,
                    child: Icon(item.selectedIcon),
                  ),
                  label: Text(item.label),
                ),
              )
              .toList(),
      trailing:
          extended
              ? Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick actions', style: AppTextStyles.label),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => onSelect(1),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Open Wallet'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => onSelect(3),
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Scan ID'),
                    ),
                  ],
                ),
              )
              : null,
    );
  }
}

class _ContentContainer extends StatelessWidget {
  const _ContentContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
        child: Padding(padding: context.pagePadding, child: child),
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  const _InsightsPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today',
              style: AppTextStyles.label.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Text(
              'Upcoming payout',
              style: AppTextStyles.headline2.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text('ETB 12,500 • Group Horizon', style: AppTextStyles.bodyText2),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: AppRadiuses.medium,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health score',
                    style: AppTextStyles.label.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '97%',
                    style: AppTextStyles.headline1.copyWith(
                      fontSize: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All cohorts funded on time this week',
                    style: AppTextStyles.bodyText2.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Alerts', style: AppTextStyles.label),
            const SizedBox(height: 12),
            _AlertTile(
              icon: Icons.notifications_active_outlined,
              title: 'Reminder queue healthy',
              subtitle: '0 muted payouts • 2 scheduled tonight',
            ),
            _AlertTile(
              icon: Icons.shield_outlined,
              title: 'All gateways online',
              subtitle: 'Telebirr · CBE Birr · Bank transfer',
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyText1),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.bodyText2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
