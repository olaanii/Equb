import 'dart:convert';

import 'package:equb/domain/feature_flags.dart';
import 'package:equb/domain/gateway_feature_flag.dart';
import 'package:equb/services/payment_service.dart';
import 'package:equb/services/adapters/telebirr_impl.dart';
import 'package:equb/services/adapters/cbe_impl.dart';
import 'package:equb/services/adapters/fenanpay_impl.dart';
import 'package:equb/services/secure_storage_service.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:firebase_database/firebase_database.dart';

enum GatewayOperation { deposit, withdrawal }

class PaymentGatewayConfig {
  final String id;
  final String name;
  final bool enabled;
  final Map<String, dynamic> meta;
  final String environment;

  PaymentGatewayConfig({
    required this.id,
    required this.name,
    this.enabled = false,
    this.meta = const {},
    this.environment = 'mock',
  });

  PaymentGatewayConfig copyWith({
    bool? enabled,
    Map<String, dynamic>? meta,
    String? environment,
  }) {
    return PaymentGatewayConfig(
      id: id,
      name: name,
      enabled: enabled ?? this.enabled,
      meta: meta ?? this.meta,
      environment: environment ?? this.environment,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'meta': jsonEncode(meta),
    'environment': environment,
  };

  static PaymentGatewayConfig fromJson(Map<String, dynamic> m) =>
      PaymentGatewayConfig(
        id: m['id'] as String,
        name: m['name'] as String,
        enabled: m['enabled'] as bool? ?? false,
        meta:
            m['meta'] != null
                ? (jsonDecode(m['meta'] as String) as Map<String, dynamic>)
                : {},
        environment: m['environment'] as String? ?? 'mock',
      );
}

PaymentGatewayConfig _fromRtdb(String id, Map<String, dynamic> m) {
  final rawMeta = m['meta'];
  Map<String, dynamic> meta;
  if (rawMeta is Map) {
    meta = Map<String, dynamic>.from(rawMeta);
  } else if (rawMeta is String && rawMeta.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(rawMeta);
      meta =
          decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
    } catch (_) {
      meta = <String, dynamic>{};
    }
  } else {
    meta = <String, dynamic>{};
  }

  return PaymentGatewayConfig(
    id: id,
    name:
        (m['name'] as String?)?.trim().isNotEmpty == true
            ? (m['name'] as String)
            : id,
    enabled: (m['enabled'] as bool?) ?? false,
    meta: meta,
    environment: (m['environment'] as String?) ?? 'mock',
  );
}

Map<String, dynamic> _toRtdb(PaymentGatewayConfig cfg) {
  return <String, dynamic>{
    'id': cfg.id,
    'name': cfg.name,
    'enabled': cfg.enabled,
    'environment': cfg.environment,
    'meta': cfg.meta,
  };
}

class GatewayService {
  GatewayService({
    FirebaseDatabase? database,
    GatewaySecretStore? secretStore,
    SystemLogService? logService,
  }) : _secretStore = secretStore,
       _logService = logService,
       _db = database ?? FirebaseDatabase.instance;

  final GatewaySecretStore? _secretStore;
  final SystemLogService? _logService;
  final FirebaseDatabase _db;

  DatabaseReference get _gatewaysRef => _db.ref('config/gateways');

  final List<PaymentGatewayConfig> _configs = [
    PaymentGatewayConfig(
      id: 'fenanpay',
      name: 'FenanPay',
      enabled: true,
      environment: 'sandbox',
      meta: const {
        'environment': 'sandbox',
        'baseUrl': 'https://api.fenanpay.com/api/v1/payment/sandbox/intent',
        'returnUrl': 'https://fenanpay.com',
        'expireIn': 3600,
        'commissionPaidByCustomer': false,
        // If empty array is passed, all enabled methods are selected.
        'methods': <String>[],
        'notes':
            'Hosted checkout test integration (Payment Intent -> checkout URL).',
      },
    ),
    PaymentGatewayConfig(
      id: 'telebirr',
      name: 'Telebirr',
      enabled: false,
      environment: 'sandbox',
      meta: const {
        'environment': 'sandbox',
        'callbackUrl': 'https://sandbox.telebirr/callback',
        'notes': 'Uses OAuth token refresh every 30m',
      },
    ),
    PaymentGatewayConfig(
      id: 'cbe_birr',
      name: 'CBE Birr',
      enabled: false,
      environment: 'mock',
      meta: const {
        'environment': 'mock',
        'notes': 'Needs client credentials before production rollout',
      },
    ),
    PaymentGatewayConfig(
      id: 'bank_transfer',
      name: 'Bank Transfer',
      enabled: true,
      environment: 'manual',
      meta: const {
        'settlement': '1-2 business days',
        'notes': 'Manual reconciliation',
      },
    ),
  ];

