import 'package:equb/providers/app_providers.dart';
import 'package:equb/services/secure_storage_service.dart';
import 'package:equb/ui/superadmin_portal/superadmin_portal_entry.dart';
import 'package:equb/ui/theme/app_theme.dart';
import 'package:equb/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';

/// Super Admin Portal entrypoint.
///
/// Run with: `flutter run -d chrome -t lib/main_superadmin.dart`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  if (firebaseInitialized) {
    try {
      final notif = NotificationService();
      await notif.init();
    } catch (_) {}
  }

  runApp(
    ProviderScope(
      child: SuperAdminPortalApp(
        firebaseInitialized: firebaseInitialized,
        firebaseError: firebaseError,
      ),
    ),
  );
}

Future<void> _bootstrapGatewaySecretsFromDartDefines() async {
  // These are provided at runtime, e.g.:
  // flutter run -d chrome -t lib/main_superadmin.dart \
  //   "--dart-define=CHAPA_SECRET_KEY=..."
  const chapaPublicKey = String.fromEnvironment('CHAPA_PUBLIC_KEY');
  const chapaSecretKey = String.fromEnvironment('CHAPA_SECRET_KEY');

  final storage = SecureStorageService();

  final hasChapaPublic = chapaPublicKey.trim().isNotEmpty;
  final hasChapaSecret = chapaSecretKey.trim().isNotEmpty;
  if (!hasChapaPublic && !hasChapaSecret) {
    return;
  }

  try {
    if (hasChapaPublic) {
      await storage.write('gateway.chapa.publicKey', chapaPublicKey.trim());
    }
    if (hasChapaSecret) {
      await storage.write('gateway.chapa.secretKey', chapaSecretKey.trim());
    }
    debugPrint('Stored Chapa keys in secure storage.');
  } catch (e) {
    debugPrint('Failed to store Chapa key in secure storage: $e');
  }
}

class SuperAdminPortalApp extends ConsumerWidget {
  const SuperAdminPortalApp({
    super.key,
    required this.firebaseInitialized,
    required this.firebaseError,
  });

  final bool firebaseInitialized;
  final String? firebaseError;

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
      title: 'Equb • Super Admin Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const SuperAdminPortalEntry(),
          settings: settings,
        );
      },
    );
  }
}
