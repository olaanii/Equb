import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pointycastle/export.dart';

class TelebirrApiService {
  TelebirrApiService({
    required this.baseUrl,
    required this.apiKey,
    this.privateKeyPem,
    this.requestTimeout = const Duration(seconds: 12),
    this.authUrl,
    this.authClientId,
    this.authClientSecret,
    this.authHeaders = const {},
    this.authPayloadOverrides = const {},
    this.authGrantType,
    this.tokenFieldOverride,
    this.expiresInFieldOverride,
    this.expiresAtFieldOverride,
    this.tokenClockSkew = const Duration(seconds: 30),
    this.includeApiKeyInAuth = true,
  });

  final String baseUrl;
  final String apiKey;
  final String? privateKeyPem;
  final Duration requestTimeout;
  final String? authUrl;
  final String? authClientId;
  final String? authClientSecret;
  final Map<String, String> authHeaders;
  final Map<String, dynamic> authPayloadOverrides;
  final String? authGrantType;
  final String? tokenFieldOverride;
  final String? expiresInFieldOverride;
  final String? expiresAtFieldOverride;
  final Duration tokenClockSkew;
  final bool includeApiKeyInAuth;

  String? _cachedToken;
  DateTime? _tokenExpiry;

  Future<String> _getAccessToken() async {
    if (_cachedToken != null && _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!.subtract(tokenClockSkew))) {
      return _cachedToken!;
    }

    final authUri = Uri.parse(authUrl ?? '$baseUrl/oauth/token');
    final payload = <String, dynamic>{
      'grant_type': authGrantType ?? 'client_credentials',
      if (authClientId != null) 'client_id': authClientId,
      if (authClientSecret != null) 'client_secret': authClientSecret,
      if (includeApiKeyInAuth) 'api_key': apiKey,
      ...authPayloadOverrides,
    };

    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      ...authHeaders,
    };

    final response = await http.post(
      authUri,
      headers: headers,
      body: payload,
      encoding: Encoding.getByName('utf-8'),
    ).timeout(requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Telebirr auth failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tokenField = tokenFieldOverride ?? 'access_token';
    final token = data[tokenField] as String?;

    if (token == null) {
      throw Exception('Telebirr auth response missing token field "$tokenField"');
    }

    _cachedToken = token;

    // Calculate expiry
    final expiresInField = expiresInFieldOverride ?? 'expires_in';
    final expiresAtField = expiresAtFieldOverride ?? 'expires_at';

    if (data.containsKey(expiresAtField)) {
      _tokenExpiry = DateTime.parse(data[expiresAtField] as String);
    } else if (data.containsKey(expiresInField)) {
      final expiresIn = data[expiresInField] as int;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
    } else {
      // Default to 1 hour if no expiry info
      _tokenExpiry = DateTime.now().add(const Duration(hours: 1));
    }

    return token;
  }

  Future<Map<String, dynamic>> createOrder({
    required String fromUserId,
    required double amount,
    required String merchantOrderId,
    required String callbackUrl,
  }) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('$baseUrl/orders');

    final payload = {
      'merchantOrderId': merchantOrderId,
      'amount': amount.toStringAsFixed(2),
      'currency': 'ETB',
      'description': 'Equb Group Contribution',
      'callbackUrl': callbackUrl,
      'payerId': fromUserId,
      'timestamp': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
    };

    final signature = _generateSignature(payload);

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'X-API-Key': apiKey,
        'X-Signature': signature,
      },
      body: jsonEncode(payload),
    ).timeout(requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Telebirr createOrder failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data;
  }

  Future<Map<String, dynamic>> queryOrder(String merchantOrderId) async {
    final token = await _getAccessToken();
    final uri = Uri.parse('$baseUrl/orders/$merchantOrderId');

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'X-API-Key': apiKey,
      },
    ).timeout(requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Telebirr queryOrder failed: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data;
  }

  Uri buildCheckoutUri(String prepayId) {
    return Uri.parse('$baseUrl/checkout/$prepayId');
  }

  String _generateSignature(Map<String, dynamic> payload) {
    if (privateKeyPem == null) {
      throw Exception('Private key required for signature generation');
    }

    final sortedKeys = payload.keys.toList()..sort();
    final signatureData = sortedKeys.map((key) => '$key=${payload[key]}').join('&');

    final privateKey = _loadPrivateKey(privateKeyPem!);
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201'); // SHA256withRSA
    signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final signature = signer.generateSignature(Uint8List.fromList(signatureData.codeUnits));

    return base64Encode(signature.bytes);
  }

  RSAPrivateKey _loadPrivateKey(String pem) {
    // NOTE: The previous implementation referenced ASN.1 helpers that are not
    // available in our current dependencies. Until we introduce a dedicated
    // PEM/ASN.1 parser, fail fast with a clear error.
    throw UnsupportedError(
      'Telebirr RSA private-key parsing is not implemented. Provide a compatible signing implementation before using Telebirr payments.',
    );
  }
}