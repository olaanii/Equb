import 'package:flutter/material.dart';

import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:equb/ui/theme/theme_constants.dart';

class PaymentIntegrationsScreen extends StatelessWidget {
  const PaymentIntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final integrations = [
      _GatewayToggle(
        name: 'Telebirr',
        description: 'Live • Instant ETB payments',
        enabled: true,
        env: 'Production',
      ),
      _GatewayToggle(
        name: 'CBE Birr',
        description: 'Live • Bank transfers',
        enabled: true,
        env: 'Sandbox',
      ),
      _GatewayToggle(
        name: 'Awash',
        description: 'Disabled • Pending credentials',
        enabled: false,
        env: 'Disabled',
      ),
    ];

    return ProdScaffold(
      title: 'Payment Integrations',
      child: ListView(
        children: [
          ProdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gateway status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ...List.generate(
                  integrations.length,
                  (index) => Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          index == integrations.length - 1 ? 0 : AppSpacing.sm,
                    ),
                    child: integrations[index],
                  ),
                ),
              ],
            ),
          ),
          ProdCard(
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: const [
                SmallStat(label: 'Live gateways', value: '2'),
                SmallStat(label: 'Sandbox gateways', value: '1'),
                SmallStat(label: 'Pending credentials', value: '1'),
              ],
            ),
          ),
          ProdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deployment environments',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _EnvironmentChip(
                      label: 'Production',
                      color: AppColors.success,
                    ),
                    _EnvironmentChip(
                      label: 'Sandbox',
                      color: AppColors.warning,
                    ),
                    _EnvironmentChip(label: 'Mock / QA', color: AppColors.info),
                    _EnvironmentChip(label: 'Disabled', color: AppColors.error),
                  ],
                ),
              ],
            ),
          ),
          if (context.isDesktop)
            ProdCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need to rotate secrets?',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Kick off the checklist to rotate Telebirr/CBE credentials and notify admins.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 220,
                    child: PrimaryButton(
                      label: 'View rotation runbook',
                      onPressed: () {},
                      icon: Icons.open_in_new,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GatewayToggle extends StatelessWidget {
  final String name;
  final String description;
  final bool enabled;
  final String env;

  const _GatewayToggle({
    required this.name,
    required this.description,
    required this.enabled,
    required this.env,
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
                  name,
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
          _EnvironmentChip(
            label: env,
            color: enabled ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch.adaptive(value: enabled, onChanged: (_) {}),
        ],
      ),
    );
  }
}

class _EnvironmentChip extends StatelessWidget {
  final String label;
  final Color color;

  const _EnvironmentChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: color,
    );
  }
}
