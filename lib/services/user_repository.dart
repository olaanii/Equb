import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/services/repository_exception.dart';
import 'package:equb/services/system_log_service.dart';

abstract class UserRepository {
  Future<void> updateUser(UserModel user);
  Future<UserModel?> getUser(String userId);
  Future<List<UserModel>> getAllUsers({int? limit, String? startAfterKey});
  Stream<List<UserModel>> watchAllUsers();
}

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _firestore;
  final SystemLogService? _logService;

  FirestoreUserRepository({
    FirebaseFirestore? firestore,
    SystemLogService? logService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _logService = logService;

  @override
  Future<void> updateUser(UserModel user) async {
    try {
      // We only update "profile" fields.
      // Sensitive fields like 'walletBalance', 'role', 'createdAt' are excluded
      // to prevent client-side manipulation.
      final updates = {
        'name': user.name,
        'phone': user.phone,
        'biometricsEnabled': user.biometricsEnabled,
        'pushEnabled': user.pushEnabled,
        'emailDigestEnabled': user.emailDigestEnabled,
        'notificationPreferences': user.notificationPreferences.toJson(),
      };

      await _firestore.collection('users').doc(user.id).update(updates);

      _logService?.log(
        LogLevel.info,
        'FirestoreUserRepository.updateUser',
        'User profile updated successfully',
        context: {'userId': user.id},
      );
    } catch (e) {
      _logService?.log(
        LogLevel.error,
        'FirestoreUserRepository.updateUser',
        'Failed to update user profile',
        context: {'userId': user.id, 'error': e.toString()},
      );
      throw RepositoryException(
        code: 'update-failed',
        message: 'Unable to update profile',
        cause: e,
      );
    }
  }

  @override
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return UserModel.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      throw RepositoryException(
        code: 'get-failed',
        message: 'Unable to fetch user',
        cause: e,
      );
    }
  }

  @override
  Future<List<UserModel>> getAllUsers({int? limit, String? startAfterKey}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('users')
          .orderBy('createdAt', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      if (startAfterKey != null) {
        final startDoc = await _firestore.collection('users').doc(startAfterKey).get();
        if (startDoc.exists) {
          query = query.startAfterDocument(startDoc);
        }
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        return UserModel.fromJson({...doc.data(), 'id': doc.id});
      }).toList();
    } catch (e) {
      _logService?.log(
        LogLevel.error,
        'FirestoreUserRepository.getAllUsers',
        'Failed to fetch all users',
        context: {'error': e.toString()},
      );
      throw RepositoryException(
        code: 'get-all-failed',
        message: 'Unable to fetch users',
        cause: e,
      );
    }
  }

  @override
  Stream<List<UserModel>> watchAllUsers() {
    return _firestore.collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return UserModel.fromJson({...doc.data(), 'id': doc.id});
          }).toList();
        });
  }
}
