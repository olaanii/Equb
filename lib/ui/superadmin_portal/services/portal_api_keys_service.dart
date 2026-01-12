import 'package:cloud_functions/cloud_functions.dart';

class PortalApiKeysService {
  PortalApiKeysService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<List<Map<String, dynamic>>> list({int limit = 200}) async {
    final callable = _functions.httpsCallable('superAdminListApiKeys');
    final result = await callable.call(<String, dynamic>{'limit': limit});

    final data = result.data;
    if (data is! Map) return const [];

    final items = data['items'];
    if (items is! List) return const [];

    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> create({
    required String label,
    String? principalEmail,
    List<String>? scopes,
  }) async {
    final callable = _functions.httpsCallable('superAdminCreateApiKey');
    final result = await callable.call(<String, dynamic>{
      'label': label,
      if (principalEmail != null && principalEmail.trim().isNotEmpty)
        'principalEmail': principalEmail.trim(),
      if (scopes != null) 'scopes': scopes,
    });

    final data = result.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const <String, dynamic>{};
  }

  Future<void> revoke({required String id}) async {
    final callable = _functions.httpsCallable('superAdminRevokeApiKey');
    await callable.call(<String, dynamic>{'id': id});
  }
}
