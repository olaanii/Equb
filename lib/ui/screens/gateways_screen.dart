import 'dart:convert';

import 'package:equb/providers/gateway_providers.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/services/gateway_service.dart';
import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GatewaysScreen extends ConsumerWidget {
  const GatewaysScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gatewaysAsync = ref.watch(gatewayConfigsProvider);
    final gatewayService = ref.watch(gatewayServiceProvider);

    final body = gatewaysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: InfoCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 36,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load gateways',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$error',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      text: 'Retry',
                      icon: Icons.refresh,
                      onPressed: () => ref.invalidate(gatewayConfigsProvider),
                    ),
                  ],
                ),
              ),
            ),
        data: (gateways) {
          final activeCount = gateways.where((g) => g.enabled).length;
          return Padding(
            padding: context.pagePadding,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
                child: ListView(
                  children: [
                    InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gateway overview',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Manage the payment rails available to your Equb members. Toggle gateways on/off and manage public metadata like callback URLs.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _SummaryChip(
                                label: 'Total gateways',
                                value: gateways.length.toString(),
                              ),
                              _SummaryChip(
                                label: 'Active gateways',
                                value: activeCount.toString(),
                                color: AppColors.success,
                              ),
                              _SummaryChip(
                                label: 'Sandbox ready',
                                value:
                                    '${gateways.where((g) => g.meta.isNotEmpty).length}',
                                color: AppColors.warning,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: PrimaryButton(
                        text: 'Add gateway',
                        icon: Icons.add_circle_outline,
                        onPressed:
                            () => _openCreateGatewayDialog(
                              context,
                              ref,
                              gatewayService,
                            ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (gateways.isEmpty)
                      InfoCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 36),
                            const SizedBox(height: 12),
                            Text(
                              'No gateways configured yet',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add Telebirr, CBE Birr or custom adapters to let members fund their wallets.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            PrimaryButton(
                              text: 'Add gateway',
                              icon: Icons.add_circle_outline,
                              onPressed:
                                  () => _openCreateGatewayDialog(
                                    context,
                                    ref,
                                    gatewayService,
                                  ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...gateways.map(
                        (config) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _GatewayCard(
                            config: config,
                            onToggle: (value) async {
                              await gatewayService.upsertGateway(
                                PaymentGatewayConfig(
                                  id: config.id,
                                  name: config.name,
                                  enabled: value,
                                  meta: config.meta,
                                ),
                              );
                              ref.invalidate(gatewayConfigsProvider);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${config.name} ${value ? 'enabled' : 'disabled'}',
                                  ),
                                ),
                              );
                            },
                            onConfigure: () async {
                              final updated = await showDialog<PaymentGatewayConfig?>(
                                context: context,
                                builder: (_) => _ConfigDialog(config: config),
                              );
                              if (updated != null) {
                                await gatewayService.upsertGateway(updated);
                                ref.invalidate(gatewayConfigsProvider);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${config.name} settings saved'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );

    if (embedded) {
      return SafeArea(child: body);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Gateways')),
      body: body,
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 6, backgroundColor: accent),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GatewayCard extends StatelessWidget {
  const _GatewayCard({
    required this.config,
    required this.onToggle,
    required this.onConfigure,
  });

  final PaymentGatewayConfig config;
  final ValueChanged<bool> onToggle;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaEntries = config.meta.entries.toList();
    return InfoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surface.withAlpha(
                  (0.3 * 255).round(),
                ),
                child: Text(_initialsFor(config.name)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${config.id}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(value: config.enabled, onChanged: onToggle),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            config.enabled
                ? 'Gateway is active and ready to process wallet top-ups.'
                : 'Disabled. Members will not see this gateway during checkout.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (metaEntries.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha((0.12 * 255).round()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No public metadata provided. Add callback URLs or webhook hints to help operators configure clients.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  metaEntries
                      .map(
                        (entry) =>
                            Chip(label: Text('${entry.key}: ${entry.value}')),
                      )
                      .toList(),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Configure'),
              onPressed: onConfigure,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigDialog extends StatefulWidget {
  const _ConfigDialog({required this.config});

  final PaymentGatewayConfig config;

  @override
  State<_ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<_ConfigDialog> {
  late final TextEditingController _metaController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _metaController = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(widget.config.meta),
    );
  }

  @override
  void dispose() {
    _metaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Configure ${widget.config.name}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update public metadata for client-side use (callback URLs, display hints). Secrets should be stored server-side only.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _metaController,
              maxLines: 10,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: '{\n  "baseUrl": "https://..."\n}',
                errorText: _error,
              ),
              keyboardType: TextInputType.multiline,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          text: 'Save changes',
          icon: Icons.save_outlined,
          onPressed: () {
            try {
              final rawText = _metaController.text.trim();
              final parsed = <String, dynamic>{};
              if (rawText.isNotEmpty) {
                final decoded = jsonDecode(rawText);
                if (decoded is Map) {
                  parsed.addAll(Map<String, dynamic>.from(decoded));
                } else {
                  setState(() => _error = 'Metadata must be a JSON object.');
                  return;
                }
              }
              Navigator.of(context).pop(
                PaymentGatewayConfig(
                  id: widget.config.id,
                  name: widget.config.name,
                  enabled: widget.config.enabled,
                  meta: parsed,
                ),
              );
            } catch (e) {
              setState(() => _error = 'Invalid JSON: $e');
            }
          },
        ),
      ],
    );
  }
}

Future<void> _openCreateGatewayDialog(
  BuildContext context,
  WidgetRef ref,
  GatewayService gatewayService,
) async {
  final created = await showDialog<PaymentGatewayConfig?>(
    context: context,
    builder: (_) => const _CreateGatewayDialog(),
  );
  if (created != null) {
    await gatewayService.upsertGateway(created);
    ref.invalidate(gatewayConfigsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${created.name} added')));
  }
}

class _CreateGatewayDialog extends StatefulWidget {
  const _CreateGatewayDialog();

  @override
  State<_CreateGatewayDialog> createState() => _CreateGatewayDialogState();
}

class _CreateGatewayDialogState extends State<_CreateGatewayDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _metaController = TextEditingController(
    text: '{}',
  );
  bool _enabled = true;
  bool _idEdited = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);
  }

  void _handleNameChanged() {
    if (_idEdited) return;
    final slug = _slugify(_nameController.text);
    if (_idController.text != slug) {
      _idController.text = slug;
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    _idController.dispose();
    _metaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add payment gateway'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a gateway entry that the operations team can configure. You can enable it now or leave it disabled until credentials are confirmed.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: 'Identifier',
                  hintText: 'e.g. telebirr',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => _idEdited = true,
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
                title: const Text('Enable immediately'),
                subtitle: const Text(
                  'Enabled gateways appear in checkout flows.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _metaController,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Public metadata (JSON)',
                  hintText: '{\n  "baseUrl": "https://..."\n}',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        PrimaryButton(
          text: 'Create gateway',
          icon: Icons.cloud_upload_outlined,
          onPressed: _submit,
        ),
      ],
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    final id = _idController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Provide a gateway display name.');
      return;
    }
    if (!_isValidId(id)) {
      setState(
        () =>
            _error =
                'Identifier should contain only lowercase letters, numbers or underscores.',
      );
      return;
    }
    try {
      final metaText = _metaController.text.trim();
      final meta = <String, dynamic>{};
      if (metaText.isNotEmpty) {
        final raw = jsonDecode(metaText);
        if (raw is Map) {
          raw.forEach((key, value) {
            meta[key.toString()] = value;
          });
        } else {
          setState(() => _error = 'Metadata must be a JSON object.');
          return;
        }
      }
      setState(() => _error = null);
      Navigator.of(context).pop(
        PaymentGatewayConfig(id: id, name: name, enabled: _enabled, meta: meta),
      );
    } catch (e) {
      setState(() => _error = 'Invalid metadata JSON: $e');
    }
  }

  bool _isValidId(String id) {
    final pattern = RegExp(r'^[a-z0-9_]{3,}$');
    return pattern.hasMatch(id);
  }
}

String _slugify(String input) {
  final lower = input.trim().toLowerCase();
  if (lower.isEmpty) return '';
  final buffer = StringBuffer();
  final alphanumeric = RegExp(r'[a-z0-9]');
  bool lastUnderscore = false;
  for (var i = 0; i < lower.length; i++) {
    final char = lower[i];
    if (alphanumeric.hasMatch(char)) {
      buffer.write(char);
      lastUnderscore = false;
    } else if (!lastUnderscore &&
        (char == ' ' || char == '-' || char == '.' || char == '/')) {
      buffer.write('_');
      lastUnderscore = true;
    }
  }
  var result = buffer.toString();
  result = result.replaceAll(RegExp(r'_+'), '_');
  if (result.endsWith('_')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

String _initialsFor(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '--';
  final parts =
      trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2) {
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
  final first = parts.first;
  if (first.length >= 2) {
    return (first[0] + first[1]).toUpperCase();
  }
  return first[0].toUpperCase();
}
