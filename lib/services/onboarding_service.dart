import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equb/models/onboarding_state.dart';
import 'package:equb/services/system_log_service.dart';

class OnboardingService {
  OnboardingService({
    required this.firestore,
    required this.logService,
  });

  final FirebaseFirestore firestore;
  final SystemLogService logService;

  static const String _collection = 'user_onboarding';

  /// Save onboarding data for a user
  Future<void> saveOnboardingData(String userId, OnboardingData data) async {
    try {
      await firestore.collection(_collection).doc(userId).set({
        ...data.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      logService.log(
        LogLevel.info,
        'onboarding_data_saved',
        'User onboarding data saved',
        context: {
          'userId': userId,
          'currentStep': data.currentStep.name,
          'isComplete': data.isComplete,
        },
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'onboarding_save_failed',
        'Failed to save onboarding data',
        context: {'userId': userId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Load onboarding data for a user
  Future<OnboardingData?> loadOnboardingData(String userId) async {
    try {
      final doc = await firestore.collection(_collection).doc(userId).get();

      if (!doc.exists) {
        return null;
      }

      return OnboardingData.fromJson(doc.data()!);
    } catch (e) {
      logService.log(
        LogLevel.error,
        'onboarding_load_failed',
        'Failed to load onboarding data',
        context: {'userId': userId, 'error': e.toString()},
      );
      return null;
    }
  }

  /// Update onboarding step
  Future<void> updateOnboardingStep(String userId, OnboardingStep step) async {
    try {
      final data = await loadOnboardingData(userId);
      final updatedData = (data ?? const OnboardingData()).copyWith(
        currentStep: step,
      );

      await saveOnboardingData(userId, updatedData);

      logService.log(
        LogLevel.info,
        'onboarding_step_updated',
        'User onboarding step updated',
        context: {
          'userId': userId,
          'step': step.name,
        },
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'onboarding_step_update_failed',
        'Failed to update onboarding step',
        context: {'userId': userId, 'step': step.name, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Complete onboarding for a user
  Future<void> completeOnboarding(String userId) async {
    try {
      final data = await loadOnboardingData(userId);
      final completedData = (data ?? const OnboardingData()).copyWith(
        currentStep: OnboardingStep.completed,
      );

      await saveOnboardingData(userId, completedData);

      // Update user document to mark onboarding as complete
      await firestore.collection('users').doc(userId).update({
        'onboardingCompleted': true,
        'onboardingCompletedAt': FieldValue.serverTimestamp(),
      });

      logService.log(
        LogLevel.info,
        'onboarding_completed',
        'User onboarding completed successfully',
        context: {'userId': userId},
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'onboarding_completion_failed',
        'Failed to complete onboarding',
        context: {'userId': userId, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Get onboarding progress for a user
  Future<OnboardingProgress> getOnboardingProgress(String userId) async {
    try {
      final data = await loadOnboardingData(userId);

      if (data == null) {
        return OnboardingProgress(
          completedSteps: 0,
          totalSteps: OnboardingStep.values.length,
          currentStep: OnboardingStep.welcome,
          isComplete: false,
        );
      }

      int completedSteps = 0;

      // Count completed required steps
      if (data.displayName.isNotEmpty) completedSteps++;
      if (data.phoneVerified) completedSteps++;
      if (data.documentsUploaded) completedSteps++;
      if (data.paymentMethodSetup) completedSteps++;

      // Group guidance is optional, so don't count it in completion

      return OnboardingProgress(
        completedSteps: completedSteps,
        totalSteps: 5, // Required steps only
        currentStep: data.currentStep,
        isComplete: data.isComplete,
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'onboarding_progress_load_failed',
        'Failed to get onboarding progress',
        context: {'userId': userId, 'error': e.toString()},
      );

      return const OnboardingProgress(
        completedSteps: 0,
        totalSteps: 5,
        currentStep: OnboardingStep.welcome,
        isComplete: false,
      );
    }
  }

  /// Check if user needs onboarding
  Future<bool> needsOnboarding(String userId) async {
    try {
      final userDoc = await firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return true; // New user needs onboarding
      }

      final userData = userDoc.data();
      final onboardingCompleted = userData?['onboardingCompleted'] as bool? ?? false;

      return !onboardingCompleted;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'onboarding_check_failed',
        'Failed to check if user needs onboarding',
        context: {'userId': userId, 'error': e.toString()},
      );
      return true; // Default to needing onboarding on error
    }
  }

  /// Skip optional steps (like group guidance)
  Future<void> skipStep(String userId, OnboardingStep step) async {
    if (!step.canSkip) {
      throw Exception('Step ${step.name} cannot be skipped');
    }

    try {
      await updateOnboardingStep(userId, _getNextStep(step));
    } catch (e) {
      logService.log(
        LogLevel.error,
        'onboarding_skip_failed',
        'Failed to skip onboarding step',
        context: {'userId': userId, 'step': step.name, 'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Get the next step in the onboarding flow
  OnboardingStep _getNextStep(OnboardingStep currentStep) {
    final steps = OnboardingStep.values;
    final currentIndex = steps.indexOf(currentStep);

    if (currentIndex < steps.length - 1) {
      return steps[currentIndex + 1];
    }

    return OnboardingStep.completed;
  }

  /// Validate if a step can be accessed
  Future<bool> canAccessStep(String userId, OnboardingStep step) async {
    try {
      final data = await loadOnboardingData(userId);

      if (data == null) {
        return step == OnboardingStep.welcome;
      }

      final currentIndex = OnboardingStep.values.indexOf(data.currentStep);
      final requestedIndex = OnboardingStep.values.indexOf(step);

      // Can access current step or previous steps
      return requestedIndex <= currentIndex;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'onboarding_access_check_failed',
        'Failed to check step access',
        context: {'userId': userId, 'step': step.name, 'error': e.toString()},
      );
      return false;
    }
  }
}

