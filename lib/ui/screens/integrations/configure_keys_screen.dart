import 'package:flutter/material.dart';

import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:equb/ui/theme/theme_constants.dart';

class ConfigureKeysScreen extends StatelessWidget {
  const ConfigureKeysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = context.isTablet || context.isDesktop;
    return ProdScaffold(
      title: 'Configure API Keys',
      child: ListView(
        children: [
          ProdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Telebirr credentials',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _KeyForm(isWide: isWide),
              ],
            ),
          ),
          ProdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CBE Birr credentials',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _KeyForm(isWide: isWide),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyForm extends StatelessWidget {
  final bool isWide;

  const _KeyForm({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final spacing = isWide ? AppSpacing.md : AppSpacing.sm;
    return Column(
      children: [
        Wrap(
          spacing: spacing,
          runSpacing: AppSpacing.sm,
          children: [
            SizedBox(
              width: isWide ? 280 : double.infinity,
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  hintText: 'telebirr-live-client-id',
                ),
              ),
            ),
            SizedBox(
              width: isWide ? 280 : double.infinity,
              child: TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Client secret',
                  hintText: '•••••••',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                'Saving will rotate keys instantly and notify admins via email.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            SizedBox(
              width: 160,
              child: PrimaryButton(label: 'Save keys', onPressed: () {}),
            ),
          ],
        ),
      ],
    );
  }
}
