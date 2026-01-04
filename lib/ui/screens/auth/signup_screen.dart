import 'package:equb/providers/providers.dart';
import 'package:equb/services/toast_service.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _acceptedTerms = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: InfoCard(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Let’s get your account set up',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We use your contact details to keep your group informed about contributions and payouts.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your name';
                      }
                      if (value.trim().split(' ').length < 2) {
                        return 'Please enter your first and last name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(
                      labelText: 'Email or phone',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Provide a contact method';
                      }
                      final input = value.trim();
                      final isEmail = input.contains('@');
                      final isPhone = RegExp(r'^\+?[0-9]{7,}$').hasMatch(input);
                      if (!isEmail && !isPhone) {
                        return 'Enter a valid email or phone number';
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
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _acceptedTerms,
                    onChanged:
                        (value) =>
                            setState(() => _acceptedTerms = value ?? false),
                    title: const Text('I agree to the community guidelines'),
                    subtitle: Text(
                      'We expect every member to contribute on time and respect fellow savers.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    text:
                        _isSubmitting ? 'Creating account…' : 'Create account',
                    icon: _isSubmitting ? null : Icons.person_add_alt_1,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed:
                        () => ToastService.info(
                          context,
                          'Redirecting to sign-in…',
                        ),
                    child: const Text('Already registered? Sign in'),
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
    if (!_acceptedTerms) {
      ToastService.warning(
        context,
        'Please accept the community guidelines to continue.',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final auth = ref.read(authServiceProvider);
      final contact = _contactController.text.trim();
      final isEmail = contact.contains('@');

      if (!isEmail) {
        ToastService.warning(
          context,
          'Phone signup not yet supported in this prototype. Please use email.',
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final user = await auth.signUpWithEmail(
        contact,
        _passwordController.text,
        _nameController.text.trim(),
      );

      if (!mounted) return;

      if (user != null) {
        ToastService.success(context, 'Welcome, ${user.name}!');
        Navigator.of(context).pop();
      } else {
        ToastService.error(context, 'Signup failed. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      ToastService.error(context, 'Error: $e');
    }
  }
}
