import 'package:equb/models/user_model.dart';
import 'package:equb/services/auth_service.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:equb/services/analytics_service.dart';
import 'package:equb/services/secure_storage_service.dart';
import 'package:equb/services/session_cache_service.dart';
import 'package:equb/services/firebase_auth_service.dart';
import 'package:equb/models/equb_model.dart';
import 'package:equb/services/equb_rotation_engine.dart';
import 'package:equb/services/memory_equb_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final systemLogServiceProvider = Provider<SystemLogService>(
  (ref) => SystemLogService(),
);

final sessionCacheServiceProvider = Provider<SessionCacheService>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final logService = ref.watch(systemLogServiceProvider);
  return SessionCacheService(secureStorage: storage, logService: logService);
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final service = AnalyticsService();
  ref.onDispose(service.dispose);
  return service;
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final sessionCache = ref.watch(sessionCacheServiceProvider);
  final logService = ref.watch(systemLogServiceProvider);

  return FirebaseAuth.instance.authStateChanges().asyncMap((user) async {
    if (user == null) {
      await sessionCache.clear();
      return null;
    }

    try {
      final cached = await sessionCache.loadUser();
      if (cached != null && cached.id == user.uid) {
        return cached;
      }

      final email = user.email ?? '';
      final fallbackName =
          email.isNotEmpty
              ? email.split('@').first
              : (user.displayName ?? 'User');

      final model = UserModel(
        id: user.uid,
        name: fallbackName,
        email: email,
        phone: user.phoneNumber,
      );

      await sessionCache.cacheUser(model);
      return model;
    } catch (err) {
      logService.log(
        LogLevel.warning,
        'auth.currentUserProvider',
        'Failed to build session user; using minimal model',
        context: {'error': '$err'},
      );

      final email = user.email ?? '';
      final fallbackName =
          email.isNotEmpty
              ? email.split('@').first
              : (user.displayName ?? 'User');

      return UserModel(
        id: user.uid,
        name: fallbackName,
        email: email,
        phone: user.phoneNumber,
      );
    }
  });
});

final authServiceProvider = Provider<AuthService>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  return FirebaseAuthService(analyticsService: analytics);
});

// ---------------------------------------------------------------------------
// Auth-only mode stubs
// ---------------------------------------------------------------------------
// The rest of the app (groups/wallet/notifications/admin) historically relied
// on Firestore-backed providers. While Firestore is removed, we keep these
// provider names around as stubs so the project can compile/analyze.

final paymentServiceProvider = Provider((ref) {
  throw UnimplementedError('Payment features are disabled in auth-only mode.');
});

final gatewayServiceProvider = Provider((ref) {
  throw UnimplementedError('Gateway features are disabled in auth-only mode.');
});

final equbStoreProvider = Provider<EqubStore>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'member-001';
  final members = <String>[uid, 'member-002', 'member-003', 'member-004'];

  final rotationEngine = EqubRotationEngine();
  final schedule = EqubScheduleConfig(
    cycleLengthDays: 7,
    strategy: PayoutStrategy.random,
    autoAssign: false,
    preferredOrder: members,
  );
  final state = rotationEngine.bootstrapState(
    config: schedule,
    members: members,
  );

  final seed = <EqubGroup>[
    EqubGroup(
      id: 'equb-001',
      name: 'Addis Friends Equb',
      contributionAmount: 500,
      scheduleConfig: schedule,
      members: members,
      rotationState: state,
    ),
  ];

  return EqubStore(seed: seed);
});

final equbRotationEngineProvider = Provider<EqubRotationEngine>((ref) {
  return EqubRotationEngine();
});

final equbRepositoryProvider = Provider<MemoryEqubRepository>((ref) {
  final store = ref.watch(equbStoreProvider);
  final engine = ref.watch(equbRotationEngineProvider);
  return MemoryEqubRepository(store: store, rotationEngine: engine);
});

final equbGroupsProvider = FutureProvider<List<EqubGroup>>((ref) async {
  final repo = ref.watch(equbRepositoryProvider);
  return repo.listGroups();
});

final equbGroupProvider = FutureProvider.family<EqubGroup?, String>((
  ref,
  String groupId,
) async {
  final repo = ref.watch(equbRepositoryProvider);
  return repo.findGroup(groupId);
});

final equbGroupMetricsProvider =
    FutureProvider.family<EqubGroupMetrics, String>((
      ref,
      String groupId,
    ) async {
      final repo = ref.watch(equbRepositoryProvider);
      return repo.fetchGroupMetrics(groupId);
    });

final equbRoundSummariesProvider =
    FutureProvider.family<List<EqubRoundSummary>, String>((
      ref,
      String groupId,
    ) async {
      final repo = ref.watch(equbRepositoryProvider);
      return repo.fetchRoundSummaries(groupId);
    });

final walletRepositoryProvider = Provider((ref) {
  throw UnimplementedError('Wallet features are disabled in auth-only mode.');
});

final userRepositoryProvider = Provider((ref) {
  throw UnimplementedError(
    'User profile features are disabled in auth-only mode.',
  );
});

final imageStorageServiceProvider = Provider((ref) {
  throw UnimplementedError('Image storage is disabled in auth-only mode.');
});

final notificationServiceProvider = Provider((ref) {
  throw UnimplementedError('Notifications are disabled in auth-only mode.');
});

final notificationReminderServiceProvider = Provider((ref) {
  throw UnimplementedError('Notifications are disabled in auth-only mode.');
});

final reminderSchedulerServiceProvider = Provider((ref) {
  throw UnimplementedError('Notifications are disabled in auth-only mode.');
});

final notificationRepositoryProvider = Provider((ref) {
  throw UnimplementedError('Notifications are disabled in auth-only mode.');
});

final notificationsProvider = StreamProvider((ref) {
  return const Stream.empty();
});
