import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/main.dart';
import 'package:myapp/onboarding/cubit/onboarding_cubit.dart';
import 'package:myapp/utils/widget_keys.dart';
import 'package:myapp/widgets/connect_required_screen.dart';

import '../mocks.mocks.dart';

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
      home: BlocProvider<OnboardingCubit>.value(
        value: mockOnboardingCubit,
        child: const AppRoot(),
      ),
    );
  }

  void emitState(OnboardingState state) {
    when(mockOnboardingCubit.state).thenReturn(state);
    stateController.add(state);
  }

  group('Anonymous Auth Bootstrap - ConnectRequiredScreen Routing', () {
    testWidgets('shows ConnectRequiredScreen when requiresConnection is true', (tester) async {
      // Given: Bootstrap failed due to offline first launch
      const state = OnboardingState(
        isInitializing: false,
        requiresConnection: true,
      );

      // When: AppRoot is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: ConnectRequiredScreen is shown
      expect(find.byType(ConnectRequiredScreen), findsOneWidget);

      // And: "Connection Required" text is visible
      expect(find.text('Connection Required'), findsOneWidget);
    });

    testWidgets('shows ConnectRequiredScreen with error when bootstrapError is set', (tester) async {
      // Given: Bootstrap failed with an error
      const state = OnboardingState(
        isInitializing: false,
        requiresConnection: true,
        bootstrapError: 'Authentication failed',
      );

      // When: AppRoot is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: ConnectRequiredScreen is shown with the error
      expect(find.byType(ConnectRequiredScreen), findsOneWidget);
      expect(find.text('Setup Failed'), findsOneWidget);
      expect(find.text('Authentication failed'), findsOneWidget);
    });

    testWidgets('shows onboarding when requiresConnection is false and not initializing', (tester) async {
      // Given: Bootstrap succeeded, user needs onboarding
      const state = OnboardingState(
        isInitializing: false,
        requiresConnection: false,
      );
      when(mockOnboardingCubit.isOnboardingCompleted()).thenReturn(false);

      // When: AppRoot is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: ConnectRequiredScreen is NOT shown
      expect(find.byType(ConnectRequiredScreen), findsNothing);
    });

    testWidgets('shows loading indicator when isInitializing is true', (tester) async {
      // Given: App is still initializing (default state)
      const state = OnboardingState(isInitializing: true);

      // When: AppRoot is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // And: ConnectRequiredScreen is NOT shown
      expect(find.byType(ConnectRequiredScreen), findsNothing);
    });
  });

  group('Anonymous Auth Bootstrap - Retry Flow', () {
    testWidgets('tapping retry on ConnectRequiredScreen calls retryConnection', (tester) async {
      // Given: User is on the connection required screen
      const state = OnboardingState(
        isInitializing: false,
        requiresConnection: true,
      );
      await tester.pumpWidget(buildTestWidget(state));

      // When: User taps the retry button
      await tester.tap(find.byKey(connectRequiredRetryButton));
      await tester.pump();

      // Then: retryConnection is called on the cubit
      verify(mockOnboardingCubit.retryConnection()).called(1);
    });

    testWidgets('shows loading spinner on retry button during retry', (tester) async {
      // Given: Retry is in progress
      const state = OnboardingState(
        isInitializing: false,
        requiresConnection: true,
        isRetrying: true,
      );

      // When: AppRoot is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: ConnectRequiredScreen is shown with retrying state
      expect(find.byType(ConnectRequiredScreen), findsOneWidget);

      // And: Retry button shows spinner (disabled)
      final button = tester.widget<ElevatedButton>(find.byKey(connectRequiredRetryButton));
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('transitions from connection required to onboarding after successful retry', (tester) async {
      // Given: User is on connection required screen
      const connectionState = OnboardingState(
        isInitializing: false,
        requiresConnection: true,
      );
      await tester.pumpWidget(buildTestWidget(connectionState));
      expect(find.byType(ConnectRequiredScreen), findsOneWidget);

      // When: Retry succeeds and state transitions
      const successState = OnboardingState(
        isInitializing: false,
        requiresConnection: false,
      );
      when(mockOnboardingCubit.isOnboardingCompleted()).thenReturn(false);
      emitState(successState);
      await tester.pumpAndSettle();

      // Then: ConnectRequiredScreen is no longer shown
      expect(find.byType(ConnectRequiredScreen), findsNothing);
    });
  });
}
