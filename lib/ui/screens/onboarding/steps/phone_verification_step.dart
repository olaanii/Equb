import 'dart:async';

import 'package:equb/models/onboarding_state.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PhoneVerificationStep extends ConsumerStatefulWidget {
  const PhoneVerificationStep({
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
  ConsumerState<PhoneVerificationStep> createState() => _PhoneVerificationStepState();
}

class _PhoneVerificationStepState extends ConsumerState<PhoneVerificationStep> {
  final _codeController = TextEditingController();
  bool _isSendingCode = false;
  bool _isVerifying = false;
  bool _codeSent = false;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _sendVerificationCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    if (_isSendingCode || _resendCountdown > 0) return;

    setState(() => _isSendingCode = true);

    try {
      // TODO: Integrate with actual SMS service (Firebase Auth, Twilio, etc.)
      // For now, simulate sending code
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _codeSent = true;
          _resendCountdown = 60; // 60 seconds countdown
        });
        _startCountdown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send verification code: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingCode = false);
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _resendCountdown--);
        if (_resendCountdown <= 0) {
          timer.cancel();
        }
      }
    });
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit code')),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // TODO: Integrate with actual verification service
      // For now, accept any 6-digit code as valid
      await Future.delayed(const Duration(seconds: 2));

      // Update onboarding data
      final updatedData = widget.initialData.copyWith(phoneVerified: true);
      widget.onDataChanged(updatedData);

      widget.onNext();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: AppSpacing.pagePaddingMobile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Verification illustration
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.phone_android,
                size: 60,
                color: scheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Verify your phone number',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            'We sent a 6-digit code to ${widget.initialData.phoneNumber}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Code input field
          TextFormField(
            controller: _codeController,
            decoration: const InputDecoration(
              labelText: 'Verification Code',
              hintText: 'Enter 6-digit code',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
            onChanged: (value) {
              // Auto-verify when 6 digits entered
              if (value.length == 6) {
                _verifyCode();
              }
            },
          ),

          const SizedBox(height: 24),

          // Verify button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isVerifying || _codeController.text.length != 6)
                  ? null
                  : _verifyCode,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isVerifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Verify Code',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // Resend code
          Center(
            child: _resendCountdown > 0
                ? Text(
                    'Resend code in ${_resendCountdown}s',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.6),
                    ),
                  )
                : TextButton(
                    onPressed: _isSendingCode ? null : _sendVerificationCode,
                    child: _isSendingCode
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Resend Code'),
                  ),
          ),

          const SizedBox(height: 32),

          // Help text
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      size: 20,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Didn\'t receive the code?',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Check your spam/junk folder\n'
                  '• Make sure your phone number is correct\n'
                  '• Ensure you have good network connection\n'
                  '• Contact support if issues persist',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Change phone number
          Center(
            child: TextButton.icon(
              onPressed: () => widget.onPrevious(),
              icon: const Icon(Icons.edit),
              label: const Text('Change Phone Number'),
            ),
          ),
        ],
      ),
    );
  }
}

