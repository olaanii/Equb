import 'package:equb/ui/auth_wrapper.dart';
import 'package:equb/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equb/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:equb/providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Initialize notification service if Firebase is available (optional)
  if (firebaseInitialized) {
    try {
      // Firebase initialization would be done elsewhere; attempt to init FCM
      // ignore: unused_local_variable
      final notif = NotificationService();
      await notif.init();
    } catch (_) {}
  }
  runApp(
    ProviderScope(
      child: EqubApp(
        firebaseInitialized: firebaseInitialized,
        firebaseError: firebaseError,
      ),
    ),
  );
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
          default:
            page = const AuthWrapper();
        }
        return MaterialPageRoute(builder: (_) => page, settings: settings);
      },
    );
  }
}
