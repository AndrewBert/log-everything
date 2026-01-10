import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/settings/cubit/settings_cubit.dart';
import 'package:myapp/settings/widgets/recovery_dialog.dart';

import '../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSettingsCubit mockSettingsCubit;

  setUp(() {
    mockSettingsCubit = MockSettingsCubit();
  });

  Widget buildTestWidget(RecoveryInfo recoveryInfo, SettingsState state) {
    when(mockSettingsCubit.state).thenReturn(state);
    when(mockSettingsCubit.stream).thenAnswer((_) => Stream.value(state));

    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<SettingsCubit>.value(
          value: mockSettingsCubit,
          child: RecoveryDialog(recoveryInfo: recoveryInfo),
        ),
      ),
    );
  }

  group('RecoveryDialog', () {
    testWidgets('displays recovery information correctly', (tester) async {
      // Given: A recovery info with entries and categories
      final recoveryInfo = RecoveryInfo(
        entryCount: 42,
        categoryCount: 5,
        snapshotCreatedAt: DateTime(2025, 1, 10, 14, 30),
      );
      final state = SettingsState(recoveryInfo: recoveryInfo);

      // When: Dialog is displayed
      await tester.pumpWidget(buildTestWidget(recoveryInfo, state));

      // Then: Title is shown
      expect(find.text('Data Recovery Available'), findsOneWidget);

      // And: Entry count is displayed
      expect(find.text('Entries'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);

      // And: Category count is displayed
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // And: Backup date is displayed
      expect(find.text('Backup created'), findsOneWidget);
      expect(find.textContaining('Jan 10, 2025'), findsOneWidget);

      // And: Both action buttons are visible
      expect(find.text('No, Continue Without'), findsOneWidget);
      expect(find.text('Restore Data'), findsOneWidget);
    });

    testWidgets('dismisses recovery when dismiss button is tapped', (tester) async {
      // Given: Dialog is displayed
      final recoveryInfo = RecoveryInfo(
        entryCount: 10,
        categoryCount: 2,
        snapshotCreatedAt: DateTime.now(),
      );
      final state = SettingsState(recoveryInfo: recoveryInfo);
      await tester.pumpWidget(buildTestWidget(recoveryInfo, state));

      // When: User taps "No, Continue Without"
      await tester.tap(find.text('No, Continue Without'));
      await tester.pumpAndSettle();

      // Then: dismissRecovery is called on the cubit
      verify(mockSettingsCubit.dismissRecovery()).called(1);
    });

    testWidgets('shows loading state when recovering', (tester) async {
      // Given: Recovery is in progress
      final recoveryInfo = RecoveryInfo(
        entryCount: 10,
        categoryCount: 2,
        snapshotCreatedAt: DateTime.now(),
      );
      final state = SettingsState(
        recoveryInfo: recoveryInfo,
        isRecovering: true,
      );

      // When: Dialog is displayed during recovery
      await tester.pumpWidget(buildTestWidget(recoveryInfo, state));

      // Then: Progress indicator is shown instead of button text
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // And: Buttons are disabled (tapping should not trigger actions)
      await tester.tap(find.text('No, Continue Without'));
      await tester.pump();
      verifyNever(mockSettingsCubit.dismissRecovery());
    });

    testWidgets('calls confirmRecovery when restore button is tapped', (tester) async {
      // Given: Dialog is displayed
      final recoveryInfo = RecoveryInfo(
        entryCount: 25,
        categoryCount: 3,
        snapshotCreatedAt: DateTime.now(),
      );
      final state = SettingsState(recoveryInfo: recoveryInfo);
      when(mockSettingsCubit.confirmRecovery()).thenAnswer((_) async {});
      await tester.pumpWidget(buildTestWidget(recoveryInfo, state));

      // When: User taps "Restore Data"
      await tester.tap(find.text('Restore Data'));
      await tester.pumpAndSettle();

      // Then: confirmRecovery is called on the cubit
      verify(mockSettingsCubit.confirmRecovery()).called(1);
    });

    testWidgets('shows warning icon in title', (tester) async {
      // Given: Dialog is displayed
      final recoveryInfo = RecoveryInfo(
        entryCount: 1,
        categoryCount: 1,
        snapshotCreatedAt: DateTime.now(),
      );
      final state = SettingsState(recoveryInfo: recoveryInfo);
      await tester.pumpWidget(buildTestWidget(recoveryInfo, state));

      // Then: Warning icon is displayed
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('displays explanatory text about data loss', (tester) async {
      // Given: Dialog is displayed
      final recoveryInfo = RecoveryInfo(
        entryCount: 15,
        categoryCount: 2,
        snapshotCreatedAt: DateTime.now(),
      );
      final state = SettingsState(recoveryInfo: recoveryInfo);
      await tester.pumpWidget(buildTestWidget(recoveryInfo, state));

      // Then: Explanatory text is shown
      expect(find.textContaining('some data may have been lost'), findsOneWidget);
      expect(find.textContaining('restore your data from this backup'), findsOneWidget);
    });
  });
}
