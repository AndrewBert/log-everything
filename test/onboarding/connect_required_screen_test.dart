import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/widgets/connect_required_screen.dart';
import 'package:myapp/utils/widget_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool retryCalled;

  setUp(() {
    retryCalled = false;
  });

  Widget buildTestWidget({
    bool isRetrying = false,
    String? errorMessage,
  }) {
    return MaterialApp(
      home: ConnectRequiredScreen(
        onRetry: () => retryCalled = true,
        isRetrying: isRetrying,
        errorMessage: errorMessage,
      ),
    );
  }

  group('ConnectRequiredScreen - Default Offline State', () {
    testWidgets('shows "Connection Required" text and wifi-off icon when offline', (tester) async {
      // Given: Default offline state (no error message)

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget());

      // Then: "Connection Required" heading is shown
      expect(find.text('Connection Required'), findsOneWidget);

      // And: wifi_off icon is displayed
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);

      // And: Default instruction text is shown
      expect(find.text('Please connect to the internet to get started'), findsOneWidget);
    });
  });

  group('ConnectRequiredScreen - Error State', () {
    testWidgets('shows error message and error icon when errorMessage is provided', (tester) async {
      // Given: A bootstrap failure error message
      const errorMsg = 'Authentication failed. Please try again.';

      // When: Widget is displayed with error
      await tester.pumpWidget(buildTestWidget(errorMessage: errorMsg));

      // Then: "Setup Failed" heading is shown instead of "Connection Required"
      expect(find.text('Setup Failed'), findsOneWidget);
      expect(find.text('Connection Required'), findsNothing);

      // And: error_outline icon is displayed instead of wifi_off
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsNothing);

      // And: The error message text is shown
      expect(find.text(errorMsg), findsOneWidget);
    });
  });

  group('ConnectRequiredScreen - Retry Button', () {
    testWidgets('tapping retry button calls onRetry callback', (tester) async {
      // Given: Widget is displayed in default state
      await tester.pumpWidget(buildTestWidget());

      // When: User taps the retry button
      await tester.tap(find.byKey(connectRequiredRetryButton));
      await tester.pump();

      // Then: onRetry callback was called
      expect(retryCalled, isTrue);
    });

    testWidgets('retry button is disabled with spinner when isRetrying is true', (tester) async {
      // Given: Widget is in retrying state

      // When: Widget is displayed with isRetrying: true
      await tester.pumpWidget(buildTestWidget(isRetrying: true));

      // Then: Retry button is disabled (onPressed is null)
      final button = tester.widget<ElevatedButton>(find.byKey(connectRequiredRetryButton));
      expect(button.onPressed, isNull);

      // And: CircularProgressIndicator is shown instead of "Retry" text
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('retry button shows "Retry" text when not retrying', (tester) async {
      // Given: Widget is not in retrying state

      // When: Widget is displayed
      await tester.pumpWidget(buildTestWidget());

      // Then: "Retry" text is shown on the button
      expect(find.text('Retry'), findsOneWidget);

      // And: No spinner is shown
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
