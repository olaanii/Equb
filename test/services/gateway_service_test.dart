import 'package:equb/services/gateway_service.dart';
import 'package:equb/services/secure_storage_service.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecretStore implements GatewaySecretStore {
  _FakeSecretStore(this.bundle);

  final GatewaySecretBundle bundle;

  @override
  Future<GatewaySecretBundle> readSecrets() async => bundle;
}

void main() {
  group('GatewayService', () {
    test('injects secure secrets into configs', () async {
      final service = GatewayService(
        secretStore: _FakeSecretStore(
          const GatewaySecretBundle(
            telebirrApiKey: 'api-key',
            telebirrPrivateKey: 'private-key',
            telebirrClientId: 'client-id',
            telebirrClientSecret: 'client-secret',
            cbeClientId: 'cbe-id',
            cbeClientSecret: 'cbe-secret',
          ),
        ),
      );

      final gateways = await service.listGateways();
      final telebirr = gateways.firstWhere((g) => g.id == 'telebirr');
      final cbe = gateways.firstWhere((g) => g.id == 'cbe_birr');

      expect(telebirr.meta['apiKey'], 'api-key');
      expect(telebirr.meta['authClientSecret'], 'client-secret');
      expect(cbe.meta['clientSecret'], 'cbe-secret');
    });

    test('throws when secure credentials are missing', () async {
      final logService = SystemLogService();
      final service = GatewayService(
        secretStore: _FakeSecretStore(const GatewaySecretBundle()),
        logService: logService,
      );

      await expectLater(
        service.getAdapter('telebirr'),
        throwsA(isA<GatewayCredentialException>()),
      );
      expect(logService.list(level: LogLevel.error), isNotEmpty);
    });
  });
}
