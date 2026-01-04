import 'package:flutter/material.dart';

import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:equb/ui/theme/theme_constants.dart';

class ApiToggleScreen extends StatelessWidget {
  const ApiToggleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = List.generate(
      6,
      (i) => _FeatureToggle(
        title: 'Provider ${i + 1}',
        description: i.isEven ? 'Live API' : 'Sandbox only',
        enabled: i.isEven,
      ),
    );

    return ProdScaffold(
      title: 'API Toggle',
      child: ProdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feature flags',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.md),
            ...List.generate(
              entries.length,
              (index) => Padding(
                padding: EdgeInsets.only(
                  bottom: index == entries.length - 1 ? 0 : AppSpacing.sm,
                ),
                child: entries[index],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureToggle extends StatelessWidget {
  final String title;
  final String description;
  final bool enabled;

  const _FeatureToggle({
    required this.title,
    required this.description,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadiuses.small,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch.adaptive(value: enabled, onChanged: (_) {}),
        ],
      ),
    );
  }
}
