import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';

import '../../../../services/gateway_service.dart';
import '../../services/portal_chapa_test_service.dart';

class PortalChapaTestPanel extends StatefulWidget {
  const PortalChapaTestPanel({super.key});

  @override
  State<PortalChapaTestPanel> createState() => _PortalChapaTestPanelState();
}

class _PortalChapaTestPanelState extends State<PortalChapaTestPanel> {
  final _service = PortalChapaTestService();
  final _gatewayService = GatewayService();

  final _secretKey = TextEditingController();
  final _publicKey = TextEditingController();
  final _encryptionKey = TextEditingController();
  final _returnUrl = TextEditingController();
  final _callbackUrl = TextEditingController();
  final _currency = TextEditingController(text: 'ETB');

  bool _savingSecrets = false;
  bool _loadingGateway = true;
  PaymentGatewayConfig? _chapaGateway;

  bool _loadingUsers = true;
  List<Map<String, dynamic>> _users = const [];

  @override
  void initState() {
    super.initState();
    _loadGateway();
    _loadUsers();
  }

  @override
  void dispose() {
    _secretKey.dispose();
    _publicKey.dispose();
    _encryptionKey.dispose();
    _returnUrl.dispose();
    _callbackUrl.dispose();
    _currency.dispose();
    super.dispose();
  }

  Future<void> _loadGateway() async {
    setState(() {
      _loadingGateway = true;
    });

    try {
      final gateways = await _gatewayService.listGateways();
      PaymentGatewayConfig? chapa;
      for (final g in gateways) {
        if (g.id == 'chapa') {
          chapa = g;
          break;
        }
      }

      if (!mounted) return;
      _chapaGateway = chapa;

      final meta = chapa?.meta ?? const <String, dynamic>{};
      _publicKey.text = (meta['publicKey'] as String?)?.trim() ?? '';
      _returnUrl.text = (meta['returnUrl'] as String?)?.trim() ?? '';
      _callbackUrl.text = (meta['callbackUrl'] as String?)?.trim() ?? '';
      final currency = (meta['currency'] as String?)?.trim();
      _currency.text = _isNullOrEmpty(currency) ? 'ETB' : currency!;
    } finally {
      if (mounted) {
        setState(() {
          _loadingGateway = false;
        });
      }
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
    });
    try {
      final users = await _service.listTestUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingUsers = false;
        });
      }
    }
  }

  Future<void> _saveSecrets() async {
    final sk = _secretKey.text.trim();
    if (sk.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Secret key is required.')));
      return;
    }

    final returnUrl = _returnUrl.text.trim();
    if (returnUrl.isEmpty || !returnUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Return URL must be a valid http(s) URL.'),
        ),
      );
      return;
    }

    final callbackUrl = _callbackUrl.text.trim();
    if (callbackUrl.isNotEmpty && !callbackUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Callback URL must be a valid http(s) URL.'),
        ),
      );
      return;
    }

    setState(() {
      _savingSecrets = true;
    });

    try {
      await _service.setChapaSecrets(
        secretKey: sk,
        publicKey: _publicKey.text,
        encryptionKey: _encryptionKey.text,
      );

      final current =
          _chapaGateway ??
          PaymentGatewayConfig(
            id: 'chapa',
            name: 'Chapa',
            enabled: true,
            environment: 'sandbox',
            meta: const <String, dynamic>{},
          );

      final meta = Map<String, dynamic>.from(current.meta);
      final pk = _publicKey.text.trim();
      if (pk.isNotEmpty) {
        meta['publicKey'] = pk;
      }
      meta['returnUrl'] = returnUrl;
      meta['callbackUrl'] = callbackUrl;
      meta['currency'] =
          _currency.text.trim().isEmpty ? 'ETB' : _currency.text.trim();

      final updated = current.copyWith(meta: meta);
      await _gatewayService.upsertGateway(updated);
      _chapaGateway = updated;

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved Chapa settings.')));
      _secretKey.clear();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed saving secrets')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingSecrets = false;
        });
      }
    }
  }

  bool _isNullOrEmpty(String? value) => value == null || value.trim().isEmpty;

  Future<void> _addOrEditUser({Map<String, dynamic>? existing}) async {
    final id = (existing?['id'] as String?) ?? const Uuid().v4();
    final labelCtrl = TextEditingController(
      text: (existing?['label'] as String?) ?? '',
    );
    final emailCtrl = TextEditingController(
      text: (existing?['email'] as String?) ?? '',
    );
    final phoneCtrl = TextEditingController(
      text: (existing?['phone'] as String?) ?? '',
    );

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(existing == null ? 'Add test user' : 'Edit test user'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (res != true || !mounted) {
      labelCtrl.dispose();
      emailCtrl.dispose();
      phoneCtrl.dispose();
      return;
    }

    final label = labelCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final phone = phoneCtrl.text.trim();

    labelCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();

    if (label.isEmpty || email.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label, email and phone are required.')),
      );
      return;
    }

    try {
      await _service.upsertTestUser(
        id: id,
        label: label,
        email: email,
        phone: phone,
      );
      if (!mounted) return;
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved test user.')));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed saving test user')),
      );
    }
  }

  Future<void> _deleteUser(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete test user?'),
            content: const Text('This removes the fixture from RTDB.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (ok != true || !mounted) return;

    try {
      await _service.deleteTestUser(id: id);
      if (!mounted) return;
      await _loadUsers();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Failed deleting test user')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Chapa keys (test)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_loadingGateway) const LinearProgressIndicator(),
        if (_loadingGateway) const SizedBox(height: 12),
        TextField(
          controller: _publicKey,
          decoration: const InputDecoration(
            labelText: 'Public key (optional but recommended for mobile SDK)',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _returnUrl,
          decoration: const InputDecoration(
            labelText: 'Return URL (required; used by Chapa initialize)',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _callbackUrl,
          decoration: const InputDecoration(
            labelText: 'Callback URL (optional)',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _currency,
          decoration: const InputDecoration(
            labelText: 'Currency (default ETB)',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _secretKey,
          decoration: const InputDecoration(
            labelText: 'Secret key (stored server-side)',
          ),
          obscureText: true,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _encryptionKey,
          decoration: const InputDecoration(
            labelText: 'Encryption key (optional)',
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
            onPressed: _savingSecrets ? null : _saveSecrets,
            child: Text(_savingSecrets ? 'Saving…' : 'Save keys'),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Chapa test users (fixtures)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: _loadingUsers ? null : () => _addOrEditUser(),
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingUsers) const LinearProgressIndicator(),
        if (!_loadingUsers && _users.isEmpty) const Text('No test users yet.'),
        if (!_loadingUsers && _users.isNotEmpty)
          ..._users.map((u) {
            final id = (u['id'] as String?) ?? '';
            final label = (u['label'] as String?) ?? '';
            final email = (u['email'] as String?) ?? '';
            final phone = (u['phone'] as String?) ?? '';

            return Card(
              child: ListTile(
                title: Text(label.isEmpty ? email : label),
                subtitle: Text('$email\n$phone'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: () => _addOrEditUser(existing: u),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: id.isEmpty ? null : () => _deleteUser(id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
