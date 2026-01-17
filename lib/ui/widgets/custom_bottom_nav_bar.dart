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

    final containerColor =
        isDark ? scheme.surfaceContainerHighest : scheme.secondary;
    final borderColor =
        isDark ? scheme.outlineVariant.withOpacity(0.55) : Colors.transparent;
    final selectedPillColor = isDark ? scheme.primary : Colors.white;
    final selectedForeground = isDark ? scheme.onPrimary : Colors.black;
    final unselectedIconColor =
        isDark
            ? scheme.onSurfaceVariant.withOpacity(0.75)
            : Colors.white.withOpacity(0.78);

    return Container(
      margin: const EdgeInsets.fromLTRB(47, 0, 47, 22),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: borderColor),
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
                horizontal: isSelected ? 16 : 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isSelected ? selectedPillColor : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: (isDark ? scheme.primary : Colors.black)
                                .withOpacity(isDark ? 0.3 : 0.18),
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
                        isSelected ? selectedForeground : unselectedIconColor,
                    size: 22,
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: selectedForeground,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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
