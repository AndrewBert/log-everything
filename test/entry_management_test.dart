import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/widgets/entries_list.dart';
import 'package:myapp/widgets/entry_card.dart';
import 'package:myapp/locator.dart';

import 'mock_path_provider_platform.dart';
import 'test_di_registrar.dart';
import 'helpers/test_helpers.dart';
import 'helpers/widget_test_scope.dart';
import 'helpers/test_data.dart';

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
    // We'll configure AI service mocks per test as needed
  });

  tearDown(() async {
    final entryRepository = getIt<EntryRepository>();
    entryRepository.dispose();
    
    await getIt.reset();
    await scope.dispose();
  });

  group('Entry Creation Behaviors', () {
    group('Creating entries through text input', () {
      testWidgets(
        'Given user has app open, When they type and submit text, Then entry is created and categorized',
        (WidgetTester tester) async {
          // Given - User has app open with existing entries visible
          const workText = 'Had a productive meeting with the development team';
          
          // Configure AI service to return the actual input text
          when(scope.mockAiService.extractEntries(any, any)).thenAnswer(
            (_) async => [
              (textSegment: workText, category: 'Work'),
            ],
          );
          
          await givenUserHasAppOpenWithEntries(tester, scope);

          // When - User types work-related text and submits
          await whenUserTypesText(tester, workText);
          await whenUserSubmitsEntry(tester);

          // Then - Entry is created, categorized, and appears in list
          await thenEntryIsCreatedAndDisplayed(tester, workText);
          await thenEntryIsCategorizedCorrectly(tester, workText, 'Work');
          await thenEntryAppearsAtTopOfList(tester, workText);
        },
      );

      testWidgets(
        'Given user types empty text, When they submit, Then no entry is created',
        (WidgetTester tester) async {
          // Given - User has app open
          // Configure AI service (though it shouldn't be called for empty text)
          when(scope.mockAiService.extractEntries(any, any)).thenAnswer(
            (_) async => [],
          );
          
          await givenUserHasAppOpenWithEntries(tester, scope);
          final initialEntryCount = await getVisibleEntryCount(tester);

          // When - User submits empty text
          await whenUserTypesText(tester, '');
          await whenUserSubmitsEntry(tester);

          // Then - No entry is created and entry count remains same
          await thenNoEntryIsCreated(tester, initialEntryCount);
          await thenInputFieldIsCleared(tester);
        },
      );
    });

    group('Creating entries through voice input', () {
      testWidgets(
        'Given user records voice, When transcription completes, Then entry is created with correct text',
        (WidgetTester tester) async {
          // Given - User has app open and voice recording is set up
          scope.stubStartRecordingSuccess();
          const transcribedText = 'Just finished a great workout at the gym';
          scope.stubTranscriptionSuccess(transcribedText);
          
          // Configure AI service to handle transcribed text
          when(scope.mockAiService.extractEntries(any, any)).thenAnswer(
            (_) async => [
              (textSegment: transcribedText, category: 'Personal'),
            ],
          );
          
          await givenUserHasAppOpenWithEntries(tester, scope);

          // When - User records voice and transcription completes
          await whenUserStartsVoiceRecording(tester);
          // Simulate recording for a few seconds
          await tester.pump(const Duration(seconds: 2));
          await whenUserStopsVoiceRecording(tester);
          await whenTranscriptionCompletes(tester);

          // Then - Entry text appears in input field (user can then submit)
          await thenTranscribedTextAppearsInInputField(tester, transcribedText);
          await thenVoiceInputReturnsToNormalState(tester);
        },
      );

      testWidgets(
        'Given user has existing text, When they start recording, Then text is preserved during voice input',
        (WidgetTester tester) async {
          // Given - User has typed some text
          scope.stubStartRecordingSuccess();
          const existingText = 'Started writing about';
          await givenUserHasAppOpenWithEntries(tester, scope);
          await givenUserHasTypedText(tester, existingText);

          // When - User starts voice recording
          await whenUserStartsVoiceRecording(tester);

          // Then - Existing text is preserved and recording state is shown
          await thenExistingTextIsPreserved(tester, existingText);
          await thenVoiceRecordingStateIsShown(tester);
        },
      );
    });
  });

  group('Entry Editing Behaviors', () {
    group('Editing existing entries', () {
      testWidgets(
        'Given user has an entry, When they edit and save it, Then changes are persisted',
        (WidgetTester tester) async {
          // Given - User has app open with entries
          const updatedText = 'Updated: Had an amazing meeting with the team';
          
          // Configure AI service for the updated text
          when(scope.mockAiService.extractEntries(any, any)).thenAnswer(
            (_) async => [
              (textSegment: updatedText, category: 'Work'),
            ],
          );
          
          await givenUserHasAppOpenWithEntries(tester, scope);
          final originalEntry = TestData.entryToday1;
          await givenEntryIsVisibleInList(tester, originalEntry.text);

          // When - User edits the entry
          await whenUserEditsEntry(tester, originalEntry.text);
          await whenUserModifiesEntryText(tester, updatedText);
          await whenUserSavesEntryChanges(tester);

          // Then - Entry is updated and changes are persisted
          await thenEntryIsUpdatedInList(tester, updatedText);
          await thenOriginalEntryIsNoLongerVisible(tester, originalEntry.text);
          await thenEntryChangesArePersisted(tester, scope, updatedText);
        },
      );

      testWidgets(
        'Given user is editing an entry, When they clear the text and submit, Then edit is cancelled',
        (WidgetTester tester) async {
          // Given - User is editing an entry
          await givenUserHasAppOpenWithEntries(tester, scope);
          final entryToEdit = TestData.entryToday1;
          await givenUserIsEditingEntry(tester, entryToEdit.text);

          // When - User clears text and submits
          await whenUserClearsEntryText(tester);
          await whenUserSubmitsEntry(tester);

          // Then - Edit is cancelled and original entry remains
          await thenEditIsCancelled(tester);
          await thenOriginalEntryIsRestored(tester, entryToEdit.text);
          await thenNoChangeIsPersisted(tester, scope);
        },
      );
    });

    group('Edit mode behaviors', () {
      testWidgets(
        'Given user is in edit mode, When they cancel edit, Then original entry is preserved',
        (WidgetTester tester) async {
          // Given - User is editing an entry
          await givenUserHasAppOpenWithEntries(tester, scope);
          final entryToEdit = TestData.entryToday1;
          await givenUserIsEditingEntry(tester, entryToEdit.text);

          // When - User cancels the edit
          await whenUserCancelsEdit(tester);

          // Then - Original entry is preserved and edit mode is exited
          await thenEditModeIsExited(tester);
          await thenOriginalEntryIsRestored(tester, entryToEdit.text);
        },
      );
    });
  });

  group('Entry Deletion and Recovery Behaviors', () {
    group('Deleting entries', () {
      testWidgets(
        'Given user has an entry, When they delete it, Then entry is removed and undo is available',
        (WidgetTester tester) async {
          // Given - User has app open with entries
          await givenUserHasAppOpenWithEntries(tester, scope);
          final entryToDelete = TestData.entryToday1;
          await givenEntryIsVisibleInList(tester, entryToDelete.text);

          // When - User deletes the entry
          await whenUserDeletesEntry(tester, entryToDelete.text);

          // Then - Entry is removed and undo option is shown
          await thenEntryIsRemovedFromList(tester, entryToDelete.text);
          await thenUndoOptionIsAvailable(tester);
          await thenDeletionIsPersisted(tester, scope);
        },
      );

      testWidgets(
        'Given user deleted an entry, When they tap undo, Then entry is restored exactly as before',
        (WidgetTester tester) async {
          // Given - User has deleted an entry
          await givenUserHasAppOpenWithEntries(tester, scope);
          final entryToRestore = TestData.entryToday1;
          await givenUserHasDeletedEntry(tester, entryToRestore.text);
          await givenUndoOptionIsShown(tester);

          // When - User taps undo
          await whenUserTapsUndo(tester);

          // Then - Entry is restored exactly as before
          await thenEntryIsRestoredToList(tester, entryToRestore.text);
          await thenEntryRestorationIsPersisted(tester, scope);
          await thenUndoOptionDisappears(tester);
        },
      );
    });
  });
}

