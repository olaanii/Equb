import 'package:equb/ui/superadmin_portal/services/portal_notification_service.dart';
import 'package:flutter/material.dart';

class PortalNotificationCenter extends StatelessWidget {
  const PortalNotificationCenter({
    super.key,
    required this.service,
  });

  final PortalNotificationService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final notifications = service.notifications;
        final unreadCount = service.unreadCount;

        return PopupMenuButton<void>(
          tooltip: 'Notifications',
          offset: const Offset(0, 8),
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            child: const Icon(Icons.notifications_outlined),
          ),
          itemBuilder: (context) => [
            PopupMenuItem<void>(
              enabled: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (notifications.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        service.markAllAsRead();
                        Navigator.pop(context);
                      },
                      child: const Text('Mark all read'),
                    ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            if (notifications.isEmpty)
              const PopupMenuItem<void>(
                enabled: false,
                child: SizedBox(
                  height: 100,
                  width: 280,
                  child: Center(child: Text('No notifications')),
                ),
              )
            else
              ...notifications.take(5).map(
                    (n) => PopupMenuItem<void>(
                      onTap: () => service.markAsRead(n.id),
                      child: SizedBox(
                        width: 320,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Icon(
                                switch (n.type) {
                                  PortalNotificationType.info =>
                                    Icons.info_outline,
                                  PortalNotificationType.success =>
                                    Icons.check_circle_outline,
                                  PortalNotificationType.warning =>
                                    Icons.warning_amber_outlined,
                                  PortalNotificationType.error =>
                                    Icons.error_outline,
                                },
                                size: 20,
                                color: switch (n.type) {
                                  PortalNotificationType.info => scheme.primary,
                                  PortalNotificationType.success => scheme.secondary,
                                  PortalNotificationType.warning => scheme.tertiary,
                                  PortalNotificationType.error => scheme.error,
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n.title,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: n.read
                                          ? FontWeight.normal
                                          : FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    n.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTime(n.timestamp),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!n.read)
                              Container(
                                margin: const EdgeInsets.only(top: 8, left: 8),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
            if (notifications.length > 5) ...[
              const PopupMenuDivider(),
              PopupMenuItem<void>(
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('View all notifications')),
                      );
                    },
                    child: const Text('View all'),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
