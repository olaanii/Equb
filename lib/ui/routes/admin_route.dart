import 'package:equb/providers/admin_providers.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/screens/admin_hub_screen.dart';
import 'package:equb/ui/screens/auth/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminRoute extends ConsumerWidget {
  const AdminRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(firebaseAuthUserProvider);

    return auth.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Auth error: $e')),
      ),
      data: (firebaseUser) {
        if (firebaseUser == null) {
          // Keep it simple: /admin requires login.
          return const LoginScreen();
        }

        final isAdminAsync = ref.watch(isAdminProvider);
        return isAdminAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            body: Center(child: Text('Admin check failed: $e')),
          ),
          data: (isAdmin) {
            if (!isAdmin) {
              return Scaffold(
                appBar: AppBar(title: const Text('Admin')),
                body: const Center(child: Text('Not authorized.')),
              );
            }
            return const AdminHubScreen();
          },
        );
      },
    );
  }
}
