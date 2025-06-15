import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/locator.dart';

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
    scope.initializeWidget();
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

  group('Voice Input', () {
    testWidgets(
      'Given user has app open with mic permission, When mic button is tapped, Then recording starts and UI shows recording state',
      (WidgetTester tester) async {
        // Given - User has app open with microphone permission granted
        scope.stubStartRecordingSuccess();
        await givenHomePageIsDisplayed(tester, scope, settle: false);
        await tester.pump();

        // When - User taps mic button
        await whenMicButtonIsTapped(tester);

        // Then - Recording starts and UI shows stop button
        thenStopCircleIconIsDisplayed(tester);
        thenAudioRecordingServicesAreCalledForStart(scope);
      },
    );

    testWidgets(
      'Given user is recording audio, When stop button is tapped, Then recording stops and transcription is processed',
      (WidgetTester tester) async {
        // Given - User is recording audio
        scope.stubStartRecordingSuccess();
        const transcribedText = 'This is the transcribed text';
        scope.stubTranscriptionSuccess(transcribedText);
        await givenHomePageIsDisplayed(tester, scope, settle: false);
        await tester.pump();

        // When - User records for a few seconds then stops
        await runFakeAsync((async) async {
          await whenMicButtonIsTapped(tester, settle: false);
          async.elapse(const Duration(seconds: 3));
          await whenStopButtonIsTapped(tester);
          async.elapse(Duration.zero);
        });
        await tester.pumpAndSettle();

        // Then - Recording stops, transcription completes, and text appears in input
        thenAudioAndSpeechServicesAreCalledForStopAndTranscribe(scope);
        thenMicIconIsDisplayed(tester);
        thenTextFieldContains(tester, transcribedText);
      },
    );

    testWidgets(
      'Given user wants to use chat, When chat button is tapped, Then chat mode becomes active',
      (WidgetTester tester) async {
        // Given - User has app open
        await givenHomePageIsDisplayed(tester, scope, settle: false);
        await tester.pump();

        // When - User taps chat button
        final chatButton = find.byIcon(Icons.forum_outlined);
        expect(chatButton, findsOneWidget);
        await tester.tap(chatButton);
        await tester.pumpAndSettle();

        // Then - Chat mode is active (icon and text change)
        expect(find.byIcon(Icons.forum_rounded), findsOneWidget);
        expect(find.text('Close Chat'), findsOneWidget);
      },
    );

    testWidgets(
      'Given user is recording voice input, When transcription completes, Then text appears in input field and can be edited',
      (WidgetTester tester) async {
        // Given - Voice recording is set up
        const transcribedText = 'This is transcribed voice text';
        scope.stubStartRecordingSuccess();
        scope.stubTranscriptionSuccess(transcribedText);
        
        await givenHomePageIsDisplayed(tester, scope, settle: false);
        await tester.pump();

        // When - User records and transcription completes
        await runFakeAsync((async) async {
          await whenMicButtonIsTapped(tester, settle: false);
          async.elapse(const Duration(seconds: 3));
          await whenStopButtonIsTapped(tester);
          async.elapse(Duration.zero);
        });
        await tester.pumpAndSettle();

        // Then - Transcribed text appears and voice input returns to normal state
        thenTextFieldContains(tester, transcribedText);
        thenMicIconIsDisplayed(tester);
      },
    );
  });
}