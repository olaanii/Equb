import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:equb/models/auto_topup.dart';
import 'package:equb/models/chat_message.dart';
import 'package:equb/models/equb_model.dart';
import 'package:equb/models/id_document.dart';
import 'package:equb/models/points_event.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/models/user_notification.dart';
import 'package:equb/services/analytics_service.dart';
import 'package:equb/services/auth_service.dart';
import 'package:equb/services/biometric_auth_service.dart';
import 'package:equb/services/device_management_service.dart';
import 'package:equb/services/device_token_registrar.dart';
import 'package:equb/services/equb_repository.dart';
import 'package:equb/services/equb_rotation_engine.dart';
import 'package:equb/services/firebase_auth_service.dart';
import 'package:equb/services/gateway_service.dart';
import 'package:equb/services/group_management_service.dart';
import 'package:equb/services/image_storage_service.dart';
import 'package:equb/services/memory_equb_repository.dart';
import 'package:equb/services/notification_reminder_service.dart';
import 'package:equb/services/notification_service.dart';
import 'package:equb/services/onboarding_service.dart';
import 'package:equb/services/payment_service.dart';
import 'package:equb/services/points_repository.dart';
import 'package:equb/services/push_notification_scheduler.dart';
import 'package:equb/services/rtdb_equb_repository.dart';
import 'package:equb/services/rtdb_notification_repository.dart';
import 'package:equb/services/rtdb_points_repository.dart';
import 'package:equb/services/rtdb_reminder_scheduler_service.dart';
import 'package:equb/services/rtdb_user_repository.dart';
import 'package:equb/services/rtdb_wallet_repository.dart';
import 'package:equb/services/secure_storage_service.dart';
import 'package:equb/services/session_security_service.dart';
import 'package:equb/services/session_cache_service.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:equb/services/chat_service.dart';
import 'package:equb/services/id_scan_service.dart';
import 'package:equb/services/id_document_repository.dart';
import 'package:equb/services/auto_topup_repository.dart';
import 'package:equb/services/auto_topup_service.dart';
import 'package:equb/services/payout_scheduler_service.dart';
import 'package:equb/services/group_analytics_service.dart';
import 'package:equb/services/email_service.dart';
import 'package:equb/services/advanced_admin_service.dart';
import 'package:equb/services/user_repository.dart';
import 'package:equb/services/wallet_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
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

final firebaseAuthUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final sessionCache = ref.watch(sessionCacheServiceProvider);
  final logService = ref.watch(systemLogServiceProvider);

  return FirebaseAuth.instance.authStateChanges().asyncExpand((firebaseUser) {
    if (firebaseUser == null) {
      return Stream.fromFuture(sessionCache.clear()).map((_) => null);
    }

    final uid = firebaseUser.uid;
    final userRef = FirebaseDatabase.instance.ref('users/$uid');
    final userRepo = RtdbUserRepository(
      database: FirebaseDatabase.instance,
      logService: logService,
    );

    Future<void> ensureUserRecord() async {
      try {
        final snapshot = await userRef.get();
        if (snapshot.exists && snapshot.value != null) {
          // Dev convenience: promote current developer account to admin so
          // dashboard admin-only flows (like create-group FAB) are accessible.
          if (kDebugMode && snapshot.value is Map) {
            final existing = Map<String, dynamic>.from(snapshot.value as Map);
            final role = existing['role']?.toString();
            if (role != 'superAdmin') {
              await userRef.update({'role': 'superAdmin'});
            }
          }
          return;
        }

        final email = firebaseUser.email ?? '';
        final fallbackName =
            email.isNotEmpty
                ? email.split('@').first
                : (firebaseUser.displayName ?? 'User');

        final seed = UserModel(
          id: uid,
          name: fallbackName,
          email: email,
          phone: firebaseUser.phoneNumber,
          role: kDebugMode ? UserRole.superAdmin : UserRole.user,
        );
        await userRef.set(seed.toJson());
      } catch (err) {
        logService.log(
          LogLevel.warning,
          'auth.currentUserProvider',
          'Failed to ensure RTDB user record; continuing with fallback model',
          context: {'userId': uid, 'error': '$err'},
        );
      }
    }

    Stream<UserModel?> streamWithFallback() async* {
      final cached = await sessionCache.loadUser();
      if (cached != null && cached.id == uid) {
        yield cached;
      }

      final email = firebaseUser.email ?? '';
      final fallbackName =
          email.isNotEmpty
              ? email.split('@').first
              : (firebaseUser.displayName ?? 'User');
      final fallback = UserModel(
        id: uid,
        name: fallbackName,
        email: email,
        phone: firebaseUser.phoneNumber,
      );

      if (cached == null || cached.id != uid) {
        yield fallback;
      }

      // Ensure a user record exists, but never block the UI on this.
      await ensureUserRecord();

      // RTDB streams can throw (e.g. permission-denied). Treat that as
      // an offline/permission state and keep the app usable with fallback data.
      final retryDelays = <Duration>[
        Duration.zero,
        const Duration(seconds: 2),
        const Duration(seconds: 5),
      ];

      for (final delay in retryDelays) {
        if (delay != Duration.zero) {
          await Future<void>.delayed(delay);
        }

        try {
          await for (final event in userRef.onValue) {
            final raw = event.snapshot.value;
            UserModel model;
            if (raw is Map) {
              model = UserModel.fromJson(
                {...Map<String, dynamic>.from(raw), 'id': uid},
              );
            } else {
              model = (await userRepo.getUser(uid)) ?? fallback;
            }

            await sessionCache.cacheUser(model);
            yield model;
          }

          // If the stream ends normally, stop retrying.
          return;
        } catch (err) {
          logService.log(
            LogLevel.warning,
            'auth.currentUserProvider',
            'RTDB user stream failed; continuing with cached/auth fallback',
            context: {'userId': uid, 'error': '$err'},
          );
        }
      }
    }

    return streamWithFallback();
  });
});

