// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:developer'; // <-- Import for log
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Add these imports for path_provider mocking
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/pages/home_page.dart';
import 'package:myapp/utils/logger.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/pages/cubit/home_page_cubit.dart';
import 'package:myapp/widgets/entries_list.dart';

// Import base, shell, registrar, and mocks
// import 'test_scope_base.dart'; // Not using yet
// import 'widget_test_shell.dart'; // Not using yet
import 'mock_path_provider_platform.dart';
import 'test_di_registrar.dart'; // Import the DI setup function
import 'mocks.mocks.dart';
import 'package:myapp/locator.dart';
import 'package:permission_handler/permission_handler.dart'; // Import PermissionStatus
import 'package:record/record.dart'; // Ensure RecordState is imported if needed

// --- Test Scope ---
class HomePageTestScope {
  // Mocks for DEPENDENCIES
  late MockEntryRepository mockEntryRepository;
  late MockSpeechService mockSpeechService;
  late MockAudioRecorder mockAudioRecorder;
  late MockPermissionService mockPermissionService;
  // Add mocks for HomePageCubit dependencies if needed
  // late MockSharedPreferences mockSharedPreferences;
  // late MockPackageInfo mockPackageInfo;

  // REMOVED: Mock Cubits and Stream Controllers
  // late MockEntryCubit mockEntryCubit;
  // late MockVoiceInputCubit mockVoiceInputCubit;
  // late MockHomeScreenCubit mockHomeScreenCubit;
  // late StreamController<EntryState> entryStateController;
  // late StreamController<VoiceInputState> voiceInputStateController;
  // late StreamController<HomePageState> homeScreenStateController;

  // Test Data (can remain mostly the same)
  static const testEntryText = 'Test entry 1';
  static final timestamp = DateTime(2025, 4, 25, 12, 0, 0);

  // Test Data for Entries (Make dates relative to now)
  static final now = DateTime.now();
  static final today = DateTime(now.year, now.month, now.day);
  static final yesterday = today.subtract(const Duration(days: 1));
  static final twoDaysAgo = today.subtract(const Duration(days: 2));

  static final entryToday1 = Entry(
    text: 'Entry today 1',
    timestamp: today.add(const Duration(hours: 14, minutes: 30)), // Today 14:30
    category: 'Misc',
  );
  static final entryToday2 = Entry(
    text: 'Entry today 2',
    timestamp: today.add(const Duration(hours: 10, minutes: 15)), // Today 10:15
    category: 'Work',
  );
  static final entryYesterday = Entry(
    text: 'Entry yesterday',
    timestamp: yesterday.add(const Duration(hours: 16)), // Yesterday 16:00
    category: 'Personal',
  );
  static final entryOlder = Entry(
    text: 'Entry older',
    timestamp: twoDaysAgo.add(const Duration(hours: 9)), // Two days ago 09:00
    category: 'Misc',
  );

  // Keep this list for verifying repository calls, maybe not for state.
  static final rawEntriesList = [
    entryToday1,
    entryToday2,
    entryYesterday,
    entryOlder,
  ];
  static final categoriesList = ['Misc', 'Work', 'Personal'];

  // Widget Under Test Setup
  late Widget widgetUnderTest;

  HomePageTestScope() {
    // Initialize mocks for dependencies
    mockEntryRepository = MockEntryRepository();
    mockSpeechService = MockSpeechService();
    mockAudioRecorder = MockAudioRecorder();
    // Add stub for onStateChanged right after initialization
    when(
      mockAudioRecorder.onStateChanged(),
    ).thenAnswer((_) => Stream<RecordState>.empty());
    mockPermissionService = MockPermissionService();
    // Add mocks for HomePageCubit dependencies if needed
    // mockSharedPreferences = MockSharedPreferences(); // etc.

    // Build the widget tree with REAL Cubits
    widgetUnderTest = MultiBlocProvider(
      providers: [
        // Provide REAL Cubits. They will get mocked dependencies via locator.
        BlocProvider<EntryCubit>(
          // EntryCubit constructor needs entryRepository, which it gets from locator
          create:
              (context) =>
                  EntryCubit(entryRepository: locator<EntryRepository>()),
        ),
        BlocProvider<VoiceInputCubit>(
          // VoiceInputCubit constructor needs EntryCubit, which it can get from context
          // It also gets its other dependencies (AudioRecorder, SpeechService, EntryRepository) via locator
          create:
              (context) =>
                  VoiceInputCubit(entryCubit: context.read<EntryCubit>()),
        ),
        BlocProvider<HomePageCubit>(
          // HomePageCubit gets its dependencies (PackageInfo, SharedPreferences) via locator
          create: (context) => HomePageCubit(),
        ),
      ],
      // Wrap with MaterialApp (minimal shell for now)
      child: MaterialApp(home: HomePage()),
    );
  }