  Future<List<PaymentGatewayConfig>> listGateways({FeatureFlags? flags}) async {
    final remote = await _loadRemoteConfigs();
    final merged = _mergeConfigs(_configs, remote);
    final secrets = await _secretStore?.readSecrets();
    if (flags == null || flags.gatewayFlags.isEmpty) {
      return List.unmodifiable(_injectSecrets(merged, secrets));
    }
    return _injectSecrets(merged, secrets)
        .map((config) {
          final override = flags.gatewayFlags[config.id];
          if (override == null) return config;
          return _applyFlag(config, override);
        })
        .toList(growable: false);
  }

  Future<List<PaymentGatewayConfig>> getEnabledGateways({
    FeatureFlags? flags,
  }) async {
    final gateways = await listGateways(flags: flags);
    return gateways.where((g) => g.enabled).toList(growable: false);
  }

  Future<void> upsertGateway(PaymentGatewayConfig cfg) async {
    final index = _configs.indexWhere((existing) => existing.id == cfg.id);
    if (index == -1) {
      _configs.add(cfg);
    } else {
      _configs[index] = cfg;
    }

    try {
      await _gatewaysRef.child(cfg.id).set(_toRtdb(cfg));
    } catch (e) {
      _logService?.log(
        LogLevel.error,
        'GatewayService.upsertGateway',
        'Failed to persist gateway config',
        context: {'gatewayId': cfg.id, 'error': e.toString()},
      );
      rethrow;
    }
  }

