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
import 'package:myapp/pages/cubit/home_screen_state.dart';
import 'package:myapp/pages/home_page.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/pages/cubit/home_screen_cubit.dart';
import 'package:myapp/widgets/entries_list.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_state.dart';

// Import the generated mocks
import 'mocks.mocks.dart';

// --- Test Scope ---
class HomePageTestScope {
  // Mocks
  late MockEntryCubit mockEntryCubit;
  late MockVoiceInputCubit mockVoiceInputCubit;
  late MockHomeScreenCubit mockHomeScreenCubit;

  // Stream Controllers for simulating state changes
  late StreamController<EntryState> entryStateController;
  late StreamController<VoiceInputState> voiceInputStateController;
  late StreamController<HomeScreenState> homeScreenStateController;

  // Test Data
  static const initialEntryState = EntryState();
  static const initialVoiceInputState = VoiceInputState();
  static const initialHomeScreenState = HomeScreenState();
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

  // Widget Under Test Setup
  late Widget widgetUnderTest;

  HomePageTestScope() {
    // Initialize mocks
    mockEntryCubit = MockEntryCubit();
    mockVoiceInputCubit = MockVoiceInputCubit();
    mockHomeScreenCubit = MockHomeScreenCubit();

    // Initialize Stream Controllers
    entryStateController = StreamController<EntryState>.broadcast();
    voiceInputStateController = StreamController<VoiceInputState>.broadcast();
    homeScreenStateController = StreamController<HomeScreenState>.broadcast();

    // Stub initial states and streams
    _stubInitialStatesAndStreams();

    // Build the widget tree
    widgetUnderTest = MultiBlocProvider(
      providers: [
        BlocProvider<EntryCubit>.value(value: mockEntryCubit),
        BlocProvider<VoiceInputCubit>.value(value: mockVoiceInputCubit),
        BlocProvider<HomeScreenCubit>.value(value: mockHomeScreenCubit),
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

  // Method to clean up resources
  void dispose() {
    entryStateController.close();
    voiceInputStateController.close();
    homeScreenStateController.close();
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

    // Add more groups and tests here following the same pattern
    // e.g., group('Voice Input', () { ... });
    // e.g., group('Category Management', () { ... });
  });
}

// --- GIVEN ---

void _givenAddEntryStubs(HomePageTestScope scope) {
  scope.stubAddEntrySequence();
  log('GIVEN: Add entry sequence stubbed.');
}

Future<void> _givenHomePageIsDisplayed(
  WidgetTester tester,
  HomePageTestScope scope,
) async {
  await tester.pumpWidget(scope.widgetUnderTest);
  // Pump and settle might be needed if there are initial async operations
  // await tester.pumpAndSettle();
  log('GIVEN: HomePage is displayed.');
  log('Initial mockEntryCubit state: ${scope.mockEntryCubit.state}');
  log('Initial mockVoiceInputCubit state: ${scope.mockVoiceInputCubit.state}');
  log('Initial mockHomeScreenCubit state: ${scope.mockHomeScreenCubit.state}');
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
