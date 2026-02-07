import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/settings/cubit/settings_cubit.dart';
import 'package:myapp/settings/widgets/account_section.dart';

import '../mocks.mocks.dart';
import '../helpers/auth_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSettingsCubit mockSettingsCubit;
  late StreamController<SettingsState> stateController;

  setUp(() {
    mockSettingsCubit = MockSettingsCubit();
    stateController = StreamController<SettingsState>.broadcast();
  });

  tearDown(() {
    stateController.close();
  });

  Widget buildTestWidget(SettingsState state) {
    when(mockSettingsCubit.state).thenReturn(state);
    when(mockSettingsCubit.stream).thenAnswer((_) => stateController.stream);

    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<SettingsCubit>.value(
          value: mockSettingsCubit,
          child: const AccountSection(),
        ),
      ),
    );
  }

  group('AccountSection - Anonymous User', () {
    testWidgets('anonymous user sees sign-in view, not signed-in view', (tester) async {
      // Given: Current user is anonymous (isAuthenticated returns false)
      final state = SettingsState(currentUser: AuthTestData.anonymousUser);

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Sign-in option is visible (signed-out view)
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Sync your data across devices'), findsOneWidget);
    });

    testWidgets('anonymous user does not see sign-out button', (tester) async {
      // Given: Current user is anonymous
      final state = SettingsState(currentUser: AuthTestData.anonymousUser);

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Sign out is NOT visible
      expect(find.text('Sign out'), findsNothing);

      // And: Recover lost data is NOT visible (only in signed-in view)
      expect(find.text('Recover lost data'), findsNothing);
    });

    testWidgets('anonymous user can trigger sign-in via bottom sheet', (tester) async {
      // Given: Current user is anonymous
      final state = SettingsState(currentUser: AuthTestData.anonymousUser);
      await tester.pumpWidget(buildTestWidget(state));

      // When: User taps sign in
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // Then: Sign-in options bottom sheet is shown
      expect(find.text('Sign in with'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
    });

    testWidgets('anonymous user selecting Google triggers sign-in', (tester) async {
      // Given: User is viewing sign-in options from anonymous state
      final state = SettingsState(currentUser: AuthTestData.anonymousUser);
      await tester.pumpWidget(buildTestWidget(state));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // When: User taps Google
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();

      // Then: signInWithGoogle is called on the cubit
      verify(mockSettingsCubit.signInWithGoogle()).called(1);
    });
  });
}
