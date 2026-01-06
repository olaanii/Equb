import 'package:equb/models/group_member.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  List<DeviceInfo> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  Future<void> _loadSecuritySettings() async {
    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;

      // Check biometric availability and status
      final biometricService = ref.read(biometricAuthServiceProvider);
      _biometricAvailable = await biometricService.isBiometricAvailable();
      _biometricEnabled = await biometricService.isBiometricEnabled(user.id);

      // Load user devices
      final deviceService = ref.read(deviceManagementServiceProvider);
      _devices = await deviceService.getUserDevices(user.id);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load security settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings'),
      ),
      body: ListView(
        padding: AppSpacing.pagePaddingMobile,
        children: [
          // Biometric Authentication
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.fingerprint,
                        color: scheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Biometric Authentication',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use fingerprint or face unlock for quick access',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_biometricAvailable) ...[
                    SwitchListTile(
                      title: const Text('Enable Biometric Login'),
                      subtitle: const Text('Use biometrics to unlock the app'),
                      value: _biometricEnabled,
                      onChanged: _toggleBiometricAuth,
                    ),
                    if (_biometricEnabled)
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                        child: Text(
                          'Biometric authentication is enabled. You can use fingerprint or face recognition to access your account.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green.withOpacity(0.8),
                          ),
                        ),
                      ),
                  ] else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Biometric authentication is not available on this device. Make sure biometrics are set up in your device settings.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Device Management
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.devices,
                        color: scheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Device Management',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage devices that have access to your account',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._devices.map((device) => _buildDeviceTile(device)),
                  if (_devices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No devices registered'),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logoutAllDevices,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout All Devices'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Session Security
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: scheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Session Security',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure session timeout and security preferences',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Session Timeout'),
                    subtitle: const Text('Automatically log out after 24 hours of inactivity'),
                    trailing: const Icon(Icons.info_outline),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: const Text('Maximum Concurrent Sessions'),
                    subtitle: const Text('Limit to 5 simultaneous logins'),
                    trailing: const Icon(Icons.info_outline),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sessions automatically expire after 24 hours of inactivity. For security, we limit concurrent sessions to 5 devices.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Security Alerts
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: scheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Security Alerts',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Get notified about important security events',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSecurityAlertOption(
                    'New Device Login',
                    'Alert when someone logs in from a new device',
                    true, // Would load from user preferences
                  ),
                  _buildSecurityAlertOption(
                    'Suspicious Activity',
                    'Alert for unusual account activity',
                    true, // Would load from user preferences
                  ),
                  _buildSecurityAlertOption(
                    'Password Changes',
                    'Alert when password is changed',
                    true, // Would load from user preferences
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Security Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb,
                      color: Colors.blue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Security Tips',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSecurityTip('Use strong, unique passwords'),
                _buildSecurityTip('Enable biometric authentication'),
                _buildSecurityTip('Regularly review your device list'),
                _buildSecurityTip('Log out from shared devices'),
                _buildSecurityTip('Keep your app updated'),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDeviceTile(DeviceInfo device) {
    final isCurrentDevice = device.isCurrentSession;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentDevice
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            device.platform == 'ios' ? Icons.phone_iphone : Icons.phone_android,
            color: isCurrentDevice ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      device.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isCurrentDevice) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Current',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${device.deviceModel} • ${device.platform} ${device.osVersion}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  'Last login: ${_formatLastLogin(device.lastLoginAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (!isCurrentDevice)
            PopupMenuButton<String>(
              onSelected: (action) => _handleDeviceAction(device, action),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove Device'),
                ),
                const PopupMenuItem(
                  value: 'trust',
                  child: Text('Mark as Trusted'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityAlertOption(String title, String description, bool enabled) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(description),
      value: enabled,
      onChanged: (value) {
        // TODO: Save security alert preferences
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Security alert preferences not yet implemented')),
        );
      },
    );
  }

  Widget _buildSecurityTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.blue.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleBiometricAuth(bool enabled) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final biometricService = ref.read(biometricAuthServiceProvider);

    try {
      if (enabled) {
        final success = await biometricService.enableBiometricAuth(user.id);
        if (success) {
          setState(() => _biometricEnabled = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication enabled')),
          );
        }
      } else {
        await biometricService.disableBiometricAuth(user.id);
        setState(() => _biometricEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication disabled')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update biometric settings: $e')),
      );
    }
  }

  void _handleDeviceAction(DeviceInfo device, String action) {
    switch (action) {
      case 'remove':
        _showRemoveDeviceDialog(device);
        break;
      case 'trust':
        _trustDevice(device);
        break;
    }
  }

  void _showRemoveDeviceDialog(DeviceInfo device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: Text('Are you sure you want to remove "${device.name}" from your account? This device will no longer be able to access your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _removeDevice(device);
              if (mounted) Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeDevice(DeviceInfo device) async {
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;

      final deviceService = ref.read(deviceManagementServiceProvider);
      await deviceService.removeDevice(device.id, user.id);

      // Refresh device list
      await _loadSecuritySettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove device: $e')),
        );
      }
    }
  }

  Future<void> _trustDevice(DeviceInfo device) async {
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;

      final deviceService = ref.read(deviceManagementServiceProvider);
      await deviceService.trustDevice(device.id, user.id);

      // Refresh device list
      await _loadSecuritySettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device marked as trusted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to trust device: $e')),
        );
      }
    }
  }

  Future<void> _logoutAllDevices() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout All Devices'),
        content: const Text('This will log you out from all devices including this one. You will need to log in again on each device. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final sessionService = ref.read(sessionSecurityServiceProvider);
        await sessionService.endAllUserSessions(user.id, user.id);

        // This would trigger logout and redirect to login screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out from all devices')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to logout all devices: $e')),
        );
      }
    }
  }

  String _formatLastLogin(DateTime lastLogin) {
    final now = DateTime.now();
    final difference = now.difference(lastLogin);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}

