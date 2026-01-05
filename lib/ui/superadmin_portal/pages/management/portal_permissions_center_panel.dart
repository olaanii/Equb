import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/portal_superadmin_service.dart';

class PortalPermissionsCenterPanel extends StatefulWidget {
  const PortalPermissionsCenterPanel({super.key});

  @override
  State<PortalPermissionsCenterPanel> createState() =>
      _PortalPermissionsCenterPanelState();
}

class _PortalPermissionsCenterPanelState
    extends State<PortalPermissionsCenterPanel> {
  final _uidController = TextEditingController();
  final _superAdminService = PortalSuperAdminService();

  final Map<String, bool> _claims = {
    'superAdmin': true,
    'admin': false,
    'ops': false,
    'support': false,
  };

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final uid = _uidController.text.trim();

    if (uid.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please enter a target user UID')),
      );
      return;
    }

    if ((_claims['ops'] ?? false) || (_claims['support'] ?? false)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ops/support not implemented yet (backend pending).'),
        ),
      );
      return;
    }

    try {
      final isSuperAdmin = _claims['superAdmin'] ?? false;
      final isAdmin = _claims['admin'] ?? false;

      // Keep ordering predictable. Backend also ensures superadmins are admins.
      await _superAdminService.setSuperAdmin(
        targetUid: uid,
        isSuperAdmin: isSuperAdmin,
      );

      // If superAdmin is enabled, admin is implied.
      if (!isSuperAdmin) {
        await _superAdminService.setAdmin(targetUid: uid, isAdmin: isAdmin);
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Permissions updated')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  Map<String, dynamic> _buildRequestPayload() {
    final uid = _uidController.text.trim();
    return {
      'uid': uid.isEmpty ? '<uid>' : uid,
      'claims': {
        for (final entry in _claims.entries) entry.key: entry.value,
      },
      'issuedAt': DateTime.now().toIso8601String(),
      'source': 'superadmin-portal',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final payload = _buildRequestPayload();
    final payloadJson = const JsonEncoder.withIndent('  ').convert(payload);

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
                    'Permissions center',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(Icons.admin_panel_settings_outlined,
                    color: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Review current access and prepare role/claim updates (UI-first).',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _CurrentSessionClaimsCard(),
            const SizedBox(height: 12),
            _RoleTemplatesCard(),
            const SizedBox(height: 12),
            _ClaimRequestCard(
              uidController: _uidController,
              claims: _claims,
              payloadJson: payloadJson,
              onChanged: () => setState(() {}),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentSessionClaimsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final user = FirebaseAuth.instance.currentUser;

    return Card(
      elevation: 0,
      color: scheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current session',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            if (user == null)
              Text(
                'Not signed in.',
                style: theme.textTheme.bodySmall,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.email ?? user.uid,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<IdTokenResult>(
                    future: user.getIdTokenResult(true),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Text('Loading claims…',
                            style: theme.textTheme.bodySmall);
                      }
                      final claims = snapshot.data?.claims;
                      if (claims == null || claims.isEmpty) {
                        return Text('No custom claims found.',
                            style: theme.textTheme.bodySmall);
                      }

                      final entries = claims.entries.toList()
                        ..sort((a, b) => a.key.compareTo(b.key));

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in entries)
                            Chip(
                              label: Text('${entry.key}: ${entry.value}'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleTemplatesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget roleRow(String name, List<String> claims) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in claims)
                    Chip(
                      label: Text(c),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: scheme.surface,
                      side: BorderSide(
                        color: scheme.outlineVariant.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 0,
      color: scheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Role templates (suggested)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            roleRow('Super Admin', const ['superAdmin']),
            roleRow('Admin', const ['admin']),
            roleRow('Operations', const ['ops']),
            roleRow('Support', const ['support']),
          ],
        ),
      ),
    );
  }
}

class _ClaimRequestCard extends StatelessWidget {
  const _ClaimRequestCard({
    required this.uidController,
    required this.claims,
    required this.payloadJson,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController uidController;
  final Map<String, bool> claims;
  final String payloadJson;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prepare claim update request',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This portal currently generates a request payload only. Wiring it to a Cloud Function/API can be added next.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: uidController,
              decoration: const InputDecoration(
                labelText: 'Target user UID',
                hintText: 'Paste Firebase Auth UID',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => onChanged(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final entry in claims.entries)
                  FilterChip(
                    label: Text(entry.key),
                    selected: entry.value,
                    onSelected: (v) {
                      claims[entry.key] = v;
                      onChanged();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withOpacity(0.7),
                ),
              ),
              child: Text(
                payloadJson,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: payloadJson));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied JSON payload')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Copy JSON'),
                  ),
                  FilledButton.icon(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.done_all_outlined),
                    label: const Text('Submit'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
