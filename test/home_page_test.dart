// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart';
import 'package:myapp/entry/repository/entry_repository.dart'; // Import REAL repository
import 'package:myapp/pages/home_page.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/pages/cubit/home_page_cubit.dart';
import 'package:myapp/widgets/entries_list.dart';
import 'package:myapp/services/audio_recorder_service.dart'; // Import service
import 'package:myapp/services/entry_persistence_service.dart'; // Import service
import 'package:myapp/services/ai_categorization_service.dart'; // Import service

import 'mock_path_provider_platform.dart';
import 'test_di_registrar.dart';
import 'mocks.mocks.dart'; // Import generated mocks
import 'package:myapp/locator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// --- Test Scope ---
class HomePageTestScope {
  // Mocks for DEPENDENCIES of the REAL repository and other components
  late MockEntryPersistenceService mockPersistenceService;
  late MockAiCategorizationService mockAiService;
  late MockSpeechService mockSpeechService;
  late MockAudioRecorderService mockAudioRecorderService; // Use service mock
  late MockPermissionService mockPermissionService;

  // Test Data (remains the same)
  static const testEntryText = 'Test entry 1';
  static final timestamp = DateTime(2025, 4, 25, 12, 0, 0);
  static final now = DateTime.now();
  static final today = DateTime(now.year, now.month, now.day);
  static final yesterday = today.subtract(const Duration(days: 1));
  static final twoDaysAgo = today.subtract(const Duration(days: 2));

  static final entryToday1 = Entry(
    text: 'Entry today 1',
    timestamp: today.add(const Duration(hours: 14, minutes: 30)),
    category: 'Misc',
  );
  static final entryToday2 = Entry(
    text: 'Entry today 2',
    timestamp: today.add(const Duration(hours: 10, minutes: 15)),
    category: 'Work',
  );
  static final entryYesterday = Entry(
    text: 'Entry yesterday',
    timestamp: yesterday.add(const Duration(hours: 16)),
    category: 'Personal',
  );
  static final entryOlder = Entry(
    text: 'Entry older',
    timestamp: twoDaysAgo.add(const Duration(hours: 9)),
    category: 'Misc',
  );

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
    // Instantiate mocks for dependencies
    mockPersistenceService = MockEntryPersistenceService();
    mockAiService = MockAiCategorizationService();
    mockSpeechService = MockSpeechService();
    mockAudioRecorderService = MockAudioRecorderService();
    when(
      mockAudioRecorderService.onStateChanged(), // Stub stream for service
    ).thenAnswer((_) => Stream<RecordState>.empty());
    mockPermissionService = MockPermissionService();

    // Widget setup uses BlocProviders which will get dependencies from locator
    widgetUnderTest = MultiBlocProvider(
      providers: [
        BlocProvider<EntryCubit>(
          create:
              (context) => EntryCubit(
                // EntryCubit gets REAL repository from locator
                entryRepository: locator<EntryRepository>(),
              ),
        ),
        BlocProvider<VoiceInputCubit>(
          create:
              (context) => VoiceInputCubit(
                entryCubit: context.read<EntryCubit>(),
                // VoiceInputCubit gets its dependencies (incl. AudioRecorderService) from locator
              ),
        ),
        BlocProvider<HomePageCubit>(create: (context) => HomePageCubit()),
      ],
      child: MaterialApp(home: HomePage()),
    );
  }

  // --- Mocking Helpers ---

  // Remove stubAddEntrySuccess (verification will be on persistence)

  // Rename and update to stub PERSISTENCE service
  void stubPersistenceWithInitialEntries() {
    // Stub loading methods used by the REAL repository's initialize()
    when(
      mockPersistenceService.loadEntries(),
    ).thenAnswer((_) async => List.from(rawEntriesList)); // Return a copy
    when(
      mockPersistenceService.loadCategories(),
    ).thenAnswer((_) async => List.from(categoriesList)); // Return a copy

    // Stub saving methods to succeed (important for delete/add/update)
    when(mockPersistenceService.saveEntries(any)).thenAnswer((_) async {});
    when(mockPersistenceService.saveCategories(any)).thenAnswer((_) async {});
  }

  void stubPermissionGranted() {
    when(
      mockPermissionService.getMicrophoneStatus(),
    ).thenAnswer((_) async => PermissionStatus.granted);
    when(
      mockPermissionService.requestMicrophonePermission(),
    ).thenAnswer((_) async => PermissionStatus.granted);
  }

  // Update to stub AudioRecorderSERVICE
  void stubStartRecordingSuccess() {
    when(
      mockAudioRecorderService.generateRecordingPath(),
    ).thenAnswer((_) async => 'fake/path/recording.m4a');
    when(
      mockAudioRecorderService.start(any, path: anyNamed('path')),
    ).thenAnswer((_) async => Future.value());
    when(mockAudioRecorderService.isRecording()).thenAnswer((_) async => true);
    when(
      mockAudioRecorderService.stop(),
    ).thenAnswer((_) async => 'fake/path/recording.m4a');
  }

  void stubTranscriptionSuccess(String resultText) {
    when(
      mockSpeechService.transcribeAudio(any, language: anyNamed('language')),
    ).thenAnswer((_) async => resultText);
  }

  Future<void> dispose() async {
    // custom cleanup if needed
  }
}

