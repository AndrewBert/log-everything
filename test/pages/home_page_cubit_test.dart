import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/pages/home_page.dart';
import 'package:myapp/pages/cubit/home_page_cubit.dart';
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

  group('HomePageCubit State Changes', () {
    testWidgets('should increment title tap count in HomePageCubit when title is tapped', (
      WidgetTester tester,
    ) async {
      await givenHomePageIsDisplayed(tester, scope);
      final homePageCubit = BlocProvider.of<HomePageCubit>(tester.element(find.byType(HomePage)));
      final initialTapCount = homePageCubit.state.titleTapCount;

      await whenAppBarTitleIsTapped(tester);

      thenTitleTapCountIsIncremented(homePageCubit, initialTapCount);
    });

    testWidgets('should display app version from HomePageCubit state', (WidgetTester tester) async {
      const testVersionString = 'v1.2.3 (42)';
      PackageInfo.setMockInitialValues(
        appName: 'LogSplitter',
        packageName: 'com.example.logsplitter',
        version: '1.2.3',
        buildNumber: '42',
        buildSignature: '',
      );

      await givenHomePageIsDisplayed(tester, scope);

      thenAppVersionIsDisplayed(tester, testVersionString);
    });

    testWidgets('should show What\'s New dialog when state indicates', (WidgetTester tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'LogSplitter',
        packageName: 'com.example.logsplitter',
        version: '2.0.0',
        buildNumber: '10',
        buildSignature: '',
      );
      SharedPreferences.setMockInitialValues({'last_shown_whats_new_version': 'v1.0.0 (1)'});

      await givenHomePageIsDisplayed(tester, scope, settle: false);
      await tester.pumpAndSettle();

      final homePageCubit = BlocProvider.of<HomePageCubit>(tester.element(find.byType(HomePage)));
      expect(
        homePageCubit.state.showWhatsNewDialog,
        isTrue,
        reason: "HomePageCubit state should have showWhatsNewDialog as true",
      );

      thenWhatsNewDialogIsDisplayed(tester);
    });
  });
}