final authServiceProvider = Provider<AuthService>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  return FirebaseAuthService(analyticsService: analytics);
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return DummyPaymentService();
});

final gatewayServiceProvider = Provider<GatewayService>((ref) {
  final storage = ref.watch(secureStorageServiceProvider);
  final logService = ref.watch(systemLogServiceProvider);
  return GatewayService(
    secretStore: SecureGatewaySecretStore(storage),
    logService: logService,
  );
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

final Provider<EqubRotationEngine> equbRotationEngineProvider = Provider<EqubRotationEngine>((ref) {
  final engine = EqubRotationEngine();
  final payoutScheduler = ref.watch(payoutSchedulerServiceProvider);
  engine.setPayoutScheduler(payoutScheduler);
  return engine;
});

final equbRepositoryProvider = Provider<EqubRepository>((ref) {
  final logService = ref.watch(systemLogServiceProvider);

  if (Firebase.apps.isEmpty) {
    final store = ref.watch(equbStoreProvider);
    final engine = ref.watch(equbRotationEngineProvider);
    logService.log(
      LogLevel.warning,
      'providers.equbRepositoryProvider',
      'Using in-memory Equb store (Firebase not initialized).',
    );
    return MemoryEqubRepository(store: store, rotationEngine: engine);
  }

  return RtdbEqubRepository(
    database: FirebaseDatabase.instance,
    logService: logService,
  );
});

final equbGroupsProvider = StreamProvider<List<EqubGroup>>((ref) {
  final authUser = ref.watch(firebaseAuthUserProvider).asData?.value;

  if (Firebase.apps.isEmpty) {
    final repo = ref.watch(equbRepositoryProvider);
    return Stream.fromFuture(repo.listGroups());
  }

  if (authUser == null) {
    return Stream<List<EqubGroup>>.value(const <EqubGroup>[]);
  }

  final logService = ref.watch(systemLogServiceProvider);
  final groupsRef = FirebaseDatabase.instance.ref('groups');

  Stream<List<EqubGroup>> stream() async* {
    try {
      await for (final event in groupsRef.onValue) {
        final raw = event.snapshot.value;

        // Debug-only: auto-seed a single demo group for the signed-in user
        // when the database is empty. This helps validate RTDB wiring quickly.
        if (kDebugMode && (raw == null || raw is! Map)) {
          final uid = authUser.uid;
          if (uid.isNotEmpty) {
            final seededFlag = FirebaseDatabase.instance.ref(
              'users/$uid/debug/demoSeeded',
            );

            try {
              final already = await seededFlag.get();
              final isSeeded = already.value == true;
              if (!isSeeded) {
                final repo = ref.read(equbRepositoryProvider);
                final engine = ref.read(equbRotationEngineProvider);
                final members = <String>[uid];
                final schedule = EqubScheduleConfig(
                  cycleLengthDays: 7,
                  strategy: PayoutStrategy.random,
                  autoAssign: false,
                  preferredOrder: members,
                );
                final state = engine.bootstrapState(
                  config: schedule,
                  members: members,
                );

                final group = EqubGroup(
                  id: '',
                  name: 'Demo Equb',
                  contributionAmount: 100,
                  scheduleConfig: schedule,
                  members: members,
                  rotationState: state,
                );
                await repo.createGroup(group, actingUserId: uid);
                await seededFlag.set(true);
              }
            } catch (err) {
              logService.log(
                LogLevel.warning,
                'providers.equbGroupsProvider',
                'Demo seed failed (non-fatal)',
                context: {'error': '$err'},
              );
            }
          }
        }

        if (raw == null || raw is! Map) {
          yield <EqubGroup>[];
          continue;
        }

        final groups = <EqubGroup>[];
        for (final entry in raw.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is! Map) continue;

          try {
            final data = Map<String, dynamic>.from(value);
            data['id'] = data['id'] ?? key;
            groups.add(EqubGroup.fromJson(data));
          } catch (err) {
            logService.log(
              LogLevel.warning,
              'providers.equbGroupsProvider',
              'Skipping malformed group payload',
              context: {'groupId': key, 'error': '$err'},
            );
          }
        }

        groups.sort((a, b) => a.name.compareTo(b.name));
        yield groups;
      }
    } on FirebaseException catch (err) {
      logService.log(
        LogLevel.error,
        'providers.equbGroupsProvider',
        'RTDB groups stream failed',
        context: {'code': err.code, 'message': err.message},
      );

      throw StateError(
        'RTDB groups read failed (${err.code}). If this is permission-denied, deploy database.rules.json via Firebase CLI. ${err.message ?? ''}',
      );
    } catch (err) {
      logService.log(
        LogLevel.error,
        'providers.equbGroupsProvider',
        'RTDB groups stream failed',
        context: {'error': '$err'},
      );

      throw StateError(
        'RTDB groups read failed. Deploy database.rules.json and confirm you are signed in. $err',
      );
    }
  }

  return stream();
});

final equbGroupProvider = StreamProvider.family<EqubGroup?, String>(
  (ref, groupId) {
    final repo = ref.watch(equbRepositoryProvider);
    if (Firebase.apps.isEmpty) {
      return Stream.fromFuture(repo.findGroup(groupId));
    }

    final groupRef = FirebaseDatabase.instance.ref('groups/$groupId');
    return groupRef.onValue.asyncMap((_) async {
      return repo.findGroup(groupId, syncRotation: true);
    });
  },
);

final equbGroupMetricsProvider = FutureProvider.family<EqubGroupMetrics, String>(
  (ref, groupId) async {
    final repo = ref.watch(equbRepositoryProvider);
    return repo.fetchGroupMetrics(groupId);
  },
);

final equbRoundSummariesProvider =
    FutureProvider.family<List<EqubRoundSummary>, String>((
      ref,
      groupId,
    ) async {
      final repo = ref.watch(equbRepositoryProvider);
      return repo.fetchRoundSummaries(groupId);
    });

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final logService = ref.watch(systemLogServiceProvider);
  if (Firebase.apps.isEmpty) {
    throw UnimplementedError('Firebase not initialized; wallet is unavailable.');
  }

  return RtdbWalletRepository(
    database: FirebaseDatabase.instance,
    logService: logService,
  );
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final logService = ref.watch(systemLogServiceProvider);
  if (Firebase.apps.isEmpty) {
    throw UnimplementedError(
      'Firebase not initialized; user profile is unavailable.',
    );
  }

  return RtdbUserRepository(
    database: FirebaseDatabase.instance,
    logService: logService,
  );
});

