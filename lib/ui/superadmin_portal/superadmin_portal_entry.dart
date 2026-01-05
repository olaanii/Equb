import 'package:equb/providers/providers.dart';
import 'package:equb/ui/screens/auth/login_screen.dart';
import 'package:equb/ui/superadmin_portal/superadmin_portal_shell.dart';
import 'package:equb/ui/superadmin_portal/superadmin_portal_unauthorized_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'superadmin_portal_providers.dart';

/// Portal-only entry gate:
/// - requires login
/// - requires RTDB flag `superadmins/{uid} == true`
class SuperAdminPortalEntry extends ConsumerWidget {
  const SuperAdminPortalEntry({super.key});

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
          return const LoginScreen();
        }

        final allowed = ref.watch(superAdminAllowedProvider);
        return allowed.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SuperAdminPortalUnauthorizedScreen(details: 'Access check failed: $e'),
          data: (isAllowed) {
            if (!isAllowed) {
              return const SuperAdminPortalUnauthorizedScreen();
            }
            return const SuperAdminPortalShell();
          },
        );
      },
    );
  }
}
