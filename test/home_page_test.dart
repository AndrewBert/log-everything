import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/pages/home_page.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/pages/cubit/home_page_cubit.dart';
import 'package:myapp/widgets/entries_list.dart';
import 'package:myapp/utils/app_bar_keys.dart';
import 'package:myapp/utils/widget_keys.dart';
import 'package:myapp/dialogs/help_dialog.dart';
import 'package:myapp/dialogs/manage_categories_dialog.dart';
import 'package:myapp/widgets/filter_section.dart';
import 'package:myapp/dialogs/whats_new_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mock_path_provider_platform.dart';
import 'test_di_registrar.dart';
import 'mocks.mocks.dart';
import 'package:myapp/locator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

// --- Test Scope ---
class HomePageTestScope {
  late MockEntryPersistenceService mockPersistenceService;
  late MockAiService mockAiService;
  late MockSpeechService mockSpeechService;
  late MockAudioRecorderService mockAudioRecorderService;
  late MockPermissionService mockPermissionService;

  static const testEntryText = 'Test entry 1';
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

  late Widget widgetUnderTest;

  HomePageTestScope() {
    mockPersistenceService = MockEntryPersistenceService();
    mockAiService = MockAiService();
    mockSpeechService = MockSpeechService();
    mockAudioRecorderService = MockAudioRecorderService();
    when(
      mockAudioRecorderService.onStateChanged(),
    ).thenAnswer((_) => Stream<RecordState>.empty());
    mockPermissionService = MockPermissionService();

    widgetUnderTest = MultiBlocProvider(
      providers: [
        BlocProvider<EntryCubit>(
          create:
              (context) =>
                  EntryCubit(entryRepository: getIt<EntryRepository>()),
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

  void stubPersistenceWithInitialEntries() {
    when(
      mockPersistenceService.loadEntries(),
    ).thenAnswer((_) async => List.from(rawEntriesList));
    when(
      mockPersistenceService.loadCategories(),
    ).thenAnswer((_) async => List.from(categoriesList));
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

  Future<void> dispose() async {}
}

// --- Helper Function for fakeAsync ---
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
      persistenceService: scope.mockPersistenceService,
      aiService: scope.mockAiService,
      speechService: scope.mockSpeechService,
      audioRecorder: scope.mockAudioRecorderService,
      permissionService: scope.mockPermissionService,
    );
    scope.stubPersistenceWithInitialEntries();
    scope.stubPermissionGranted();
  });

  tearDown(() async {
    await getIt.reset();
    await scope.dispose();
  });

  group('HomePage Widget Tests', () {
    group('Initialization and Display', () {
      testWidgets('should display initial UI elements correctly', (
        WidgetTester tester,
      ) async {
        // GIVEN
        await _givenHomePageIsDisplayed(tester, scope);

        // THEN
        _thenInitialUiElementsAreDisplayed(tester);
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
        _thenDateHeadersAreCorrect(tester);
      });

      testWidgets('should display FilterSection', (WidgetTester tester) async {
        // GIVEN
        await _givenHomePageIsDisplayed(tester, scope);

        // THEN
        _thenFilterSectionIsDisplayed(tester);
      });
    });

    group('Text Entry Input', () {
      testWidgets('should add entry and save via persistence', (
        WidgetTester tester,
      ) async {
        // GIVEN
        scope.stubTranscriptionSuccess('transcribed text');
        await _givenHomePageIsDisplayed(tester, scope);
        const newEntryText = HomePageTestScope.testEntryText;
        final initialListLength = HomePageTestScope.rawEntriesList.length;

        // WHEN
        await _whenTextIsEntered(tester, newEntryText);
        await _whenSendButtonIsTapped(tester);

        // THEN
        await _thenEntryIsDisplayedInList(tester, newEntryText);
        _thenTextFieldIsCleared(tester);
        _thenPersistenceSaveEntriesIsCalledWithNewEntry(
          scope,
          newEntryText,
          initialListLength,
        );
      });

      testWidgets('should not add entry or call save if input is empty', (
        WidgetTester tester,
      ) async {
        // GIVEN
        await _givenHomePageIsDisplayed(tester, scope);
        final initialListLength = HomePageTestScope.rawEntriesList.length;

        // WHEN
        await _whenTextIsEntered(tester, ''); // Enter empty text
        await _whenSendButtonIsTapped(tester);

        // THEN
        _thenTextFieldIsCleared(tester);
        verifyNever(scope.mockPersistenceService.saveEntries(any));

        final entriesListFinder = find.byType(EntriesList);
        final entryItemFinder = find.descendant(
          of: entriesListFinder,
          matching: find.byType(ListTile),
        );
        expect(entryItemFinder, findsNWidgets(initialListLength));
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
        _thenAudioRecordingServicesAreCalledForStart(scope);
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

          // WHEN
          await runFakeAsync((async) async {
            await _whenMicButtonIsTapped(tester, settle: false);
            async.elapse(const Duration(seconds: 3));
            await _whenStopButtonIsTapped(tester);
            async.elapse(Duration.zero); // Allow transcription to process
          });
          await tester.pumpAndSettle();

          // THEN
          _thenAudioAndSpeechServicesAreCalledForStopAndTranscribe(scope);
          _thenMicIconIsDisplayed(tester);
          _thenTextFieldContains(tester, transcribedText);
        },
      );

      // group('Voice Input with Temporary UI Update', () {
      //   testWidgets(
      //     'should show temporary entry in UI when send is tapped during recording with text',
      //     (WidgetTester tester) async {
      //       // GIVEN
      //       scope.stubStartRecordingSuccess();
      //       await _givenHomePageIsDisplayed(tester, scope, settle: false);
      //       await tester.pump();
      //       await _whenMicButtonIsTapped(tester, settle: false);
      //       await tester.pump();
      //       _thenStopCircleIconIsDisplayed(tester);

      //       const typedTextWhileRecording =
      //           'Hello from input field during recording';
      //       await _whenTextIsEntered(tester, typedTextWhileRecording);
      //       await tester.pump();

      //       // WHEN
      //       await _whenSendButtonIsTapped(tester);
      //       await tester.pump();

      //       // THEN
      //       _thenTemporaryEntryIsDisplayedInList(
      //         tester,
      //         typedTextWhileRecording,
      //         'Processing...',
      //       );
      //       verifyNever(scope.mockPersistenceService.saveEntries(any));
      //       verifyNever(
      //         scope.mockSpeechService.transcribeAudio(
      //           any,
      //           language: anyNamed('language'),
      //         ),
      //       );
      //     },
      //   );

      //   testWidgets(
      //     'should show temporary entry with "Processing voice..." if input is empty during recording send',
      //     (WidgetTester tester) async {
      //       // GIVEN
      //       scope.stubStartRecordingSuccess();
      //       await _givenHomePageIsDisplayed(tester, scope, settle: false);
      //       await tester.pump();
      //       await _whenMicButtonIsTapped(tester, settle: false);
      //       await tester.pump();
      //       _thenStopCircleIconIsDisplayed(tester);

      //       await _whenTextIsEntered(tester, '');
      //       await tester.pump();

      //       // WHEN
      //       await _whenSendButtonIsTapped(tester);
      //       await tester.pump();

      //       // THEN
      //       _thenTemporaryEntryIsDisplayedInList(
      //         tester,
      //         'Processing voice...',
      //         'Processing...',
      //       );
      //       verifyNever(scope.mockPersistenceService.saveEntries(any));
      //       verifyNever(
      //         scope.mockSpeechService.transcribeAudio(
      //           any,
      //           language: anyNamed('language'),
      //         ),
      //       );
      //     },
      //   );
      // });
    });

    group('Entry List Interactions', () {
      group('Delete', () {
        testWidgets('should delete entry and save via persistence', (
          WidgetTester tester,
        ) async {
          // GIVEN
          await _givenHomePageIsDisplayed(tester, scope);
          final entryToDelete = HomePageTestScope.entryToday1;
          _thenEntryIsDisplayed(tester, entryToDelete.text, '14:30');

          final expectedEntriesAfterDelete = _getExpectedEntriesAfterDelete(
            entryToDelete,
          );

          // WHEN
          await _whenDeleteIconIsTappedForEntry(tester, entryToDelete.text);

          // THEN
          _thenEntryIsNotDisplayed(tester, entryToDelete.text);
          _thenSnackbarIsDisplayedWithMessage(tester, 'Entry deleted');
          _thenSnackbarHasAction(tester, 'Undo');
          _thenPersistenceSaveEntriesIsCalledWithList(
            scope,
            expectedEntriesAfterDelete,
          );
        });

        testWidgets(
          'should restore entry and save via persistence when Undo is tapped',
          (WidgetTester tester) async {
            // GIVEN
            await _givenHomePageIsDisplayed(tester, scope);
            final entryToRestore = HomePageTestScope.entryToday1;
            await _whenDeleteIconIsTappedForEntry(tester, entryToRestore.text);
            _thenSnackbarIsDisplayedWithMessage(tester, 'Entry deleted');
            clearInteractions(scope.mockPersistenceService);
            final expectedEntriesAfterUndo = _getExpectedEntriesAfterUndo(
              entryToRestore,
            );

            // WHEN
            await _whenSnackbarActionIsTapped(tester, 'Undo');

            // THEN
            await _thenEntryIsDisplayedInList(tester, entryToRestore.text);
            _thenPersistenceSaveEntriesIsCalledWithList(
              scope,
              expectedEntriesAfterUndo,
            );
          },
        );
      });

      group('Edit Entry', () {
        testWidgets('should open EditEntryDialog when edit icon is tapped', (
          WidgetTester tester,
        ) async {
          // GIVEN
          await _givenHomePageIsDisplayed(tester, scope);
          final entryToEditText = HomePageTestScope.entryToday1.text;

          // WHEN
          await _whenEditIconIsTappedForEntry(tester, entryToEditText);

          // THEN
          _thenEditEntryDialogIsDisplayed(tester);
        });

        testWidgets(
          'should update entry and save when EditEntryDialog confirms',
          (WidgetTester tester) async {
            // GIVEN
            await _givenHomePageIsDisplayed(tester, scope);
            final entryToEdit = HomePageTestScope.entryToday1;
            const updatedText = 'Updated entry text';
            await _whenEditIconIsTappedForEntry(tester, entryToEdit.text);
            _thenEditEntryDialogIsDisplayed(tester);
            clearInteractions(scope.mockPersistenceService);
            final expectedEntriesAfterUpdate = _getExpectedEntriesAfterEdit(
              entryToEdit,
              updatedText,
            );

            // WHEN
            await _whenDialogTextFieldIsEdited(tester, updatedText);
            await _whenDialogButtonIsTapped(tester, 'Save');

            // THEN
            _thenEditEntryDialogIsNotDisplayed(tester);
            await _thenEntryTextIsUpdatedInList(
              tester,
              entryToEdit.text,
              updatedText,
            );
            _thenPersistenceSaveEntriesIsCalledWithList(
              scope,
              expectedEntriesAfterUpdate,
            );
          },
        );

        testWidgets('should not update entry if EditEntryDialog is cancelled', (
          WidgetTester tester,
        ) async {
          // GIVEN
          await _givenHomePageIsDisplayed(tester, scope);
          final entryToEdit = HomePageTestScope.entryToday1;
          final originalText = entryToEdit.text;

          await _whenEditIconIsTappedForEntry(tester, originalText);
          _thenEditEntryDialogIsDisplayed(tester);
          clearInteractions(scope.mockPersistenceService);

          // WHEN
          await _whenDialogTextFieldIsEdited(
            tester,
            'Some new text that won\'t be saved',
          );
          await _whenDialogButtonIsTapped(tester, 'Cancel');

          // THEN
          _thenEditEntryDialogIsNotDisplayed(tester);
          await _thenEntryTextIsUnchangedInList(tester, originalText);
          verifyNever(scope.mockPersistenceService.saveEntries(any));
        });
      });
    });

    group('AppBar Interactions', () {
      testWidgets('should show HelpDialog when help button is tapped', (
        WidgetTester tester,
      ) async {
        // GIVEN
        await _givenHomePageIsDisplayed(tester, scope);

        // WHEN
        await _whenHelpButtonIsTapped(tester);

        // THEN
        _thenHelpDialogIsDisplayed(tester);
      });

      testWidgets(
        'should show ManageCategoriesDialog when manage categories button is tapped',
        (WidgetTester tester) async {
          // GIVEN
          await _givenHomePageIsDisplayed(tester, scope);

          // WHEN
          await _whenManageCategoriesButtonIsTapped(tester);

          // THEN
          _thenManageCategoriesDialogIsDisplayed(tester);
        },
      );

      testWidgets(
        'should increment title tap count in HomePageCubit when title is tapped',
        (WidgetTester tester) async {
          // GIVEN
          await _givenHomePageIsDisplayed(tester, scope);
          final homePageCubit = BlocProvider.of<HomePageCubit>(
            tester.element(find.byType(HomePage)),
          );
          final initialTapCount = homePageCubit.state.titleTapCount;

          // WHEN
          await _whenAppBarTitleIsTapped(tester);

          // THEN
          _thenTitleTapCountIsIncremented(homePageCubit, initialTapCount);
        },
      );
    });

    group('HomePageCubit State Changes', () {
      testWidgets('should display app version from HomePageCubit state', (
        WidgetTester tester,
      ) async {
        // GIVEN
        const testVersionString = 'v1.2.3 (42)';
        PackageInfo.setMockInitialValues(
          appName: 'LogSplitter',
          packageName: 'com.example.logsplitter',
          version: '1.2.3',
          buildNumber: '42',
          buildSignature: '',
        );

        // WHEN
        await _givenHomePageIsDisplayed(tester, scope);

        // THEN
        _thenAppVersionIsDisplayed(tester, testVersionString);
      });

      testWidgets('should show What\'s New dialog when state indicates', (
        WidgetTester tester,
      ) async {
        // GIVEN
        PackageInfo.setMockInitialValues(
          appName: 'LogSplitter',
          packageName: 'com.example.logsplitter',
          version: '2.0.0',
          buildNumber: '10',
          buildSignature: '',
        );
        SharedPreferences.setMockInitialValues({
          'last_shown_whats_new_version': 'v1.0.0 (1)',
        });

        await _givenHomePageIsDisplayed(tester, scope, settle: false);
        await tester.pumpAndSettle();

        final homePageCubit = BlocProvider.of<HomePageCubit>(
          tester.element(find.byType(HomePage)),
        );
        expect(
          homePageCubit.state.showWhatsNewDialog,
          isTrue,
          reason: "HomePageCubit state should have showWhatsNewDialog as true",
        );

        // THEN
        _thenWhatsNewDialogIsDisplayed(tester);
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
    await tester.pump();
  }
}

Future<void> _whenStopButtonIsTapped(WidgetTester tester) async {
  final stopButtonFinder = find.byIcon(Icons.stop_circle_outlined);
  expect(stopButtonFinder, findsOneWidget);
  await tester.tap(stopButtonFinder);
  await tester.pump();
}

Future<void> _whenDeleteIconIsTappedForEntry(
  WidgetTester tester,
  String entryText,
) async {
  final entry = HomePageTestScope.rawEntriesList.firstWhere(
    (e) => e.text == entryText,
    orElse:
        () =>
            throw StateError(
              'Entry with text "$entryText" not found in rawEntriesList for delete icon lookup',
            ),
  );
  final deleteIconFinder = find.byKey(entryDeleteIconKey(entry));
  expect(
    deleteIconFinder,
    findsOneWidget,
    reason: 'Could not find delete icon for entry "$entryText"',
  );
  await tester.tap(deleteIconFinder);
  await tester.pumpAndSettle();
}

Future<void> _whenEditIconIsTappedForEntry(
  WidgetTester tester,
  String entryText,
) async {
  final entry = HomePageTestScope.rawEntriesList.firstWhere(
    (e) => e.text == entryText,
    orElse:
        () =>
            throw StateError(
              'Entry with text "$entryText" not found in rawEntriesList for edit icon lookup',
            ),
  );
  final editIconFinder = find.byKey(entryEditIconKey(entry));
  expect(
    editIconFinder,
    findsOneWidget,
    reason: 'Could not find edit icon for entry "$entryText"',
  );
  await tester.tap(editIconFinder);
  await tester.pumpAndSettle();
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
  await tester.pumpAndSettle();
}

Future<void> _whenDialogTextFieldIsEdited(
  WidgetTester tester,
  String newText,
) async {
  final textFieldFinder = find.byKey(editEntryDialogTextField);
  expect(textFieldFinder, findsOneWidget);
  await tester.enterText(textFieldFinder, newText);
  await tester.pump();
}

Future<void> _whenDialogButtonIsTapped(
  WidgetTester tester,
  String buttonText,
) async {
  late Key buttonKey;
  if (buttonText == 'Update' || buttonText == 'Save') {
    buttonKey = editEntryDialogSaveButton;
  } else if (buttonText == 'Cancel') {
    buttonKey = editEntryDialogCancelButton;
  } else {
    throw ArgumentError('Unsupported dialog button text: $buttonText');
  }
  final buttonFinder = find.byKey(buttonKey);
  expect(
    buttonFinder,
    findsOneWidget,
    reason: 'Could not find "$buttonText" button in dialog',
  );
  await tester.tap(buttonFinder);
  await tester.pumpAndSettle();
}

Future<void> _whenHelpButtonIsTapped(WidgetTester tester) async {
  final helpButtonFinder = find.byIcon(Icons.help_outline);
  expect(helpButtonFinder, findsOneWidget);
  await tester.tap(helpButtonFinder);
  await tester.pumpAndSettle();
}

Future<void> _whenManageCategoriesButtonIsTapped(WidgetTester tester) async {
  final manageCategoriesButtonFinder = find.byIcon(Icons.category_outlined);
  expect(manageCategoriesButtonFinder, findsOneWidget);
  await tester.tap(manageCategoriesButtonFinder);
  await tester.pumpAndSettle();
}

Future<void> _whenAppBarTitleIsTapped(WidgetTester tester) async {
  final appBarTitleFinder = find.byKey(appBarTitleGestureDetector);

  expect(appBarTitleFinder, findsOneWidget);
  await tester.tap(appBarTitleFinder);
  await tester.pump();
}

// --- THEN ---
Future<void> _thenEntryIsDisplayedInList(
  WidgetTester tester,
  String text,
) async {
  await tester.pumpAndSettle();
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
  final entryListTileFinder = find.ancestor(
    of: entryTextFinder,
    matching: find.byType(ListTile),
  );
  expect(entryTextFinder, findsOneWidget);
  expect(
    find.descendant(of: entryListTileFinder, matching: entryTimeFinder),
    findsOneWidget,
  );
}

void _thenSnackbarIsDisplayedWithMessage(WidgetTester tester, String message) {
  final snackBarFinder = find.byType(SnackBar);
  expect(snackBarFinder, findsOneWidget);
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

void _thenEditEntryDialogIsDisplayed(WidgetTester tester) {
  final dialogFinder = find.byKey(editEntryDialog);
  expect(
    dialogFinder,
    findsOneWidget,
    reason: 'EditEntryDialog should be displayed',
  );
}

void _thenEditEntryDialogIsNotDisplayed(WidgetTester tester) {
  final dialogFinder = find.byKey(editEntryDialog);
  expect(
    dialogFinder,
    findsNothing,
    reason: 'EditEntryDialog should not be displayed',
  );
}

Future<void> _thenEntryTextIsUpdatedInList(
  WidgetTester tester,
  String oldText,
  String newText,
) async {
  await tester.pumpAndSettle();
  final listFinder = find.byType(EntriesList);
  expect(listFinder, findsOneWidget);
  final oldTextFinder = find.descendant(
    of: listFinder,
    matching: find.text(oldText),
  );
  final newTextFinder = find.descendant(
    of: listFinder,
    matching: find.text(newText),
  );
  expect(
    oldTextFinder,
    findsNothing,
    reason: 'Old entry text "$oldText" should not be found',
  );
  expect(
    newTextFinder,
    findsOneWidget,
    reason: 'New entry text "$newText" should be found',
  );
}

Future<void> _thenEntryTextIsUnchangedInList(
  WidgetTester tester,
  String expectedText,
) async {
  await tester.pumpAndSettle();
  final listFinder = find.byType(EntriesList);
  expect(listFinder, findsOneWidget);
  final textFinder = find.descendant(
    of: listFinder,
    matching: find.text(expectedText),
  );
  expect(
    textFinder,
    findsOneWidget,
    reason: 'Entry text "$expectedText" should still be found in the list',
  );
}

void _thenHelpDialogIsDisplayed(WidgetTester tester) {
  expect(
    find.byType(HelpDialog),
    findsOneWidget,
    reason: 'HelpDialog should be displayed',
  );
}

void _thenManageCategoriesDialogIsDisplayed(WidgetTester tester) {
  expect(
    find.byType(ManageCategoriesDialog),
    findsOneWidget,
    reason: 'ManageCategoriesDialog should be displayed',
  );
}

void _thenFilterSectionIsDisplayed(WidgetTester tester) {
  expect(
    find.byType(FilterSection),
    findsOneWidget,
    reason: 'FilterSection should be displayed',
  );
}

void _thenTitleTapCountIsIncremented(HomePageCubit cubit, int initialTapCount) {
  expect(
    cubit.state.titleTapCount,
    initialTapCount + 1,
    reason: 'Title tap count should have incremented',
  );
}

void _thenInitialUiElementsAreDisplayed(WidgetTester tester) {
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
}

void _thenDateHeadersAreCorrect(WidgetTester tester) {
  final todayHeaderFinder = find.text('Today');
  final yesterdayHeaderFinder = find.text('Yesterday');
  final olderDateHeaderFinder = find.text(
    DateFormat.yMMMd().format(HomePageTestScope.entryOlder.timestamp),
  );
  final firstTodayEntryFinder = find.text(HomePageTestScope.entryToday1.text);
  final firstYesterdayEntryFinder = find.text(
    HomePageTestScope.entryYesterday.text,
  );
  final firstOlderEntryFinder = find.text(HomePageTestScope.entryOlder.text);

  expect(todayHeaderFinder, findsOneWidget);
  expect(yesterdayHeaderFinder, findsOneWidget);
  expect(olderDateHeaderFinder, findsOneWidget);
  expect(firstTodayEntryFinder, findsOneWidget);
  expect(firstYesterdayEntryFinder, findsOneWidget);
  expect(firstOlderEntryFinder, findsOneWidget);

  final todayHeaderOffset = tester.getTopLeft(todayHeaderFinder).dy;
  final firstTodayEntryOffset = tester.getTopLeft(firstTodayEntryFinder).dy;
  final yesterdayHeaderOffset = tester.getTopLeft(yesterdayHeaderFinder).dy;
  final firstYesterdayEntryOffset =
      tester.getTopLeft(firstYesterdayEntryFinder).dy;
  final olderHeaderOffset = tester.getTopLeft(olderDateHeaderFinder).dy;
  final firstOlderEntryOffset = tester.getTopLeft(firstOlderEntryFinder).dy;

  expect(todayHeaderOffset, lessThan(firstTodayEntryOffset));
  expect(yesterdayHeaderOffset, lessThan(firstYesterdayEntryOffset));
  expect(olderHeaderOffset, lessThan(firstOlderEntryOffset));
}

void _thenPersistenceSaveEntriesIsCalledWithNewEntry(
  HomePageTestScope scope,
  String newEntryText,
  int initialListLength,
) {
  verify(
    scope.mockPersistenceService.saveEntries(
      argThat(
        predicate<List<Entry>>((savedList) {
          if (savedList.length != initialListLength + 1) return false;
          final addedEntry = savedList.firstWhere(
            (entry) => entry.text == newEntryText && entry.isNew,
            orElse: () => Entry(text: '', timestamp: DateTime(0), category: ''),
          );
          final bool textMatches = addedEntry.text == newEntryText;
          final bool categoryMatches = addedEntry.category == 'Misc';
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
          final originalEntry1Present = savedList.any(
            (e) => e.text == HomePageTestScope.entryToday1.text,
          );
          return originalEntry1Present;
        }),
      ),
    ),
  ).called(1);
}

void _thenAudioRecordingServicesAreCalledForStart(HomePageTestScope scope) {
  verify(scope.mockAudioRecorderService.generateRecordingPath()).called(1);
  verify(
    scope.mockAudioRecorderService.start(any, path: anyNamed('path')),
  ).called(1);
  verify(
    scope.mockPermissionService.getMicrophoneStatus(),
  ).called(greaterThanOrEqualTo(1));
}

void _thenAudioAndSpeechServicesAreCalledForStopAndTranscribe(
  HomePageTestScope scope,
) {
  verify(scope.mockAudioRecorderService.generateRecordingPath()).called(1);
  verify(
    scope.mockAudioRecorderService.start(any, path: anyNamed('path')),
  ).called(1);
  verify(scope.mockAudioRecorderService.stop()).called(1);
  verify(
    scope.mockSpeechService.transcribeAudio(any, language: 'en'),
  ).called(1);
}

List<Entry> _getExpectedEntriesAfterDelete(Entry entryToDelete) {
  return List<Entry>.from(HomePageTestScope.rawEntriesList)..removeWhere(
    (e) =>
        e.timestamp == entryToDelete.timestamp && e.text == entryToDelete.text,
  );
}

List<Entry> _getExpectedEntriesAfterUndo(Entry entryToRestore) {
  return List<Entry>.from(HomePageTestScope.rawEntriesList)
    ..removeWhere(
      (e) =>
          e.timestamp == entryToRestore.timestamp &&
          e.text == entryToRestore.text,
    )
    ..add(entryToRestore);
}

List<Entry> _getExpectedEntriesAfterEdit(
  Entry entryToEdit,
  String updatedText,
) {
  final expectedList = List<Entry>.from(HomePageTestScope.rawEntriesList);
  final indexToUpdate = expectedList.indexWhere(
    (e) => e.timestamp == entryToEdit.timestamp && e.text == entryToEdit.text,
  );
  if (indexToUpdate != -1) {
    expectedList[indexToUpdate] = entryToEdit.copyWith(text: updatedText);
  }
  return expectedList;
}

void _thenPersistenceSaveEntriesIsCalledWithList(
  HomePageTestScope scope,
  List<Entry> expectedList,
) {
  verify(
    scope.mockPersistenceService.saveEntries(argThat(equals(expectedList))),
  ).called(1);
}

void _thenEntryIsNotDisplayed(WidgetTester tester, String text) {
  expect(find.text(text), findsNothing);
}

void _thenAppVersionIsDisplayed(WidgetTester tester, String version) {
  final appBarFinder = find.byType(AppBar);
  expect(appBarFinder, findsOneWidget);
  final versionTextFinder = find.descendant(
    of: appBarFinder,
    matching: find.text(version),
  );
  expect(
    versionTextFinder,
    findsOneWidget,
    reason: 'App version "$version" should be displayed in the AppBar',
  );
}

void _thenTemporaryEntryIsDisplayedInList(
  WidgetTester tester,
  String expectedText,
  String expectedCategory,
) {
  final entryListFinder = find.byType(EntriesList);
  expect(
    entryListFinder,
    findsOneWidget,
    reason: 'EntriesList should be present',
  );

  final entryWidgets = tester.widgetList<ListTile>(
    find.descendant(of: entryListFinder, matching: find.byType(ListTile)),
  );

  bool found = false;
  for (final tile in entryWidgets) {
    final textFindersInTile = find.descendant(
      of: find.byWidget(tile),
      matching: find.byType(Text),
    );

    bool textMatch = false;
    bool categoryMatch = false;

    for (final textFinder in textFindersInTile.evaluate()) {
      final textWidget = textFinder.widget as Text;
      if (textWidget.data == expectedText) {
        textMatch = true;
      }
      if (textWidget.data == expectedCategory) {
        categoryMatch = true;
      }
    }

    if (textMatch && categoryMatch) {
      found = true;
      break;
    }
  }

  expect(
    found,
    isTrue,
    reason:
        'Temporary entry with text "$expectedText" and category "$expectedCategory" should be displayed',
  );
}

void _thenWhatsNewDialogIsDisplayed(WidgetTester tester) {
  expect(
    find.byType(WhatsNewDialog),
    findsOneWidget,
    reason: 'WhatsNewDialog should be displayed',
  );
}