final imageStorageServiceProvider = Provider<ImageStorageService>((ref) {
  final logService = ref.watch(systemLogServiceProvider);
  if (Firebase.apps.isEmpty) {
    throw UnimplementedError('Firebase not initialized; storage is unavailable.');
  }
  return ImageStorageService(logService: logService);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final deviceTokenRegistrarProvider = Provider<DeviceTokenRegistrar>((ref) {
  if (Firebase.apps.isEmpty) {
    throw UnimplementedError(
      'Firebase not initialized; device token registration is unavailable.',
    );
  }
  return DeviceTokenRegistrar(
    database: FirebaseDatabase.instance,
    notificationService: ref.watch(notificationServiceProvider),
  );
});

final notificationReminderServiceProvider = Provider<NotificationReminderService>(
  (ref) {
    final service = NotificationReminderService();
    ref.onDispose(service.dispose);
    return service;
  },
);

final reminderSchedulerServiceProvider = Provider<RtdbReminderSchedulerService>(
  (ref) {
    final logService = ref.watch(systemLogServiceProvider);
    if (Firebase.apps.isEmpty) {
      throw UnimplementedError(
        'Firebase not initialized; reminders are unavailable.',
      );
    }
    final service = RtdbReminderSchedulerService(
      database: FirebaseDatabase.instance,
      logService: logService,
    );
    ref.onDispose(() {
      unawaited(service.dispose());
    });
    return service;
  },
);

final notificationRepositoryProvider = Provider<RtdbNotificationRepository>((ref) {
  if (Firebase.apps.isEmpty) {
    throw UnimplementedError(
      'Firebase not initialized; notifications are unavailable.',
    );
  }
  return RtdbNotificationRepository(database: FirebaseDatabase.instance);
});

final notificationsProvider = StreamProvider<List<UserNotification>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getNotifications(user.id);
});

