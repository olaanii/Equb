import 'package:equb/models/notification_preferences.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends ConsumerState<NotificationPreferencesScreen> {
  late NotificationPreferences _preferences;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    try {
      // In a real app, this would load from Firestore
      // For now, use default preferences
      setState(() {
        _preferences = const NotificationPreferences();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load preferences: $e')),
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);

    try {
      // In a real app, this would save to Firestore
      // For now, just simulate saving
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
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
        title: const Text('Notification Preferences'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePreferences,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.pagePaddingMobile,
        children: [
          // Contribution Reminders
          _buildPreferenceSection(
            title: 'Contribution Reminders',
            subtitle: 'Get notified before your contributions are due',
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable Contribution Reminders'),
                  subtitle: const Text('Receive reminders before contributions are due'),
                  value: _preferences.contributionRemindersEnabled,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(contributionRemindersEnabled: value);
                    });
                  },
                ),
                if (_preferences.contributionRemindersEnabled)
                  ListTile(
                    title: const Text('Reminder Timing'),
                    subtitle: Text('${_preferences.reminderLeadTimeHours} hours before due date'),
                    trailing: DropdownButton<int>(
                      value: _preferences.reminderLeadTimeHours,
                      items: [1, 6, 12, 24, 48, 72].map((hours) {
                        return DropdownMenuItem(
                          value: hours,
                          child: Text('$hours hours'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _preferences = _preferences.copyWith(reminderLeadTimeHours: value);
                          });
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Payout Notifications
          _buildPreferenceSection(
            title: 'Payout Notifications',
            subtitle: 'Get notified about upcoming and completed payouts',
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable Payout Notifications'),
                  subtitle: const Text('Receive notifications about your payouts'),
                  value: _preferences.payoutRemindersEnabled,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(payoutRemindersEnabled: value);
                    });
                  },
                ),
                if (_preferences.payoutRemindersEnabled) ...[
                  SwitchListTile(
                    title: const Text('Payout Scheduled'),
                    subtitle: const Text('Notify when payout is scheduled'),
                    value: _preferences.payoutScheduledEnabled,
                    onChanged: (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(payoutScheduledEnabled: value);
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Payout Completed'),
                    subtitle: const Text('Notify when payout is processed'),
                    value: _preferences.payoutCompletedEnabled,
                    onChanged: (value) {
                      setState(() {
                        _preferences = _preferences.copyWith(payoutCompletedEnabled: value);
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Group Activity
          _buildPreferenceSection(
            title: 'Group Activity',
            subtitle: 'Notifications about your savings groups',
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('New Members'),
                  subtitle: const Text('When someone joins your group'),
                  value: _preferences.groupNewMemberEnabled,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(groupNewMemberEnabled: value);
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Group Messages'),
                  subtitle: const Text('New messages in group chat'),
                  value: _preferences.groupMessageEnabled,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(groupMessageEnabled: value);
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Group Updates'),
                  subtitle: const Text('Important group announcements'),
                  value: _preferences.groupUpdatesEnabled,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(groupUpdatesEnabled: value);
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // System Notifications
          _buildPreferenceSection(
            title: 'System & Security',
            subtitle: 'Important app and security notifications',
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Security Alerts'),
                  subtitle: const Text('Login attempts and security events'),
                  value: _preferences.securityAlertsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(securityAlertsEnabled: value);
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('App Updates'),
                  subtitle: const Text('New features and app improvements'),
                  value: _preferences.appUpdatesEnabled,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(appUpdatesEnabled: value);
                    });
                  },
                ),
                SwitchListTile(
                  title: const Text('Weekly Summary'),
                  subtitle: const Text('Weekly activity summary'),
                  value: _preferences.weeklySummaryEnabled,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(weeklySummaryEnabled: value);
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quiet Hours
          _buildPreferenceSection(
            title: 'Quiet Hours',
            subtitle: 'Pause notifications during specific times',
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Enable Quiet Hours'),
                  subtitle: const Text('Pause notifications during sleep hours'),
                  value: _preferences.quietHoursEnabled,
                  onChanged: (value) {
                    setState(() {
                      _preferences = _preferences.copyWith(quietHoursEnabled: value);
                    });
                  },
                ),
                if (_preferences.quietHoursEnabled) ...[
                  ListTile(
                    title: const Text('Quiet Hours Start'),
                    subtitle: Text(_preferences.quietHoursStart.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _preferences.quietHoursStart,
                      );
                      if (time != null) {
                        setState(() {
                          _preferences = _preferences.copyWith(quietHoursStart: time);
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('Quiet Hours End'),
                    subtitle: Text(_preferences.quietHoursEnd.format(context)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: _preferences.quietHoursEnd,
                      );
                      if (time != null) {
                        setState(() {
                          _preferences = _preferences.copyWith(quietHoursEnd: time);
                        });
                      }
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Test Notifications
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Notifications',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Send a test notification to verify your settings are working.',
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _sendTestNotification,
                      child: const Text('Send Test Notification'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Footer note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outline.withOpacity(0.3)),
            ),
            child: Text(
              'Notification preferences are synced across all your devices. Changes may take a few minutes to take effect.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    try {
      final pushScheduler = ref.read(pushNotificationSchedulerProvider);
      final user = ref.read(currentUserProvider).value;

      if (user == null) return;

      await pushScheduler.sendImmediateNotification(
        userId: user.id,
        title: 'Test Notification',
        body: 'This is a test notification to verify your settings are working correctly.',
        notificationType: 'test',
        data: {
          'test': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test notification sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send test notification: $e')),
        );
      }
    }
  }
}

