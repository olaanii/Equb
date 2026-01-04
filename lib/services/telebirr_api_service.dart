import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';

/// Error wrapper used when Telebirr API responses are not successful.
class TelebirrApiException implements Exception {
  TelebirrApiException(this.message, {this.statusCode, this.responseBody});

  final String message;
  final int? statusCode;
  final String? responseBody;

  @override
  String toString() {
    final code = statusCode != null ? ' (statusCode: $statusCode)' : '';
    return 'TelebirrApiException: $message$code';
  }
}

class TelebirrApiService {
  TelebirrApiService({
    required this.baseUrl,
    required this.apiKey,
    String? privateKeyPem,
    http.Client? httpClient,
    Duration requestTimeout = const Duration(seconds: 12),
    String? authUrl,
    String? authClientId,
    String? authClientSecret,
    Map<String, String>? authHeaders,
    Map<String, dynamic>? authPayloadOverrides,
    String? authGrantType,
    String? tokenFieldOverride,
    String? expiresInFieldOverride,
    String? expiresAtFieldOverride,
    Duration tokenClockSkew = const Duration(seconds: 30),
    bool includeApiKeyInAuth = true,
  }) : _client = httpClient ?? http.Client(),
       _requestTimeout = requestTimeout,
       _signingKey = JsonWebKey.fromPem(
         (privateKeyPem == null || privateKeyPem.trim().isEmpty)
             ? placeholderPrivateKey
             : privateKeyPem,
       ),
       _authUrl =
           (authUrl != null && authUrl.trim().isNotEmpty)
               ? Uri.tryParse(authUrl.trim())
               : null,
       _authClientId = authClientId,
       _authClientSecret = authClientSecret,
       _authHeaders =
           authHeaders != null ? Map<String, String>.from(authHeaders) : null,
       _authPayloadOverrides =
           authPayloadOverrides != null
               ? Map<String, dynamic>.from(authPayloadOverrides)
               : null,
       _authGrantType = authGrantType,
       _tokenFieldOverride = tokenFieldOverride,
       _expiresInFieldOverride = expiresInFieldOverride,
       _expiresAtFieldOverride = expiresAtFieldOverride,
       _tokenClockSkew = tokenClockSkew,
       _includeApiKeyInAuth = includeApiKeyInAuth;

  static const String placeholderPrivateKey = '''
-----BEGIN PRIVATE KEY-----
YOUR_PRIVATE_KEY_HERE
-----END PRIVATE KEY-----
''';

  final String baseUrl;
  final String apiKey;

  final http.Client _client;
  final Duration _requestTimeout;
  final JsonWebKey _signingKey;
  final Uri? _authUrl;
  final String? _authClientId;
  final String? _authClientSecret;
  final Map<String, String>? _authHeaders;
  final Map<String, dynamic>? _authPayloadOverrides;
  final String? _authGrantType;
  final String? _tokenFieldOverride;
  final String? _expiresInFieldOverride;
  final String? _expiresAtFieldOverride;
  final Duration _tokenClockSkew;
  final bool _includeApiKeyInAuth;

  String? _fabricToken;
  DateTime? _fabricTokenExpiry;

  Future<String> applyFabricToken({bool force = false}) async {
    final tokenStillValid =
        _fabricToken != null &&
        _fabricTokenExpiry != null &&
        DateTime.now().isBefore(_fabricTokenExpiry!);
    if (!force && tokenStillValid) {
      return _fabricToken!;
    }

    final token = await _retrieveFabricToken();
    _storeFabricToken(token);
    return _fabricToken!;
  }

