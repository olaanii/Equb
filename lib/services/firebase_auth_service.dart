import 'package:firebase_auth/firebase_auth.dart';
import 'package:equb/models/user_model.dart';
import 'package:equb/services/auth_service.dart';
import 'package:equb/services/analytics_service.dart';

import 'package:flutter/foundation.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({AnalyticsService? analyticsService})
    : _analyticsService = analyticsService;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AnalyticsService? _analyticsService;

  @override
  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user == null) return null;

      final authUser = credential.user!;
      final model = UserModel(
        id: authUser.uid,
        name: authUser.displayName ?? email.split('@').first,
        email: email,
        phone: authUser.phoneNumber,
      );

      await _track(
        'auth_sign_in',
        userId: authUser.uid,
        properties: {'method': 'email'},
      );
      await _identify(model, traits: {'method': 'email'});

      return model;
    } catch (e) {
      debugPrint('Error signing in: $e');
      await _track(
        'auth_sign_in_failed',
        properties: {'method': 'email', 'reason': e.toString()},
      );
      return null;
    }
  }

  @override
  Future<UserModel?> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user == null) return null;

      final authUser = credential.user!;

      final user = UserModel(
        id: authUser.uid,
        name: name,
        email: email,
        phone: authUser.phoneNumber,
      );

      await _track(
        'auth_sign_up',
        userId: user.id,
        properties: {'method': 'email'},
      );
      await _identify(user, traits: {'method': 'email'});
      return user;
    } catch (e) {
      debugPrint('Error signing up: $e');
      await _track(
        'auth_sign_up_failed',
        properties: {'method': 'email', 'reason': e.toString()},
      );
      return null;
    }
  }

  @override
  Future<UserModel?> signInWithPhone(String phone, String smsCode) async {
    // For prototype, we can't easily do real phone auth without UI flow (verifyPhoneNumber).
    // We'll assume this method is called after verification or we mock it for now
    // if the user wants "real" prototype, they need the UI flow.
    // But since the interface is simple, I'll just throw or return null.
    // Or better, I'll implement a dummy lookup for now to not break the app if they try phone login.
    // Real implementation requires changing the UI to handle code sent/verify.
    debugPrint('Phone auth not fully implemented in this prototype step');
    await _track(
      'auth_sign_in_attempt',
      properties: {'method': 'phone', 'supported': false},
    );
    return null;
  }

  @override
  Future<void> signOut() async {
    final userId = _auth.currentUser?.uid;
    await _auth.signOut();
    await _track('auth_sign_out', userId: userId);
  }

  Future<void> _track(
    String event, {
    String? userId,
    Map<String, dynamic>? properties,
  }) async {
    if (_analyticsService == null) return;
    await _analyticsService.track(
      event,
      userId: userId,
      properties: properties,
    );
  }

  Future<void> _identify(UserModel user, {Map<String, dynamic>? traits}) async {
    if (_analyticsService == null) return;
    await _analyticsService.identify(
      user.id,
      traits: {'email': user.email, 'role': user.role.name, ...?traits},
    );
  }
}
