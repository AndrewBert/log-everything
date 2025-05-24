part of 'onboarding_cubit.dart';

enum OnboardingStep {
  welcome,
  appOverview,
  categoriesSetup,
  chatDemo,
  completed,
}

class OnboardingState extends Equatable {
  final OnboardingStep currentStep;
  final int currentStepIndex;
  final bool isLoading;
  final List<String> selectedCategories;
  final List<String> suggestedCategories;
  final String? errorMessage;
  final bool canProceed;

  const OnboardingState({
    this.currentStep = OnboardingStep.welcome,
    this.currentStepIndex = 0,
    this.isLoading = false,
    this.selectedCategories = const [],
    this.suggestedCategories = const [
      'Work',
      'Personal',
      'Health',
      'Learning',
      'Travel',
      'Food',
      'Exercise',
      'Family',
      'Projects',
      'Ideas',
    ],
    this.errorMessage,
    this.canProceed = true,
  });

  OnboardingState copyWith({
    OnboardingStep? currentStep,
    int? currentStepIndex,
    bool? isLoading,
    List<String>? selectedCategories,
    List<String>? suggestedCategories,
    String? errorMessage,
    bool? canProceed,
    bool clearErrorMessage = false,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isLoading: isLoading ?? this.isLoading,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      suggestedCategories: suggestedCategories ?? this.suggestedCategories,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      canProceed: canProceed ?? this.canProceed,
    );
  }

  bool get isFirstStep => currentStepIndex == 0;
  bool get isLastStep => currentStep == OnboardingStep.completed;
  int get totalSteps =>
      OnboardingStep.values.length - 1; // CP: Exclude completed step from total
  double get progress => currentStepIndex / (totalSteps - 1);

  @override
  List<Object?> get props => [
    currentStep,
    currentStepIndex,
    isLoading,
    selectedCategories,
    suggestedCategories,
    errorMessage,
    canProceed,
  ];
}
