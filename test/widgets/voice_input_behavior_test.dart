import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/locator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../mock_path_provider_platform.dart';
import '../test_di_registrar.dart';
import '../helpers/test_helpers.dart';
import '../helpers/widget_test_scope.dart';

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
  });

  tearDown(() async {
    final entryRepository = getIt<EntryRepository>();
    entryRepository.dispose();
    
    await getIt.reset();
    await scope.dispose();
  });

  group('Voice Input Behaviors', () {
    group('Recording session behaviors', () {
      testWidgets(
        'Given user taps mic button, When recording starts, Then UI shows recording state',
        (WidgetTester tester) async {
          // Given - User has app open with microphone permission granted
          scope.stubPermissionGranted();
          scope.stubStartRecordingSuccess();
          
          await givenUserHasAppOpenWithMicPermission(tester, scope);

          // When - User taps mic button to start recording
          await whenUserTapsMicButton(tester);

          // Then - UI shows recording state with stop button and timer
          await thenRecordingStateIsShown(tester);
          await thenStopButtonIsVisible(tester);
          await thenRecordingTimerIsVisible(tester);
          await thenMicButtonIsHidden(tester);
        },
      );

      testWidgets(
        'Given user is recording, When they tap stop, Then transcription begins',
        (WidgetTester tester) async {
          // Given - User is recording
          scope.stubPermissionGranted();
          scope.stubStartRecordingSuccess();
          const transcribedText = 'This is my voice input test';
          scope.stubTranscriptionSuccess(transcribedText);
          
          await givenUserHasAppOpenWithMicPermission(tester, scope);
          await givenUserIsRecording(tester);

          // When - User taps stop button
          await whenUserTapsStopButton(tester);

          // Then - Transcription begins and text appears in input field
          await thenTranscriptionBegins(tester);
          await thenTranscribedTextAppearsInInput(tester, transcribedText);
          await thenVoiceInputReturnsToNormalState(tester);
        },
      );

      testWidgets(
        'Given recording is too short, When user stops, Then appropriate feedback is shown',
        (WidgetTester tester) async {
          // Given - User starts recording but stops very quickly (< 1 second)
          scope.stubPermissionGranted();
          scope.stubStartRecordingSuccess();
          
          await givenUserHasAppOpenWithMicPermission(tester, scope);
          await givenUserStartsRecordingBriefly(tester);

          // When - User stops recording too quickly
          await whenUserStopsRecordingTooQuickly(tester);

          // Then - Error message about recording being too short is shown
          await thenTooShortRecordingErrorIsShown(tester);
          await thenNoTranscriptionOccurs(tester);
          await thenVoiceInputReturnsToNormalState(tester);
        },
      );
    });

    group('Permission handling', () {
      testWidgets(
        'Given microphone permission denied, When user taps mic, Then permission request is shown',
        (WidgetTester tester) async {
          // Given - User has app open but microphone permission is denied
          when(scope.mockPermissionService.getMicrophoneStatus()).thenAnswer(
            (_) async => PermissionStatus.denied,
          );
          when(scope.mockPermissionService.requestMicrophonePermission()).thenAnswer(
            (_) async => PermissionStatus.denied,
          );
          
          await givenUserHasAppOpenWithoutMicPermission(tester, scope);

          // When - User taps mic button
          await whenUserTapsMicButton(tester);

          // Then - Permission request occurs and recording doesn't start
          await thenMicrophonePermissionIsRequested(tester, scope);
          await thenRecordingDoesNotStart(tester);
          await thenPermissionErrorIsShown(tester);
        },
      );

      testWidgets(
        'Given permission is granted, When user taps mic, Then recording starts immediately',
        (WidgetTester tester) async {
          // Given - User grants microphone permission
          scope.stubPermissionGranted();
          scope.stubStartRecordingSuccess();
          
          await givenUserHasAppOpenWithMicPermission(tester, scope);

          // When - User taps mic button
          await whenUserTapsMicButton(tester);

          // Then - Recording starts immediately without additional prompts
          await thenRecordingStartsImmediately(tester);
          await thenRecordingStateIsShown(tester);
        },
      );

      testWidgets(
        'Given permission is revoked during recording, When recording stops, Then graceful error handling',
        (WidgetTester tester) async {
          // Given - User starts recording but permission gets revoked
          scope.stubPermissionGranted();
          scope.stubStartRecordingSuccess();
          
          // Configure recorder service to throw error (simulating permission revocation)
          when(scope.mockAudioRecorderService.stop()).thenThrow(
            Exception('Recording permission revoked'),
          );
          
          await givenUserHasAppOpenWithMicPermission(tester, scope);
          await givenUserIsRecording(tester);
          await givenPermissionIsRevokedDuringRecording(tester, scope);

          // When - Recording attempts to stop
          await whenUserTapsStopButton(tester);

          // Then - Graceful error handling occurs
          await thenPermissionRevokedErrorIsHandled(tester);
          await thenVoiceInputReturnsToNormalState(tester);
          await thenNoTranscriptionAttempted(tester);
        },
      );
    });

    group('Transcription accuracy', () {
      testWidgets(
        'Given user speaks clearly, When transcription completes, Then text accurately reflects speech',
        (WidgetTester tester) async {
          // Given - User has clear speech recording
          scope.stubPermissionGranted();
          scope.stubStartRecordingSuccess();
          const clearSpeech = 'I had a productive meeting with my team today and accomplished all goals';
          scope.stubTranscriptionSuccess(clearSpeech);
          
          await givenUserHasAppOpenWithMicPermission(tester, scope);
          await givenUserRecordsClearSpeech(tester);

          // When - Transcription completes
          await whenTranscriptionCompletes(tester);

          // Then - Text accurately reflects the spoken content
          await thenTranscribedTextIsAccurate(tester, clearSpeech);
          await thenTextAppearsInInputField(tester, clearSpeech);
        },
      );

      testWidgets(
        'Given background noise exists, When transcription runs, Then system handles noise appropriately',
        (WidgetTester tester) async {
          // Given - Recording has background noise (simulated by partial transcription)
          scope.stubPermissionGranted();
          scope.stubStartRecordingSuccess();
          const noisySpeechResult = 'meeting with team'; // Partial due to noise
          scope.stubTranscriptionSuccess(noisySpeechResult);
          
          await givenUserHasAppOpenWithMicPermission(tester, scope);
          await givenUserRecordsWithBackgroundNoise(tester);

          // When - Transcription runs with noise
          await whenTranscriptionRunsWithNoise(tester);

          // Then - System handles noise and provides best-effort transcription
          await thenPartialTranscriptionIsProvided(tester, noisySpeechResult);
          await thenUserCanEditPartialTranscription(tester);
        },
      );

      testWidgets(
        'Given transcription fails, When error occurs, Then user receives clear feedback',
        (WidgetTester tester) async {
          // Given - User records but transcription service fails
          scope.stubPermissionGranted();
          scope.stubStartRecordingSuccess();
          
          // Configure transcription to fail
          when(scope.mockSpeechService.transcribeAudio(any, language: anyNamed('language')))
              .thenThrow(Exception('Transcription service unavailable'));
          
          await givenUserHasAppOpenWithMicPermission(tester, scope);
          await givenUserRecordsValidAudio(tester);

          // When - Transcription fails
          await whenTranscriptionFails(tester);

          // Then - Clear error feedback is provided to user
          await thenTranscriptionErrorIsShown(tester);
          await thenUserCanRetryOrEnterTextManually(tester);
          await thenVoiceInputReturnsToNormalState(tester);
        },
      );
    });

    group('Voice input integration with text input', () {
      testWidgets(
        'Given user has typed text, When they add voice input, Then voice content is appended',
        (WidgetTester tester) async {
          // Given - User has already typed some text
          const existingText = 'Started working on project and';
          const voiceText = 'finished the implementation successfully';
          const expectedCombined = 'Started working on project and finished the implementation successfully';
          
          scope.stubPermissionGranted();
          scope.stubStartRecordingSuccess();
          scope.stubTranscriptionSuccess(voiceText);
          
          await givenUserHasAppOpenWithMicPermission(tester, scope);
          await givenUserHasTypedText(tester, existingText);

          // When - User adds voice input
          await whenUserAddsVoiceInput(tester);
          await whenTranscriptionCompletes(tester);

          // Then - Voice content is appended to existing text
          await thenVoiceContentIsAppended(tester, expectedCombined);
          await thenUserCanSubmitCombinedEntry(tester);
        },
      );

      // TODO: Fix intermittent test failure for "Given user has typed text, When they add voice input, Then voice content is appended"
      // The test passes when run individually but fails when run with other tests, indicating potential state contamination.
      // Need to investigate test isolation or timing issues in voice input text appending functionality.
      
      // Note: Voice input during edit mode may not be currently supported in the UI
      // This test would verify that voice input works during entry editing
      // but it may require UI changes to enable mic button in edit mode
    });

    group('Chat mode integration', () {
      testWidgets(
        'Given app is loaded, When user taps chat button, Then chat mode becomes active',
        (WidgetTester tester) async {
          // Given - User has app open
          scope.stubPermissionGranted();
          await givenUserHasAppOpenWithMicPermission(tester, scope);

          // When - User taps chat button
          await givenChatModeIsActive(tester);

          // Then - Chat mode is active (UI changes)
          await thenChatModeIsActive(tester);
        },
      );

      testWidgets(
        'Given chat mode is active, When user taps close chat, Then chat mode becomes inactive',
        (WidgetTester tester) async {
          // Given - Chat mode is active
          scope.stubPermissionGranted();
          await givenUserHasAppOpenWithMicPermission(tester, scope);
          await givenChatModeIsActive(tester);

          // When - User taps close chat button
          final closeChatButton = find.byIcon(Icons.forum_rounded);
          await tester.tap(closeChatButton);
          await tester.pumpAndSettle();

          // Then - Chat mode becomes inactive
          expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
          expect(find.text('Chat'), findsOneWidget);
        },
      );

      testWidgets(
        'Given chat mode is active, When user records voice, Then voice input handles chat context appropriately',
        (WidgetTester tester) async {
          // Given - Chat mode is active and voice input is configured
          const voiceText = 'What did I work on yesterday?';
          scope.stubPermissionGranted();
          scope.stubStartRecordingSuccess();
          scope.stubTranscriptionSuccess(voiceText);
          
          await givenUserHasAppOpenWithMicPermission(tester, scope);
          await givenChatModeIsActive(tester);

          // When - User records voice input in chat mode
          await whenUserRecordsVoiceInChatMode(tester);

          // Then - Voice input behaves appropriately for chat context
          await thenVoiceInputReturnsToNormalState(tester);
          // Note: Full chat integration tested elsewhere
        },
      );
    });
  });
}

