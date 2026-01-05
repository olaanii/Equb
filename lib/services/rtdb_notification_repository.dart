import 'package:equb/models/user_notification.dart';
import 'package:firebase_database/firebase_database.dart';

class RtdbNotificationRepository {
  RtdbNotificationRepository({FirebaseDatabase? database})
    : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference _userNotificationsRef(String userId) =>
      _db.ref('users/$userId/notifications');

  Stream<List<UserNotification>> getNotifications(String userId) {
    final query = _userNotificationsRef(userId)
        .orderByChild('createdAtMs')
        .limitToLast(50);

    return query.onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw == null || raw is! Map) return <UserNotification>[];

      final list = <UserNotification>[];
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final data = Map<String, dynamic>.from(value);
        data['id'] = data['id'] ?? entry.key.toString();
        list.add(UserNotification.fromJson(data));
      }

      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> sendNotification(UserNotification notification) async {
    final ref = notification.id.isEmpty
        ? _userNotificationsRef(notification.userId).push()
        : _userNotificationsRef(notification.userId).child(notification.id);

    final id = ref.key;
    if (id == null || id.isEmpty) return;

    final payload = notification.toJson();
    payload['id'] = id;
    payload['createdAtMs'] = notification.createdAt.millisecondsSinceEpoch;

    await ref.set(payload);
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _userNotificationsRef(userId).child(notificationId).update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _userNotificationsRef(userId).get();
    final raw = snapshot.value;
    if (raw == null || raw is! Map) return;

    final updates = <String, Object?>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final data = Map<String, dynamic>.from(value);
      final isRead = data['isRead'] as bool? ?? false;
      if (!isRead) {
        updates['${entry.key}/isRead'] = true;
      }
    }
    if (updates.isEmpty) return;
    await _userNotificationsRef(userId).update(updates);
  }
}
