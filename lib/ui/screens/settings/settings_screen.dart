import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _pushEnabled = true;
  bool _biometricsEnabled = false;
  bool _marketingEnabled = false;
  bool _betaFeaturesEnabled = true;
  final List<_SessionInfo> _sessions = [
    _SessionInfo(
      id: 'current',
      deviceName: 'Pixel 8 Pro',
      location: 'Addis Ababa, Ethiopia',
      platform: 'Android 15',
      lastActive: DateTime.now().subtract(const Duration(minutes: 2)),
      isCurrent: true,
    ),
    _SessionInfo(
      id: 'ios-14',
      deviceName: 'iPhone 15 Pro',
      location: 'Nairobi, Kenya',
      platform: 'iOS 18.1',
      lastActive: DateTime.now().subtract(
        const Duration(hours: 3, minutes: 24),
      ),
    ),
    _SessionInfo(
      id: 'web-01',
      deviceName: 'Chrome on macOS',
      location: 'Frankfurt, Germany',
      platform: 'macOS 15.1',
      lastActive: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notifications', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _pushEnabled,
                  title: const Text('Push alerts'),
                  subtitle: Text(
                    'Contribution reminders, payout notifications, and chat mentions',
                    style: theme.textTheme.bodySmall,
                  ),
                  onChanged: (value) => setState(() => _pushEnabled = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _marketingEnabled,
                  title: const Text('Product updates'),
                  subtitle: Text(
                    'Occasional emails about new features and onboarding tips',
                    style: theme.textTheme.bodySmall,
                  ),
                  onChanged:
                      (value) => setState(() => _marketingEnabled = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Security', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _biometricsEnabled,
                  title: const Text('Biometric authentication'),
                  subtitle: Text(
                    'Use Face ID or fingerprint to confirm payouts and login faster',
                    style: theme.textTheme.bodySmall,
                  ),
                  onChanged:
                      (value) => setState(() => _biometricsEnabled = value),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Reset password'),
                  subtitle: Text(
                    'Recommended every 90 days to keep your account secure',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: TextButton(
                    onPressed: () => _startPasswordReset(context),
                    child: const Text('Update'),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.devices_other_outlined),
                  title: const Text('Active sessions'),
                  subtitle: Text(
                    'Manage devices with existing sign-ins',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: TextButton(
                    onPressed: () => _openSessionManager(context),
                    child: const Text('Review'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Experiments', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _betaFeaturesEnabled,
                  title: const Text('Early access features'),
                  subtitle: Text(
                    'Preview in-progress screens like the new contribution planner',
                    style: theme.textTheme.bodySmall,
                  ),
                  onChanged:
                      (value) => setState(() => _betaFeaturesEnabled = value),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.feedback_outlined),
                  title: const Text('Share feedback'),
                  subtitle: Text(
                    'Help us prioritize by sending quick notes about your experience',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: TextButton(
                    onPressed: () => _openFeedbackForm(context),
                    child: const Text('Open form'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Data & privacy', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(
                  'You can export your Equb activity anytime. We generate a secure PDF with transaction history and payout summaries.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PrimaryButton(
                    text: 'Export statement',
                    icon: Icons.archive_outlined,
                    onPressed: () => _exportPrivacyReport(context),
                  ),
                ),
                TextButton(
                  onPressed: () => _requestDataDeletion(context),
                  child: const Text('Request data deletion'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPasswordReset(BuildContext context) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setLocalState) => AlertDialog(
                  title: const Text('Reset password'),
                  content: SizedBox(
                    width: 360,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: currentController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Current password',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: newController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New password (min 8 characters)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: confirmController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm new password',
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    PrimaryButton(
                      text: 'Update password',
                      icon: Icons.check,
                      onPressed: () {
                        final newValue = newController.text.trim();
                        if (newValue.length < 8) {
                          setLocalState(
                            () =>
                                error =
                                    'Use at least 8 characters for your new password.',
                          );
                          return;
                        }
                        if (newValue != confirmController.text.trim()) {
                          setLocalState(
                            () => error = 'Confirmation does not match.',
                          );
                          return;
                        }
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ],
                ),
          ),
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password updated. You will need it for your next sign-in.',
          ),
        ),
      );
    }
  }

  Future<void> _openSessionManager(BuildContext context) async {
    var localSessions = List<_SessionInfo>.from(_sessions);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, sheetSetState) => Padding(
                  padding: MediaQuery.of(
                    context,
                  ).viewInsets.add(const EdgeInsets.fromLTRB(24, 24, 24, 32)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.devices_other_outlined),
                          const SizedBox(width: 8),
                          Text(
                            'Active sessions',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sign out of devices you no longer recognize. Removing a session immediately revokes access.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 360),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              final session = localSessions[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  session.isCurrent
                                      ? Icons.phone_iphone
                                      : Icons.laptop_mac_outlined,
                                ),
                                title: Text(session.deviceName),
                                subtitle: Text(
                                  '${session.platform} • ${session.location}\nLast active ${_relativeTime(session.lastActive)}',
                                ),
                                isThreeLine: true,
                                trailing:
                                    session.isCurrent
                                        ? const Chip(label: Text('This device'))
                                        : TextButton(
                                          onPressed: () {
                                            sheetSetState(() {
                                              localSessions =
                                                  List<_SessionInfo>.from(
                                                    localSessions,
                                                  )..removeWhere(
                                                    (s) => s.id == session.id,
                                                  );
                                            });
                                            setState(() {
                                              _sessions.removeWhere(
                                                (s) => s.id == session.id,
                                              );
                                            });
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Signed out ${session.deviceName}.',
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text('Sign out'),
                                        ),
                              );
                            },
                            separatorBuilder: (_, __) => const Divider(),
                            itemCount: localSessions.length,
                          ),
                        ),
                      ),
                      if (localSessions.length > 1)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              sheetSetState(() {
                                localSessions = [
                                  ...localSessions.where(
                                    (session) => session.isCurrent,
                                  ),
                                ];
                              });
                              setState(() {
                                _sessions.removeWhere(
                                  (session) => !session.isCurrent,
                                );
                              });
                              Navigator.of(context).maybePop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Signed out everywhere else.'),
                                ),
                              );
                            },
                            child: const Text('Sign out of other devices'),
                          ),
                        ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _openFeedbackForm(BuildContext context) async {
    final feedbackController = TextEditingController();
    String category = 'General';
    bool sendDiagnostics = true;
    String? error;
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => Padding(
            padding: MediaQuery.of(
              context,
            ).viewInsets.add(const EdgeInsets.fromLTRB(24, 24, 24, 32)),
            child: StatefulBuilder(
              builder:
                  (context, setLocalState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share quick feedback',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'General',
                            child: Text('General experience'),
                          ),
                          DropdownMenuItem(
                            value: 'Feature request',
                            child: Text('Feature request'),
                          ),
                          DropdownMenuItem(
                            value: 'Bug report',
                            child: Text('Bug report'),
                          ),
                          DropdownMenuItem(
                            value: 'Payments',
                            child: Text('Payments & withdrawals'),
                          ),
                        ],
                        onChanged:
                            (value) => setLocalState(
                              () => category = value ?? category,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: feedbackController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Tell us what happened',
                          hintText:
                              'Share details so the team can follow up quickly',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: sendDiagnostics,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Attach anonymized diagnostics'),
                        subtitle: const Text(
                          'Includes app version, device info, and last error logs',
                        ),
                        onChanged:
                            (value) =>
                                setLocalState(() => sendDiagnostics = value),
                      ),
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          PrimaryButton(
                            text: 'Send',
                            icon: Icons.send_outlined,
                            onPressed: () {
                              if (feedbackController.text.trim().length < 10) {
                                setLocalState(
                                  () =>
                                      error =
                                          'Please share at least 10 characters.',
                                );
                                return;
                              }
                              Navigator.of(context).pop(true);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
            ),
          ),
    );
    if (submitted == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thanks for the feedback! We tagged it as $category.'),
        ),
      );
    }
  }

  Future<void> _exportPrivacyReport(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (!context.mounted) return;
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Export ready. We emailed the encrypted PDF to you.',
                ),
              ),
            );
          }
        });
        return AlertDialog(
          title: const Text('Preparing export'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Generating a secure archive with your contributions, payouts, and notifications...',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _requestDataDeletion(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Request data deletion'),
            content: const Text(
              'We will review your request within 48 hours. Pending transactions must settle before data removal. '
              'You will receive a confirmation email with next steps.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              PrimaryButton(
                text: 'Submit request',
                icon: Icons.shield_outlined,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Privacy team notified. Expect a follow-up email shortly.',
          ),
        ),
      );
    }
  }

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) {
      return 'just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} hr ago';
    }
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
}

class _SessionInfo {
  _SessionInfo({
    required this.id,
    required this.deviceName,
    required this.location,
    required this.platform,
    required this.lastActive,
    this.isCurrent = false,
  });

  final String id;
  final String deviceName;
  final String location;
  final String platform;
  final DateTime lastActive;
  final bool isCurrent;
}
