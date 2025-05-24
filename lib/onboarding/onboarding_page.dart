import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'cubit/onboarding_cubit.dart';
import 'widgets/welcome_step.dart';
import 'widgets/app_overview_step.dart';
import 'widgets/categories_setup_step.dart';
import 'widgets/first_entry_step.dart';
import 'widgets/chat_demo_step.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<OnboardingCubit, OnboardingState>(
          builder: (context, state) {
            return Column(
              children: [
                // CP: Progress bar
                _buildProgressBar(context, state),
                // CP: Current step content
                Expanded(child: _buildCurrentStep(context, state)),
                // CP: Navigation buttons
                _buildNavigationButtons(context, state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, OnboardingState state) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${state.currentStepIndex + 1} of ${state.totalSteps}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              Text(
                '${(state.progress * 100).round()}%',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: state.progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context, OnboardingState state) {
    switch (state.currentStep) {
      case OnboardingStep.welcome:
        return const WelcomeStep();
      case OnboardingStep.appOverview:
        return const AppOverviewStep();
      case OnboardingStep.categoriesSetup:
        return const CategoriesSetupStep();
      case OnboardingStep.firstEntry:
        return const FirstEntryStep();
      case OnboardingStep.chatDemo:
        return const ChatDemoStep();
      case OnboardingStep.completed:
        return const SizedBox.shrink(); // CP: This shouldn't be reached
    }
  }

  Widget _buildNavigationButtons(BuildContext context, OnboardingState state) {
    final cubit = context.read<OnboardingCubit>();

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // CP: Back button
          if (!state.isFirstStep)
            Expanded(
              child: OutlinedButton(
                onPressed: state.isLoading ? null : () => cubit.previousStep(),
                child: const Text('Back'),
              ),
            ),
          if (!state.isFirstStep) const SizedBox(width: 16),
          // CP: Next/Complete button
          Expanded(
            flex: state.isFirstStep ? 1 : 1,
            child: ElevatedButton(
              onPressed:
                  state.isLoading || !state.canProceed
                      ? null
                      : () => _handleNextButton(context, state),
              child:
                  state.isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(_getNextButtonText(state)),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNextButton(BuildContext context, OnboardingState state) {
    final cubit = context.read<OnboardingCubit>();

    if (state.currentStep == OnboardingStep.chatDemo) {
      // CP: Last step - complete onboarding
      cubit.completeOnboarding();
    } else {
      // CP: Regular step - go to next
      cubit.nextStep();
    }
  }

  String _getNextButtonText(OnboardingState state) {
    switch (state.currentStep) {
      case OnboardingStep.welcome:
        return 'Get Started';
      case OnboardingStep.chatDemo:
        return 'Complete Setup';
      default:
        return 'Next';
    }
  }
}
