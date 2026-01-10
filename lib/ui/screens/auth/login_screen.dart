import 'package:equb/providers/providers.dart';
import 'package:equb/services/toast_service.dart';
import 'package:equb/ui/screens/auth/signup_screen.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: InfoCard(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome back',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to manage contributions, payouts, and group activity.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _startPasswordReset,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    text: _isSubmitting ? 'Signing in…' : 'Sign in',
                    icon: _isSubmitting ? null : Icons.login,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('Sign in with phone'),
                    onPressed: _isSubmitting ? null : _startPhoneSignIn,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isSubmitting ? null : _startSignup,
                    child: const Text('Need an account? Create one'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      final auth = ref.read(authServiceProvider);
      final user = await auth.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;
      if (user == null) {
        ToastService.error(
          context,
          'Unable to sign in. Check your credentials.',
        );
        return;
      }
      // ref.read(currentUserProvider).value = user; // Removed: StreamProvider updates automatically
      ToastService.success(context, 'Signed in as ${user.name}.');
    } catch (error) {
      if (!mounted) return;
      ToastService.error(context, 'Sign-in failed: $error');
    }
  }

  Future<void> _startPasswordReset() async {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    String? error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setStateDialog) => AlertDialog(
                  title: const Text('Reset password'),
                  content: TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      errorText: error,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    PrimaryButton(
                      text: 'Send reset link',
                      icon: Icons.mark_email_read_outlined,
                      onPressed: () {
                        final value = emailController.text.trim();
                        if (value.isEmpty || !value.contains('@')) {
                          setStateDialog(() => error = 'Enter a valid email.');
                          return;
                        }
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ],
                ),
          ),
    );
    if (confirmed == true) {
      if (!mounted) return;
      ToastService.success(
        context,
        'Instruction email sent to ${emailController.text.trim()}.',
      );
    }
  }

  Future<void> _startPhoneSignIn() async {
    final phoneController = TextEditingController();
    final codeController = TextEditingController();
    bool codeSent = false;
    bool isSubmitting = false;

    String? verificationId;
    ConfirmationResult? confirmationResult;

    String normalizePhone(String input) {
      final raw = input.replaceAll(' ', '').trim();
      if (raw.isEmpty) return raw;
      if (raw.startsWith('+')) return raw;
      if (raw.startsWith('251')) return '+$raw';
      if (raw.startsWith('0')) return '+251${raw.substring(1)}';
      return raw;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setSheetState) => Padding(
                  padding: MediaQuery.of(
                    context,
                  ).viewInsets.add(const EdgeInsets.fromLTRB(24, 24, 24, 32)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sign in with phone',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          hintText: '+251 900 000 000',
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (codeSent)
                        TextField(
                          controller: codeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'One-time code',
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed:
                                isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          PrimaryButton(
                            text:
                                isSubmitting
                                    ? 'Signing in…'
                                    : codeSent
                                    ? 'Verify and sign in'
                                    : 'Send code',
                            icon: isSubmitting ? null : Icons.sms_outlined,
                            onPressed:
                                isSubmitting
                                    ? null
                                    : () async {
                                      final phone = normalizePhone(
                                        phoneController.text,
                                      );
                                      if (phone.length < 9) {
                                        ToastService.warning(
                                          context,
                                          'Enter a valid phone number.',
                                        );
                                        return;
                                      }
                                      if (!codeSent) {
                                        setSheetState(
                                          () => isSubmitting = true,
                                        );
                                        try {
                                          if (kIsWeb) {
                                            final verifier = RecaptchaVerifier(
                                              auth:
                                                  FirebaseAuthPlatform.instance,
                                              container: 'recaptcha-container',
                                            );
                                            confirmationResult =
                                                await FirebaseAuth.instance
                                                    .signInWithPhoneNumber(
                                                      phone,
                                                      verifier,
                                                    );
                                          } else {
                                            await FirebaseAuth.instance
                                                .verifyPhoneNumber(
                                                  phoneNumber: phone,
                                                  verificationCompleted: (
                                                    credential,
                                                  ) async {
                                                    await FirebaseAuth.instance
                                                        .signInWithCredential(
                                                          credential,
                                                        );
                                                    if (!context.mounted)
                                                      return;
                                                    if (Navigator.of(
                                                      context,
                                                    ).canPop()) {
                                                      Navigator.of(
                                                        context,
                                                      ).pop();
                                                    }
                                                    Navigator.of(
                                                      context,
                                                    ).pushNamedAndRemoveUntil(
                                                      '/',
                                                      (r) => false,
                                                    );
                                                    ToastService.success(
                                                      context,
                                                      'Signed in successfully.',
                                                    );
                                                  },
                                                  verificationFailed: (e) {
                                                    throw e;
                                                  },
                                                  codeSent: (id, _) {
                                                    verificationId = id;
                                                  },
                                                  codeAutoRetrievalTimeout: (
                                                    id,
                                                  ) {
                                                    verificationId = id;
                                                  },
                                                );
                                          }

                                          if (!context.mounted) return;
                                          setSheetState(() => codeSent = true);
                                          ToastService.info(
                                            context,
                                            'SMS code sent to $phone.',
                                          );
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ToastService.error(
                                            context,
                                            'Failed to send SMS code: $e',
                                          );
                                        } finally {
                                          if (context.mounted) {
                                            setSheetState(
                                              () => isSubmitting = false,
                                            );
                                          }
                                        }
                                        return;
                                      }
                                      if (codeController.text.trim().length <
                                          4) {
                                        ToastService.warning(
                                          context,
                                          'Enter the 4-digit code we sent.',
                                        );
                                        return;
                                      }
                                      setSheetState(() => isSubmitting = true);
                                      try {
                                        final smsCode =
                                            codeController.text.trim();
                                        if (kIsWeb) {
                                          final result =
                                              await confirmationResult?.confirm(
                                                smsCode,
                                              );
                                          if (result?.user == null) {
                                            throw Exception(
                                              'Verification failed.',
                                            );
                                          }
                                        } else {
                                          final id = verificationId;
                                          if (id == null || id.isEmpty) {
                                            throw Exception(
                                              'Verification not initialized. Please resend the code.',
                                            );
                                          }
                                          final credential =
                                              PhoneAuthProvider.credential(
                                                verificationId: id,
                                                smsCode: smsCode,
                                              );
                                          await FirebaseAuth.instance
                                              .signInWithCredential(credential);
                                        }

                                        if (!context.mounted) return;
                                        if (Navigator.of(context).canPop()) {
                                          Navigator.of(context).pop();
                                        }
                                        Navigator.of(
                                          context,
                                        ).pushNamedAndRemoveUntil(
                                          '/',
                                          (r) => false,
                                        );
                                        ToastService.success(
                                          context,
                                          'Signed in successfully.',
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ToastService.error(
                                          context,
                                          'Unable to verify code: $e',
                                        );
                                      } finally {
                                        if (context.mounted) {
                                          setSheetState(
                                            () => isSubmitting = false,
                                          );
                                        }
                                      }
                                    },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Future<void> _startSignup() async {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
  }
}
