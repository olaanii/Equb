import 'package:cloud_functions/cloud_functions.dart';

class PortalSuperAdminService {
  PortalSuperAdminService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> setAdmin({required String targetUid, required bool isAdmin}) async {
    final callable = _functions.httpsCallable('superAdminSetAdmin');
    await callable.call(<String, dynamic>{
      'targetUid': targetUid,
      'isAdmin': isAdmin,
    });
  }

  Future<void> setSuperAdmin({
    required String targetUid,
    required bool isSuperAdmin,
  }) async {
    final callable = _functions.httpsCallable('superAdminSetSuperAdmin');
    await callable.call(<String, dynamic>{
      'targetUid': targetUid,
      'isSuperAdmin': isSuperAdmin,
    });
  }
}
