import 'gateway_feature_flag.dart';

class FeatureFlags {
  final bool gemini25ProEnabled;
  final Map<String, GatewayFeatureFlag> gatewayFlags;

  const FeatureFlags({
    this.gemini25ProEnabled = false,
    this.gatewayFlags = const {},
  });

  GatewayFeatureFlag gatewayFlagFor(String gatewayId) {
    return gatewayFlags[gatewayId] ?? const GatewayFeatureFlag();
  }

  FeatureFlags copyWith({
    bool? gemini25ProEnabled,
    Map<String, GatewayFeatureFlag>? gatewayFlags,
  }) => FeatureFlags(
    gemini25ProEnabled: gemini25ProEnabled ?? this.gemini25ProEnabled,
    gatewayFlags: gatewayFlags ?? this.gatewayFlags,
  );

  Map<String, dynamic> toMap() => {
    'gemini25ProEnabled': gemini25ProEnabled,
    'gatewayFlags': gatewayFlags.map(
      (key, value) => MapEntry(key, value.toMap()),
    ),
  };

  factory FeatureFlags.fromMap(Map<String, dynamic> map) {
    final gatewayMap = map['gatewayFlags'] as Map<String, dynamic>?;
    return FeatureFlags(
      gemini25ProEnabled: (map['gemini25ProEnabled'] as bool?) ?? false,
      gatewayFlags:
          gatewayMap == null
              ? const {}
              : gatewayMap.map(
                (key, value) => MapEntry(
                  key,
                  GatewayFeatureFlag.fromMap(value as Map<String, dynamic>?),
                ),
              ),
    );
  }
}
