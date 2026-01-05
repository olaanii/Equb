import 'dart:async';

import 'package:equb/providers/providers.dart';
import 'package:equb/providers/app_providers.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/ui/home_shell.dart';
import 'package:equb/ui/screens/auth/login_screen.dart';
import 'package:equb/ui/screens/onboarding/onboarding_screen.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthWrapper extends ConsumerStatefulWidget {
  const AuthWrapper({super.key});

  @override
  ConsumerState<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends ConsumerState<AuthWrapper> {
  String? _lastTokenUserId;

  @override
  Widget build(BuildContext context) {
    // Non-blocking side effect: when we have a current user profile, try to
    // register FCM token into RTDB so push alerts can be delivered later.
    // Riverpod requires ref.listen to be called during build.
    ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (prev, next) {
      final user = next.asData?.value;
      if (user == null) return;
      if (_lastTokenUserId == user.id) return;
      _lastTokenUserId = user.id;

      try {
        unawaited(
          ref.read(deviceTokenRegistrarProvider).registerIfNeeded(user),
        );
      } catch (_) {
        // Firebase not initialized or registrar unavailable.
      }
    });

    // 1. Check Firebase Auth State first. If user is logged in, skip onboarding
    // and do not block navigation on profile/RTDB availability.
    final firebaseAuthState = ref.watch(firebaseAuthUserProvider);
    final firebaseUser = firebaseAuthState.asData?.value;
    if (firebaseUser != null) {
      return const HomeShell();
    }

    // 2. Check Onboarding Status
    final onboardingAsync = ref.watch(onboardingStatusProvider);
    final analytics = ref.read(analyticsServiceProvider);
    final logService = ref.read(systemLogServiceProvider);

    return onboardingAsync.when(
      data: (hasSeenOnboarding) {
        if (!hasSeenOnboarding) {
          return const OnboardingScreen();
        }

        // 3. Render Auth State (Login or Loading/Error)
        return firebaseAuthState.when(
          data: (user) {
            if (user != null) return const HomeShell();
            return const LoginScreen();
          },
          loading: () => const _AuthLoadingState(),
          error: (err, stack) {
            final errorProps = <String, dynamic>{
              'errorType': err.runtimeType.toString(),
              'message': '$err',
              'stackTrace': stack.toString(),
            };

            return _AuthErrorState(
              error: err,
              onRetry: () {
                logService.log(
                  LogLevel.info,
                  'AuthWrapper',
                  'User tapped retry from auth error state',
                  context: errorProps,
                );
                unawaited(
                  analytics.track('auth_session_retry', properties: errorProps),
                );
                ref.invalidate(firebaseAuthUserProvider);
              },
              onOpenLogin: () {
                logService.log(
                  LogLevel.info,
                  'AuthWrapper',
                  'User opened login from auth error state',
                  context: errorProps,
                );
                unawaited(
                  analytics.track(
                    'auth_session_open_login',
                    properties: errorProps,
                  ),
                );
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            );
          },
        );
      },
      loading: () => const _AuthLoadingState(),
      error:
          (err, stack) => _AuthErrorState(
            error: err,
            onRetry: () => ref.refresh(onboardingStatusProvider),
            onOpenLogin: () {},
          ),
    );
  }
}

class _AuthLoadingState extends StatelessWidget {
  const _AuthLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Restoring your secure session...'),
          ],
        ),
      ),
    );
  }
}

class _AuthErrorState extends StatelessWidget {
  const _AuthErrorState({
    required this.error,
    required this.onRetry,
    required this.onOpenLogin,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onOpenLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48),
              const SizedBox(height: 16),
              const Text(
                'We could not verify your session',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection or retry. Error: $error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: onOpenLogin,
                    child: const Text('Open Login'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