// --- Helper Function for fakeAsync ---

/// Runs a callback using FakeAsync.run while continually pumping the
/// microtask queue.
Future<T> runFakeAsync<T>(Future<T> Function(FakeAsync time) f) async {
  return FakeAsync().run((FakeAsync time) async {
    bool pump = true;
    final Future<T> future = f(time).whenComplete(() => pump = false);
    while (pump) {
      time.flushMicrotasks();
    }
    return future;
  });
}

// --- Test Main ---
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HomePageTestScope scope;

  setUp(() async {
    final mockPathProvider = MockPathProviderPlatform();
    PathProviderPlatform.instance = mockPathProvider;

    scope = HomePageTestScope();
    // Update call to setupTestDependencies
    await setupTestDependencies(
      persistenceService: scope.mockPersistenceService, // Pass persistence mock
      aiService: scope.mockAiService, // Pass AI mock
      speechService: scope.mockSpeechService,
      audioRecorder: scope.mockAudioRecorderService, // Pass service mock
      permissionService: scope.mockPermissionService,
    );
    // Use the updated stubbing method
    scope.stubPersistenceWithInitialEntries();
    scope.stubPermissionGranted();

    // IMPORTANT: Ensure repository is initialized IF the cubit doesn't do it.
    // If EntryCubit calls repository.initialize() on creation, this is fine.
    // Otherwise, you might need:
    // await locator<EntryRepository>().initialize();
    // Make sure stubs are set *before* this.
  });

  tearDown(() async {
    await locator.reset();
    await scope.dispose();
  });

  group('HomePage Widget Tests', () {
    // Group: Tests related to the initial state and display of the list
    group('Initialization and Display', () {
      testWidgets('should display initial UI elements correctly', (
        WidgetTester tester,
      ) async {
        // GIVEN
        await _givenHomePageIsDisplayed(tester, scope);

        // THEN
        expect(
          find.text(HomePageTestScope.entryToday1.text),
          findsOneWidget,
          reason: 'First initial entry text should be displayed',
        );
        expect(
          find.byType(TextField),
          findsOneWidget,
          reason: 'Input TextField should be present',
        );
        expect(
          find.byIcon(Icons.mic),
          findsOneWidget,
          reason: 'Mic button should be present initially',
        );
      });

      testWidgets('should display entries with correct text and time', (
        WidgetTester tester,
      ) async {
        // GIVEN
        await _givenHomePageIsDisplayed(tester, scope);

        // THEN
        _thenEntryIsDisplayed(
          tester,
          HomePageTestScope.entryToday1.text,
          '14:30',
        );
        _thenEntryIsDisplayed(
          tester,
          HomePageTestScope.entryToday2.text,
          '10:15',
        );
        _thenEntryIsDisplayed(
          tester,
          HomePageTestScope.entryYesterday.text,
          '16:00',
        );
        _thenEntryIsDisplayed(
          tester,
          HomePageTestScope.entryOlder.text,
          '09:00',
        );
      });

      testWidgets('should display correct date headers', (
        WidgetTester tester,
      ) async {
        // GIVEN
        await _givenHomePageIsDisplayed(tester, scope);

        // THEN
        final todayHeaderFinder = find.text('Today');
        final yesterdayHeaderFinder = find.text('Yesterday');
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

        expect(todayHeaderFinder, findsOneWidget);
        expect(yesterdayHeaderFinder, findsOneWidget);
        expect(olderDateHeaderFinder, findsOneWidget);
        expect(firstTodayEntryFinder, findsOneWidget);
        expect(firstYesterdayEntryFinder, findsOneWidget);
        expect(firstOlderEntryFinder, findsOneWidget);

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

        expect(todayHeaderOffset, lessThan(firstTodayEntryOffset));
        expect(yesterdayHeaderOffset, lessThan(firstYesterdayEntryOffset));
        expect(olderHeaderOffset, lessThan(firstOlderEntryOffset));
      });
    }); // End of Initialization and Display group

    // Group: Tests related to adding entries via the text field
    group('Text Entry Input', () {
      testWidgets('should add entry and save via persistence', (
        WidgetTester tester,
      ) async {
        // GIVEN
        scope.stubTranscriptionSuccess(
          'transcribed text',
        ); // Avoid interference
        await _givenHomePageIsDisplayed(tester, scope);

        final newEntryText = HomePageTestScope.testEntryText;
        final initialListLength = HomePageTestScope.rawEntriesList.length;

        // WHEN
        await _whenTextIsEntered(tester, newEntryText);
        await _whenSendButtonIsTapped(tester);

        // THEN: Verify UI
        await _thenEntryIsDisplayedInList(tester, newEntryText);
        _thenTextFieldIsCleared(tester);

        // THEN: Verify Persistence Call
        verify(
          scope.mockPersistenceService.saveEntries(
            // Use argThat with a predicate to check the saved list
            argThat(
              predicate<List<Entry>>((savedList) {
                // 1. Check if the list length increased by one
                if (savedList.length != initialListLength + 1) {
                  return false;
                }
                // 2. Find the newly added entry
                final addedEntry = savedList.firstWhere(
                  (entry) => entry.text == newEntryText && entry.isNew,
                  orElse:
                      () => Entry(
                        text: '',
                        timestamp: DateTime(0),
                        category: '',
                      ), // Return dummy if not found
                );

                // 3. Verify properties of the added entry
                final bool textMatches = addedEntry.text == newEntryText;
                final bool categoryMatches =
                    addedEntry.category == 'Misc'; // Assuming default category
                final bool isNewMatches = addedEntry.isNew == true;
                final bool timestampValid = addedEntry.timestamp.isAfter(
                  DateTime(1970),
                );

                if (!textMatches ||
                    !categoryMatches ||
                    !isNewMatches ||
                    !timestampValid) {
                  return false;
                }

                // 4. Optional: Verify other entries are still present
                final originalEntry1Present = savedList.any(
                  (e) => e.text == HomePageTestScope.entryToday1.text,
                );
                if (!originalEntry1Present) {
                  return false;
                }

                return true;
              }),
            ),
          ),
        ).called(1);
      });
    }); // End of Text Entry Input group

    // Group: Tests related to voice input functionality
    group('Voice Input', () {
      testWidgets('should show stop_circle icon when mic button is tapped', (
        WidgetTester tester,
      ) async {
        // GIVEN
        scope.stubStartRecordingSuccess(); // Uses service mock now
        await _givenHomePageIsDisplayed(tester, scope, settle: false);
        await tester.pump(); // Allow cubit init

        // WHEN
        await _whenMicButtonIsTapped(tester);

        // THEN
        _thenStopCircleIconIsDisplayed(tester);
        // Verify service methods
        verify(
          scope.mockAudioRecorderService.generateRecordingPath(),
        ).called(1);
        verify(
          scope.mockAudioRecorderService.start(any, path: anyNamed('path')),
        ).called(1);
        verify(
          scope.mockPermissionService.getMicrophoneStatus(),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets(
        'should call stop and transcribe when stop button is tapped',
        (WidgetTester tester) async {
          // GIVEN
          scope.stubStartRecordingSuccess(); // Uses service mock now
          const transcribedText = 'This is the transcribed text';
          scope.stubTranscriptionSuccess(transcribedText);
          await _givenHomePageIsDisplayed(tester, scope, settle: false);
          await tester.pump(); // Allow cubit init

          await runFakeAsync((async) async {
            // WHEN: Start recording
            await _whenMicButtonIsTapped(tester, settle: false);

            // Simulate recording time
            async.elapse(const Duration(seconds: 3));

            // WHEN: Stop recording
            await _whenStopButtonIsTapped(tester);

            // Allow transcription to process
            async.elapse(Duration.zero);
          });

          await tester.pumpAndSettle();

          // THEN: Verify interactions and UI
          // Verify service methods
          verify(
            scope.mockAudioRecorderService.generateRecordingPath(),
          ).called(1);
          verify(
            scope.mockAudioRecorderService.start(any, path: anyNamed('path')),
          ).called(1);
          verify(scope.mockAudioRecorderService.stop()).called(1);
          // Verify speech service
          verify(
            scope.mockSpeechService.transcribeAudio(any, language: 'en'),
          ).called(1);
          // Verify UI
          _thenMicIconIsDisplayed(tester);
          _thenTextFieldContains(tester, transcribedText);
        },
      );
      // Add more voice input tests here (e.g., permissions, errors, combine)
    }); // End of Voice Input group

    // Group: Tests related to interactions with items in the entry list
    group('Entry List Interactions', () {
      // Sub-group for Deletion
      group('Delete', () {
        testWidgets('should delete entry and save via persistence', (
          WidgetTester tester,
        ) async {
          // GIVEN
          await _givenHomePageIsDisplayed(tester, scope);
          final entryToDelete = HomePageTestScope.entryToday1;
          final entryToDeleteText = entryToDelete.text;
          final entryFinder = find.text(entryToDeleteText);
          expect(
            entryFinder,
            findsOneWidget,
            reason: 'Entry to delete should initially be visible',
          );

          // Prepare expected list for verification AFTER deletion
          final expectedEntriesAfterDelete = List<Entry>.from(
            HomePageTestScope.rawEntriesList,
          )..removeWhere(
            (e) =>
                e.timestamp == entryToDelete.timestamp &&
                e.text == entryToDelete.text,
          );

          // WHEN
          await _whenDeleteIconIsTappedForEntry(tester, entryToDeleteText);

          // THEN: Verify UI changes
          expect(
            entryFinder,
            findsNothing,
            reason: 'Entry should be removed from the list',
          );
          _thenSnackbarIsDisplayedWithMessage(tester, 'Entry deleted');
          _thenSnackbarHasAction(tester, 'Undo');

          // THEN: Verify Persistence Call
          verify(
            scope.mockPersistenceService.saveEntries(
              // Use argThat with equals for exact list comparison
              argThat(equals(expectedEntriesAfterDelete)),
            ),
          ).called(1);
        });

        testWidgets(
          'should restore entry and save via persistence when Undo is tapped',
          (WidgetTester tester) async {
            // GIVEN
            await _givenHomePageIsDisplayed(tester, scope);
            final entryToRestore = HomePageTestScope.entryToday1;
            final entryToRestoreText = entryToRestore.text;
            final entryFinder = find.text(entryToRestoreText);
            expect(entryFinder, findsOneWidget);

            // Delete the entry first
            await _whenDeleteIconIsTappedForEntry(tester, entryToRestoreText);
            expect(entryFinder, findsNothing);
            _thenSnackbarIsDisplayedWithMessage(tester, 'Entry deleted');

            // Prepare expected list for verification AFTER undo
            final expectedEntriesAfterUndo =
                List<Entry>.from(HomePageTestScope.rawEntriesList)
                  ..removeWhere(
                    (e) =>
                        e.timestamp == entryToRestore.timestamp &&
                        e.text == entryToRestore.text,
                  )
                  ..add(entryToRestore); // Add the original entry back

            // Clear previous interactions with saveEntries before Undo
            clearInteractions(scope.mockPersistenceService);

            // WHEN: Tap Undo
            await _whenSnackbarActionIsTapped(tester, 'Undo');

            // THEN: Verify UI
            await _thenEntryIsDisplayedInList(tester, entryToRestoreText);

            // THEN: Verify Persistence Call for the UNDO action
            verify(
              scope.mockPersistenceService.saveEntries(
                // Use argThat with equals for exact list comparison
                argThat(equals(expectedEntriesAfterUndo)),
              ),
            ).called(1);
          },
        );
      }); // End of Delete sub-group

      // Add sub-groups for Edit, Change Category etc. here
    }); // End of Entry List Interactions group
  }); // End of HomePage Widget Tests group
}

// --- GIVEN ---

Future<void> _givenHomePageIsDisplayed(
  WidgetTester tester,
  HomePageTestScope scope, {
  bool settle = true,
}) async {
  await tester.pumpWidget(scope.widgetUnderTest);
  if (settle) {
    await tester.pumpAndSettle();
  }
}

// --- WHEN ---

Future<void> _whenTextIsEntered(WidgetTester tester, String text) async {
  final inputFinder = find.byType(TextField);
  expect(inputFinder, findsOneWidget);
  await tester.enterText(inputFinder, text);
  await tester.pump();
}

Future<void> _whenSendButtonIsTapped(WidgetTester tester) async {
  final sendButtonFinder = find.byIcon(Icons.send_rounded);
  expect(sendButtonFinder, findsOneWidget);
  await tester.tap(sendButtonFinder);
  await tester.pumpAndSettle();
}

Future<void> _whenMicButtonIsTapped(
  WidgetTester tester, {
  bool settle = true,
}) async {
  final micButtonFinder = find.byIcon(Icons.mic);
  expect(micButtonFinder, findsOneWidget);
  await tester.tap(micButtonFinder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(); // Use pump instead of pumpAndSettle if settle is false
  }
}

Future<void> _whenStopButtonIsTapped(WidgetTester tester) async {
  final stopButtonFinder = find.byIcon(Icons.stop_circle_outlined);
  expect(stopButtonFinder, findsOneWidget);
  await tester.tap(stopButtonFinder);
  await tester.pump(); // Don't settle immediately
}

Future<void> _whenDeleteIconIsTappedForEntry(
  WidgetTester tester,
  String entryText,
) async {
  final entryTextFinder = find.text(entryText);
  expect(entryTextFinder, findsOneWidget);

  // Find the Card containing the text, which represents the entry item
  final entryCardFinder = find.ancestor(
    of: entryTextFinder,
    matching: find.byType(Card), // Use Card instead of EntryListItem
  );
  expect(entryCardFinder, findsOneWidget);

  // Find the delete icon *within* that specific Card
  final deleteIconFinder = find.descendant(
    of: entryCardFinder, // Search within the Card
    matching: find.byIcon(Icons.delete_outline),
  );
  expect(deleteIconFinder, findsOneWidget);

  await tester.tap(deleteIconFinder);
  await tester.pumpAndSettle(); // Allow snackbar to appear
}

Future<void> _whenSnackbarActionIsTapped(
  WidgetTester tester,
  String actionLabel,
) async {
  final snackBarFinder = find.byType(SnackBar);
  expect(snackBarFinder, findsOneWidget);

  final actionFinder = find.widgetWithText(SnackBarAction, actionLabel);
  expect(actionFinder, findsOneWidget);

  await tester.tap(actionFinder);
  await tester.pumpAndSettle(); // Allow UI to update after undo
}

// --- THEN ---

Future<void> _thenEntryIsDisplayedInList(
  WidgetTester tester,
  String text,
) async {
  await tester.pumpAndSettle(); // Ensure UI updates
  final listFinder = find.byType(EntriesList);
  expect(listFinder, findsOneWidget);
  final textFinder = find.descendant(of: listFinder, matching: find.text(text));
  expect(textFinder, findsOneWidget);
}

void _thenTextFieldIsCleared(WidgetTester tester) {
  final inputFinder = find.byType(TextField);
  final textField = tester.widget<TextField>(inputFinder);
  expect(textField.controller?.text, isEmpty);
}

void _thenStopCircleIconIsDisplayed(WidgetTester tester) {
  expect(find.byIcon(Icons.mic), findsNothing);
  expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
}

void _thenMicIconIsDisplayed(WidgetTester tester) {
  expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
  expect(find.byIcon(Icons.mic), findsOneWidget);
}

void _thenTextFieldContains(WidgetTester tester, String text) {
  final inputFinder = find.byType(TextField);
  final textField = tester.widget<TextField>(inputFinder);
  expect(textField.controller?.text, contains(text));
}

void _thenEntryIsDisplayed(WidgetTester tester, String text, String time) {
  final entryTextFinder = find.text(text);
  final entryTimeFinder = find.text(time);
  // Find the ListTile containing the entry text
  final entryListTileFinder = find.ancestor(
    of: entryTextFinder,
    matching: find.byType(ListTile), // Use ListTile instead of EntryListItem
  );
  expect(entryTextFinder, findsOneWidget);
  expect(
    find.descendant(
      of: entryListTileFinder,
      matching: entryTimeFinder,
    ), // Search within the ListTile
    findsOneWidget,
  );
}

void _thenSnackbarIsDisplayedWithMessage(WidgetTester tester, String message) {
  final snackBarFinder = find.byType(SnackBar);
  expect(snackBarFinder, findsOneWidget, reason: 'Snackbar should be visible');
  final messageFinder = find.descendant(
    of: snackBarFinder,
    matching: find.text(message),
  );
  expect(
    messageFinder,
    findsOneWidget,
    reason: 'Snackbar should contain the message "$message"',
  );
}

void _thenSnackbarHasAction(WidgetTester tester, String actionLabel) {
  final snackBarFinder = find.byType(SnackBar);
  expect(snackBarFinder, findsOneWidget);
  final actionFinder = find.widgetWithText(SnackBarAction, actionLabel);
  expect(
    actionFinder,
    findsOneWidget,
    reason: 'Snackbar should have an action button labeled "$actionLabel"',
  );
}
