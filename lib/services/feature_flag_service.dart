import 'package:equb/domain/feature_flags.dart';
import 'package:firebase_database/firebase_database.dart';

class FeatureFlagService {
  FeatureFlagService({FirebaseDatabase? database})
    : _db = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference get _ref => _db.ref('config/feature_flags');

  Future<FeatureFlags> load() async {
    try {
      final snapshot = await _ref.get();
      final raw = snapshot.value;
      if (raw == null || raw is! Map) return const FeatureFlags();
      return FeatureFlags.fromMap(Map<String, dynamic>.from(raw));
    } catch (_) {
      return const FeatureFlags();
    }
  }

  Future<void> save(FeatureFlags flags) async {
    await _ref.set(flags.toMap());
  }
}
