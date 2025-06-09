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

  group('Voice Input Tests', () {
    testWidgets('should show stop_circle icon when mic button is tapped', (WidgetTester tester) async {
      scope.stubStartRecordingSuccess();
      await givenHomePageIsDisplayed(tester, scope, settle: false);
      await tester.pump();

      await whenMicButtonIsTapped(tester);

      thenStopCircleIconIsDisplayed(tester);
      thenAudioRecordingServicesAreCalledForStart(scope);
    });

    testWidgets('should call stop and transcribe when stop button is tapped', (WidgetTester tester) async {
      scope.stubStartRecordingSuccess();
      const transcribedText = 'This is the transcribed text';
      scope.stubTranscriptionSuccess(transcribedText);
      await givenHomePageIsDisplayed(tester, scope, settle: false);
      await tester.pump();

      await runFakeAsync((async) async {
        await whenMicButtonIsTapped(tester, settle: false);
        async.elapse(const Duration(seconds: 3));
        await whenStopButtonIsTapped(tester);
        async.elapse(Duration.zero);
      });
      await tester.pumpAndSettle();

      thenAudioAndSpeechServicesAreCalledForStopAndTranscribe(scope);
      thenMicIconIsDisplayed(tester);
      thenTextFieldContains(tester, transcribedText);
    });
  });
}
