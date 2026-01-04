import 'package:flutter/foundation.dart';

enum GatewayEnvironment { mock, sandbox, production }

@immutable
class GatewayFeatureFlag {
  const GatewayFeatureFlag({
    this.enabled = false,
    this.environment = GatewayEnvironment.mock,
  });

  final bool enabled;
  final GatewayEnvironment environment;

  GatewayFeatureFlag copyWith({
    bool? enabled,
    GatewayEnvironment? environment,
  }) {
    return GatewayFeatureFlag(
      enabled: enabled ?? this.enabled,
      environment: environment ?? this.environment,
    );
  }

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'environment': environment.name,
  };

  factory GatewayFeatureFlag.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const GatewayFeatureFlag();
    final envString = map['environment'] as String?;
    final env = GatewayEnvironment.values.firstWhere(
      (value) => value.name == envString,
      orElse: () => GatewayEnvironment.mock,
    );
    return GatewayFeatureFlag(
      enabled: map['enabled'] as bool? ?? false,
      environment: env,
    );
  }
}
