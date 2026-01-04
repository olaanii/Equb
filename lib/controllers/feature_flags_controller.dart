import 'package:equb/domain/feature_flags.dart';
import 'package:equb/domain/gateway_feature_flag.dart';
import 'package:equb/services/feature_flag_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final featureFlagServiceProvider = Provider<FeatureFlagService>(
  (ref) => FeatureFlagService(),
);

final featureFlagsProvider =
    AsyncNotifierProvider<FeatureFlagsController, FeatureFlags>(
      FeatureFlagsController.new,
    );

class FeatureFlagsController extends AsyncNotifier<FeatureFlags> {
  late final FeatureFlagService _service;

  @override
  Future<FeatureFlags> build() async {
    _service = ref.read(featureFlagServiceProvider);
    return _service.load();
  }

  Future<void> setGemini25ProEnabled(bool enabled) async {
    final current = state.value ?? const FeatureFlags();
    final next = current.copyWith(gemini25ProEnabled: enabled);
    state = AsyncData(next);
    await _service.save(next);
  }

  Future<void> setGatewayFlag(String gatewayId, GatewayFeatureFlag flag) async {
    final current = state.value ?? const FeatureFlags();
    final updatedFlags = Map<String, GatewayFeatureFlag>.from(
      current.gatewayFlags,
    )..[gatewayId] = flag;
    final next = current.copyWith(gatewayFlags: updatedFlags);
    state = AsyncData(next);
    await _service.save(next);
  }
}