  Future<List<PaymentGatewayConfig>> _loadRemoteConfigs() async {
    try {
      final snapshot = await _gatewaysRef.get();
      final raw = snapshot.value;
      if (raw == null || raw is! Map) return const <PaymentGatewayConfig>[];

      final out = <PaymentGatewayConfig>[];
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final map = Map<String, dynamic>.from(value);
        final id =
            (map['id'] as String?)?.trim().isNotEmpty == true
                ? (map['id'] as String)
                : entry.key.toString();
        out.add(_fromRtdb(id, map));
      }
      return out;
    } catch (_) {
      return const <PaymentGatewayConfig>[];
    }
  }

  List<PaymentGatewayConfig> _mergeConfigs(
    List<PaymentGatewayConfig> defaults,
    List<PaymentGatewayConfig> remote,
  ) {
    if (remote.isEmpty) return defaults;
    final byId = <String, PaymentGatewayConfig>{
      for (final cfg in defaults) cfg.id: cfg,
    };
    for (final r in remote) {
      final existing = byId[r.id];
      if (existing == null) {
        byId[r.id] = r;
        continue;
      }
      byId[r.id] = PaymentGatewayConfig(
        id: existing.id,
        name: r.name.isNotEmpty ? r.name : existing.name,
        enabled: r.enabled,
        environment: r.environment,
        meta: r.meta.isNotEmpty ? r.meta : existing.meta,
      );
    }
    return byId.values.toList(growable: false);
  }

  // Used to pick the right credentials for gateways that distinguish
  // between inbound (deposit) and outbound (withdrawal/payout) operations.
  // Defaults to deposit for existing call sites.
  static const GatewayOperation _defaultOperation = GatewayOperation.deposit;

  /// Returns a PaymentService adapter for the given gateway id if configured.
  Future<PaymentService?> getAdapter(
    String gatewayId, {
    FeatureFlags? flags,
    GatewayOperation operation = _defaultOperation,
  }) async {
    final list = await listGateways(flags: flags);
    final g = list.firstWhere(
      (x) => x.id == gatewayId,
      orElse: () => PaymentGatewayConfig(id: '', name: '', enabled: false),
    );
    if (!g.enabled) return null;
    final meta = g.meta;
    if (gatewayId == 'fenanpay') {
      final base = meta['baseUrl'] as String?;
      final apiKey = _resolveFenanPayApiKey(meta, operation: operation);
      final returnUrl = meta['returnUrl'] as String?;
      final callbackUrl = meta['callbackUrl'] as String?;
      final expireIn = meta['expireIn'] as int?;
      final commissionPaidByCustomer =
          meta['commissionPaidByCustomer'] as bool?;
      final methodsRaw = meta['methods'];
      final methods =
          (methodsRaw is List)
              ? methodsRaw
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList()
              : const <String>[];

      return FenanPayImpl(
        apiKey: apiKey,
        intentEndpoint: base,
        returnUrl: returnUrl,
        callbackUrl: callbackUrl,
        expireInSeconds: expireIn ?? 3600,
        commissionPaidByCustomer: commissionPaidByCustomer ?? false,
        methods: methods,
      );
    }
    if (gatewayId == 'telebirr') {
      final base = meta['baseUrl'] as String? ?? 'https://api.telebirr.example';
      final key = _requireCredential(meta, 'apiKey', gatewayId);
      final privateKey = _requireCredential(meta, 'privateKey', gatewayId);
      final timeoutMs = meta['timeoutMs'] as int?;
      final callbackUrl = meta['callbackUrl'] as String?;
      final authUrl = meta['authUrl'] as String?;
      final authClientId = _requireCredential(meta, 'authClientId', gatewayId);
      final authClientSecret = _requireCredential(
        meta,
        'authClientSecret',
        gatewayId,
      );
      final authGrantType = meta['authGrantType'] as String?;
      final tokenFieldOverride = meta['authTokenField'] as String?;
      final expiresInFieldOverride = meta['authExpiresInField'] as String?;
      final expiresAtFieldOverride = meta['authExpiresAtField'] as String?;
      final tokenClockSkewSeconds = meta['authClockSkewSeconds'] as int?;
      final includeApiKeyInAuth = meta['authIncludeApiKeyHeader'] as bool?;
      final authHeaders = _stringMap(meta['authHeaders']);
      final authPayload = _dynamicMap(meta['authPayload']);
      return TelebirrImpl(
        baseUrl: base,
        apiKey: key,
        privateKeyPem: privateKey,
        requestTimeout:
            timeoutMs != null ? Duration(milliseconds: timeoutMs) : null,
        callbackUrl: callbackUrl,
        authUrl: authUrl,
        authClientId: authClientId,
        authClientSecret: authClientSecret,
        authHeaders: authHeaders,
        authPayloadOverrides: authPayload,
        authGrantType: authGrantType,
        tokenFieldOverride: tokenFieldOverride,
        expiresInFieldOverride: expiresInFieldOverride,
        expiresAtFieldOverride: expiresAtFieldOverride,
        tokenClockSkew:
            tokenClockSkewSeconds != null
                ? Duration(seconds: tokenClockSkewSeconds)
                : null,
        includeApiKeyInAuth: includeApiKeyInAuth ?? true,
      );
    }
    if (gatewayId == 'cbe_birr') {
      final base = meta['baseUrl'] as String? ?? 'https://api.cbe.example';
      final clientId = _requireCredential(meta, 'clientId', gatewayId);
      final clientSecret = _requireCredential(meta, 'clientSecret', gatewayId);
      return CbeImpl(
        baseUrl: base,
        clientId: clientId,
        clientSecret: clientSecret,
      );
    }
    return null;
  }

  String _requireCredential(
    Map<String, dynamic> meta,
    String field,
    String gatewayId,
  ) {
    final value = (meta[field] as String?)?.trim() ?? '';
    if (value.isEmpty) {
      final message =
          'Missing $field for $gatewayId gateway. Add the secret via SecureStorage.';
      _logService?.log(
        LogLevel.error,
        'GatewayService.$gatewayId',
        message,
        context: {'gatewayId': gatewayId, 'field': field},
      );
      throw GatewayCredentialException(
        message: message,
        gatewayId: gatewayId,
        field: field,
      );
    }
    return value;
  }

  String _resolveFenanPayApiKey(
    Map<String, dynamic> meta, {
    required GatewayOperation operation,
  }) {
    // Allow distinct keys for deposit vs withdrawal while keeping backwards
    // compatibility with a single `apiKey` value.
    final primaryField =
        (operation == GatewayOperation.withdrawal)
            ? 'withdrawalApiKey'
            : 'depositApiKey';

    final primary = (meta[primaryField] as String?)?.trim() ?? '';
    if (primary.isNotEmpty) return primary;

    // Back-compat / default.
    return _requireCredential(meta, 'apiKey', 'fenanpay');
  }
}

