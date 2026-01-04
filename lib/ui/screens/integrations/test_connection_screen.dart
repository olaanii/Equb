import 'package:flutter/material.dart';

import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:equb/ui/theme/theme_constants.dart';

class TestConnectionScreen extends StatelessWidget {
  const TestConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ProdScaffold(
      title: 'Test Connection',
      child: ProdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gateway health checks',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: const [
                SmallStat(label: 'Last test', value: '2m ago'),
                SmallStat(label: 'Success rate', value: '99.3%'),
                SmallStat(label: 'Queued retries', value: '0'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Recent activity',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadiuses.small,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('08:14 • Telebirr ping ✓'),
                  SizedBox(height: AppSpacing.xs),
                  Text('08:10 • CBE Birr sandbox ✓'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: 240,
              child: PrimaryButton(
                label: 'Run test now',
                icon: Icons.play_arrow,
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
