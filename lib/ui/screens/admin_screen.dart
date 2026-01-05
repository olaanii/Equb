import 'package:equb/controllers/feature_flags_controller.dart';
import 'package:equb/domain/gateway_feature_flag.dart';
import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagsAsync = ref.watch(featureFlagsProvider);
    final body = flagsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Failed to load flags: $e')),
          data:
              (flags) => LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= Breakpoints.desktop;
                  final body = SingleChildScrollView(
                    padding: context.pagePadding,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: context.contentMaxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Feature Governance',
                              style: AppTextStyles.headline2,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Control platform-wide experiments and gateway availability before shipping to new cohorts.',
                              style: AppTextStyles.bodyText2,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Flex(
                              direction:
                                  isDesktop ? Axis.horizontal : Axis.vertical,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _PlatformCard(
                                    enabled: flags.gemini25ProEnabled,
                                    onChanged:
                                        (value) => ref
                                            .read(featureFlagsProvider.notifier)
                                            .setGemini25ProEnabled(value),
                                  ),
                                ),
                                if (isDesktop)
                                  const SizedBox(width: AppSpacing.lg)
                                else
                                  const SizedBox(height: AppSpacing.lg),
                                Expanded(
                                  flex: 1,
                                  child: const _AdminHighlights(),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'Gateway Feature Flags',
                              style: AppTextStyles.headline2,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.lg,
                              runSpacing: AppSpacing.lg,
                              children: [
                                SizedBox(
                                  width:
                                      isDesktop
                                          ? (context.contentMaxWidth -
                                                  AppSpacing.lg) /
                                              2
                                          : double.infinity,
                                  child: _GatewayFlagCard(
                                    title: 'Telebirr',
                                    description:
                                        'Control Telebirr rollout per environment',
                                    flag: flags.gatewayFlagFor('telebirr'),
                                    onChanged:
                                        (flag) => ref
                                            .read(featureFlagsProvider.notifier)
                                            .setGatewayFlag('telebirr', flag),
                                  ),
                                ),
                                SizedBox(
                                  width:
                                      isDesktop
                                          ? (context.contentMaxWidth -
                                                  AppSpacing.lg) /
                                              2
                                          : double.infinity,
                                  child: _GatewayFlagCard(
                                    title: 'CBE Birr',
                                    description:
                                        'Toggle CBE Birr adapter across environments',
                                    flag: flags.gatewayFlagFor('cbe_birr'),
                                    onChanged:
                                        (flag) => ref
                                            .read(featureFlagsProvider.notifier)
                                            .setGatewayFlag('cbe_birr', flag),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Feature flags are stored in Firebase Realtime Database. Gateway credentials still live in SecureStorage on each operator device.',
                              style: AppTextStyles.bodyText2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  return body;
                },
              ),
        );

    if (embedded) {
      return SafeArea(child: body);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
          IconButton(
            tooltip: 'Export config snapshot',
            icon: const Icon(Icons.download_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Gemini 2.5 Pro rollout',
                  style: AppTextStyles.headline2.copyWith(fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Control access to advanced inference for all clients. Toggle off to fall back to the legacy assistant.',
              style: AppTextStyles.bodyText2,
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                enabled
                    ? 'Enabled for pilot cohorts'
                    : 'Disabled (legacy only)',
                style: AppTextStyles.bodyText1,
              ),
              subtitle: Text(
                'Logs emit `feature.gemini25.toggle` events for audit trails.',
                style: AppTextStyles.bodyText2,
              ),
              value: enabled,
              onChanged: onChanged,
            ),
            const Divider(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: const [
                _StatusChip(label: 'Audit ready'),
                _StatusChip(label: 'Dark launch configured'),
                _StatusChip(
                  label: 'Remote config pending',
                  tone: ChipTone.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GatewayFlagCard extends StatelessWidget {
  const _GatewayFlagCard({
    required this.title,
    required this.description,
    required this.flag,
    required this.onChanged,
  });

  final String title;
  final String description;
  final GatewayFeatureFlag flag;
  final ValueChanged<GatewayFeatureFlag> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.headline2.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(description, style: AppTextStyles.bodyText2),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: flag.enabled,
                  onChanged:
                      (value) => onChanged(flag.copyWith(enabled: value)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<GatewayEnvironment>(
              multiSelectionEnabled: false,
              segments:
                  GatewayEnvironment.values
                      .map(
                        (env) => ButtonSegment(
                          value: env,
                          label: Text(env.name.toUpperCase()),
                        ),
                      )
                      .toList(),
              selected: {flag.environment},
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                final env = selection.first;
                onChanged(flag.copyWith(environment: env));
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _StatusChip(
                  label: 'Mode: ${flag.environment.name}',
                  tone:
                      flag.environment == GatewayEnvironment.production
                          ? ChipTone.positive
                          : ChipTone.warning,
                ),
                _StatusChip(
                  label: flag.enabled ? 'Live' : 'Paused',
                  tone: flag.enabled ? ChipTone.positive : ChipTone.muted,
                ),
                _StatusChip(label: 'Last updated 2h ago', tone: ChipTone.muted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminHighlights extends StatelessWidget {
  const _AdminHighlights();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gateway health', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '100% uptime',
                  style: AppTextStyles.headline2.copyWith(fontSize: 20),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Telemetry syncs Telebirr · CBE · Bank within SLA.',
                  style: AppTextStyles.bodyText2,
                ),
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(
                  value: 1,
                  minHeight: 6,
                  color: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Audit trail', style: AppTextStyles.label),
                const SizedBox(height: AppSpacing.sm),
                _AuditRow(label: 'Last gateway change', value: '12 min ago'),
                _AuditRow(label: 'Pending reviews', value: '0'),
                _AuditRow(label: 'Secure storage sync', value: 'Today • 09:20'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyText2),
          Text(value, style: AppTextStyles.bodyText1),
        ],
      ),
    );
  }
}

enum ChipTone { positive, warning, muted }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, this.tone = ChipTone.positive});

  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      ChipTone.positive => AppColors.success,
      ChipTone.warning => AppColors.warning,
      ChipTone.muted => AppColors.textMuted,
    };

    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.12),
      labelStyle: AppTextStyles.label.copyWith(color: color),
      side: BorderSide(color: color.withOpacity(0.3)),
    );
  }
}