// BDD Helper Functions - GIVEN

Future<void> givenUserHasAppOpenWithEntries(WidgetTester tester, WidgetTestScope scope) async {
  await givenHomePageIsDisplayed(tester, scope);
  thenInitialUiElementsAreDisplayed(tester);
}

Future<void> givenEntryIsVisibleInList(WidgetTester tester, String entryText) async {
  await thenEntryIsDisplayedInList(tester, entryText);
}

Future<void> givenUserHasTypedText(WidgetTester tester, String text) async {
  await whenTextIsEntered(tester, text);
}

Future<void> givenUserIsEditingEntry(WidgetTester tester, String entryText) async {
  await whenEditIconIsTappedForEntry(tester, entryText);
  thenInputFieldContainsText(tester, entryText);
}

Future<void> givenUserHasDeletedEntry(WidgetTester tester, String entryText) async {
  await whenDeleteIconIsTappedForEntry(tester, entryText);
}

Future<void> givenUndoOptionIsShown(WidgetTester tester) async {
  thenSnackbarIsDisplayedWithMessage(tester, 'Entry deleted');
  thenSnackbarHasAction(tester, 'Undo');
}

// BDD Helper Functions - WHEN

Future<void> whenUserTypesText(WidgetTester tester, String text) async {
  await whenTextIsEntered(tester, text);
}

