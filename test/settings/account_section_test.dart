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

  void emitState(SettingsState state) {
    when(mockSettingsCubit.state).thenReturn(state);
    stateController.add(state);
  }

  group('AccountSection - Signed Out View', () {
    testWidgets('shows sign in option when unauthenticated', (tester) async {
      // Given: User is not authenticated
      final state = const SettingsState();

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Sign in option is visible
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Sync your data across devices'), findsOneWidget);

      // And: Sign out option is not visible
      expect(find.text('Sign out'), findsNothing);
    });

    testWidgets('shows loading indicator during sign-in', (tester) async {
      // Given: Sign-in is in progress
      final state = const SettingsState(isSigningIn: true);

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // And: The sign in tile is disabled (trailing has spinner, not chevron)
      final signInTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('Sign in'), matching: find.byType(ListTile)),
      );
      expect(signInTile.enabled, isFalse);
    });

    testWidgets('tapping sign in shows provider options', (tester) async {
      // Given: User is not authenticated
      final state = const SettingsState();
      await tester.pumpWidget(buildTestWidget(state));

      // When: User taps sign in
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // Then: Sign in options bottom sheet is shown
      expect(find.text('Sign in with'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
    });

    testWidgets('selecting Google in bottom sheet triggers sign in', (tester) async {
      // Given: User is viewing sign in options
      final state = const SettingsState();
      await tester.pumpWidget(buildTestWidget(state));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // When: User taps Google
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();

      // Then: signInWithGoogle is called on the cubit
      verify(mockSettingsCubit.signInWithGoogle()).called(1);
    });

    testWidgets('selecting Apple in bottom sheet triggers sign in', (tester) async {
      // Given: User is viewing sign in options
      final state = const SettingsState();
      await tester.pumpWidget(buildTestWidget(state));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // When: User taps Apple
      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();

      // Then: signInWithApple is called on the cubit
      verify(mockSettingsCubit.signInWithApple()).called(1);
    });
  });

  group('AccountSection - Signed In View', () {
    testWidgets('displays user info when authenticated', (tester) async {
      // Given: User is authenticated
      final state = SettingsState(currentUser: AuthTestData.testUser);

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: User display name is shown
      expect(find.text('Test User'), findsOneWidget);

      // And: User email is shown
      expect(find.text('test@example.com'), findsOneWidget);

      // And: Sign out option is visible
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('displays fallback name when displayName is null', (tester) async {
      // Given: User has no display name
      final state = SettingsState(currentUser: AuthTestData.userMinimal);

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Fallback name "User" is shown
      expect(find.text('User'), findsOneWidget);
    });

    testWidgets('shows person icon when no photo URL', (tester) async {
      // Given: User has no photo
      final state = SettingsState(currentUser: AuthTestData.testUser);

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Person icon is shown in avatar
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('shows loading indicator during sign-out', (tester) async {
      // Given: Sign-out is in progress
      final state = SettingsState(
        currentUser: AuthTestData.testUser,
        isSigningOut: true,
      );

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Loading indicator is shown on sign out tile
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // And: Sign out tile is disabled
      final signOutTile = tester.widget<ListTile>(
        find.ancestor(of: find.text('Sign out'), matching: find.byType(ListTile)),
      );
      expect(signOutTile.enabled, isFalse);
    });

    testWidgets('tapping sign out shows confirmation dialog', (tester) async {
      // Given: User is authenticated
      final state = SettingsState(currentUser: AuthTestData.testUser);
      await tester.pumpWidget(buildTestWidget(state));

      // When: User taps sign out
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // Then: Confirmation dialog is shown
      expect(find.text('Sign out?'), findsOneWidget);
      expect(find.textContaining('safely stored in the cloud'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancelling sign out dialog keeps user signed in', (tester) async {
      // Given: User is viewing sign out confirmation
      final state = SettingsState(currentUser: AuthTestData.testUser);
      await tester.pumpWidget(buildTestWidget(state));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // When: User taps Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Then: signOut is NOT called
      verifyNever(mockSettingsCubit.signOut());

      // And: Dialog is dismissed
      expect(find.text('Sign out?'), findsNothing);
    });

    testWidgets('confirming sign out triggers sign out', (tester) async {
      // Given: User is viewing sign out confirmation
      final state = SettingsState(currentUser: AuthTestData.testUser);
      await tester.pumpWidget(buildTestWidget(state));
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      // When: User confirms sign out (tap the second "Sign out" text - the button)
      await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
      await tester.pumpAndSettle();

      // Then: signOut is called on the cubit
      verify(mockSettingsCubit.signOut()).called(1);
    });

    testWidgets('shows recover lost data option when authenticated', (tester) async {
      // Given: User is authenticated
      final state = SettingsState(currentUser: AuthTestData.testUser);

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Recover lost data option is visible
      expect(find.text('Recover lost data'), findsOneWidget);
      expect(find.text('Check for backup from previous sign-in'), findsOneWidget);
    });

    testWidgets('tapping recover lost data triggers recovery check', (tester) async {
      // Given: User is authenticated
      final state = SettingsState(currentUser: AuthTestData.testUser);
      await tester.pumpWidget(buildTestWidget(state));

      // When: User taps recover lost data
      await tester.tap(find.text('Recover lost data'));
      await tester.pumpAndSettle();

      // Then: checkForManualRecovery is called
      verify(mockSettingsCubit.checkForManualRecovery()).called(1);
    });
  });

  group('AccountSection - Export Data', () {
    testWidgets('shows export data option when signed out', (tester) async {
      // Given: User is not authenticated
      final state = const SettingsState();

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Export data option is visible
      expect(find.text('Export data'), findsOneWidget);
      expect(find.text('Save a backup of all entries'), findsOneWidget);
    });

    testWidgets('shows export data option when signed in', (tester) async {
      // Given: User is authenticated
      final state = SettingsState(currentUser: AuthTestData.testUser);

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget(state));

      // Then: Export data option is visible
      expect(find.text('Export data'), findsOneWidget);
    });
  });

  group('AccountSection - State Transitions', () {
    testWidgets('updates UI when user signs in', (tester) async {
      // Given: User is initially signed out
      final initialState = const SettingsState();
      await tester.pumpWidget(buildTestWidget(initialState));

      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Sign out'), findsNothing);

      // When: User signs in (state changes)
      final signedInState = SettingsState(currentUser: AuthTestData.testUser);
      emitState(signedInState);
      await tester.pumpAndSettle();

      // Then: UI updates to show signed in view
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
    });

    testWidgets('updates UI when user signs out', (tester) async {
      // Given: User is initially signed in
      final initialState = SettingsState(currentUser: AuthTestData.testUser);
      await tester.pumpWidget(buildTestWidget(initialState));

      expect(find.text('Sign out'), findsOneWidget);

      // When: User signs out (state changes)
      final signedOutState = const SettingsState();
      emitState(signedOutState);
      await tester.pumpAndSettle();

      // Then: UI updates to show signed out view
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Sign out'), findsNothing);
    });
  });
}
