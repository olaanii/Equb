import 'package:flutter/material.dart';

enum PortalNotificationType { info, success, warning, error }

class PortalNotification {
  final String id;
  final String title;
  final String body;
  final PortalNotificationType type;
  final DateTime timestamp;
  final bool read;

  const PortalNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.read = false,
  });

  PortalNotification copyWith({bool? read}) {
    return PortalNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      timestamp: timestamp,
      read: read ?? this.read,
    );
  }
}

class PortalNotificationService extends ChangeNotifier {
  final List<PortalNotification> _notifications = [];

  List<PortalNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.read).length;

  void addNotification(PortalNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(read: true);
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(read: true);
    }
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
}
