import 'package:equb/models/email_preferences.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EmailPreferencesScreen extends ConsumerStatefulWidget {
  const EmailPreferencesScreen({super.key});

  @override
  ConsumerState<EmailPreferencesScreen> createState() => _EmailPreferencesScreenState();
}

class _EmailPreferencesScreenState extends ConsumerState<EmailPreferencesScreen> {
  late EmailPreferences _preferences;
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
      final emailService = ref.read(emailServiceProvider);
      final preferences = await emailService.getUserPreferences(user.id);

      if (mounted) {
        setState(() {
          _preferences = preferences;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load preferences: $e')),
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final emailService = ref.read(emailServiceProvider);
      final success = await emailService.updateUserPreferences(user.id, _preferences);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email preferences saved successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save preferences')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _sendTestEmail() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null || user.email == null) return;

    try {
      final emailService = ref.read(emailServiceProvider);
      final success = await emailService.sendTestEmail(user.email!, user.name);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success ? 'Test email sent!' : 'Failed to send test email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending test email: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Preferences'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePreferences,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.pagePaddingMobile,
        children: [
          // Test email button
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Test Email',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Send a test email to verify your email settings are working.'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _sendTestEmail,
                      icon: const Icon(Icons.send),
                      label: const Text('Send Test Email'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Notification preferences
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email Notifications',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),

                  // Contribution reminders
                  _EmailPreferenceItem(
                    type: EmailType.contributionReminder,
                    currentFrequency: _preferences.contributionReminders,
                    onChanged: (frequency) => setState(() {
                      _preferences = _preferences.copyWith(contributionReminders: frequency);
                    }),
                  ),

                  const Divider(height: 24),

                  // Payout notifications
                  _EmailPreferenceItem(
                    type: EmailType.payoutNotification,
                    currentFrequency: _preferences.payoutNotifications,
                    onChanged: (frequency) => setState(() {
                      _preferences = _preferences.copyWith(payoutNotifications: frequency);
                    }),
                  ),

                  const Divider(height: 24),

                  // Group invitations
                  _EmailPreferenceItem(
                    type: EmailType.groupInvitation,
                    currentFrequency: _preferences.groupInvitations,
                    onChanged: (frequency) => setState(() {
                      _preferences = _preferences.copyWith(groupInvitations: frequency);
                    }),
                  ),

                  const Divider(height: 24),

                  // Transaction confirmations
                  _EmailPreferenceItem(
                    type: EmailType.transactionConfirmation,
                    currentFrequency: _preferences.transactionConfirmations,
                    onChanged: (frequency) => setState(() {
                      _preferences = _preferences.copyWith(transactionConfirmations: frequency);
                    }),
                  ),

                  const Divider(height: 24),

                  // Low balance warnings
                  _EmailPreferenceItem(
                    type: EmailType.lowBalanceWarning,
                    currentFrequency: _preferences.lowBalanceWarnings,
                    onChanged: (frequency) => setState(() {
                      _preferences = _preferences.copyWith(lowBalanceWarnings: frequency);
                    }),
                  ),

                  const Divider(height: 24),

                  // Weekly summaries
                  _EmailPreferenceItem(
                    type: EmailType.weeklySummary,
                    currentFrequency: _preferences.weeklySummaries,
                    onChanged: (frequency) => setState(() {
                      _preferences = _preferences.copyWith(weeklySummaries: frequency);
                    }),
                  ),

                  const Divider(height: 24),

                  // System updates
                  _EmailPreferenceItem(
                    type: EmailType.systemUpdate,
                    currentFrequency: _preferences.systemUpdates,
                    onChanged: (frequency) => setState(() {
                      _preferences = _preferences.copyWith(systemUpdates: frequency);
                    }),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Marketing preferences
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marketing Communications',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Receive promotional offers and new feature announcements.'),
                  const SizedBox(height: 16),

                  SwitchListTile.adaptive(
                    value: _preferences.marketingEmails,
                    onChanged: (value) => setState(() {
                      _preferences = _preferences.copyWith(marketingEmails: value);
                    }),
                    title: const Text('Marketing Emails'),
                    subtitle: const Text('Promotional offers and new features'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Unsubscribe section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unsubscribe Options',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Quick options to stop receiving specific types of emails.'),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: EmailType.values.map((type) {
                      if (type == EmailType.marketing) return const SizedBox.shrink();

                      return OutlinedButton(
                        onPressed: () => _unsubscribeFromType(type),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: scheme.error.withOpacity(0.5)),
                          foregroundColor: scheme.error,
                        ),
                        child: Text('Stop ${type.label.toLowerCase()}'),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Footer note
          Text(
            'Email preferences are saved automatically when you make changes. You can update these settings at any time.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _unsubscribeFromType(EmailType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsubscribe'),
        content: Text('Are you sure you want to stop receiving ${type.label.toLowerCase()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Unsubscribe'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    try {
      final emailService = ref.read(emailServiceProvider);
      final success = await emailService.unsubscribeFromEmailType(user.id, type);

      if (mounted) {
        if (success) {
          setState(() {
            _preferences = _updatePreferenceForType(_preferences, type, EmailFrequency.never);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unsubscribed from ${type.label.toLowerCase()}')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to unsubscribe')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  EmailPreferences _updatePreferenceForType(
    EmailPreferences preferences,
    EmailType emailType,
    EmailFrequency frequency,
  ) {
    switch (emailType) {
      case EmailType.contributionReminder:
        return preferences.copyWith(contributionReminders: frequency);
      case EmailType.payoutNotification:
        return preferences.copyWith(payoutNotifications: frequency);
      case EmailType.groupInvitation:
        return preferences.copyWith(groupInvitations: frequency);
      case EmailType.transactionConfirmation:
        return preferences.copyWith(transactionConfirmations: frequency);
      case EmailType.weeklySummary:
        return preferences.copyWith(weeklySummaries: frequency);
      case EmailType.lowBalanceWarning:
        return preferences.copyWith(lowBalanceWarnings: frequency);
      case EmailType.systemUpdate:
        return preferences.copyWith(systemUpdates: frequency);
      case EmailType.marketing:
        return preferences.copyWith(marketingEmails: false);
    }
  }
}

class _EmailPreferenceItem extends StatelessWidget {
  const _EmailPreferenceItem({
    required this.type,
    required this.currentFrequency,
    required this.onChanged,
  });

  final EmailType type;
  final EmailFrequency currentFrequency;
  final ValueChanged<EmailFrequency> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          type.label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          type.description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<EmailFrequency>(
            value: currentFrequency,
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
            items: EmailFrequency.values.map((frequency) {
              return DropdownMenuItem(
                value: frequency,
                child: Text(frequency.label),
              );
            }).toList(),
            isExpanded: true,
            underline: const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

