import 'package:equb/models/user_model.dart';

abstract class AuthService {
  Future<UserModel?> signInWithEmail(String email, String password);
  Future<UserModel?> signUpWithEmail(
    String email,
    String password,
    String name,
  );
  Future<UserModel?> signInWithPhone(String phone, String smsCode);
  Future<void> signOut();
}

// Removed SupabaseAuthService for frontend-only mode.

class DummyAuthService implements AuthService {
  @override
  Future<UserModel?> signInWithEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return UserModel(id: 'u_demo_email', name: 'Demo Email', email: email);
  }

  @override
  Future<UserModel?> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return UserModel(id: 'u_demo_signup', name: name, email: email);
  }

  @override
  Future<UserModel?> signInWithPhone(String phone, String smsCode) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return UserModel(id: 'u_demo_phone', name: 'Demo Phone', phone: phone);
  }

  @override
  Future<void> signOut() async {}
}
