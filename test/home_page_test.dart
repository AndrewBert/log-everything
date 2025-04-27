// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';
import 'dart:developer'; // <-- Import for log
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart';
import 'package:myapp/pages/cubit/home_page_state.dart';
import 'package:myapp/pages/home_page.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/pages/cubit/home_page_cubit.dart';
import 'package:myapp/widgets/entries_list.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_state.dart';

// Import the generated mocks
import 'mocks.mocks.dart';

// --- Test Scope ---
class HomePageTestScope {
  // Mocks
  late MockEntryCubit mockEntryCubit;
  late MockVoiceInputCubit mockVoiceInputCubit;
  late MockHomePageCubit mockHomeScreenCubit;

  // Stream Controllers for simulating state changes
  late StreamController<EntryState> entryStateController;
  late StreamController<VoiceInputState> voiceInputStateController;
  late StreamController<HomePageState> homeScreenStateController;

  // Test Data
  static const initialEntryState = EntryState();
  static const initialVoiceInputState = VoiceInputState();
  static const initialHomeScreenState = HomePageState();
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
  static final loadingEntryState = initialEntryState.copyWith(
    isLoading: true,
    displayListItems: [tempEntry],
  );
  static final finalEntryState = initialEntryState.copyWith(
    isLoading: false,
    displayListItems: [finalEntry],
    categories: ['Misc'],
  );
  // Use isRecording based on actual VoiceInputState
  static final recordingState = initialVoiceInputState.copyWith(
    isRecording: true,
  );

  // Test Data for Entries
  static final entry1 = Entry(
    text: 'Entry today 1',
    timestamp: DateTime(2025, 4, 25, 14, 30, 0), // Today
    category: 'Misc',
  );
  static final entry2 = Entry(
    text: 'Entry today 2',
    timestamp: DateTime(2025, 4, 25, 10, 15, 0), // Today
    category: 'Work',
  );
  static final entry3 = Entry(
    text: 'Entry yesterday',
    timestamp: DateTime(2025, 4, 24, 16, 0, 0), // Yesterday
    category: 'Personal',
  );
  static final entry4 = Entry(
    text: 'Entry older',
    timestamp: DateTime(2025, 4, 22, 9, 0, 0), // Older
    category: 'Misc',
  );

  // Manually construct the expected display list WITH headers
  static final expectedDisplayListWithHeaders = [
    DateTime.now(), // Today Header
    entry1,
    entry2,
    DateTime.now().subtract(Duration(days: 1)), // Yesterday Header
    entry3,
    DateTime(2025, 4, 22), // Older Header
    entry4,
  ];

  static final entryStateWithItems = initialEntryState.copyWith(
    // Use the correctly constructed list
    displayListItems: expectedDisplayListWithHeaders,
    categories: ['Misc', 'Work', 'Personal'],
  );

  // Widget Under Test Setup
  late Widget widgetUnderTest;

  HomePageTestScope() {
    // Initialize mocks
    mockEntryCubit = MockEntryCubit();
    mockVoiceInputCubit = MockVoiceInputCubit();
    mockHomeScreenCubit = MockHomePageCubit();

    // Initialize Stream Controllers
    entryStateController = StreamController<EntryState>.broadcast();
    voiceInputStateController = StreamController<VoiceInputState>.broadcast();
    homeScreenStateController = StreamController<HomePageState>.broadcast();

    // Stub initial states and streams
    _stubInitialStatesAndStreams();

    // Build the widget tree
    widgetUnderTest = MultiBlocProvider(
      providers: [
        BlocProvider<EntryCubit>.value(value: mockEntryCubit),
        BlocProvider<VoiceInputCubit>.value(value: mockVoiceInputCubit),
        BlocProvider<HomePageCubit>.value(value: mockHomeScreenCubit),
      ],
      child: MaterialApp(home: HomePage()),
    );
  }

  void _stubInitialStatesAndStreams() {
    // Stub initial state getters
    when(mockEntryCubit.state).thenReturn(initialEntryState);
    when(mockVoiceInputCubit.state).thenReturn(initialVoiceInputState);
    when(mockHomeScreenCubit.state).thenReturn(initialHomeScreenState);

    // Stub streams
    when(mockEntryCubit.stream).thenAnswer((_) => entryStateController.stream);
    when(
      mockVoiceInputCubit.stream,
    ).thenAnswer((_) => voiceInputStateController.stream);
    when(
      mockHomeScreenCubit.stream,
    ).thenAnswer((_) => homeScreenStateController.stream);
  }

  // --- Mocking Helpers ---

  void stubAddEntrySequence() {
    // Stub the addEntry method call itself
    when(mockEntryCubit.addEntry(testEntryText)).thenAnswer((_) async {
      log('Mock addEntry called with: $testEntryText');

      // 1. Emit Loading State
      log('Mock emitting loading state: $loadingEntryState');
      when(
        mockEntryCubit.state,
      ).thenReturn(loadingEntryState); // Update state getter
      entryStateController.add(loadingEntryState); // Emit via stream

      // 2. Simulate processing delay and emit Final State
      await Future.delayed(
        const Duration(milliseconds: 50),
      ); // Simulate async work
      log('Mock emitting final state: $finalEntryState');
      when(
        mockEntryCubit.state,
      ).thenReturn(finalEntryState); // Update state getter
      entryStateController.add(finalEntryState); // Emit via stream
    });
  }

  void stubStartRecordingEmitsRecordingState() {
    // Stub the startRecording method to emit the recording state
    when(mockVoiceInputCubit.startRecording()).thenAnswer((_) async {
      log('Mock startRecording called.');
      // Update the state getter first
      when(mockVoiceInputCubit.state).thenReturn(recordingState);
      // Emit the state via the stream
      voiceInputStateController.add(recordingState);
      log('Mock emitting recording state: $recordingState');
    });
  }