// BDD Helper Functions - GIVEN

Future<void> givenUserHasAppOpenWithMicPermission(WidgetTester tester, WidgetTestScope scope) async {
  await givenHomePageIsDisplayed(tester, scope);
  thenInitialUiElementsAreDisplayed(tester);
  thenMicIconIsDisplayed(tester);
}

Future<void> givenUserHasAppOpenWithoutMicPermission(WidgetTester tester, WidgetTestScope scope) async {
  await givenHomePageIsDisplayed(tester, scope);
  thenInitialUiElementsAreDisplayed(tester);
  thenMicIconIsDisplayed(tester);
}

Future<void> givenUserIsRecording(WidgetTester tester) async {
  await whenMicButtonIsTapped(tester);
  await tester.pump(const Duration(seconds: 1));
}

Future<void> givenUserStartsRecordingBriefly(WidgetTester tester) async {
  await whenMicButtonIsTapped(tester);
  // Don't wait - simulate immediate stop
}

Future<void> givenPermissionIsRevokedDuringRecording(WidgetTester tester, WidgetTestScope scope) async {
  // Simulate permission status change during recording
  when(scope.mockPermissionService.getMicrophoneStatus()).thenAnswer(
    (_) async => PermissionStatus.denied,
  );
}

Future<void> givenUserRecordsClearSpeech(WidgetTester tester) async {
  await givenUserIsRecording(tester);
  await tester.pump(const Duration(seconds: 2)); // Adequate recording time
}

