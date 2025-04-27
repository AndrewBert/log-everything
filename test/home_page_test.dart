// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:developer'; // <-- Import for log
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart'; // <-- Import fake_async
// Add these imports for path_provider mocking
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
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

  // Test Data
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
    mockEntryRepository = MockEntryRepository();
    mockSpeechService = MockSpeechService();
    mockAudioRecorder = MockAudioRecorder();
    when(
      mockAudioRecorder.onStateChanged(),
    ).thenAnswer((_) => Stream<RecordState>.empty());
    mockPermissionService = MockPermissionService();

    widgetUnderTest = MultiBlocProvider(
      providers: [
        BlocProvider<EntryCubit>(
          create:
              (context) =>
                  EntryCubit(entryRepository: locator<EntryRepository>()),
        ),
        BlocProvider<VoiceInputCubit>(
          create:
              (context) =>
                  VoiceInputCubit(entryCubit: context.read<EntryCubit>()),
        ),
        BlocProvider<HomePageCubit>(create: (context) => HomePageCubit()),
      ],
      child: MaterialApp(home: HomePage()),
    );
  }

  // --- Mocking Helpers ---

  void stubAddEntrySuccess() {
    when(mockEntryRepository.addEntry(testEntryText)).thenAnswer((_) async {
      final finalEntry = Entry(
        text: testEntryText,
        timestamp: timestamp,
        category: 'Misc',
        isNew: true,
      );
      return [finalEntry];
    });
    when(mockEntryRepository.currentEntries).thenAnswer((_) {
      final finalEntry = Entry(
        text: testEntryText,
        timestamp: timestamp,
        category: 'Misc',
        isNew: true,
      );
      return [finalEntry];
    });
    when(mockEntryRepository.currentCategories).thenAnswer((_) {
      return ['Misc'];
    });
  }

  void stubRepositoryWithInitialEntries() {
    when(mockEntryRepository.initialize()).thenAnswer((_) async {});
    when(mockEntryRepository.currentEntries).thenReturn(rawEntriesList);
    when(mockEntryRepository.currentCategories).thenReturn(categoriesList);
  }

  void stubPermissionGranted() {
    when(
      mockPermissionService.getMicrophoneStatus(),
    ).thenAnswer((_) async => PermissionStatus.granted);
    when(
      mockPermissionService.requestMicrophonePermission(),
    ).thenAnswer((_) async => PermissionStatus.granted);
  }

  void stubStartRecordingSuccess() {
    when(
      mockAudioRecorder.start(any, path: anyNamed('path')),
    ).thenAnswer((_) async => Future.value());
    when(mockAudioRecorder.isRecording()).thenAnswer((_) async => true);
    when(
      mockAudioRecorder.stop(),
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
    await setupTestDependencies(
      entryRepository: scope.mockEntryRepository,
      speechService: scope.mockSpeechService,
      audioRecorder: scope.mockAudioRecorder,
      permissionService: scope.mockPermissionService,
    );
    scope.stubRepositoryWithInitialEntries();
    scope.stubPermissionGranted();
  });

  tearDown(() async {
    await locator.reset();
    await scope.dispose();
  });

  group('HomePage Widget Tests', () {
    group('Add Text Entry', () {
      testWidgets('should add entry to list when text is entered and sent', (
        WidgetTester tester,
      ) async {
        // GIVEN
        scope.stubAddEntrySuccess();
        scope.stubTranscriptionSuccess(
          'transcribed text',
        ); // Avoid interference
        await _givenHomePageIsDisplayed(tester, scope);

        // WHEN
        await _whenTextIsEntered(tester, HomePageTestScope.testEntryText);
        await _whenSendButtonIsTapped(tester);

        // THEN
        verify(
          scope.mockEntryRepository.addEntry(HomePageTestScope.testEntryText),
        ).called(1);
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
    });

    group('Voice Input', () {
      testWidgets('should show stop_circle icon when mic button is tapped', (
        WidgetTester tester,
      ) async {
        // GIVEN
        scope.stubStartRecordingSuccess();
        await _givenHomePageIsDisplayed(tester, scope, settle: false);
        await tester.pump(); // Allow cubit init

        // WHEN
        await _whenMicButtonIsTapped(tester);

        // THEN
        _thenStopCircleIconIsDisplayed(tester);
        verify(
          scope.mockAudioRecorder.start(any, path: anyNamed('path')),
        ).called(1);
        verify(
          scope.mockPermissionService.getMicrophoneStatus(),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets(
        'should call stop and transcribe when stop button is tapped',
        (WidgetTester tester) async {
          // GIVEN
          scope.stubStartRecordingSuccess();
          const transcribedText = 'This is the transcribed text';
          scope.stubTranscriptionSuccess(transcribedText);
          await _givenHomePageIsDisplayed(tester, scope, settle: false);
          await tester.pump(); // Allow cubit init

          await runFakeAsync((async) async {
            // WHEN: Start recording
            await _whenMicButtonIsTapped(
              tester,
              settle: false,
            ); // Don't settle fully inside fakeAsync

            // Simulate recording time
            async.elapse(const Duration(seconds: 3));

            // WHEN: Stop recording
            await _whenStopButtonIsTapped(tester); // Calls pump() inside

            // Allow transcription to process
            async.elapse(Duration.zero);
          });

          // Pump and settle AFTER fake async block completes
          await tester.pumpAndSettle();

          // THEN: Verify interactions and UI
          verify(
            scope.mockAudioRecorder.start(any, path: anyNamed('path')),
          ).called(1);
          verify(scope.mockAudioRecorder.stop()).called(1);
          verify(
            scope.mockSpeechService.transcribeAudio(any, language: 'en'),
          ).called(1);
          _thenMicIconIsDisplayed(tester);
          _thenTextFieldContains(tester, transcribedText);
        },
      );
    });

    group('Displaying Entries', () {
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
    });
  });
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
  final entryListItemFinder = find.ancestor(
    of: entryTextFinder,
    matching: find.byType(ListTile),
  );
  expect(entryTextFinder, findsOneWidget);
  expect(
    find.descendant(of: entryListItemFinder, matching: entryTimeFinder),
    findsOneWidget,
  );
}
