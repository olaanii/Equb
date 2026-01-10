enum OnboardingStep {
  welcome,
  profileSetup,
  phoneVerification,
  documentUpload,
  paymentSetup,
  groupGuidance,
  completed,
}

extension OnboardingStepX on OnboardingStep {
  String get title {
    switch (this) {
      case OnboardingStep.welcome:
        return 'Welcome to Equb';
      case OnboardingStep.profileSetup:
        return 'Set up your profile';
      case OnboardingStep.phoneVerification:
        return 'Verify your phone';
      case OnboardingStep.documentUpload:
        return 'Upload documents';
      case OnboardingStep.paymentSetup:
        return 'Set up payments';
      case OnboardingStep.groupGuidance:
        return 'Join or create a group';
      case OnboardingStep.completed:
        return 'You\'re all set!';
    }
  }

  String get description {
    switch (this) {
      case OnboardingStep.welcome:
        return 'Let\'s get you started with Ethiopian savings groups';
      case OnboardingStep.profileSetup:
        return 'Tell us a bit about yourself';
      case OnboardingStep.phoneVerification:
        return 'We need to verify your phone number for security';
      case OnboardingStep.documentUpload:
        return 'Upload your ID for account verification';
      case OnboardingStep.paymentSetup:
        return 'Connect your mobile money for contributions';
      case OnboardingStep.groupGuidance:
        return 'Find or create your savings group';
      case OnboardingStep.completed:
        return 'Ready to start saving with your community';
    }
  }

  bool get isRequired => this != OnboardingStep.groupGuidance;
  bool get canSkip => this == OnboardingStep.groupGuidance;
}

class OnboardingData {
  const OnboardingData({
    this.displayName = '',
    this.phoneNumber = '',
    this.phoneVerified = false,
    this.documentsUploaded = false,
    this.paymentMethodSetup = false,
    this.preferredGroupType = '',
    this.currentStep = OnboardingStep.welcome,
  });

  final String displayName;
  final String phoneNumber;
  final bool phoneVerified;
  final bool documentsUploaded;
  final bool paymentMethodSetup;
  final String preferredGroupType;
  final OnboardingStep currentStep;

  OnboardingData copyWith({
    String? displayName,
    String? phoneNumber,
    bool? phoneVerified,
    bool? documentsUploaded,
    bool? paymentMethodSetup,
    String? preferredGroupType,
    OnboardingStep? currentStep,
  }) {
    return OnboardingData(
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      documentsUploaded: documentsUploaded ?? this.documentsUploaded,
      paymentMethodSetup: paymentMethodSetup ?? this.paymentMethodSetup,
      preferredGroupType: preferredGroupType ?? this.preferredGroupType,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  bool get isComplete {
    return phoneVerified &&
        documentsUploaded &&
        paymentMethodSetup &&
        displayName.isNotEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'phoneVerified': phoneVerified,
      'documentsUploaded': documentsUploaded,
      'paymentMethodSetup': paymentMethodSetup,
      'preferredGroupType': preferredGroupType,
      'currentStep': currentStep.name,
    };
  }

  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    return OnboardingData(
      displayName: json['displayName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      documentsUploaded: json['documentsUploaded'] as bool? ?? false,
      paymentMethodSetup: json['paymentMethodSetup'] as bool? ?? false,
      preferredGroupType: json['preferredGroupType'] as String? ?? '',
      currentStep: OnboardingStep.values.firstWhere(
        (e) => e.name == json['currentStep'],
        orElse: () => OnboardingStep.welcome,
      ),
    );
  }
}

class OnboardingProgress {
  const OnboardingProgress({
    required this.completedSteps,
    required this.totalSteps,
    required this.currentStep,
    required this.isComplete,
  });

  final int completedSteps;
  final int totalSteps;
  final OnboardingStep currentStep;
  final bool isComplete;

  double get progressPercentage =>
      totalSteps > 0 ? completedSteps / totalSteps : 0.0;

  OnboardingProgress copyWith({
    int? completedSteps,
    int? totalSteps,
    OnboardingStep? currentStep,
    bool? isComplete,
  }) {
    return OnboardingProgress(
      completedSteps: completedSteps ?? this.completedSteps,
      totalSteps: totalSteps ?? this.totalSteps,
      currentStep: currentStep ?? this.currentStep,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}
