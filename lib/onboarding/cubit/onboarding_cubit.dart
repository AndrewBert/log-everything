import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../entry/cubit/entry_cubit.dart';
import '../../entry/repository/entry_repository.dart';
import '../../services/firestore_sync_service.dart';
import '../../settings/services/auth_service.dart';
import '../../utils/logger.dart';
import '../model/model.dart';

part 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  final SharedPreferences _prefs;
  final EntryCubit _entryCubit;
  final AuthService _authService;
  final FirestoreSyncService _firestoreSyncService;
  final EntryRepository _entryRepository;

  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _onboardingProgressKey = 'onboarding_progress';

  OnboardingCubit({
    required SharedPreferences sharedPreferences,
    required EntryCubit entryCubit,
    required AuthService authService,
    required FirestoreSyncService firestoreSyncService,
    required EntryRepository entryRepository,
  }) : _prefs = sharedPreferences,
       _entryCubit = entryCubit,
       _authService = authService,
       _firestoreSyncService = firestoreSyncService,
       _entryRepository = entryRepository,
       super(const OnboardingState()) {
    _loadProgress();
  }

  void _loadProgress() {
    try {
      final stepIndex = _prefs.getInt(_onboardingProgressKey) ?? 0;
      final step = OnboardingStep.values[stepIndex.clamp(0, OnboardingStep.values.length - 1)];

      emit(state.copyWith(currentStep: step, currentStepIndex: stepIndex));

      AppLogger.info('[OnboardingCubit] Loaded progress: step $stepIndex ($step)');
    } catch (e) {
      AppLogger.error('[OnboardingCubit] Error loading progress: $e');
    }
  }

  Future<void> _saveProgress() async {
    try {
      await _prefs.setInt(_onboardingProgressKey, state.currentStepIndex);
      AppLogger.info('[OnboardingCubit] Saved progress: step ${state.currentStepIndex}');
    } catch (e) {
      AppLogger.error('[OnboardingCubit] Error saving progress: $e');
    }
  }

  bool isOnboardingCompleted() {
    return _prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> nextStep() async {
    if (state.isLoading || state.isLastStep) return;

    final nextStepIndex = state.currentStepIndex + 1;
    final nextStep = OnboardingStep.values[nextStepIndex];

    emit(state.copyWith(currentStep: nextStep, currentStepIndex: nextStepIndex, clearErrorMessage: true));

    await _saveProgress();
    AppLogger.info('[OnboardingCubit] Advanced to step $nextStepIndex ($nextStep)');
  }

  Future<void> previousStep() async {
    if (state.isLoading || state.isFirstStep) return;

    final prevStepIndex = state.currentStepIndex - 1;
    final prevStep = OnboardingStep.values[prevStepIndex];

    emit(state.copyWith(currentStep: prevStep, currentStepIndex: prevStepIndex, clearErrorMessage: true));

    await _saveProgress();
    AppLogger.info('[OnboardingCubit] Went back to step $prevStepIndex ($prevStep)');
  }

  void toggleCategorySelection(String category) {
    final currentSelected = List<String>.from(state.selectedCategories);

    if (currentSelected.contains(category)) {
      currentSelected.remove(category);
    } else {
      currentSelected.add(category);
    }

    emit(state.copyWith(selectedCategories: currentSelected));
    AppLogger.info('[OnboardingCubit] Category selection updated: $currentSelected');
  }

  Future<void> addCustomCategory(String categoryName) async {
    if (categoryName.trim().isEmpty) return;

    final trimmedName = categoryName.trim();

    // CP: Add to selected categories if not already present
    final currentSelected = List<String>.from(state.selectedCategories);
    if (!currentSelected.contains(trimmedName)) {
      currentSelected.add(trimmedName);
    }

    // CP: Add to suggested categories for display
    final currentSuggested = List<String>.from(state.suggestedCategories);
    if (!currentSuggested.contains(trimmedName)) {
      currentSuggested.add(trimmedName);
    }

    emit(state.copyWith(selectedCategories: currentSelected, suggestedCategories: currentSuggested));

    AppLogger.info('[OnboardingCubit] Added custom category: $trimmedName');
  }

  Future<void> completeOnboarding() async {
    try {
      emit(state.copyWith(isLoading: true));

      // CP: Add selected categories to the entry cubit
      for (final categoryName in state.selectedCategories) {
        await _entryCubit.addCustomCategory(categoryName);
      }

      // CP: Mark onboarding as completed
      await _prefs.setBool(_onboardingCompletedKey, true);
      await _prefs.remove(_onboardingProgressKey); // CP: Clear progress

      emit(state.copyWith(currentStep: OnboardingStep.completed, isLoading: false));

      AppLogger.info('[OnboardingCubit] Onboarding completed with ${state.selectedCategories.length} categories');
    } catch (e) {
      AppLogger.error('[OnboardingCubit] Error completing onboarding: $e');
      emit(state.copyWith(isLoading: false, errorMessage: 'Failed to complete onboarding. Please try again.'));
    }
  }

  void clearError() {
    emit(state.copyWith(clearErrorMessage: true));
  }

  void clearAuthError() {
    emit(state.copyWith(clearAuthError: true));
  }

  // CP: Sign in with Google during onboarding
  Future<void> signInWithGoogle() async {
    await _performSignIn(() => _authService.signInWithGoogle());
  }

  // CP: Sign in with Apple during onboarding
  Future<void> signInWithApple() async {
    await _performSignIn(() => _authService.signInWithApple());
  }

  // CP: Common sign-in logic for both providers
  Future<void> _performSignIn(Future<AuthUser> Function() signInMethod) async {
    if (state.isSigningIn) return;

    emit(state.copyWith(isSigningIn: true, clearAuthError: true));

    try {
      final user = await signInMethod();
      AppLogger.info('[OnboardingCubit] Sign-in successful: ${user.email}');

      await _checkForCloudDataAndComplete(user);
    } on AuthCancelledException {
      // CP: User cancelled - just clear signing in state, no error message
      AppLogger.info('[OnboardingCubit] Sign-in cancelled by user');
      emit(state.copyWith(isSigningIn: false));
    } on AuthException catch (e) {
      AppLogger.error('[OnboardingCubit] Sign-in failed', error: e);
      emit(state.copyWith(isSigningIn: false, authErrorMessage: e.message));
    } catch (e) {
      AppLogger.error('[OnboardingCubit] Unexpected sign-in error', error: e);
      emit(state.copyWith(
        isSigningIn: false,
        authErrorMessage: 'Sign in failed. Please try again.',
      ));
    }
  }

  // CP: Check if user has cloud data and complete onboarding if so
  Future<void> _checkForCloudDataAndComplete(AuthUser user) async {
    try {
      final cloudEntries = await _firestoreSyncService.fetchEntries(user.uid);

      if (cloudEntries.isNotEmpty) {
        // CP: Has data → restore and skip onboarding
        AppLogger.info('[OnboardingCubit] Found ${cloudEntries.length} cloud entries, skipping onboarding');
        await _entryRepository.onUserSignedIn(user.uid);
        await _prefs.setBool(_onboardingCompletedKey, true);
        await _prefs.remove(_onboardingProgressKey);
        emit(state.copyWith(
          currentStep: OnboardingStep.completed,
          isSigningIn: false,
          signedInUser: user,
        ));
      } else {
        // CP: No data → continue onboarding (but stay signed in)
        AppLogger.info('[OnboardingCubit] No cloud data found, continuing onboarding');
        await _entryRepository.onUserSignedIn(user.uid);
        emit(state.copyWith(isSigningIn: false, signedInUser: user));
      }
    } catch (e) {
      AppLogger.error('[OnboardingCubit] Error checking cloud data', error: e);
      emit(state.copyWith(
        isSigningIn: false,
        authErrorMessage: 'Failed to check cloud data. Please try again.',
      ));
    }
  }

  Future<void> resetOnboarding() async {
    try {
      await _prefs.remove(_onboardingCompletedKey);
      await _prefs.remove(_onboardingProgressKey);

      emit(const OnboardingState());
      AppLogger.info('[OnboardingCubit] Onboarding reset');
    } catch (e) {
      AppLogger.error('[OnboardingCubit] Error resetting onboarding: $e');
    }
  }
}
