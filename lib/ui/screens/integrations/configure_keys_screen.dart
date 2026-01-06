import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:equb/providers/providers.dart';
import 'package:equb/ui/responsive.dart';
import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:equb/ui/theme/theme_constants.dart';

class ConfigureKeysScreen extends ConsumerStatefulWidget {
  const ConfigureKeysScreen({super.key});

  @override
  ConsumerState<ConfigureKeysScreen> createState() => _ConfigureKeysScreenState();
}

class _ConfigureKeysScreenState extends ConsumerState<ConfigureKeysScreen> {
  final _telebirrFormKey = GlobalKey<FormState>();
  final _cbeFormKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Telebirr configuration
  final _telebirrApiKeyController = TextEditingController();
  final _telebirrClientIdController = TextEditingController();
  final _telebirrClientSecretController = TextEditingController();
  final _telebirrPrivateKeyController = TextEditingController();
  final _telebirrBaseUrlController = TextEditingController();
  final _telebirrWebhookUrlController = TextEditingController();
  final _telebirrPublicKeyController = TextEditingController();

  // CBE configuration
  final _cbeClientIdController = TextEditingController();
  final _cbeClientSecretController = TextEditingController();
  final _cbeBaseUrlController = TextEditingController();
  final _cbeWebhookUrlController = TextEditingController();
  final _cbeApiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  @override
  void dispose() {
    _telebirrApiKeyController.dispose();
    _telebirrClientIdController.dispose();
    _telebirrClientSecretController.dispose();
    _telebirrPrivateKeyController.dispose();
    _telebirrBaseUrlController.dispose();
    _telebirrWebhookUrlController.dispose();
    _telebirrPublicKeyController.dispose();
    _cbeClientIdController.dispose();
    _cbeClientSecretController.dispose();
    _cbeBaseUrlController.dispose();
    _cbeWebhookUrlController.dispose();
    _cbeApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingConfig() async {
    try {
      // Load existing configuration from secure storage or Firebase
      // This would typically load from the gateway configuration
      final secureStorage = ref.read(secureStorageServiceProvider);

      _telebirrApiKeyController.text = await secureStorage.get('telebirr_api_key') ?? '';
      _telebirrClientIdController.text = await secureStorage.get('telebirr_client_id') ?? '';
      _telebirrClientSecretController.text = await secureStorage.get('telebirr_client_secret') ?? '';
      _telebirrBaseUrlController.text = await secureStorage.get('telebirr_base_url') ?? 'https://api.telebirr.com';
      _telebirrWebhookUrlController.text = await secureStorage.get('telebirr_webhook_url') ?? '';

      _cbeClientIdController.text = await secureStorage.get('cbe_client_id') ?? '';
      _cbeClientSecretController.text = await secureStorage.get('cbe_client_secret') ?? '';
      _cbeBaseUrlController.text = await secureStorage.get('cbe_base_url') ?? 'https://api.cbe.com.et';
      _cbeWebhookUrlController.text = await secureStorage.get('cbe_webhook_url') ?? '';
      _cbeApiKeyController.text = await secureStorage.get('cbe_api_key') ?? '';

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load configuration: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = context.isTablet || context.isDesktop;

    return ProdScaffold(
      title: 'Configure Mobile Money APIs',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Telebirr Configuration
          ProdCard(
            child: Form(
              key: _telebirrFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Telebirr Configuration',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildTelebirrForm(isWide),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'All fields are required for production use. Private keys must be in PEM format.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 140,
                        child: PrimaryButton(
                          label: _isSaving ? 'Saving...' : 'Save Telebirr',
                          onPressed: _isSaving ? null : () => _saveConfiguration('telebirr'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // CBE Birr Configuration
          ProdCard(
            child: Form(
              key: _cbeFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'CBE Birr Configuration',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildCbeForm(isWide),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Configure webhook URLs to point to your Firebase Functions endpoints.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 140,
                        child: PrimaryButton(
                          label: _isSaving ? 'Saving...' : 'Save CBE',
                          onPressed: _isSaving ? null : () => _saveConfiguration('cbe'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Test Configuration
          ProdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test Configuration',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Test the configured APIs with sample transactions.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 16),
                    PrimaryButton(
                      label: 'Test APIs',
                      onPressed: _testConfiguration,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelebirrForm(bool isWide) {
    return Column(
      children: [
        Wrap(
          spacing: isWide ? AppSpacing.md : AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            SizedBox(
              width: isWide ? 280 : double.infinity,
              child: TextFormField(
                controller: _telebirrApiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'telebirr-api-key',
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
            SizedBox(
              width: isWide ? 280 : double.infinity,
              child: TextFormField(
                controller: _telebirrClientIdController,
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  hintText: 'telebirr-client-id',
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
            SizedBox(
              width: isWide ? 280 : double.infinity,
              child: TextFormField(
                controller: _telebirrClientSecretController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Client Secret',
                  hintText: '••••••••',
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
            SizedBox(
              width: isWide ? 280 : double.infinity,
              child: TextFormField(
                controller: _telebirrBaseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.telebirr.com',
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _telebirrWebhookUrlController,
          decoration: const InputDecoration(
            labelText: 'Webhook URL',
            hintText: 'https://your-project.web.app/telebirrWebhook',
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _telebirrPrivateKeyController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Private Key (PEM)',
            hintText: '-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----',
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _telebirrPublicKeyController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Public Key (PEM)',
            hintText: '-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----',
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildCbeForm(bool isWide) {
    return Column(
      children: [
        Wrap(
          spacing: isWide ? AppSpacing.md : AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            SizedBox(
              width: isWide ? 280 : double.infinity,
              child: TextFormField(
                controller: _cbeApiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'cbe-api-key',
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
            SizedBox(
              width: isWide ? 280 : double.infinity,
              child: TextFormField(
                controller: _cbeClientIdController,
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  hintText: 'cbe-client-id',
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
            SizedBox(
              width: isWide ? 280 : double.infinity,
              child: TextFormField(
                controller: _cbeClientSecretController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Client Secret',
                  hintText: '••••••••',
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
            SizedBox(
              width: isWide ? 280 : double.infinity,
              child: TextFormField(
                controller: _cbeBaseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.cbe.com.et',
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _cbeWebhookUrlController,
          decoration: const InputDecoration(
            labelText: 'Webhook URL',
            hintText: 'https://your-project.web.app/cbeBirrWebhook',
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
        ),
      ],
    );
  }

  Future<void> _saveConfiguration(String gateway) async {
    final formKey = gateway == 'telebirr' ? _telebirrFormKey : _cbeFormKey;

    if (!formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final secureStorage = ref.read(secureStorageServiceProvider);

      if (gateway == 'telebirr') {
        await secureStorage.set('telebirr_api_key', _telebirrApiKeyController.text);
        await secureStorage.set('telebirr_client_id', _telebirrClientIdController.text);
        await secureStorage.set('telebirr_client_secret', _telebirrClientSecretController.text);
        await secureStorage.set('telebirr_private_key', _telebirrPrivateKeyController.text);
        await secureStorage.set('telebirr_public_key', _telebirrPublicKeyController.text);
        await secureStorage.set('telebirr_base_url', _telebirrBaseUrlController.text);
        await secureStorage.set('telebirr_webhook_url', _telebirrWebhookUrlController.text);
      } else if (gateway == 'cbe') {
        await secureStorage.set('cbe_api_key', _cbeApiKeyController.text);
        await secureStorage.set('cbe_client_id', _cbeClientIdController.text);
        await secureStorage.set('cbe_client_secret', _cbeClientSecretController.text);
        await secureStorage.set('cbe_base_url', _cbeBaseUrlController.text);
        await secureStorage.set('cbe_webhook_url', _cbeWebhookUrlController.text);
      }

      // Update Firebase Functions config (would need admin privileges)
      // This would typically be done via Firebase CLI or admin panel

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${gateway.toUpperCase()} configuration saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save configuration: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _testConfiguration() async {
    // TODO: Implement API testing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API testing not yet implemented')),
    );
  }
}

class _KeyForm extends StatelessWidget {
  final bool isWide;

  const _KeyForm({required this.isWide});

  @override
  Widget build(BuildContext context) {
    final spacing = isWide ? AppSpacing.md : AppSpacing.sm;
    return Column(
      children: [
        Wrap(
          spacing: spacing,
          runSpacing: AppSpacing.sm,
          children: [
            SizedBox(
              width: isWide ? 280 : double.infinity,
              child: TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  hintText: 'telebirr-live-client-id',
                ),
              ),
            ),
            SizedBox(
              width: isWide ? 280 : double.infinity,
              child: TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Client secret',
                  hintText: '•••••••',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                'Saving will rotate keys instantly and notify admins via email.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            SizedBox(
              width: 160,
              child: PrimaryButton(label: 'Save keys', onPressed: () {}),
            ),
          ],
        ),
      ],
    );
  }
}
