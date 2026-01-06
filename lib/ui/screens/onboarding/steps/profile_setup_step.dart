import 'package:equb/models/onboarding_state.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileSetupStep extends ConsumerStatefulWidget {
  const ProfileSetupStep({
    super.key,
    required this.initialData,
    required this.onDataChanged,
    required this.onNext,
    required this.onPrevious,
  });

  final OnboardingData initialData;
  final Function(OnboardingData) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  ConsumerState<ProfileSetupStep> createState() => _ProfileSetupStepState();
}

class _ProfileSetupStepState extends ConsumerState<ProfileSetupStep> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData.displayName);
    _phoneController = TextEditingController(text: widget.initialData.phoneNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) return;

      // Update user profile in database
      final userRepository = ref.read(userRepositoryProvider);
      await userRepository.updateUser(user.id, {
        'displayName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
      });

      // Update onboarding data
      final updatedData = widget.initialData.copyWith(
        displayName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );
      widget.onDataChanged(updatedData);

      widget.onNext();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: AppSpacing.pagePaddingMobile,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile illustration
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  size: 60,
                  color: scheme.primary,
                ),
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'Tell us about yourself',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              'This information helps us personalize your experience and verify your account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Full Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name as it appears on your ID',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
              onChanged: (value) {
                // Auto-save draft
                final updatedData = widget.initialData.copyWith(displayName: value);
                widget.onDataChanged(updatedData);
              },
            ),

            const SizedBox(height: 24),

            // Phone Number field
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '+251911234567',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your phone number';
                }
                // Ethiopian phone number validation
                final phoneRegex = RegExp(r'^\+251[0-9]{9}$|^251[0-9]{9}$|^0[0-9]{9}$');
                if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
                  return 'Please enter a valid Ethiopian phone number';
                }
                return null;
              },
              onChanged: (value) {
                // Auto-save draft
                final updatedData = widget.initialData.copyWith(phoneNumber: value);
                widget.onDataChanged(updatedData);
              },
            ),

            const SizedBox(height: 16),

            Text(
              'We\'ll use this number to send verification codes and important updates.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.6),
              ),
            ),

            const SizedBox(height: 48),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Privacy note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outline.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shield,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your information is encrypted and secure. We never share personal data without your consent.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