class GatewayCredentialException implements Exception {
  GatewayCredentialException({
    required this.message,
    required this.gatewayId,
    required this.field,
  });

  final String message;
  final String gatewayId;
  final String field;

  @override
  String toString() => message;
}

Map<String, String>? _stringMap(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, dynamic v) => MapEntry(key.toString(), v?.toString() ?? ''),
    );
  }
  return null;
}

PaymentGatewayConfig _applyFlag(
  PaymentGatewayConfig base,
  GatewayFeatureFlag flag,
) {
  final mergedMeta = Map<String, dynamic>.from(base.meta)
    ..['environment'] = flag.environment.name;
  return base.copyWith(
    enabled: flag.enabled,
    environment: flag.environment.name,
    meta: mergedMeta,
  );
}

Map<String, dynamic>? _dynamicMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

List<PaymentGatewayConfig> _injectSecrets(
  List<PaymentGatewayConfig> configs,
  GatewaySecretBundle? secrets,
) {
  if (secrets == null) {
    return configs;
  }
  return configs
      .map((config) {
        if (config.id == 'fenanpay') {
          final mergedMeta = Map<String, dynamic>.from(config.meta);
          // Prefer new split-key configuration.
          if (secrets.fenanPayDepositKey != null &&
              secrets.fenanPayDepositKey!.trim().isNotEmpty) {
            mergedMeta['depositApiKey'] = secrets.fenanPayDepositKey;
            // Keep existing callers working by also setting `apiKey`.
            mergedMeta['apiKey'] = secrets.fenanPayDepositKey;
          }
          if (secrets.fenanPayWithdrawalKey != null &&
              secrets.fenanPayWithdrawalKey!.trim().isNotEmpty) {
            mergedMeta['withdrawalApiKey'] = secrets.fenanPayWithdrawalKey;
          }
          // Backwards compatible single key.
          if (secrets.fenanPayApiKey != null &&
              secrets.fenanPayApiKey!.trim().isNotEmpty) {
            mergedMeta['apiKey'] = secrets.fenanPayApiKey;
          }
          return config.copyWith(meta: mergedMeta);
        }
        if (config.id == 'telebirr') {
          final mergedMeta = Map<String, dynamic>.from(config.meta);
          if (secrets.telebirrApiKey != null) {
            mergedMeta['apiKey'] = secrets.telebirrApiKey;
          }
          if (secrets.telebirrPrivateKey != null) {
            mergedMeta['privateKey'] = secrets.telebirrPrivateKey;
          }
          if (secrets.telebirrClientId != null) {
            mergedMeta['authClientId'] = secrets.telebirrClientId;
          }
          if (secrets.telebirrClientSecret != null) {
            mergedMeta['authClientSecret'] = secrets.telebirrClientSecret;
          }
          return config.copyWith(meta: mergedMeta);
        }
        if (config.id == 'cbe_birr') {
          final mergedMeta = Map<String, dynamic>.from(config.meta);
          if (secrets.cbeClientId != null) {
            mergedMeta['clientId'] = secrets.cbeClientId;
          }
          if (secrets.cbeClientSecret != null) {
            mergedMeta['clientSecret'] = secrets.cbeClientSecret;
          }
          return config.copyWith(meta: mergedMeta);
        }
        if (config.id == 'bank_transfer' &&
            secrets.bankSettlementWebhook != null) {
          final mergedMeta = Map<String, dynamic>.from(config.meta)
            ..['webhookUrl'] = secrets.bankSettlementWebhook;
          return config.copyWith(meta: mergedMeta);
        }
        return config;
      })
      .toList(growable: false);
}
