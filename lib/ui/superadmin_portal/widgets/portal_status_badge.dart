import 'package:equb/ui/superadmin_portal/models/portal_models.dart';
import 'package:flutter/material.dart';

class PortalStatusBadge extends StatelessWidget {
  const PortalStatusBadge({super.key, required this.status});

  final PortalServiceStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (label, color) = switch (status) {
      PortalServiceStatus.up => ('UP', scheme.primary),
      PortalServiceStatus.degraded => ('DEGRADED', scheme.tertiary),
      PortalServiceStatus.down => ('DOWN', scheme.error),
      PortalServiceStatus.unknown => ('UNKNOWN', scheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
