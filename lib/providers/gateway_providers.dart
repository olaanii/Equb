import 'package:equb/controllers/feature_flags_controller.dart';
import 'package:equb/domain/feature_flags.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/gateway_service.dart';
import 'providers.dart';

final gatewayConfigsProvider = FutureProvider<List<PaymentGatewayConfig>>((
  ref,
) async {
  final service = ref.watch(gatewayServiceProvider);
  final flagsAsync = ref.watch(featureFlagsProvider);
  final flags = flagsAsync.maybeWhen(
    data: (value) => value,
    orElse: () => const FeatureFlags(),
  );
  return service.listGateways(flags: flags);
});
