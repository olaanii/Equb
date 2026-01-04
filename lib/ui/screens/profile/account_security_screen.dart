import 'package:equb/models/user_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountSecurityScreen extends ConsumerStatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  ConsumerState<AccountSecurityScreen> createState() =>
      _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends ConsumerState<AccountSecurityScreen> {
  bool _showPersonalDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text("Profile not found.")),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Account & Security')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader(theme, 'Security Access'),
              InfoCard(
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: user.biometricsEnabled,
                      title: const Text('Biometric Authentication'),
                      subtitle: Text(
                        'Use Face ID or Fingerprint for faster access',
                        style: theme.textTheme.bodySmall,
                      ),
                      onChanged:
                          (value) => _updateUser(
                            user.copyWith(biometricsEnabled: value),
                          ),
                    ),
                    const Divider(),
                    _buildActionTile(
                      theme,
                      icon: Icons.lock_outline,
                      title: 'Change Password',
                      subtitle: 'Update your login credentials',
                      onTap: () => _startPasswordReset(context),
                    ),
                    const Divider(),
                    _buildActionTile(
                      theme,
                      icon: Icons.devices_outlined,
                      title: 'Trusted Devices',
                      subtitle: '2 active sessions detected',
                      onTap: () => _showTrustedDevices(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(theme, 'Personal Information'),
              InfoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(theme, 'Full Name', user.name),
                    const Divider(),
                    _buildInfoRow(
                      theme,
                      'Email Address',
                      user.email ?? 'Not set',
                    ),
                    const Divider(),
                    _buildInfoRow(
                      theme,
                      'Phone Number',
                      user.phone ?? 'Not set',
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton.icon(
                        icon: Icon(
                          _showPersonalDetails
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _showPersonalDetails
                              ? 'Hide Legal Details'
                              : 'View Legal Details',
                        ),
                        onPressed:
                            () => setState(
                              () =>
                                  _showPersonalDetails = !_showPersonalDetails,
                            ),
                      ),
                    ),
                    if (_showPersonalDetails) ...[
                      const SizedBox(height: 12),
                      _buildLegalInfo(theme, user),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text("Error: $e"))),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalInfo(ThemeData theme, UserModel user) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(theme, 'National ID', '403998-ET'),
          _buildInfoRow(theme, 'Residency', 'Addis Ababa, Ethiopia'),
        ],
      ),
    );
  }

  void _updateUser(UserModel updated) {
    ref.read(sessionCacheServiceProvider).cacheUser(updated);
    // In a real app, this would call an API or update Firestore
  }

  void _startPasswordReset(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset flow initiated.')),
    );
  }

  void _showTrustedDevices(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Device management coming soon.')),
    );
  }
}
