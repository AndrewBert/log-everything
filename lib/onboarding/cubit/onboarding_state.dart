part of 'onboarding_cubit.dart';

enum OnboardingStep { welcome, appOverview, categoriesSetup, chatDemo, completed }

class OnboardingState extends Equatable {
  final OnboardingStep currentStep;
  final int currentStepIndex;
  final bool isLoading;
  final List<String> selectedCategories;
  final List<String> suggestedCategories;
  final String? errorMessage;
  final bool canProceed;
  // CP: Auth-related fields for sign-in during onboarding
  final bool isSigningIn;
  final AuthUser? signedInUser;
  final String? authErrorMessage;

  const OnboardingState({
    this.currentStep = OnboardingStep.welcome,
    this.currentStepIndex = 0,
    this.isLoading = false,
    this.selectedCategories = const [],
    this.isSigningIn = false,
    this.signedInUser,
    this.authErrorMessage,
    this.suggestedCategories = const [
      // CP: Work & Productivity
      'Work',
      'Projects',
      'Meetings',
      'Goals',
      'Ideas',
      'Problems',
      'Solutions',

      // CP: Personal Life
      'Personal',
      'Family',
      'Relationships',
      'Home',
      'Daily',
      'Memories',
      'Events',

      // CP: Health & Wellness
      'Health',
      'Exercise',
      'Mood',
      'Habits',

      // CP: Learning & Growth
      'Learning',
      'Books',
      'Quotes',
      'Inspiration',
      'Reflections',

      // CP: Lifestyle & Interests
      'Food',
      'Travel',
      'Hobbies',
      'Movies',
      'Music',
      'Shopping',

      // CP: Planning & Tracking
      'Finance',
      'Reminders',
      'Weekly',
      'Monthly',
      'Gratitude',
      'Dreams',

      // CP: Miscellaneous
      'Random',
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
    bool? isSigningIn,
    AuthUser? signedInUser,
    String? authErrorMessage,
    bool clearAuthError = false,
    bool clearSignedInUser = false,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isLoading: isLoading ?? this.isLoading,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      suggestedCategories: suggestedCategories ?? this.suggestedCategories,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      canProceed: canProceed ?? this.canProceed,
      isSigningIn: isSigningIn ?? this.isSigningIn,
      signedInUser: clearSignedInUser ? null : (signedInUser ?? this.signedInUser),
      authErrorMessage: clearAuthError ? null : (authErrorMessage ?? this.authErrorMessage),
    );
  }

  bool get isFirstStep => currentStepIndex == 0;
  bool get isLastStep => currentStep == OnboardingStep.completed;
  int get totalSteps => OnboardingStep.values.length - 1; // CP: Exclude completed step from total
  double get progress => currentStepIndex / (totalSteps - 1);

  // CP: Get organized category groups for UI display
  List<CategoryGroup> get categoryGroups => CategoryGroup.defaultGroups;

  @override
  List<Object?> get props => [
    currentStep,
    currentStepIndex,
    isLoading,
    selectedCategories,
    suggestedCategories,
    errorMessage,
    canProceed,
    isSigningIn,
    signedInUser,
    authErrorMessage,
  ];
}
