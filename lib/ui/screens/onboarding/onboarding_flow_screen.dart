import 'package:equb/models/onboarding_state.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/screens/onboarding/steps/document_upload_step.dart';
import 'package:equb/ui/screens/onboarding/steps/group_guidance_step.dart';
import 'package:equb/ui/screens/onboarding/steps/payment_setup_step.dart';
import 'package:equb/ui/screens/onboarding/steps/phone_verification_step.dart';
import 'package:equb/ui/screens/onboarding/steps/profile_setup_step.dart';
import 'package:equb/ui/screens/onboarding/steps/welcome_step.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  OnboardingData _onboardingData = const OnboardingData();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOnboardingData();
  }

  Future<void> _loadOnboardingData() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final onboardingService = ref.read(onboardingServiceProvider);
    final data = await onboardingService.loadOnboardingData(user.id);

    if (mounted) {
      setState(() {
        _onboardingData = data ?? const OnboardingData();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveOnboardingData() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final onboardingService = ref.read(onboardingServiceProvider);
    await onboardingService.saveOnboardingData(user.id, _onboardingData);
  }

  void _updateData(OnboardingData newData) {
    setState(() => _onboardingData = newData);
    _saveOnboardingData();
  }

  void _nextStep() {
    final currentIndex = OnboardingStep.values.indexOf(_onboardingData.currentStep);
    if (currentIndex < OnboardingStep.values.length - 1) {
      final nextStep = OnboardingStep.values[currentIndex + 1];
      _updateData(_onboardingData.copyWith(currentStep: nextStep));
    }
  }

  void _previousStep() {
    final currentIndex = OnboardingStep.values.indexOf(_onboardingData.currentStep);
    if (currentIndex > 0) {
      final previousStep = OnboardingStep.values[currentIndex - 1];
      _updateData(_onboardingData.copyWith(currentStep: previousStep));
    }
  }

  void _skipStep() {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final onboardingService = ref.read(onboardingServiceProvider);
    onboardingService.skipStep(user.id, _onboardingData.currentStep).then((_) {
      _nextStep();
    });
  }

  Future<void> _completeOnboarding() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final onboardingService = ref.read(onboardingServiceProvider);
    await onboardingService.completeOnboarding(user.id);

    if (mounted) {
      // Navigate to main app
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final progress = _calculateProgress();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(progress),

            // Step content
            Expanded(
              child: _buildCurrentStep(),
            ),

            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(OnboardingProgress progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${progress.completedSteps}/${progress.totalSteps}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const Spacer(),
              Text(
                '${(progress.progressPercentage * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.progressPercentage,
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _onboardingData.currentStep.title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _onboardingData.currentStep.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_onboardingData.currentStep) {
      case OnboardingStep.welcome:
        return WelcomeStep(
          onNext: _nextStep,
        );
      case OnboardingStep.profileSetup:
        return ProfileSetupStep(
          initialData: _onboardingData,
          onDataChanged: (data) => _updateData(data),
          onNext: _nextStep,
          onPrevious: _previousStep,
        );
      case OnboardingStep.phoneVerification:
        return PhoneVerificationStep(
          initialData: _onboardingData,
          onDataChanged: (data) => _updateData(data),
          onNext: _nextStep,
          onPrevious: _previousStep,
        );
      case OnboardingStep.documentUpload:
        return DocumentUploadStep(
          initialData: _onboardingData,
          onDataChanged: (data) => _updateData(data),
          onNext: _nextStep,
          onPrevious: _previousStep,
        );
      case OnboardingStep.paymentSetup:
        return PaymentSetupStep(
          initialData: _onboardingData,
          onDataChanged: (data) => _updateData(data),
          onNext: _nextStep,
          onPrevious: _previousStep,
        );
      case OnboardingStep.groupGuidance:
        return GroupGuidanceStep(
          initialData: _onboardingData,
          onDataChanged: (data) => _updateData(data),
          onNext: _nextStep,
          onPrevious: _previousStep,
          onSkip: _skipStep,
        );
      case OnboardingStep.completed:
        return _buildCompletionStep();
    }
  }

  Widget _buildCompletionStep() {
    return Padding(
      padding: AppSpacing.pagePaddingMobile,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'You\'re all set!',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to the Equb community. You can now start saving with your group.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _completeOnboarding,
              child: const Text('Get Started'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final currentStep = _onboardingData.currentStep;

    if (currentStep == OnboardingStep.welcome || currentStep == OnboardingStep.completed) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (currentStep != OnboardingStep.welcome)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text('Back'),
              ),
            ),
          if (currentStep != OnboardingStep.welcome && currentStep != OnboardingStep.completed)
            const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _nextStep,
              child: Text(_getNextButtonText()),
            ),
          ),
        ],
      ),
    );
  }

  String _getNextButtonText() {
    switch (_onboardingData.currentStep) {
      case OnboardingStep.groupGuidance:
        return 'Complete Setup';
      case OnboardingStep.paymentSetup:
        return 'Continue';
      default:
        return 'Next';
    }
  }

  OnboardingProgress _calculateProgress() {
    int completedSteps = 0;

    if (_onboardingData.displayName.isNotEmpty) completedSteps++;
    if (_onboardingData.phoneVerified) completedSteps++;
    if (_onboardingData.documentsUploaded) completedSteps++;
    if (_onboardingData.paymentMethodSetup) completedSteps++;

    return OnboardingProgress(
      completedSteps: completedSteps,
      totalSteps: 5, // Required steps
      currentStep: _onboardingData.currentStep,
      isComplete: _onboardingData.isComplete,
    );
  }
}