  // --- Mocking Helpers (Now mock dependencies, not Cubit state) ---

  // Example: Stubbing repository for adding entry
  void stubAddEntrySuccess() {
    // Assume addEntry returns the updated list
    when(mockEntryRepository.addEntry(testEntryText)).thenAnswer((_) async {
      log('Mock EntryRepository addEntry called with: $testEntryText');
      // Return a list including the new entry (or based on repo logic)
      // Let's simulate adding the finalEntry from previous setup
      final finalEntry = Entry(
        text: testEntryText,
        timestamp: timestamp, // Use static timestamp
        category: 'Misc',
        isNew: true,
      );
      return [finalEntry]; // Return list with the new entry
    });
    // Also stub currentEntries and currentCategories if needed after add
    // These might be called by the Cubit to rebuild its state
    when(mockEntryRepository.currentEntries).thenAnswer((_) {
      log('Mock EntryRepository currentEntries called (after add)');
      final finalEntry = Entry(
        text: testEntryText,
        timestamp: timestamp,
        category: 'Misc',
        isNew: true,
      );
      return [finalEntry];
    });
    when(mockEntryRepository.currentCategories).thenAnswer((_) {
      log('Mock EntryRepository currentCategories called (after add)');
      return ['Misc'];
    });
  }

  // Example: Stubbing repository for initial entries
  void stubRepositoryWithInitialEntries() {
    when(mockEntryRepository.initialize()).thenAnswer((_) async {
      log('Mock EntryRepository initialize called.');
    });
    when(mockEntryRepository.currentEntries).thenAnswer((_) {
      log('Mock EntryRepository currentEntries called (initial)');
      return rawEntriesList;
    });
    when(mockEntryRepository.currentCategories).thenAnswer((_) {
      log('Mock EntryRepository currentCategories called (initial)');
      return categoriesList;
    });
  }

  // Example: Stubbing permission status
  void stubPermissionGranted() {
    when(
      mockPermissionService.getMicrophoneStatus(),
    ).thenAnswer((_) async => PermissionStatus.granted);
    when(
      mockPermissionService.requestMicrophonePermission(),
    ).thenAnswer((_) async => PermissionStatus.granted);
    log('Mock PermissionService stubbed to return granted.');
  }

  // Example: Stubbing voice recording start
  void stubStartRecordingSuccess() {
    // Mock recorder start
    when(mockAudioRecorder.start(any, path: anyNamed('path'))).thenAnswer((
      invocation, // Add invocation parameter
    ) async {
      // Add logging HERE
      AppLogger.debug(
        '[Test Mock] mockAudioRecorder.start called. Path: ${invocation.namedArguments[#path]}',
      );
      // Ensure it completes successfully (no return value needed for Future<void>)
      return Future.value(); // Explicitly return a completed void future
    });
    // Mock recorder state if needed
    when(mockAudioRecorder.isRecording()).thenAnswer((_) async => true);
    // Mock recorder stop (needed for toggle/stop)
    when(mockAudioRecorder.stop()).thenAnswer((_) async {
      log('Mock AudioRecorder stop called.');
      return 'fake/path/recording.m4a'; // Return a fake path
    });
  }

  // Example: Stubbing transcription success
  void stubTranscriptionSuccess(String resultText) {
    when(
      mockSpeechService.transcribeAudio(any, language: anyNamed('language')),
    ).thenAnswer((invocation) async {
      final path = invocation.positionalArguments[0];
      log('Mock SpeechService transcribeAudio called with path: $path');
      return resultText;
    });
  }

