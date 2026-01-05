import 'package:equb/ui/responsive.dart';
import 'package:flutter/material.dart';

import 'management/portal_group_admin_console_panel.dart';
import 'management/portal_permissions_center_panel.dart';

class PortalManagementPage extends StatelessWidget {
  const PortalManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Management',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage groups, content, and permissions from a single portal.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              const PortalGroupAdminConsolePanel(),
              const SizedBox(height: 12),
              _StubSection(
                title: 'Content',
                items: const [
                  'Announcements',
                  'Banners',
                  'FAQ / Help content',
                ],
              ),
              const SizedBox(height: 12),
              const PortalPermissionsCenterPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StubSection extends StatelessWidget {
  const _StubSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.lock_open_outlined,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in items)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: scheme.outlineVariant.withOpacity(0.6),
                      ),
                    ),
                    child: Text(
                      item,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