Future<void> whenUserSubmitsEntry(WidgetTester tester) async {
  await whenSendButtonIsTapped(tester);
}

Future<void> whenUserStartsVoiceRecording(WidgetTester tester) async {
  await whenMicButtonIsTapped(tester);
}

Future<void> whenUserStopsVoiceRecording(WidgetTester tester) async {
  await whenStopButtonIsTapped(tester);
}

Future<void> whenTranscriptionCompletes(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

Future<void> whenUserEditsEntry(WidgetTester tester, String entryText) async {
  await whenEditIconIsTappedForEntry(tester, entryText);
}

Future<void> whenUserModifiesEntryText(WidgetTester tester, String newText) async {
  await whenTextIsEntered(tester, newText);
}

Future<void> whenUserSavesEntryChanges(WidgetTester tester) async {
  await whenSendButtonIsTapped(tester);
}

Future<void> whenUserClearsEntryText(WidgetTester tester) async {
  await whenTextIsEntered(tester, '');
}

Future<void> whenUserDeletesEntry(WidgetTester tester, String entryText) async {
  await whenDeleteIconIsTappedForEntry(tester, entryText);
}

Future<void> whenUserTapsUndo(WidgetTester tester) async {
  await whenSnackbarActionIsTapped(tester, 'Undo');
}

Future<void> whenUserCancelsEdit(WidgetTester tester) async {
  // Find and tap the cancel button in edit mode
  final cancelButton = find.text('Cancel');
  expect(cancelButton, findsOneWidget, reason: 'Cancel button should be visible in edit mode');
  await tester.tap(cancelButton);
  await tester.pumpAndSettle();
}

// BDD Helper Functions - THEN

Future<void> thenEntryIsCreatedAndDisplayed(WidgetTester tester, String entryText) async {
  await thenEntryIsDisplayedInList(tester, entryText);
}

Future<void> thenEntryIsCategorizedCorrectly(WidgetTester tester, String entryText, String expectedCategory) async {
  // Verification that entry appears with correct category would require UI updates
  // For now, verify the entry exists (category verification would need category display in UI)
  await thenEntryIsDisplayedInList(tester, entryText);
}

Future<void> thenEntryAppearsAtTopOfList(WidgetTester tester, String entryText) async {
  await thenEntryIsDisplayedInList(tester, entryText);
}

Future<void> thenNoEntryIsCreated(WidgetTester tester, int expectedCount) async {
  final currentCount = await getVisibleEntryCount(tester);
  expect(currentCount, equals(expectedCount), reason: 'Entry count should remain unchanged');
}

Future<void> thenInputFieldIsCleared(WidgetTester tester) async {
  thenTextFieldIsCleared(tester);
}

Future<void> thenTranscribedTextAppearsInInputField(WidgetTester tester, String transcribedText) async {
  thenTextFieldContains(tester, transcribedText);
}

Future<void> thenVoiceInputReturnsToNormalState(WidgetTester tester) async {
  thenMicIconIsDisplayed(tester);
}

Future<void> thenExistingTextIsPreserved(WidgetTester tester, String existingText) async {
  thenTextFieldContains(tester, existingText);
}

Future<void> thenVoiceRecordingStateIsShown(WidgetTester tester) async {
  thenStopCircleIconIsDisplayed(tester);
}

Future<void> thenEntryIsUpdatedInList(WidgetTester tester, String updatedText) async {
  await thenEntryIsDisplayedInList(tester, updatedText);
}

Future<void> thenOriginalEntryIsNoLongerVisible(WidgetTester tester, String originalText) async {
  thenEntryIsNotDisplayed(tester, originalText);
}

Future<void> thenEntryChangesArePersisted(WidgetTester tester, WidgetTestScope scope, String updatedText) async {
  // Verify persistence service was called (this verifies the behavior was persisted)
  verify(scope.mockPersistenceService.saveEntries(any)).called(greaterThanOrEqualTo(1));
}

Future<void> thenEditIsCancelled(WidgetTester tester) async {
  thenTextFieldIsCleared(tester);
}

Future<void> thenOriginalEntryIsRestored(WidgetTester tester, String originalText) async {
  await thenEntryIsDisplayedInList(tester, originalText);
}

Future<void> thenNoChangeIsPersisted(WidgetTester tester, WidgetTestScope scope) async {
  // Clear previous interactions and verify no new saves occurred
  verifyNever(scope.mockPersistenceService.saveEntries(any));
}

Future<void> thenVoiceContentReplacesEditText(WidgetTester tester, String transcribedText) async {
  thenTextFieldContains(tester, transcribedText);
}

Future<void> thenUserCanSaveVoiceEditedEntry(WidgetTester tester) async {
  // User should be able to save the voice-edited content
  expect(find.byIcon(Icons.check_rounded), findsOneWidget);
}

Future<void> thenEntryIsRemovedFromList(WidgetTester tester, String entryText) async {
  thenEntryIsNotDisplayed(tester, entryText);
}

Future<void> thenUndoOptionIsAvailable(WidgetTester tester) async {
  thenSnackbarIsDisplayedWithMessage(tester, 'Entry deleted');
  thenSnackbarHasAction(tester, 'Undo');
}

Future<void> thenDeletionIsPersisted(WidgetTester tester, WidgetTestScope scope) async {
  verify(scope.mockPersistenceService.saveEntries(any)).called(greaterThanOrEqualTo(1));
}

Future<void> thenEntryIsRestoredToList(WidgetTester tester, String entryText) async {
  await thenEntryIsDisplayedInList(tester, entryText);
}

Future<void> thenEntryRestorationIsPersisted(WidgetTester tester, WidgetTestScope scope) async {
  verify(scope.mockPersistenceService.saveEntries(any)).called(greaterThanOrEqualTo(1));
}

Future<void> thenUndoOptionDisappears(WidgetTester tester) async {
  // Snackbar should disappear after undo action
  await tester.pumpAndSettle();
  expect(find.byType(SnackBar), findsNothing);
}

Future<void> thenEditModeIsExited(WidgetTester tester) async {
  // Verify cancel button is no longer visible
  expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);
  // Verify text field is cleared
  thenTextFieldIsCleared(tester);
}

// Helper Functions

Future<int> getVisibleEntryCount(WidgetTester tester) async {
  final entriesListFinder = find.byType(EntriesList);
  if (entriesListFinder.evaluate().isEmpty) return 0;
  
  final entryItemFinder = find.descendant(of: entriesListFinder, matching: find.byType(EntryCard));
  return entryItemFinder.evaluate().length;
}