  // Method to clean up resources
  void dispose() {
    entryStateController.close();
    voiceInputStateController.close();
    homeScreenStateController.close();
  }

  // Modify this method to ONLY stub the state getter
  void stubEntryCubitStateWithItems() {
    when(mockEntryCubit.state).thenReturn(entryStateWithItems);
    log('Mock EntryCubit .state getter stubbed with items.');
    // DO NOT emit via stream here for initial display tests
  }
}

// --- Test Main ---
void main() {
  // Ensure Flutter bindings are initialized for widget testing
  TestWidgetsFlutterBinding.ensureInitialized();

  // Declare the scope variable
  late HomePageTestScope scope;

  // Set up the scope before each test
  setUp(() {
    scope = HomePageTestScope();
  });

  // Clean up resources after each test
  tearDown(() {
    scope.dispose();
  });

  group('HomePage Widget Tests', () {
    group('Add Text Entry', () {
      testWidgets('should add entry to list when text is entered and sent', (
        WidgetTester tester,
      ) async {
        // GIVEN: The necessary mocks and initial state are set up
        _givenAddEntryStubs(scope);
        await _givenHomePageIsDisplayed(tester, scope);

        // WHEN: The user enters text and taps send
        await _whenTextIsEntered(tester, HomePageTestScope.testEntryText);
        await _whenSendButtonIsTapped(tester);

        // THEN: The entry should be processed and displayed
        _thenAddEntryIsCalled(scope, HomePageTestScope.testEntryText);
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
        _givenVoiceInputStartsRecording(scope);
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
        // GIVEN: EntryCubit has entries
        _givenEntriesAreAvailable(scope);
        // Settle needed for list to build
        await _givenHomePageIsDisplayed(tester, scope, settle: true);

        // THEN: Verify entries are displayed with correct text and time format
        _thenEntryIsDisplayed(tester, HomePageTestScope.entry1.text, '14:30');
        _thenEntryIsDisplayed(tester, HomePageTestScope.entry2.text, '10:15');
        _thenEntryIsDisplayed(tester, HomePageTestScope.entry3.text, '16:00');
        _thenEntryIsDisplayed(tester, HomePageTestScope.entry4.text, '09:00');
      });

      testWidgets('should display correct date headers', (
        WidgetTester tester,
      ) async {
        _givenEntriesAreAvailable(scope);
        await _givenHomePageIsDisplayed(tester, scope);

        _thenDateHeaderIsDisplayed(tester, 'Today');
        _thenDateHeaderIsDisplayed(tester, 'Yesterday');
        _thenDateHeaderIsDisplayed(tester, 'Apr 22, 2025');
      });
    });

    // Add more groups and tests here following the same pattern
    // e.g., group('Category Management', () { ... });
    // e.g., group('Error Handling', () { ... });
  });
}

// --- GIVEN ---

void _givenAddEntryStubs(HomePageTestScope scope) {
  scope.stubAddEntrySequence();
  log('GIVEN: Add entry sequence stubbed.');
}

Future<void> _givenHomePageIsDisplayed(
  WidgetTester tester,
  HomePageTestScope scope, {
  bool settle = true, // Add optional parameter
}) async {
  await tester.pumpWidget(scope.widgetUnderTest);
  if (settle) {
    await tester.pumpAndSettle(); // Add pumpAndSettle
  }
  log('GIVEN: HomePage is displayed.');
  log('Initial mockEntryCubit state: ${scope.mockEntryCubit.state}');
  log('Initial mockVoiceInputCubit state: ${scope.mockVoiceInputCubit.state}');
  log('Initial mockHomeScreenCubit state: ${scope.mockHomeScreenCubit.state}');
}

void _givenVoiceInputStartsRecording(HomePageTestScope scope) {
  // Set up the mock behavior for starting recording
  scope.stubStartRecordingEmitsRecordingState();
  log('GIVEN: Voice input stubbed to emit recording state.');
}

void _givenEntriesAreAvailable(HomePageTestScope scope) {
  // Stub BOTH the state getter AND emit the initial state via stream
  when(
    scope.mockEntryCubit.state,
  ).thenReturn(HomePageTestScope.entryStateWithItems);
  scope.entryStateController.add(HomePageTestScope.entryStateWithItems);
  log(
    'GIVEN: Entries are available in EntryCubit state AND emitted via stream.',
  );
}

// --- WHEN ---

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

void _thenAddEntryIsCalled(HomePageTestScope scope, String text) {
  verify(scope.mockEntryCubit.addEntry(text)).called(1);
  log('THEN: mockEntryCubit.addEntry("$text") verified.');
}

Future<void> _thenEntryIsDisplayedInList(
  WidgetTester tester,
  String text,
) async {
  // It might take a moment for the list to update after state changes
  // await tester.pumpAndSettle(); // Ensure UI updates are complete

  final listFinder = find.byType(EntriesList);
  expect(listFinder, findsOneWidget, reason: 'Could not find EntriesList');

  final textFinder = find.descendant(of: listFinder, matching: find.text(text));

  expect(
    textFinder,
    findsOneWidget,
    reason: 'Expected text "$text" not found in EntriesList',
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

void _thenDateHeaderIsDisplayed(WidgetTester tester, String headerText) {
  expect(
    find.text(headerText),
    findsOneWidget, // Use findsOneWidget or findsWidgets depending on grouping
    reason: 'Date header "$headerText" not found',
  );
  log('THEN: Date header "$headerText" is displayed.');
}