  Future<Map<String, dynamic>> createOrder({
    required String fromUserId,
    required double amount,
    required String merchantOrderId,
    String? callbackUrl,
  }) async {
    await applyFabricToken();

    final payload = <String, dynamic>{
      'merchantOrderId': merchantOrderId,
      'amount': amount,
      'currency': 'ETB',
      'payer': {'id': fromUserId},
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      if (callbackUrl != null) 'callbackUrl': callbackUrl,
    };

    payload.removeWhere((key, value) => value == null);

    final signature = _signPayload(payload);

    final response = await _post(
      path: 'orders',
      payload: payload,
      headers: {
        'X-API-KEY': apiKey,
        if (_fabricToken != null) 'X-FABRIC-TOKEN': _fabricToken!,
        'X-SIGNATURE': signature,
      },
      retryOnUnauthorized: true,
    );

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> queryOrder(String merchantOrderId) async {
    await applyFabricToken();

    final response = await _get(
      path: 'orders/$merchantOrderId',
      headers: {
        'X-API-KEY': apiKey,
        if (_fabricToken != null) 'X-FABRIC-TOKEN': _fabricToken!,
      },
      retryOnUnauthorized: true,
    );

    return _decodeResponse(response);
  }

  Uri buildCheckoutUri(String prepayId) => _buildUri('pay?prepayId=$prepayId');

  void clearFabricToken() {
    _fabricToken = null;
    _fabricTokenExpiry = null;
  }

  void dispose() => _client.close();

  Future<_FabricToken> _retrieveFabricToken() async {
    if (_authUrl == null) {
      return _simulateToken();
    }
    final payload = <String, dynamic>{
      if (_authClientId != null) 'clientId': _authClientId,
      if (_authClientSecret != null) 'clientSecret': _authClientSecret,
      if (_authGrantType != null) 'grantType': _authGrantType,
      ...?_authPayloadOverrides,
    };
    if (payload.isEmpty && _authGrantType == null) {
      payload['grantType'] = 'client_credentials';
    }
    payload.removeWhere((key, value) {
      if (value == null) return true;
      if (value is String) return value.trim().isEmpty;
      return false;
    });

    final headers = _filteredHeaders({
      if (_includeApiKeyInAuth && apiKey.isNotEmpty) 'X-API-KEY': apiKey,
      ...?_authHeaders,
    });

    final contentTypeKey = headers.keys.firstWhere(
      (key) => key.toLowerCase() == 'content-type',
      orElse: () => '',
    );

    final contentType = contentTypeKey.isEmpty ? null : headers[contentTypeKey];
    final isFormEncoded =
        contentType != null &&
        contentType.toLowerCase().contains('application/x-www-form-urlencoded');

    if (!isFormEncoded && contentType == null) {
      headers['Content-Type'] = 'application/json';
    }

    final body = isFormEncoded ? _encodeFormBody(payload) : jsonEncode(payload);

    try {
      final response = await _client
          .post(_authUrl, headers: headers, body: body)
          .timeout(_requestTimeout);
      final decoded = _decodeResponse(response);
      return _parseTokenPayload(decoded);
    } on TimeoutException catch (_) {
      throw TelebirrApiException('Telebirr auth request timed out');
    }
  }

  String _signPayload(Map<String, dynamic> payload) {
    final builder = JsonWebSignatureBuilder();
    builder.jsonContent = payload;
    builder.addRecipient(_signingKey, algorithm: 'RS256');
    final jws = builder.build();
    return jws.toCompactSerialization();
  }

  _FabricToken _simulateToken() {
    final now = DateTime.now();
    return _FabricToken(
      token: 'simulated_fabric_token_${now.millisecondsSinceEpoch}',
      expiry: now.add(const Duration(minutes: 5)),
    );
  }

  void _storeFabricToken(_FabricToken token) {
    final adjustedExpiry = token.expiry.subtract(_tokenClockSkew);
    _fabricToken = token.token;
    _fabricTokenExpiry =
        adjustedExpiry.isAfter(DateTime.now())
            ? adjustedExpiry
            : DateTime.now().add(const Duration(seconds: 30));
  }

  Future<http.Response> _post({
    required String path,
    required Map<String, dynamic> payload,
    required Map<String, String> headers,
    bool retryOnUnauthorized = false,
  }) async {
    final uri = _buildUri(path);
    final body = jsonEncode(payload);
    try {
      final response = await _client
          .post(uri, headers: _jsonHeaders(headers), body: body)
          .timeout(_requestTimeout);
      if (response.statusCode == 401 && retryOnUnauthorized) {
        await applyFabricToken(force: true);
        final retryHeaders = <String, String>{
          ...headers,
          if (_fabricToken != null) 'X-FABRIC-TOKEN': _fabricToken!,
        };
        return _client
            .post(uri, headers: _jsonHeaders(retryHeaders), body: body)
            .timeout(_requestTimeout);
      }
      return response;
    } on TimeoutException catch (_) {
      throw TelebirrApiException('Telebirr POST $path timed out');
    }
  }

  Future<http.Response> _get({
    required String path,
    required Map<String, String> headers,
    bool retryOnUnauthorized = false,
  }) async {
    final uri = _buildUri(path);
    try {
      final response = await _client
          .get(uri, headers: _filteredHeaders(headers))
          .timeout(_requestTimeout);
      if (response.statusCode == 401 && retryOnUnauthorized) {
        await applyFabricToken(force: true);
        final retryHeaders = <String, String>{
          ...headers,
          if (_fabricToken != null) 'X-FABRIC-TOKEN': _fabricToken!,
        };
        return _client
            .get(uri, headers: _filteredHeaders(retryHeaders))
            .timeout(_requestTimeout);
      }
      return response;
    } on TimeoutException catch (_) {
      throw TelebirrApiException('Telebirr GET $path timed out');
    }
  }

  Map<String, String> _jsonHeaders(Map<String, String> headers) {
    final map = <String, String>{'Content-Type': 'application/json'};
    map.addAll(_filteredHeaders(headers));
    return map;
  }

  Map<String, String> _filteredHeaders(Map<String, String> headers) {
    final map = <String, String>{};
    headers.forEach((key, value) {
      if (value.isNotEmpty) {
        map[key] = value;
      }
    });
    return map;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      if (response.body.isEmpty) {
        return const <String, dynamic>{};
      }
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return <String, dynamic>{'data': decoded};
      } on FormatException catch (_) {
        throw TelebirrApiException(
          'Telebirr returned invalid JSON',
          statusCode: status,
          responseBody: response.body,
        );
      }
    }
    throw TelebirrApiException(
      'Telebirr request failed with status $status',
      statusCode: status,
      responseBody: response.body,
    );
  }

  Uri _buildUri(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse(base).resolve(cleanPath);
  }

  _FabricToken _parseTokenPayload(Map<String, dynamic> payload) {
    final Map<String, dynamic> flattened = _flattenPayload(payload);
    final token = _extractString(flattened, [
      _tokenFieldOverride,
      'fabricToken',
      'token',
      'accessToken',
      'access_token',
    ]);

    if (token == null || token.isEmpty) {
      throw TelebirrApiException(
        'Telebirr auth response missing token',
        responseBody: jsonEncode(payload),
      );
    }

    final now = DateTime.now();
    final expiresInSeconds = _extractInt(flattened, [
      _expiresInFieldOverride,
      'expiresIn',
      'expires_in',
      'validFor',
    ]);

    DateTime expiry;
    if (expiresInSeconds != null && expiresInSeconds > 0) {
      expiry = now.add(Duration(seconds: expiresInSeconds));
    } else {
      final expiresAtValue = _extractDynamic(flattened, [
        _expiresAtFieldOverride,
        'expiresAt',
        'expires_at',
        'expiry',
      ]);
      expiry =
          _parseExpiry(expiresAtValue) ?? now.add(const Duration(minutes: 5));
    }

    return _FabricToken(token: token, expiry: expiry);
  }

  Map<String, dynamic> _flattenPayload(Map<String, dynamic> payload) {
    final flattened = Map<String, dynamic>.from(payload);
    for (final key in ['data', 'result', 'payload']) {
      final nested = payload[key];
      if (nested is Map) {
        flattened.addAll(Map<String, dynamic>.from(nested));
      }
    }
    return flattened;
  }

  String? _extractString(Map<String, dynamic> payload, List<String?> keys) {
    for (final key in keys) {
      if (key == null || key.isEmpty) continue;
      final value = payload[key];
      if (value is String && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  int? _extractInt(Map<String, dynamic> payload, List<String?> keys) {
    for (final key in keys) {
      if (key == null || key.isEmpty) continue;
      final value = payload[key];
      final result = _coerceToInt(value);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  dynamic _extractDynamic(Map<String, dynamic> payload, List<String?> keys) {
    for (final key in keys) {
      if (key == null || key.isEmpty) continue;
      if (payload.containsKey(key)) {
        return payload[key];
      }
    }
    return null;
  }

  int? _coerceToInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  DateTime? _parseExpiry(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is int) {
      // Assume epoch seconds if the number is reasonable, otherwise milliseconds.
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed;
      final asInt = int.tryParse(trimmed);
      if (asInt != null) {
        return _parseExpiry(asInt);
      }
    }
    return null;
  }

  String _encodeFormBody(Map<String, dynamic> payload) {
    if (payload.isEmpty) {
      return '';
    }
    return payload.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value.toString())}',
        )
        .join('&');
  }
}

class _FabricToken {
  const _FabricToken({required this.token, required this.expiry});

  final String token;
  final DateTime expiry;
}
