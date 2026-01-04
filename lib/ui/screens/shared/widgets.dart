import 'package:flutter/material.dart';

import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/theme/theme_constants.dart';

class ProdScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  const ProdScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: actions,
      ),
      body: SafeArea(
        child: Padding(
          padding: context.pagePadding,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class ProdCard extends StatelessWidget {
  final Widget child;
  const ProdCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadiuses.medium,
        side: BorderSide(color: scheme.outlineVariant.withOpacity(0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final button =
        icon == null
            ? FilledButton(
              onPressed: onPressed,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )
            : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            );

    return SizedBox(width: expand ? double.infinity : null, child: button);
  }
}

class SmallStat extends StatelessWidget {
  final String label;
  final String value;
  const SmallStat({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

Widget prodStub(String heading, [String? subtitle]) => ProdScaffold(
  title: heading,
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(heading, style: AppTextStyles.headline1),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: 360,
          child: Text(
            subtitle ?? 'Production-ready prototype for $heading',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText2,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 220,
          child: PrimaryButton(label: 'Primary action', onPressed: () {}),
        ),
      ],
    ),
  ),
);
