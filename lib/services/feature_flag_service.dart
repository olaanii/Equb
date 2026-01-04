import 'dart:convert';

import 'package:equb/domain/feature_flags.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FeatureFlagService {
  static const _kKey = 'feature_flags_v1';
  final FlutterSecureStorage _storage;
  FeatureFlagService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<FeatureFlags> load() async {
    try {
      final raw = await _storage.read(key: _kKey);
      if (raw == null) return const FeatureFlags();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return FeatureFlags.fromMap(map);
    } catch (_) {
      return const FeatureFlags();
    }
  }

  Future<void> save(FeatureFlags flags) async {
    final raw = jsonEncode(flags.toMap());
    await _storage.write(key: _kKey, value: raw);
  }
}
