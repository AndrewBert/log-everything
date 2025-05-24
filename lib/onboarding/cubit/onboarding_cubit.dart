import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../entry/cubit/entry_cubit.dart';
import '../../utils/logger.dart';

part 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  final SharedPreferences _prefs;
  final EntryCubit _entryCubit;

  static const String _onboardingCompletedKey = 'onboarding_completed';
  static const String _onboardingProgressKey = 'onboarding_progress';

  OnboardingCubit({
    required SharedPreferences sharedPreferences,
    required EntryCubit entryCubit,
  }) : _prefs = sharedPreferences,
       _entryCubit = entryCubit,
       super(const OnboardingState()) {
    _loadProgress();
  }

  void _loadProgress() {
    try {
      final stepIndex = _prefs.getInt(_onboardingProgressKey) ?? 0;
      final step =
          OnboardingStep.values[stepIndex.clamp(
            0,
            OnboardingStep.values.length - 1,
          )];

      emit(state.copyWith(currentStep: step, currentStepIndex: stepIndex));

      AppLogger.info(
        '[OnboardingCubit] Loaded progress: step $stepIndex ($step)',
      );
    } catch (e) {
      AppLogger.error('[OnboardingCubit] Error loading progress: $e');
    }
  }

  Future<void> _saveProgress() async {
    try {
      await _prefs.setInt(_onboardingProgressKey, state.currentStepIndex);
      AppLogger.info(
        '[OnboardingCubit] Saved progress: step ${state.currentStepIndex}',
      );
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

    emit(
      state.copyWith(
        currentStep: nextStep,
        currentStepIndex: nextStepIndex,
        clearErrorMessage: true,
      ),
    );

    await _saveProgress();
    AppLogger.info(
      '[OnboardingCubit] Advanced to step $nextStepIndex ($nextStep)',
    );
  }

  Future<void> previousStep() async {
    if (state.isLoading || state.isFirstStep) return;

    final prevStepIndex = state.currentStepIndex - 1;
    final prevStep = OnboardingStep.values[prevStepIndex];

    emit(
      state.copyWith(
        currentStep: prevStep,
        currentStepIndex: prevStepIndex,
        clearErrorMessage: true,
      ),
    );

    await _saveProgress();
    AppLogger.info(
      '[OnboardingCubit] Went back to step $prevStepIndex ($prevStep)',
    );
  }

  void toggleCategorySelection(String category) {
    final currentSelected = List<String>.from(state.selectedCategories);

    if (currentSelected.contains(category)) {
      currentSelected.remove(category);
    } else {
      currentSelected.add(category);
    }

    emit(state.copyWith(selectedCategories: currentSelected));
    AppLogger.info(
      '[OnboardingCubit] Category selection updated: $currentSelected',
    );
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

    emit(
      state.copyWith(
        selectedCategories: currentSelected,
        suggestedCategories: currentSuggested,
      ),
    );

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

      emit(
        state.copyWith(currentStep: OnboardingStep.completed, isLoading: false),
      );

      AppLogger.info(
        '[OnboardingCubit] Onboarding completed with ${state.selectedCategories.length} categories',
      );
    } catch (e) {
      AppLogger.error('[OnboardingCubit] Error completing onboarding: $e');
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to complete onboarding. Please try again.',
        ),
      );
    }
  }

  void clearError() {
    emit(state.copyWith(clearErrorMessage: true));
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
