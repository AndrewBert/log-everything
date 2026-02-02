import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/onboarding/cubit/onboarding_cubit.dart';
import 'package:myapp/onboarding/widgets/welcome_step.dart';
import 'package:myapp/utils/onboarding_keys.dart';

import '../mocks.mocks.dart';
import '../helpers/auth_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockOnboardingCubit mockOnboardingCubit;
  late StreamController<OnboardingState> stateController;

  setUp(() {
    mockOnboardingCubit = MockOnboardingCubit();
    stateController = StreamController<OnboardingState>.broadcast();
  });

  tearDown(() {
    stateController.close();
  });

  Widget buildTestWidget(OnboardingState state) {
    when(mockOnboardingCubit.state).thenReturn(state);
    when(mockOnboardingCubit.stream).thenAnswer((_) => stateController.stream);

    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<OnboardingCubit>.value(
          value: mockOnboardingCubit,
          child: const WelcomeStep(),
        ),
      ),
    );
  }

  void emitState(OnboardingState state) {
    when(mockOnboardingCubit.state).thenReturn(state);
    stateController.add(state);
  }

  group('WelcomeStep - Sign-In Section Visibility', () {
    testWidgets('shows sign-in section on welcome step', (tester) async {
      // Given: User is on welcome step, not signed in
      const state = OnboardingState();

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Sign-in section is visible
      expect(find.text('Already have an account?'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsOneWidget);
    });

    testWidgets('shows "or" divider between features and sign-in', (tester) async {
      // Given: User is on welcome step
      const state = OnboardingState();

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: "or" divider is visible
      expect(find.text('or'), findsOneWidget);
    });
  });

  group('WelcomeStep - Google Sign-In', () {
    testWidgets('tapping Google sign-in button triggers signInWithGoogle', (tester) async {
      // Given: User is on welcome step
      const state = OnboardingState();
      await tester.pumpWidget(buildTestWidget(state));

      // CP: Scroll down to make sign-in button visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pump();

      // When: User taps Google sign-in button
      await tester.tap(find.byKey(OnboardingKeys.signInWithGoogleButton));
      await tester.pump();

      // Then: signInWithGoogle is called on the cubit
      verify(mockOnboardingCubit.signInWithGoogle()).called(1);
    });

    testWidgets('shows loading indicator during sign-in', (tester) async {
      // Given: Sign-in is in progress
      const state = OnboardingState(isSigningIn: true);

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Loading indicator is shown
      expect(find.byKey(OnboardingKeys.signInLoadingIndicator), findsOneWidget);

      // And: Sign-in buttons are not visible
      expect(find.byKey(OnboardingKeys.signInWithGoogleButton), findsNothing);
    });

    testWidgets('hides loading and shows buttons when sign-in completes', (tester) async {
      // Given: Sign-in is in progress
      const loadingState = OnboardingState(isSigningIn: true);
      await tester.pumpWidget(buildTestWidget(loadingState));

      expect(find.byKey(OnboardingKeys.signInLoadingIndicator), findsOneWidget);

      // When: Sign-in completes (state changes)
      const completedState = OnboardingState(isSigningIn: false);
      emitState(completedState);
      await tester.pumpAndSettle();

      // Then: Loading indicator is hidden and buttons are visible
      expect(find.byKey(OnboardingKeys.signInLoadingIndicator), findsNothing);
      expect(find.byKey(OnboardingKeys.signInWithGoogleButton), findsOneWidget);
    });
  });

  group('WelcomeStep - Error Handling', () {
    testWidgets('displays error message when auth fails', (tester) async {
      // Given: Auth failed with error message
      const state = OnboardingState(authErrorMessage: 'Sign in failed. Please try again.');

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Error container is visible
      expect(find.byKey(OnboardingKeys.authErrorContainer), findsOneWidget);

      // And: Error message text is shown
      expect(find.text('Sign in failed. Please try again.'), findsOneWidget);
    });

    testWidgets('tapping dismiss clears error message', (tester) async {
      // Given: Auth failed with error message
      const state = OnboardingState(authErrorMessage: 'Sign in failed.');
      await tester.pumpWidget(buildTestWidget(state));

      // CP: Scroll down to make error message visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pump();

      // When: User taps dismiss button
      await tester.tap(find.byKey(OnboardingKeys.authErrorDismissButton));
      await tester.pump();

      // Then: clearAuthError is called on the cubit
      verify(mockOnboardingCubit.clearAuthError()).called(1);
    });

    testWidgets('error message disappears when cleared', (tester) async {
      // Given: Error message is displayed
      const errorState = OnboardingState(authErrorMessage: 'Sign in failed.');
      await tester.pumpWidget(buildTestWidget(errorState));

      expect(find.text('Sign in failed.'), findsOneWidget);

      // When: Error is cleared (state changes)
      const clearedState = OnboardingState();
      emitState(clearedState);
      await tester.pumpAndSettle();

      // Then: Error message is no longer visible
      expect(find.text('Sign in failed.'), findsNothing);
    });
  });

  group('WelcomeStep - Signed In State', () {
    testWidgets('hides sign-in section entirely when user is authenticated', (tester) async {
      // Given: User signed in during onboarding
      final state = OnboardingState(signedInUser: AuthTestData.testUser);

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Sign-in section is completely hidden (no confirmation, no buttons)
      expect(find.byKey(OnboardingKeys.signInWithGoogleButton), findsNothing);
      expect(find.text('Already have an account?'), findsNothing);
      expect(find.textContaining('Signed in as'), findsNothing);
    });
  });

  group('WelcomeStep - State Transitions', () {
    testWidgets('transitions from not signed in to signing in', (tester) async {
      // Given: User is not signed in
      const initialState = OnboardingState();
      await tester.pumpWidget(buildTestWidget(initialState));

      // CP: Scroll down to see the sign-in section
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.byKey(OnboardingKeys.signInWithGoogleButton), findsOneWidget);
      expect(find.byKey(OnboardingKeys.signInLoadingIndicator), findsNothing);

      // When: Sign-in starts
      const signingInState = OnboardingState(isSigningIn: true);
      emitState(signingInState);
      // CP: Use pump() instead of pumpAndSettle() because CircularProgressIndicator animates indefinitely
      await tester.pump();

      // Then: Loading indicator appears
      expect(find.byKey(OnboardingKeys.signInLoadingIndicator), findsOneWidget);
      expect(find.byKey(OnboardingKeys.signInWithGoogleButton), findsNothing);
    });

    testWidgets('transitions from signing in to signed in', (tester) async {
      // Given: Sign-in is in progress
      const signingInState = OnboardingState(isSigningIn: true);
      await tester.pumpWidget(buildTestWidget(signingInState));

      // CP: Scroll down to see the sign-in section
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.byKey(OnboardingKeys.signInLoadingIndicator), findsOneWidget);

      // When: Sign-in completes successfully
      final signedInState = OnboardingState(
        isSigningIn: false,
        signedInUser: AuthTestData.testUser,
      );
      emitState(signedInState);
      await tester.pumpAndSettle();

      // Then: Sign-in section disappears entirely
      expect(find.byKey(OnboardingKeys.signInLoadingIndicator), findsNothing);
      expect(find.byKey(OnboardingKeys.signInWithGoogleButton), findsNothing);
      expect(find.text('Already have an account?'), findsNothing);
    });

    testWidgets('transitions from signing in to error', (tester) async {
      // Given: Sign-in is in progress
      const signingInState = OnboardingState(isSigningIn: true);
      await tester.pumpWidget(buildTestWidget(signingInState));

      // CP: Scroll down to see the sign-in section
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pump();

      expect(find.byKey(OnboardingKeys.signInLoadingIndicator), findsOneWidget);

      // When: Sign-in fails
      const errorState = OnboardingState(
        isSigningIn: false,
        authErrorMessage: 'Network error occurred',
      );
      emitState(errorState);
      await tester.pumpAndSettle();

      // Then: Error message is shown and buttons reappear
      expect(find.byKey(OnboardingKeys.authErrorContainer), findsOneWidget);
      expect(find.byKey(OnboardingKeys.signInWithGoogleButton), findsOneWidget);
      expect(find.byKey(OnboardingKeys.signInLoadingIndicator), findsNothing);
    });
  });
}
