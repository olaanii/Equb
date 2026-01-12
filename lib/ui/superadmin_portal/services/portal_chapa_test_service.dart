import 'package:cloud_functions/cloud_functions.dart';

class PortalChapaTestService {
  PortalChapaTestService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> setChapaSecrets({
    required String secretKey,
    String? publicKey,
    String? encryptionKey,
  }) async {
    final callable = _functions.httpsCallable('superAdminSetGatewaySecret');

    final payload = <String, dynamic>{
      'gatewayId': 'chapa',
      'secrets': <String, dynamic>{
        'secretKey': secretKey,
        if (publicKey != null && publicKey.trim().isNotEmpty)
          'publicKey': publicKey.trim(),
        if (encryptionKey != null && encryptionKey.trim().isNotEmpty)
          'encryptionKey': encryptionKey.trim(),
      },
    };

    await callable.call(payload);
  }

  Future<List<Map<String, dynamic>>> listTestUsers() async {
    final callable = _functions.httpsCallable('superAdminListChapaTestUsers');
    final res = await callable.call(<String, dynamic>{});
    final data = res.data;
    if (data is Map && data['users'] is List) {
      return (data['users'] as List)
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }

  Future<void> upsertTestUser({
    required String id,
    required String label,
    required String email,
    required String phone,
  }) async {
    final callable = _functions.httpsCallable('superAdminUpsertChapaTestUser');
    await callable.call(<String, dynamic>{
      'id': id,
      'label': label,
      'email': email,
      'phone': phone,
    });
  }

  Future<void> deleteTestUser({required String id}) async {
    final callable = _functions.httpsCallable('superAdminDeleteChapaTestUser');
    await callable.call(<String, dynamic>{'id': id});
  }
}
