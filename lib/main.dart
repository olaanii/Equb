import 'dart:async';

import 'package:equb/ui/auth_wrapper.dart';
import 'package:equb/ui/home_shell.dart';
import 'package:equb/ui/routes/admin_route.dart';
import 'package:equb/ui/screens/groups/group_invitations_screen.dart';
import 'package:equb/ui/screens/groups/group_settings_screen.dart';
import 'package:equb/ui/screens/onboarding/onboarding_flow_screen.dart';
import 'package:equb/models/group_model.dart';
import 'package:equb/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equb/services/notification_service.dart';
import 'package:equb/services/secure_storage_service.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:equb/providers/app_providers.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/utils/app_snackbar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppSnackbar.showError(details.exceptionAsString());
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    AppSnackbar.showError(error.toString());
    return true;
  };

  if (!kReleaseMode) {
    await _bootstrapGatewaySecretsFromDartDefines();
  }

  bool firebaseInitialized = false;
  String? firebaseError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    firebaseError = e.toString();
  }

  if (firebaseInitialized && !kReleaseMode) {
    const useEmulators = bool.fromEnvironment(
      'USE_FIREBASE_EMULATORS',
      defaultValue: false,
    );
    if (useEmulators) {
      try {
        final host = kIsWeb ? 'localhost' : '10.0.2.2';
        FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
        debugPrint('Using Firebase Functions emulator at $host:5001');
      } catch (e) {
        debugPrint('Failed to configure Functions emulator: $e');
      }
    }
  }

  // Initialize notification service if Firebase is available (optional)
  if (firebaseInitialized) {
    try {
      // Firebase initialization would be done elsewhere; attempt to init FCM
      // ignore: unused_local_variable
      final notif = NotificationService();
      await notif.init();
    } catch (_) {}
  }

  // Start background services
  Future.microtask(() {
    try {
      // Services will be started when providers are initialized
      // Payout scheduler and auto top-up monitoring will start automatically
    } catch (e) {
      debugPrint('Failed to start background services: $e');
    }
  });
  runApp(
    ProviderScope(
      child: EqubLifecycleGate(
        firebaseInitialized: firebaseInitialized,
        firebaseError: firebaseError,
      ),
    ),
  );
}

Future<void> _bootstrapGatewaySecretsFromDartDefines() async {
  // Optional dev helper: pass keys at runtime so the wallet app can run
  // even if secure storage isn't shared between different dev-server ports.
  const chapaPublicKey = String.fromEnvironment('CHAPA_PUBLIC_KEY');
  const chapaSecretKey = String.fromEnvironment('CHAPA_SECRET_KEY');
  const chapaCallbackUrl = String.fromEnvironment('CHAPA_CALLBACK_URL');
  const chapaReturnUrl = String.fromEnvironment('CHAPA_RETURN_URL');

  final storage = SecureStorageService();

  final hasChapaPublic = chapaPublicKey.trim().isNotEmpty;
  final hasChapaSecret = chapaSecretKey.trim().isNotEmpty;
  final hasCallbackUrl = chapaCallbackUrl.trim().isNotEmpty;
  final hasReturnUrl = chapaReturnUrl.trim().isNotEmpty;
  if (!hasChapaPublic && !hasChapaSecret && !hasCallbackUrl && !hasReturnUrl) {
    return;
  }

  try {
    if (hasChapaPublic) {
      await storage.write('gateway.chapa.publicKey', chapaPublicKey.trim());
    }
    if (hasChapaSecret) {
      await storage.write('gateway.chapa.secretKey', chapaSecretKey.trim());
    }
    if (hasCallbackUrl) {
      await storage.write(
        'gateway.chapa.callbackUrl',
        chapaCallbackUrl.trim(),
      );
    }
    if (hasReturnUrl) {
      await storage.write('gateway.chapa.returnUrl', chapaReturnUrl.trim());
    }
    debugPrint('Stored Chapa keys in secure storage.');
  } catch (e) {
    debugPrint('Failed to store Chapa key in secure storage: $e');
  }
}

class EqubApp extends ConsumerWidget {
  final bool firebaseInitialized;
  final String? firebaseError;
  const EqubApp({
    super.key,
    this.firebaseInitialized = true,
    this.firebaseError,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    if (!firebaseInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Firebase Configuration Missing',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please run the following command in your terminal to configure Firebase:',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.grey[900],
                    child: const SelectableText(
                      'flutterfire configure',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (firebaseError != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Error details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      firebaseError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Equb - Modern Savings',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppSnackbar.messengerKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/':
            page = const AuthWrapper();
            break;
          case '/home':
            page = const HomeShell();
            break;
          case '/admin':
            page = const AdminRoute();
            break;
          case '/onboarding':
            page = const OnboardingFlowScreen();
            break;
          case '/group-settings':
            if (!kDebugMode) {
              page = const HomeShell();
              break;
            }
            final group = settings.arguments as GroupModel?;
            page =
                group != null
                    ? GroupSettingsScreen(group: group)
                    : const AuthWrapper();
            break;
          case '/group-invitations':
            page =
                kDebugMode ? const GroupInvitationsScreen() : const HomeShell();
            break;
          default:
            page = const AuthWrapper();
        }
        return MaterialPageRoute(builder: (_) => page, settings: settings);
      },
    );
  }
}

class EqubLifecycleGate extends ConsumerStatefulWidget {
  final bool firebaseInitialized;
  final String? firebaseError;

  const EqubLifecycleGate({
    super.key,
    required this.firebaseInitialized,
    required this.firebaseError,
  });

  @override
  ConsumerState<EqubLifecycleGate> createState() => _EqubLifecycleGateState();
}

class _EqubLifecycleGateState extends ConsumerState<EqubLifecycleGate>
    with WidgetsBindingObserver {
  DateTime? _lastResumeAttemptAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(_recoverPendingPayments());
    }
  }

  Future<void> _recoverPendingPayments() async {
    if (!mounted) return;
    if (!widget.firebaseInitialized) return;

    final now = DateTime.now();
    final last = _lastResumeAttemptAt;
    if (last != null && now.difference(last) < const Duration(seconds: 8)) {
      return;
    }
    _lastResumeAttemptAt = now;

    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    await ref
        .read(paymentRecoveryServiceProvider)
        .recoverLatestPendingChapaTx(userId: user.id);
  }

  @override
  Widget build(BuildContext context) {
    return EqubApp(
      firebaseInitialized: widget.firebaseInitialized,
      firebaseError: widget.firebaseError,
    );
  }
}
