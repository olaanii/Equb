import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _storage.delete(key: key);
}

class GatewaySecretBundle {
  const GatewaySecretBundle({
    this.telebirrApiKey,
    this.telebirrPrivateKey,
    this.telebirrClientId,
    this.telebirrClientSecret,
    this.cbeClientId,
    this.cbeClientSecret,
    this.bankSettlementWebhook,
    this.chapaPublicKey,
    this.chapaSecretKey,
    this.chapaCallbackUrl,
    this.chapaReturnUrl,
  });

  final String? telebirrApiKey;
  final String? telebirrPrivateKey;
  final String? telebirrClientId;
  final String? telebirrClientSecret;
  final String? cbeClientId;
  final String? cbeClientSecret;
  final String? bankSettlementWebhook;
  final String? chapaPublicKey;
  final String? chapaSecretKey;
  final String? chapaCallbackUrl;
  final String? chapaReturnUrl;
}

abstract class GatewaySecretStore {
  Future<GatewaySecretBundle> readSecrets();
}

class SecureGatewaySecretStore implements GatewaySecretStore {
  SecureGatewaySecretStore(this._storage);

  final SecureStorageService _storage;

  @override
  Future<GatewaySecretBundle> readSecrets() async {
    final values = await Future.wait([
      _storage.read('gateway.telebirr.apiKey'),
      _storage.read('gateway.telebirr.privateKey'),
      _storage.read('gateway.telebirr.clientId'),
      _storage.read('gateway.telebirr.clientSecret'),
      _storage.read('gateway.cbe.clientId'),
      _storage.read('gateway.cbe.clientSecret'),
      _storage.read('gateway.bank.webhook'),
      _storage.read('gateway.chapa.publicKey'),
      _storage.read('gateway.chapa.secretKey'),
      _storage.read('gateway.chapa.callbackUrl'),
      _storage.read('gateway.chapa.returnUrl'),
    ]);

    return GatewaySecretBundle(
      telebirrApiKey: values[0],
      telebirrPrivateKey: values[1],
      telebirrClientId: values[2],
      telebirrClientSecret: values[3],
      cbeClientId: values[4],
      cbeClientSecret: values[5],
      bankSettlementWebhook: values[6],
      chapaPublicKey: values[7],
      chapaSecretKey: values[8],
      chapaCallbackUrl: values[9],
      chapaReturnUrl: values[10],
    );
  }
}
