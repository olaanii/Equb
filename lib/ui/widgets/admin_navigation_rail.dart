import 'package:equb/ui/responsive.dart';
import 'package:flutter/material.dart';

class AdminRailDestination {
  final String label;
  final IconData icon;

  const AdminRailDestination({required this.label, required this.icon});
}

class AdminNavigationRail extends StatelessWidget {
  const AdminNavigationRail({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final String title;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdminRailDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDesktop = context.isDesktop;

    final extended = isDesktop;
    final minWidth = isDesktop ? 220.0 : 80.0;

    return NavigationRail(
      extended: extended,
      minWidth: minWidth,
      labelType:
          extended ? NavigationRailLabelType.none : NavigationRailLabelType.selected,
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      leading: Padding(
        padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
        child: Align(
          alignment: Alignment.topLeft,
          child: extended
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                )
              : Tooltip(
                  message: title,
                  child: Icon(Icons.admin_panel_settings_outlined, color: scheme.primary),
                ),
        ),
      ),
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Tooltip(
              message: destination.label,
              child: Icon(destination.icon),
            ),
            selectedIcon: Tooltip(
              message: destination.label,
              child: Icon(destination.icon),
            ),
            label: Text(destination.label),
          ),
      ],
    );
  }
}
