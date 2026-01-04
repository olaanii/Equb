import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<CustomNavItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.55)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(isDark ? 0.4 : 0.12),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(items.length, (index) {
          final isSelected = selectedIndex == index;
          final item = items[index];

          return GestureDetector(
            onTap: () => onDestinationSelected(index),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 20 : 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isSelected ? scheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: scheme.primary.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                        : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    color:
                        isSelected
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant.withOpacity(0.75),
                    size: 24,
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class CustomNavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const CustomNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