final pointsRepositoryProvider = Provider<PointsRepository>((ref) {
  if (Firebase.apps.isEmpty) {
    throw UnimplementedError('Firebase not initialized; points are unavailable.');
  }
  return RtdbPointsRepository(FirebaseDatabase.instance);
});

final pointsLedgerProvider = StreamProvider<List<PointsEvent>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(pointsRepositoryProvider);
  return repo.watchPointsLedger(user.id);
});

final chatServiceProvider = Provider<ChatService>((ref) {
  final logService = ref.watch(systemLogServiceProvider);
  if (Firebase.apps.isEmpty) {
    throw UnimplementedError('Firebase not initialized; chat is unavailable.');
  }

  final service = ChatService(
    database: FirebaseDatabase.instance,
    logService: logService,
  );
  ref.onDispose(service.dispose);
  return service;
});

final groupChatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, groupId) async* {
  final chatService = ref.watch(chatServiceProvider);

  final history = await chatService.getChatHistory(groupId);
  final allMessages = List<ChatMessage>.from(history);
  allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  yield List<ChatMessage>.unmodifiable(allMessages);

  await for (final newMessage in chatService.watchMessages(groupId)) {
    if (!allMessages.any((msg) => msg.id == newMessage.id)) {
      allMessages.add(newMessage);
      allMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      yield List<ChatMessage>.unmodifiable(allMessages);
    }
  }
});

final groupTypingStatusProvider = StreamProvider.family<Map<String, String>, String>((
  ref,
  groupId,
) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.watchTypingStatus(groupId);
});

final idScanServiceProvider = Provider<IdScanService>((ref) {
  final logService = ref.watch(systemLogServiceProvider);
  final service = IdScanService(logService: logService);
  ref.onDispose(service.dispose);
  return service;
});

final idDocumentRepositoryProvider = Provider<IdDocumentRepository>((ref) {
  final logService = ref.watch(systemLogServiceProvider);
  if (Firebase.apps.isEmpty) {
    throw UnimplementedError('Firebase not initialized; ID document repository is unavailable.');
  }

  return IdDocumentRepository(
    database: FirebaseDatabase.instance,
    logService: logService,
  );
});

final userIdDocumentsProvider = StreamProvider<List<IdDocument>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const Stream.empty();

  final repo = ref.watch(idDocumentRepositoryProvider);
  return repo.watchUserDocuments(user.id);
});

final pendingIdDocumentsProvider = StreamProvider<List<IdDocument>>((ref) {
  final repo = ref.watch(idDocumentRepositoryProvider);
  return repo.watchPendingDocuments();
});