  // REMOVED: stubAddEntrySequence
  // REMOVED: stubStartRecordingEmitsRecordingState
  // REMOVED: stubEntryCubitStateWithItems

  // Keep dispose for potential future use, but GetIt reset is main cleanup
  Future<void> dispose() async {
    // custom cleanup if needed
  }
}

// --- Test Main (Adjust setUp and tearDown) ---
void main() {
  // Ensure Flutter bindings are initialized
  TestWidgetsFlutterBinding.ensureInitialized();

  late HomePageTestScope scope;

  // Use async setUp to initialize DI and mock platform channels
  setUp(() async {
    // --- Mock path_provider ---
    // Create an instance of the mock platform implementation
    final mockPathProvider = MockPathProviderPlatform();
    // Set this mock instance as the one to be used by the path_provider package
    PathProviderPlatform.instance = mockPathProvider;
    log('Mock PathProviderPlatform set up.');
    // --- End Mock path_provider ---

    scope = HomePageTestScope();
    // Initialize DI with the mocks created in the scope constructor
    await setupTestDependencies(
      entryRepository: scope.mockEntryRepository,
      speechService: scope.mockSpeechService,
      audioRecorder: scope.mockAudioRecorder,
      permissionService: scope.mockPermissionService,
    );
    // Stub initial states needed for most tests
    scope.stubRepositoryWithInitialEntries();
    scope.stubPermissionGranted();
  });

  // Clean up resources after each test
  tearDown(() async {
    // Reset GetIt locator
    await locator.reset();
    // Call scope dispose if it has custom logic
    await scope.dispose();
    // Reset the platform interface after tests
    // Use null check or a default implementation if available
    // PathProviderPlatform.instance = MethodChannelPathProvider(); // Or similar default if exists
  });

  group('HomePage Widget Tests', () {
    group('Add Text Entry', () {
      testWidgets('should add entry to list when text is entered and sent', (
        WidgetTester tester,
      ) async {
        // GIVEN: Stub the repository response for adding an entry
        // Note: Initial entries are already stubbed in setUp
        scope.stubAddEntrySuccess();
        // Stub transcription as well, in case voice input state interferes
        scope.stubTranscriptionSuccess('transcribed text');

        await _givenHomePageIsDisplayed(tester, scope);

        // WHEN: The user enters text and taps send
        await _whenTextIsEntered(tester, HomePageTestScope.testEntryText);
        await _whenSendButtonIsTapped(tester);

        // THEN: Verify the repository method was called
        verify(
          scope.mockEntryRepository.addEntry(HomePageTestScope.testEntryText),
        ).called(1);

        // THEN: The entry should be processed and displayed by the REAL cubit
        // Need pumpAndSettle for the Cubit to process and UI to update
        await tester.pumpAndSettle();
        await _thenEntryIsDisplayedInList(
          tester,
          HomePageTestScope.testEntryText,
        );
        _thenTextFieldIsCleared(tester);
      });
    });

    group('Initial State', () {
      testWidgets('should display initial UI elements correctly', (
        WidgetTester tester,
      ) async {
        // GIVEN: HomePage is displayed with initial mock states (from setUp)
        await _givenHomePageIsDisplayed(tester, scope);

        // THEN: Verify essential UI elements are present, like the first entry
        // Check if the text from the first entry in our mock data is displayed
        expect(
          find.text(HomePageTestScope.entryToday1.text),
          findsOneWidget,
          reason: 'First initial entry text should be displayed',
        );
        // Check for the input field
        expect(
          find.byType(TextField),
          findsOneWidget,
          reason: 'Input TextField should be present',
        );
        // Check for the mic button
        expect(
          find.byIcon(Icons.mic),
          findsOneWidget,
          reason: 'Mic button should be present initially',
        );
      });
    });

    group('Voice Input', () {
      testWidgets('should show stop_circle icon when mic button is tapped', (
        WidgetTester tester,
      ) async {
        // GIVEN: Stub recorder start (Permission already stubbed in setUp)
        scope.stubStartRecordingSuccess();
        await _givenHomePageIsDisplayed(
          tester,
          scope,
          // Don't settle yet, allow button tap to trigger state change
          settle: false, // Keep settle: false here
        );
        // Pump once after initial display to ensure cubit initialization (like permission check) completes
        await tester.pump();
        log('[Test] Pumped once after initial display for cubit init.');

        // WHEN: The microphone button is tapped
        await _whenMicButtonIsTapped(tester); // This calls pumpAndSettle

        // THEN: Verify the stop_circle_outlined icon is displayed
        _thenStopCircleIconIsDisplayed(tester);
        // Verify recorder start was called
        verify(
          scope.mockAudioRecorder.start(any, path: anyNamed('path')),
        ).called(1);
        // Verify permission status was checked (at least once during init or start)
        verify(
          scope.mockPermissionService.getMicrophoneStatus(),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets(
        'should call stop and transcribe when stop button is tapped',
        (WidgetTester tester) async {
          // GIVEN: Recording is started (Permission granted in setUp)
          scope.stubStartRecordingSuccess();
          const transcribedText = 'This is the transcribed text';
          scope.stubTranscriptionSuccess(transcribedText);
          await _givenHomePageIsDisplayed(tester, scope, settle: false);
          await tester.pump(); // Pump for init
          await _whenMicButtonIsTapped(
            tester,
          ); // Start recording (calls pumpAndSettle)
          _thenStopCircleIconIsDisplayed(tester); // Verify recording started

          // WHEN: The stop button (same as mic button when recording) is tapped
          await _whenStopButtonIsTapped(tester); // Calls pump()

          // THEN: Verify recorder stop was called
          verify(scope.mockAudioRecorder.stop()).called(1);

          // THEN: Verify transcription was called
          // Need pumpAndSettle for async transcription call
          await tester.pumpAndSettle();
          verify(
            scope.mockSpeechService.transcribeAudio(
              any, // Path is checked in stub
              language: 'en',
            ),
          ).called(1);

          // THEN: Verify the icon reverts to mic
          _thenMicIconIsDisplayed(tester);

          // THEN: Verify transcribed text is appended to the text field
          _thenTextFieldContains(tester, transcribedText);
        },
      );

      // TODO: Add tests for voice input state changes (listening, processing, success, error)
      // TODO: Add test for combining text and voice
    });

    group('Displaying Entries', () {
      testWidgets('should display entries with correct text and time', (
        WidgetTester tester,
      ) async {
        // GIVEN: EntryCubit gets initial entries from stubbed repository (in setUp)
        // await _givenHomePageIsDisplayed(tester, scope, settle: true);
        // Pump the widget initially
        await tester.pumpWidget(scope.widgetUnderTest);
        // Wait for async operations like repository init and cubit processing
        await tester.pumpAndSettle();

        // THEN: Verify entries are displayed with correct text and time format
        _thenEntryIsDisplayed(
          tester,
          HomePageTestScope.entryToday1.text, // Use renamed var
          '14:30',
        );
        _thenEntryIsDisplayed(
          tester,
          HomePageTestScope.entryToday2.text, // Use renamed var
          '10:15',
        );
        _thenEntryIsDisplayed(
          tester,
          HomePageTestScope.entryYesterday.text, // Use renamed var
          '16:00',
        );
        _thenEntryIsDisplayed(
          tester,
          HomePageTestScope.entryOlder.text, // Use renamed var
          '09:00',
        );
      });

      testWidgets('should display correct date headers', (
        WidgetTester tester,
      ) async {
        // GIVEN: HomePage is displayed with initial entries spanning multiple days (from setUp)
        await _givenHomePageIsDisplayed(tester, scope);

        // THEN: Verify the date headers appear correctly above their respective entries

        // Find headers and first entry of each group
        final todayHeaderFinder = find.text('Today');
        final yesterdayHeaderFinder = find.text('Yesterday');
        // Use DateFormat consistent with the app's _formatDateHeader logic
        final olderDateHeaderFinder = find.text(
          DateFormat.yMMMd().format(HomePageTestScope.entryOlder.timestamp),
        );

        final firstTodayEntryFinder = find.text(
          HomePageTestScope.entryToday1.text,
        );
        final firstYesterdayEntryFinder = find.text(
          HomePageTestScope.entryYesterday.text,
        );
        final firstOlderEntryFinder = find.text(
          HomePageTestScope.entryOlder.text,
        );

        // Verify headers exist
        expect(
          todayHeaderFinder,
          findsOneWidget,
          reason: '"Today" header not found',
        );
        expect(
          yesterdayHeaderFinder,
          findsOneWidget,
          reason: '"Yesterday" header not found',
        );
        expect(
          olderDateHeaderFinder,
          findsOneWidget,
          reason: 'Older date header not found',
        );

        // Verify entries exist
        expect(
          firstTodayEntryFinder,
          findsOneWidget,
          reason: 'First entry for today not found',
        );
        expect(
          firstYesterdayEntryFinder,
          findsOneWidget,
          reason: 'First entry for yesterday not found',
        );
        expect(
          firstOlderEntryFinder,
          findsOneWidget,
          reason: 'First entry for older date not found',
        );

        // Verify order (Header should come before the first entry of its group)
        // This relies on the vertical arrangement in the ListView
        final listFinder = find.byType(ListView);
        expect(listFinder, findsOneWidget);

        // Get the vertical offsets
        final todayHeaderOffset = tester.getTopLeft(todayHeaderFinder).dy;
        final firstTodayEntryOffset =
            tester.getTopLeft(firstTodayEntryFinder).dy;

        final yesterdayHeaderOffset =
            tester.getTopLeft(yesterdayHeaderFinder).dy;
        final firstYesterdayEntryOffset =
            tester.getTopLeft(firstYesterdayEntryFinder).dy;

        final olderHeaderOffset = tester.getTopLeft(olderDateHeaderFinder).dy;
        final firstOlderEntryOffset =
            tester.getTopLeft(firstOlderEntryFinder).dy;

        // Assert vertical order
        expect(
          todayHeaderOffset,
          lessThan(firstTodayEntryOffset),
          reason: '"Today" header should be above its first entry',
        );
        expect(
          yesterdayHeaderOffset,
          lessThan(firstYesterdayEntryOffset),
          reason: '"Yesterday" header should be above its first entry',
        );
        expect(
          olderHeaderOffset,
          lessThan(firstOlderEntryOffset),
          reason: 'Older date header should be above its first entry',
        );

        log('THEN: Date headers are displayed correctly above their entries.');
      });
    });

    // Add more groups and tests here following the same pattern
    // e.g., group('Category Management', () { ... });
    // e.g., group('Error Handling', () { ... });
  });
}

// --- GIVEN ---

Future<void> _givenHomePageIsDisplayed(
  WidgetTester tester,
  HomePageTestScope scope, {
  bool settle = true, // Add optional parameter
}) async {
  await tester.pumpWidget(scope.widgetUnderTest);
  if (settle) {
    // Pump and settle is often needed after initial pump
    // to allow Cubits to initialize and process initial state
    await tester.pumpAndSettle();
    log('GIVEN: HomePage is displayed and settled.');
  } else {
    log('GIVEN: HomePage is displayed (widget pumped, not settled).');
  }
  // Log initial state from REAL cubits if needed (requires accessing them)
  // log('Initial EntryCubit state: ${scope.locate<EntryCubit>().state}');
  // log('Initial VoiceInputCubit state: ${scope.locate<VoiceInputCubit>().state}');
}

Future<void> _whenTextIsEntered(WidgetTester tester, String text) async {
  final inputFinder = find.byType(TextField);
  expect(inputFinder, findsOneWidget, reason: 'Could not find TextField');
  await tester.enterText(inputFinder, text);
  await tester.pump(); // Allow text field controller to update
  log('WHEN: Text "$text" entered.');
}

Future<void> _whenSendButtonIsTapped(WidgetTester tester) async {
  final sendButtonFinder = find.byIcon(Icons.send_rounded);
  expect(
    sendButtonFinder,
    findsOneWidget,
    reason: 'Could not find Send Button',
  );
  await tester.tap(sendButtonFinder);
  // Pump and settle to allow all animations and async operations (like state changes) to complete
  await tester.pumpAndSettle();
  log('WHEN: Send button tapped.');
}

Future<void> _whenMicButtonIsTapped(WidgetTester tester) async {
  // Assuming the mic button is an IconButton with Icons.mic
  // Adjust the finder if your implementation is different
  final micButtonFinder = find.byIcon(Icons.mic);
  expect(micButtonFinder, findsOneWidget, reason: 'Could not find Mic Button');
  await tester.tap(micButtonFinder);
  await tester.pumpAndSettle(); // Allow any animations or state changes
  log('WHEN: Mic button tapped.');
}

Future<void> _whenStopButtonIsTapped(WidgetTester tester) async {
  // The stop button is the same physical button as the mic button, but with a different icon
  final stopButtonFinder = find.byIcon(Icons.stop_circle_outlined);
  expect(
    stopButtonFinder,
    findsOneWidget,
    reason: 'Could not find Stop Button (stop_circle_outlined icon)',
  );
  await tester.tap(stopButtonFinder);
  // Don't settle here immediately, allow transcription call verification later
  await tester.pump();
  log('WHEN: Stop button tapped.');
}

// --- THEN ---

Future<void> _thenEntryIsDisplayedInList(
  WidgetTester tester,
  String text,
) async {
  // It might take a moment for the list to update after state changes
  // Ensure UI updates are complete
  await tester.pumpAndSettle();

  final listFinder = find.byType(EntriesList);
  expect(listFinder, findsOneWidget, reason: 'Could not find EntriesList');

  final textFinder = find.descendant(of: listFinder, matching: find.text(text));

  expect(
    textFinder,
    findsOneWidget,
    reason: 'Expected text "$text" not found in EntriesList after interaction',
  );
  log('THEN: Entry "$text" is displayed in the list.');
}

void _thenTextFieldIsCleared(WidgetTester tester) {
  final inputFinder = find.byType(TextField);
  final textField = tester.widget<TextField>(inputFinder);
  expect(
    textField.controller?.text,
    isEmpty,
    reason: 'TextField was not cleared',
  );
  log('THEN: TextField is cleared.');
}

void _thenStopCircleIconIsDisplayed(WidgetTester tester) {
  // Verify that the icon changed from mic to stop_circle_outlined
  expect(
    find.byIcon(Icons.mic),
    findsNothing,
    reason: 'Mic icon should not be present',
  );
  expect(
    find.byIcon(Icons.stop_circle_outlined), // Correct icon
    findsOneWidget,
    reason: 'Stop circle icon should be displayed',
  );
  log('THEN: Stop circle icon is displayed, indicating recording started.');
}

void _thenMicIconIsDisplayed(WidgetTester tester) {
  expect(
    find.byIcon(Icons.stop_circle_outlined),
    findsNothing,
    reason: 'Stop circle icon should not be present',
  );
  expect(
    find.byIcon(Icons.mic),
    findsOneWidget,
    reason: 'Mic icon should be displayed after stopping',
  );
  log('THEN: Mic icon is displayed.');
}

void _thenTextFieldContains(WidgetTester tester, String text) {
  final inputFinder = find.byType(TextField);
  final textField = tester.widget<TextField>(inputFinder);
  expect(
    textField.controller?.text,
    contains(text),
    reason: 'TextField should contain "$text"',
  );
  log('THEN: TextField contains "$text".');
}

void _thenEntryIsDisplayed(WidgetTester tester, String text, String time) {
  final entryTextFinder = find.text(text);
  final entryTimeFinder = find.text(time);

  // Find the specific list item containing the text
  final entryListItemFinder = find.ancestor(
    of: entryTextFinder,
    matching: find.byType(ListTile), // Adjust if using a different widget
  );

  expect(
    entryTextFinder,
    findsOneWidget,
    reason: 'Entry text "$text" not found',
  );
  // Check that the time is within the same list item as the text
  expect(
    find.descendant(of: entryListItemFinder, matching: entryTimeFinder),
    findsOneWidget,
    reason: 'Time "$time" for entry "$text" not found or not in same item',
  );
  log('THEN: Entry "$text" at "$time" is displayed.');
}
