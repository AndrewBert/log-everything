import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/locator.dart';

import '../mock_path_provider_platform.dart';
import '../test_di_registrar.dart';
import '../helpers/test_helpers.dart';
import '../helpers/widget_test_scope.dart';
import '../helpers/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WidgetTestScope scope;

  setUp(() async {
    final mockPathProvider = MockPathProviderPlatform();
    PathProviderPlatform.instance = mockPathProvider;

    scope = WidgetTestScope();
    await setupTestDependencies(
      persistenceService: scope.mockPersistenceService,
      aiService: scope.mockAiService,
      speechService: scope.mockSpeechService,
      audioRecorder: scope.mockAudioRecorderService,
      permissionService: scope.mockPermissionService,
      vectorStoreService: scope.mockVectorStoreService,
      sharedPreferences: scope.mockSharedPreferences,
      httpClient: scope.mockHttpClient,
    );
    scope.stubPersistenceWithInitialEntries();
    scope.stubPermissionGranted();
    scope.stubAiServiceExtractEntries();
  });

  tearDown(() async {
    final entryRepository = getIt<EntryRepository>();
    entryRepository.dispose();

    await getIt.reset();
    await scope.dispose();
  });

  group('Entry List Interactions', () {
    group('Delete', () {
      testWidgets('should delete entry and save via persistence', (WidgetTester tester) async {
        await givenHomePageIsDisplayed(tester, scope);
        final entryToDelete = TestData.entryToday1;
        thenEntryIsDisplayed(tester, entryToDelete.text, '2:30 PM');

        final expectedEntriesAfterDelete = TestData.getExpectedEntriesAfterDelete(entryToDelete);

        await whenDeleteIconIsTappedForEntry(tester, entryToDelete.text);

        thenEntryIsNotDisplayed(tester, entryToDelete.text);
        thenSnackbarIsDisplayedWithMessage(tester, 'Entry deleted');
        thenSnackbarHasAction(tester, 'Undo');
        thenPersistenceSaveEntriesIsCalledWithList(scope, expectedEntriesAfterDelete);
      });

      testWidgets('should restore entry and save via persistence when Undo is tapped', (WidgetTester tester) async {
        await givenHomePageIsDisplayed(tester, scope);
        final entryToRestore = TestData.entryToday1;
        await whenDeleteIconIsTappedForEntry(tester, entryToRestore.text);
        thenSnackbarIsDisplayedWithMessage(tester, 'Entry deleted');
        clearInteractions(scope.mockPersistenceService);
        final expectedEntriesAfterUndo = TestData.getExpectedEntriesAfterUndo(entryToRestore);

        await whenSnackbarActionIsTapped(tester, 'Undo');

        await thenEntryIsDisplayedInList(tester, entryToRestore.text);
        thenPersistenceSaveEntriesIsCalledWithList(scope, expectedEntriesAfterUndo);
      });
    });

    group('Edit Entry', () {
      testWidgets('should populate input field when edit option is tapped', (WidgetTester tester) async {
        await givenHomePageIsDisplayed(tester, scope);
        final entryToEditText = TestData.entryToday1.text;

        await whenEditIconIsTappedForEntry(tester, entryToEditText);

        thenInputFieldContainsText(tester, entryToEditText);
      });

      testWidgets('should update entry and save when text is modified and sent', (WidgetTester tester) async {
        await givenHomePageIsDisplayed(tester, scope);
        final entryToEdit = TestData.entryToday1;
        const updatedText = 'Updated entry text';
        await whenEditIconIsTappedForEntry(tester, entryToEdit.text);
        thenInputFieldContainsText(tester, entryToEdit.text);
        clearInteractions(scope.mockPersistenceService);

        await whenTextIsEntered(tester, updatedText);
        await whenSendButtonIsTapped(tester);

        await thenEntryIsDisplayedInList(tester, updatedText);
        thenTextFieldIsCleared(tester);
      });

      testWidgets('should clear input field without saving if text is cleared', (WidgetTester tester) async {
        await givenHomePageIsDisplayed(tester, scope);
        final entryToEdit = TestData.entryToday1;
        final originalText = entryToEdit.text;

        await whenEditIconIsTappedForEntry(tester, originalText);
        thenInputFieldContainsText(tester, originalText);
        clearInteractions(scope.mockPersistenceService);

        await whenTextIsEntered(tester, '');
        await whenSendButtonIsTapped(tester);

        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 100));

        await thenEntryIsDisplayedInList(tester, originalText);
        thenTextFieldIsCleared(tester);
        verifyNever(scope.mockPersistenceService.saveEntries(any));
      });
    });
  });
}
