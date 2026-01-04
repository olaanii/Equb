import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equb/models/user_notification.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<UserNotification>> getNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return UserNotification.fromJson(data);
          }).toList();
        });
  }

  Future<void> sendNotification(UserNotification notification) async {
    await _firestore
        .collection('users')
        .doc(notification.userId)
        .collection('notifications')
        .doc(notification.id.isEmpty ? null : notification.id)
        .set(notification.toJson());
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final batch = _firestore.batch();
    final notifications =
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .where('isRead', isEqualTo: false)
            .get();

    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
