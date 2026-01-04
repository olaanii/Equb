import 'package:equb/models/user_model.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:equb/models/notification_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          appBar: AppBar(title: const Text('Notifications')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader(theme, 'Delivery Channels'),
              InfoCard(
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: user.pushEnabled,
                      title: const Text('Push Notifications'),
                      subtitle: Text(
                        'Instant alerts for contributions and payouts',
                        style: theme.textTheme.bodySmall,
                      ),
                      onChanged:
                          (value) => _updateUser(
                            ref,
                            user.copyWith(pushEnabled: value),
                          ),
                    ),
                    const Divider(),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: user.emailDigestEnabled,
                      title: const Text('Email Digest'),
                      subtitle: Text(
                        'Weekly summary of your balance activity',
                        style: theme.textTheme.bodySmall,
                      ),
                      onChanged:
                          (value) => _updateUser(
                            ref,
                            user.copyWith(emailDigestEnabled: value),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader(theme, 'Reminder Preferences'),
              InfoCard(
                child: _ReminderSettingsSection(
                  user: user,
                  onUpdate:
                      (prefs) => _updateNotificationPrefs(ref, user, prefs),
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

  void _updateUser(WidgetRef ref, UserModel updated) {
    ref.read(sessionCacheServiceProvider).cacheUser(updated);
  }

  void _updateNotificationPrefs(
    WidgetRef ref,
    UserModel user,
    NotificationPreferences prefs,
  ) {
    _updateUser(ref, user.copyWith(notificationPreferences: prefs));
  }
}

class _ReminderSettingsSection extends StatelessWidget {
  const _ReminderSettingsSection({required this.user, required this.onUpdate});

  final UserModel user;
  final Function(NotificationPreferences) onUpdate;

  @override
  Widget build(BuildContext context) {
    final prefs = user.notificationPreferences;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.contributionRemindersEnabled,
          title: const Text('Contribution Reminders'),
          subtitle: const Text('Get notified before your next auto-charge'),
          onChanged:
              (v) => onUpdate(prefs.copyWith(contributionRemindersEnabled: v)),
        ),
        const Divider(),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: prefs.payoutRemindersEnabled,
          title: const Text('Payout Reminders'),
          subtitle: const Text('Notifications for incoming funds'),
          onChanged: (v) => onUpdate(prefs.copyWith(payoutRemindersEnabled: v)),
        ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Lead Time'),
          subtitle: Text(
            'Remind me ${prefs.reminderLeadTimeHours} hours before',
          ),
          trailing: SizedBox(
            width: 80,
            child: DropdownButton<int>(
              value: prefs.reminderLeadTimeHours,
              isExpanded: true,
              underline: const SizedBox(),
              items:
                  [2, 6, 12, 24]
                      .map(
                        (h) => DropdownMenuItem(value: h, child: Text('${h}h')),
                      )
                      .toList(),
              onChanged:
                  (v) => onUpdate(prefs.copyWith(reminderLeadTimeHours: v)),
            ),
          ),
        ),
      ],
    );
  }
}