final autoTopupRepositoryProvider = Provider<AutoTopupRepository>((ref) {
  final logService = ref.watch(systemLogServiceProvider);
  if (Firebase.apps.isEmpty) {
    throw UnimplementedError('Firebase not initialized; auto top-up is unavailable.');
  }

  return AutoTopupRepository(
    database: FirebaseDatabase.instance,
    logService: logService,
  );
});

final autoTopupServiceProvider = Provider<AutoTopupService>((ref) {
  final repository = ref.watch(autoTopupRepositoryProvider);
  final walletRepo = ref.watch(walletRepositoryProvider);
  final gatewayService = ref.watch(gatewayServiceProvider);
  final logService = ref.watch(systemLogServiceProvider);

  final service = AutoTopupService(
    repository: repository,
    walletRepository: walletRepo,
    gatewayService: gatewayService,
    logService: logService,
  );

  ref.onDispose(service.stopBalanceMonitoring);
  return service;
});

final userAutoTopupRulesProvider = StreamProvider<List<AutoTopupRule>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const Stream.empty();

  final repository = ref.watch(autoTopupRepositoryProvider);
  return repository.watchUserRules(user.id);
});

final userAutoTopupHistoryProvider = StreamProvider<List<AutoTopupExecution>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return const Stream.empty();

  final repository = ref.watch(autoTopupRepositoryProvider);
  return repository.watchExecutionHistory(user.id);
});

final payoutSchedulerServiceProvider = Provider<PayoutSchedulerService>((ref) {
  final equbRepo = ref.watch(equbRepositoryProvider);
  final walletRepo = ref.watch(walletRepositoryProvider);
  final logService = ref.watch(systemLogServiceProvider);

  final service = PayoutSchedulerService(
    equbRepository: equbRepo,
    walletRepository: walletRepo,
    logService: logService,
  );

  // Start the scheduler automatically
  service.startScheduler();

  ref.onDispose(service.stopScheduler);
  return service;
});

final groupAnalyticsServiceProvider = Provider<GroupAnalyticsService>((ref) {
  final equbRepo = ref.watch(equbRepositoryProvider);
  final logService = ref.watch(systemLogServiceProvider);

  return GroupAnalyticsService(
    equbRepository: equbRepo,
    logService: logService,
  );
});

final emailServiceProvider = Provider<EmailService>((ref) {
  return EmailService(
    functions: FirebaseFunctions.instance,
    logService: ref.watch(systemLogServiceProvider),
  );
});

final advancedAdminServiceProvider = Provider<AdvancedAdminService>((ref) {
  return AdvancedAdminService(
    functions: FirebaseFunctions.instance,
    equbRepository: ref.watch(equbRepositoryProvider),
    userRepository: ref.watch(userRepositoryProvider),
    idDocumentRepository: ref.watch(idDocumentRepositoryProvider),
    logService: ref.watch(systemLogServiceProvider),
  );
});

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService(
    firestore: FirebaseFirestore.instance,
    logService: ref.watch(systemLogServiceProvider),
  );
});

final pushNotificationSchedulerProvider = Provider<PushNotificationScheduler>((ref) {
  return PushNotificationScheduler(
    firestore: FirebaseFirestore.instance,
    functions: FirebaseFunctions.instance,
    logService: ref.watch(systemLogServiceProvider),
  );
});

final groupManagementServiceProvider = Provider<GroupManagementService>((ref) {
  return GroupManagementService(
    firestore: FirebaseFirestore.instance,
    logService: ref.watch(systemLogServiceProvider),
  );
});

final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService(
    logService: ref.watch(systemLogServiceProvider),
  );
});

final deviceManagementServiceProvider = Provider<DeviceManagementService>((ref) {
  return DeviceManagementService(
    firestore: FirebaseFirestore.instance,
    logService: ref.watch(systemLogServiceProvider),
  );
});

final sessionSecurityServiceProvider = Provider<SessionSecurityService>((ref) {
  return SessionSecurityService(
    firestore: FirebaseFirestore.instance,
    deviceService: ref.watch(deviceManagementServiceProvider),
    logService: ref.watch(systemLogServiceProvider),
  );
});
