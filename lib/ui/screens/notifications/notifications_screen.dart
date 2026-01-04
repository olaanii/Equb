import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/models/user_notification.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/screens/shared/widgets.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return ProdScaffold(
      title: 'Notifications',
      actions: [
        IconButton(
          icon: const Icon(Icons.done_all),
          onPressed: () {
            final user = ref.read(currentUserProvider).value;
            if (user != null) {
              ref.read(notificationRepositoryProvider).markAllAsRead(user.id);
            }
          },
          tooltip: 'Mark all as read',
        ),
      ],
      child: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(notification: notification);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final UserNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    IconData icon;
    Color color;

    switch (notification.type) {
      case NotificationType.success:
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case NotificationType.error:
        icon = Icons.error;
        color = AppColors.error;
        break;
      case NotificationType.warning:
        icon = Icons.warning;
        color = AppColors.warning;
        break;
      case NotificationType.transaction:
        icon = Icons.swap_horiz;
        color = AppColors.primary;
        break;
      default:
        icon = Icons.info;
        color = Colors.blue;
    }

    return Dismissible(
      key: Key(notification.id),
      onDismissed: (_) {
        // Handle deletion if needed
      },
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            final user = ref.read(currentUserProvider).value;
            if (user != null) {
              ref
                  .read(notificationRepositoryProvider)
                  .markAsRead(user.id, notification.id);
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                notification.isRead
                    ? Colors.transparent
                    : color.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight:
                            notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat.yMMMd().add_jm().format(
                        notification.createdAt,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
