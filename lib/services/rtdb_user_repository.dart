import 'package:equb/models/user_model.dart';
import 'package:equb/services/repository_exception.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:firebase_database/firebase_database.dart';

import 'user_repository.dart';

class RtdbUserRepository implements UserRepository {
  RtdbUserRepository({FirebaseDatabase? database, SystemLogService? logService})
    : _db = database ?? FirebaseDatabase.instance,
      _logService = logService;

  final FirebaseDatabase _db;
  final SystemLogService? _logService;

  DatabaseReference get _usersRef => _db.ref('users');

  @override
  Future<void> updateUser(UserModel user) async {
    try {
      final updates = {
        'name': user.name,
        'phone': user.phone,
        'biometricsEnabled': user.biometricsEnabled,
        'pushEnabled': user.pushEnabled,
        'emailDigestEnabled': user.emailDigestEnabled,
        'notificationPreferences': user.notificationPreferences.toJson(),
      };

      await _usersRef.child(user.id).update(updates);

      _logService?.log(
        LogLevel.info,
        'RtdbUserRepository.updateUser',
        'User profile updated successfully',
        context: {'userId': user.id},
      );
    } catch (e) {
      _logService?.log(
        LogLevel.error,
        'RtdbUserRepository.updateUser',
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
      final snapshot = await _usersRef.child(userId).get();
      final raw = snapshot.value;
      if (raw == null) return null;
      if (raw is! Map) {
        throw RepositoryException(code: 'invalid-data', message: 'Expected user to be a Map');
      }
      return UserModel.fromJson({...Map<String, dynamic>.from(raw), 'id': userId});
    } catch (e) {
      throw RepositoryException(
        code: 'get-failed',
        message: 'Unable to fetch user',
        cause: e,
      );
    }
  }
}
