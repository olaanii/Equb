import 'dart:convert';

import 'package:equb/domain/feature_flags.dart';
import 'package:equb/domain/gateway_feature_flag.dart';
import 'package:equb/services/payment_service.dart';
import 'package:equb/services/adapters/telebirr_impl.dart';
import 'package:equb/services/adapters/cbe_impl.dart';
import 'package:equb/services/secure_storage_service.dart';
import 'package:equb/services/system_log_service.dart';

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

class GatewayService {
  GatewayService({
    GatewaySecretStore? secretStore,
    SystemLogService? logService,
  }) : _secretStore = secretStore,
       _logService = logService;

  final GatewaySecretStore? _secretStore;
  final SystemLogService? _logService;

  final List<PaymentGatewayConfig> _configs = [
    PaymentGatewayConfig(
      id: 'telebirr',
      name: 'Telebirr',
      enabled: true,
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
    final secrets = await _secretStore?.readSecrets();
    if (flags == null || flags.gatewayFlags.isEmpty) {
      return List.unmodifiable(_injectSecrets(_configs, secrets));
    }
    return _injectSecrets(_configs, secrets)
        .map((config) {
          final override = flags.gatewayFlags[config.id];
          if (override == null) return config;
          return _applyFlag(config, override);
        })
        .toList(growable: false);
  }

  Future<void> upsertGateway(PaymentGatewayConfig cfg) async {
    final index = _configs.indexWhere((existing) => existing.id == cfg.id);
    if (index == -1) {
      _configs.add(cfg);
    } else {
      _configs[index] = cfg;
    }
  }

  /// Returns a PaymentService adapter for the given gateway id if configured.
  Future<PaymentService?> getAdapter(
    String gatewayId, {
    FeatureFlags? flags,
  }) async {
    final list = await listGateways(flags: flags);
    final g = list.firstWhere(
      (x) => x.id == gatewayId,
      orElse: () => PaymentGatewayConfig(id: '', name: '', enabled: false),
    );
    if (!g.enabled) return null;
    final meta = g.meta;
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