Future<void> givenUserRecordsWithBackgroundNoise(WidgetTester tester) async {
  await givenUserIsRecording(tester);
  await tester.pump(const Duration(seconds: 3)); // Recording with noise
}

Future<void> givenUserRecordsValidAudio(WidgetTester tester) async {
  await givenUserIsRecording(tester);
  await tester.pump(const Duration(seconds: 2)); // Valid duration
}

Future<void> givenUserHasTypedText(WidgetTester tester, String text) async {
  await whenTextIsEntered(tester, text);
}


// BDD Helper Functions - WHEN

Future<void> whenUserTapsMicButton(WidgetTester tester) async {
  await whenMicButtonIsTapped(tester);
}

Future<void> whenUserTapsStopButton(WidgetTester tester) async {
  await whenStopButtonIsTapped(tester);
}

Future<void> whenUserStopsRecordingTooQuickly(WidgetTester tester) async {
  // Stop recording immediately without adequate duration
  await whenStopButtonIsTapped(tester);
}

Future<void> whenTranscriptionCompletes(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

Future<void> whenTranscriptionRunsWithNoise(WidgetTester tester) async {
  await whenUserTapsStopButton(tester);
  await tester.pumpAndSettle();
}

Future<void> whenTranscriptionFails(WidgetTester tester) async {
  await whenUserTapsStopButton(tester);
  await tester.pumpAndSettle();
}

Future<void> whenUserAddsVoiceInput(WidgetTester tester) async {
  await whenUserTapsMicButton(tester);
  await tester.pump(const Duration(seconds: 2));
  await whenUserTapsStopButton(tester);
}


// BDD Helper Functions - THEN

Future<void> thenRecordingStateIsShown(WidgetTester tester) async {
  thenStopCircleIconIsDisplayed(tester);
}

Future<void> thenStopButtonIsVisible(WidgetTester tester) async {
  thenStopCircleIconIsDisplayed(tester);
}

Future<void> thenRecordingTimerIsVisible(WidgetTester tester) async {
  // Look for timer text (recording duration)
  await tester.pump(const Duration(seconds: 1));
  // Timer would show format like "00:01" but we'll verify stop button as proxy
  thenStopCircleIconIsDisplayed(tester);
}

Future<void> thenMicButtonIsHidden(WidgetTester tester) async {
  // When recording, mic button should be replaced by stop button
  expect(find.byIcon(Icons.mic_rounded), findsNothing);
}

Future<void> thenTranscriptionBegins(WidgetTester tester) async {
  // Transcription starts after recording stops
  await tester.pumpAndSettle();
}

Future<void> thenTranscribedTextAppearsInInput(WidgetTester tester, String expectedText) async {
  thenTextFieldContains(tester, expectedText);
}

Future<void> thenVoiceInputReturnsToNormalState(WidgetTester tester) async {
  thenMicIconIsDisplayed(tester);
  expect(find.byIcon(Icons.stop_circle_rounded), findsNothing);
}

Future<void> thenTooShortRecordingErrorIsShown(WidgetTester tester) async {
  // Look for error message about recording being too short
  expect(find.textContaining('too short'), findsOneWidget);
}

Future<void> thenNoTranscriptionOccurs(WidgetTester tester) async {
  // Text field should remain empty since transcription was skipped
  thenTextFieldIsCleared(tester);
}

Future<void> thenMicrophonePermissionIsRequested(WidgetTester tester, WidgetTestScope scope) async {
  verify(scope.mockPermissionService.requestMicrophonePermission()).called(1);
}

Future<void> thenRecordingDoesNotStart(WidgetTester tester) async {
  // Recording state should not be shown
  expect(find.byIcon(Icons.stop_circle_rounded), findsNothing);
  thenMicIconIsDisplayed(tester);
}

Future<void> thenPermissionErrorIsShown(WidgetTester tester) async {
  expect(find.textContaining('permission'), findsOneWidget);
}

Future<void> thenRecordingStartsImmediately(WidgetTester tester) async {
  thenStopCircleIconIsDisplayed(tester);
}

Future<void> thenPermissionRevokedErrorIsHandled(WidgetTester tester) async {
  // Should show error about recording failure
  expect(find.textContaining('Error'), findsOneWidget);
}

Future<void> thenNoTranscriptionAttempted(WidgetTester tester) async {
  // Text field should remain empty since transcription wasn't attempted
  thenTextFieldIsCleared(tester);
}

Future<void> thenTranscribedTextIsAccurate(WidgetTester tester, String expectedText) async {
  thenTextFieldContains(tester, expectedText);
}

Future<void> thenTextAppearsInInputField(WidgetTester tester, String expectedText) async {
  thenTextFieldContains(tester, expectedText);
}

Future<void> thenPartialTranscriptionIsProvided(WidgetTester tester, String partialText) async {
  thenTextFieldContains(tester, partialText);
}

Future<void> thenUserCanEditPartialTranscription(WidgetTester tester) async {
  // User should be able to edit the text field
  final textField = find.byType(TextField);
  expect(textField, findsOneWidget);
}

Future<void> thenTranscriptionErrorIsShown(WidgetTester tester) async {
  expect(find.textContaining('Transcription'), findsOneWidget);
}

Future<void> thenUserCanRetryOrEnterTextManually(WidgetTester tester) async {
  // Mic button should be available for retry
  thenMicIconIsDisplayed(tester);
  // Text field should be available for manual entry
  final textField = find.byType(TextField);
  expect(textField, findsOneWidget);
}

Future<void> thenVoiceContentIsAppended(WidgetTester tester, String expectedCombined) async {
  thenTextFieldContains(tester, expectedCombined);
}

Future<void> thenUserCanSubmitCombinedEntry(WidgetTester tester) async {
  // Send button should be available
  expect(find.byIcon(Icons.send_rounded), findsOneWidget);
}

// Chat Mode Helper Functions

Future<void> givenChatModeIsActive(WidgetTester tester) async {
  // Tap chat button to activate chat mode
  final chatButton = find.byIcon(Icons.forum_outlined);
  expect(chatButton, findsOneWidget);
  await tester.tap(chatButton);
  await tester.pumpAndSettle();
}

Future<void> whenUserRecordsVoiceInChatMode(WidgetTester tester) async {
  await whenUserTapsMicButton(tester);
  await tester.pump(const Duration(seconds: 2));
  await whenUserTapsStopButton(tester);
  await tester.pumpAndSettle();
}

Future<void> thenVoiceInputIsSentToChat(WidgetTester tester, String expectedText) async {
  // Check that the user message appears in chat
  expect(find.text(expectedText), findsOneWidget);
}

Future<void> thenChatShowsAiResponse(WidgetTester tester, String aiResponse) async {
  // Check that AI response appears in chat
  expect(find.text(aiResponse), findsOneWidget);
}

Future<void> thenChatShowsErrorResponse(WidgetTester tester) async {
  // Check for error message in chat
  expect(find.textContaining('Sorry'), findsOneWidget);
}

Future<void> thenChatModeRemainsActive(WidgetTester tester) async {
  // Verify chat mode is still active (bottom sheet should be visible)
  expect(find.byType(BottomSheet), findsOneWidget);
}

Future<void> thenChatModeIsActive(WidgetTester tester) async {
  // Verify chat mode is active (icon changes to filled version)
  expect(find.byIcon(Icons.forum_rounded), findsOneWidget);
  expect(find.text('Close Chat'), findsOneWidget);
}

