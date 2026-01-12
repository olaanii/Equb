import 'package:equb/ui/responsive.dart';
import 'package:flutter/material.dart';

import '../../services/portal_api_keys_service.dart';

class PortalApiKeysPanel extends StatefulWidget {
  const PortalApiKeysPanel({super.key});

  @override
  State<PortalApiKeysPanel> createState() => _PortalApiKeysPanelState();
}

class _PortalApiKeysPanelState extends State<PortalApiKeysPanel> {
  final _service = PortalApiKeysService();

  final _labelController = TextEditingController();
  final _principalEmailController = TextEditingController();

  bool _scopeAdmin = true;
  bool _scopeUser = false;

  Future<List<Map<String, dynamic>>>? _future;
  Map<String, dynamic>? _lastCreated;

  @override
  void initState() {
    super.initState();
    _future = _service.list();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _principalEmailController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _service.list();
    });
  }

  Future<void> _create() async {
    final messenger = ScaffoldMessenger.of(context);
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Label required')));
      return;
    }

    final scopes = <String>[];
    if (_scopeAdmin) scopes.add('admin');
    if (_scopeUser) scopes.add('user');

    try {
      final created = await _service.create(
        label: label,
        principalEmail: _principalEmailController.text.trim(),
        scopes: scopes,
      );
      if (!mounted) return;

      setState(() {
        _lastCreated = created;
      });

      messenger.showSnackBar(const SnackBar(content: Text('API key created')));
      _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Create failed: $e')));
    }
  }

  Future<void> _revoke(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.revoke(id: id);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('API key revoked')));
      _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Revoke failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Map<String, dynamic>>[];

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.contentMaxWidth),
            child: ListView(
              padding: context.pagePadding,
              children: [
                Text(
                  'API keys',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create, list, and revoke external API keys. Keys are shown only once at creation.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _CreateCard(
                  labelController: _labelController,
                  principalEmailController: _principalEmailController,
                  scopeAdmin: _scopeAdmin,
                  scopeUser: _scopeUser,
                  onChanged: (admin, user) {
                    setState(() {
                      _scopeAdmin = admin;
                      _scopeUser = user;
                    });
                  },
                  onCreate: _create,
                ),
                if (_lastCreated != null) ...[
                  const SizedBox(height: 12),
                  _CreatedKeyCard(data: _lastCreated!),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Existing keys',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (snapshot.hasError)
                  Text(
                    'Load failed: ${snapshot.error}',
                    style: theme.textTheme.bodySmall,
                  )
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ))
                else if (items.isEmpty)
                  Text('No keys found.', style: theme.textTheme.bodyMedium)
                else
                  ...items.map(
                    (row) => _ApiKeyRow(
                      row: row,
                      onRevoke: () => _revoke((row['id'] ?? '').toString()),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreateCard extends StatelessWidget {
  const _CreateCard({
    required this.labelController,
    required this.principalEmailController,
    required this.scopeAdmin,
    required this.scopeUser,
    required this.onChanged,
    required this.onCreate,
  });

  final TextEditingController labelController;
  final TextEditingController principalEmailController;
  final bool scopeAdmin;
  final bool scopeUser;
  final void Function(bool admin, bool user) onChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create key', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Label',
                hintText: 'e.g. Backoffice integration',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: principalEmailController,
              decoration: const InputDecoration(
                labelText: 'Owner email (optional)',
                hintText: 'e.g. ops@company.com',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('admin'),
                  selected: scopeAdmin,
                  onSelected: (v) => onChanged(v, scopeUser),
                ),
                FilterChip(
                  label: const Text('user'),
                  selected: scopeUser,
                  onSelected: (v) => onChanged(scopeAdmin, v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.key_outlined),
                label: const Text('Create key'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatedKeyCard extends StatelessWidget {
  const _CreatedKeyCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final apiKey = (data['apiKey'] ?? '').toString();
    final id = (data['id'] ?? '').toString();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New key (shown once)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('id: $id'),
            const SizedBox(height: 8),
            SelectableText(apiKey.isEmpty ? '<no key returned>' : apiKey),
            const SizedBox(height: 8),
            Text(
              'Store this value securely. It cannot be retrieved again from the portal.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApiKeyRow extends StatelessWidget {
  const _ApiKeyRow({required this.row, required this.onRevoke});

  final Map<String, dynamic> row;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = row['enabled'] == true;
    final label = (row['label'] ?? row['id'] ?? '').toString();
    final principalEmail = (row['principalEmail'] ?? '').toString();
    final scopes = row['scopes'];
    final scopeText =
        scopes is List ? scopes.map((e) => e.toString()).join(', ') : '';

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'id: ${(row['id'] ?? '').toString()}  prefix: ${(row['keyPrefix'] ?? '').toString()}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (principalEmail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('owner: $principalEmail',
                        style: theme.textTheme.bodySmall),
                  ],
                  if (scopeText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('scopes: $scopeText',
                        style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(
              onPressed: enabled ? onRevoke : null,
              child: Text(enabled ? 'Revoke' : 'Revoked'),
            ),
          ],
        ),
      ),
    );
  }
}
