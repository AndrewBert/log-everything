// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:developer'; // <-- Import for log
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart'; // <-- Import Mockito
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart';
import 'package:myapp/entry/repository/entry_repository.dart'; // <-- Import EntryRepository
import 'package:myapp/pages/cubit/home_page_state.dart';
import 'package:myapp/pages/home_page.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/pages/cubit/home_page_cubit.dart';
import 'package:myapp/widgets/entries_list.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_state.dart';

// Import base, shell, registrar, and mocks
// import 'test_scope_base.dart'; // Not using yet
// import 'widget_test_shell.dart'; // Not using yet
import 'test_di_registrar.dart'; // Import the DI setup function
import 'mocks.mocks.dart';
import 'dart:developer'; // Keep log
import 'package:myapp/locator.dart'; // Import locator for teardown

// --- Test Scope ---
class HomePageTestScope {
  // Mocks for DEPENDENCIES
  late MockEntryRepository mockEntryRepository;
  late MockSpeechService mockSpeechService;
  late MockAudioRecorder mockAudioRecorder;
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
  static final tempEntry = Entry(
    text: testEntryText,
    timestamp: timestamp,
    category: 'Processing...',
    isNew: true,
  );
  static final finalEntry = Entry(
    text: testEntryText,
    timestamp: timestamp,
    category: 'Misc',
    isNew: true,
  );
  static final loadingEntryState = EntryState(
    isLoading: true,
    displayListItems: [tempEntry],
  );
  static final finalEntryState = EntryState(
    isLoading: false,
    displayListItems: [finalEntry],
    categories: ['Misc'],
  );
  // Use isRecording based on actual VoiceInputState
  static final recordingState = VoiceInputState(isRecording: true);

  // Test Data for Entries
  static final entryApr25_1 = Entry(
    text: 'Entry today 1',
    timestamp: DateTime(2025, 4, 25, 14, 30, 0), // Today
    category: 'Misc',
  );
  static final entryApr25_2 = Entry(
    text: 'Entry today 2',
    timestamp: DateTime(2025, 4, 25, 10, 15, 0), // Today
    category: 'Work',
  );
  static final entryApr24 = Entry(
    text: 'Entry yesterday',
    timestamp: DateTime(2025, 4, 24, 16, 0, 0), // Yesterday
    category: 'Personal',
  );
  static final entryApr22 = Entry(
    text: 'Entry older',
    timestamp: DateTime(2025, 4, 22, 9, 0, 0), // Older
    category: 'Misc',
  );
  // Keep this list for verifying repository calls, maybe not for state.
  static final rawEntriesList = [
    entryApr25_1,
    entryApr25_2,
    entryApr24,
    entryApr22,
  ];
  static final categoriesList = ['Misc', 'Work', 'Personal'];

  // Widget Under Test Setup
  late Widget widgetUnderTest;

  HomePageTestScope() {
    // Initialize mocks for dependencies
    mockEntryRepository = MockEntryRepository();
    mockSpeechService = MockSpeechService();
    mockAudioRecorder = MockAudioRecorder();
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

  // Example: Stubbing voice recording start
  void stubStartRecordingSuccess() {
    // Mock permission check if necessary (might need a wrapper service)
    // For now, assume permission is granted - Cubit checks this
    // when(mockPermissionsService.getMicrophoneStatus()).thenAnswer((_) async => PermissionStatus.granted);

    // Mock recorder start
    when(mockAudioRecorder.start(any, path: anyNamed('path'))).thenAnswer((
      _,
    ) async {
      log('Mock AudioRecorder start called.');
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

  // Use async setUp to initialize DI
  setUp(() async {
    scope = HomePageTestScope();
    // Initialize DI with the mocks created in the scope constructor
    await setupTestDependencies(
      entryRepository: scope.mockEntryRepository,
      speechService: scope.mockSpeechService,
      audioRecorder: scope.mockAudioRecorder,
      // Pass other mocks...
    );
    // Perform any other async setup needed before each test
    // e.g., stubbing initial repository state for all tests
    scope.stubRepositoryWithInitialEntries();
  });

  // Clean up resources after each test
  tearDown(() async {
    // Reset GetIt locator
    await locator.reset();
    // Call scope dispose if it has custom logic
    await scope.dispose();
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
        _thenEntryIsDisplayedInList(tester, HomePageTestScope.testEntryText);
        _thenTextFieldIsCleared(tester);
      });
    });

    group('Initial State', () {
      testWidgets('should display initial UI elements correctly', (
        WidgetTester tester,
      ) async {
        // GIVEN: HomePage is displayed with initial mock states
        await _givenHomePageIsDisplayed(tester, scope);

        // THEN: Verify essential UI elements are present
        _thenInitialUIElementsArePresent(tester);
      });
    });

    group('Voice Input', () {
      testWidgets('should show stop_circle icon when mic button is tapped', (
        WidgetTester tester,
      ) async {
        // GIVEN: Voice input is stubbed to emit recording state
        scope.stubStartRecordingSuccess(); // Use the correct helper
        await _givenHomePageIsDisplayed(
          tester,
          scope,
          settle: false,
        ); // Don't settle yet

        // WHEN: The microphone button is tapped
        await _whenMicButtonIsTapped(tester);

        // THEN: Verify the stop_circle_outlined icon is displayed
        _thenStopCircleIconIsDisplayed(tester);
      });

      // TODO: Add tests for voice input state changes (listening, processing, success, error)
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
          HomePageTestScope.entryApr25_1.text, // Use renamed var
          '14:30',
        );
        _thenEntryIsDisplayed(
          tester,
          HomePageTestScope.entryApr25_2.text, // Use renamed var
          '10:15',
        );
        _thenEntryIsDisplayed(
          tester,
          HomePageTestScope.entryApr24.text, // Use renamed var
          '16:00',
        );
        _thenEntryIsDisplayed(
          tester,
          HomePageTestScope.entryApr22.text, // Use renamed var
          '09:00',
        );
      });

      // TODO: Re-evaluate date header test without fakeAsync
      // testWidgets('should display correct date headers', ...);
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
  }
  log('GIVEN: HomePage is displayed.');
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

void _thenInitialUIElementsArePresent(WidgetTester tester) {
  expect(find.byType(TextField), findsOneWidget, reason: 'TextField not found');
  expect(
    find.byIcon(Icons.send_rounded),
    findsOneWidget,
    reason: 'Send Button not found',
  );
  expect(
    find.byIcon(Icons.mic),
    findsOneWidget,
    reason: 'Mic Button not found',
  );
  // Optionally, check if the EntriesList is initially empty or shows specific initial content
  // Example: Check for an empty list placeholder if one exists
  // expect(find.text('No entries yet'), findsOneWidget);
  log('THEN: Initial UI elements are present.');
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
