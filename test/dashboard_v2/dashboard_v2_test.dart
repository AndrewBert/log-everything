import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/locator.dart';

import '../mock_path_provider_platform.dart';
import '../test_di_registrar.dart';
import '../helpers/widget_test_scope.dart';
import '../helpers/test_data.dart';
import 'dashboard_v2_test_helpers.dart';

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
      imageStorageService: scope.mockImageStorageService,
      sharedPreferences: scope.mockSharedPreferences,
      httpClient: scope.mockHttpClient,
      firestoreSyncService: scope.mockFirestoreSyncService,
      intentDetectionService: scope.mockIntentDetectionService,
    );
    scope.initializeWidgetWithDashboardV2();
    scope.stubPersistenceWithInitialEntries();
    scope.stubPermissionGranted();
    scope.stubAiServiceForDashboardV2();

    // Stub SharedPreferences for prompt suggestions
    when(scope.mockSharedPreferences.getString(any)).thenReturn(null);
    when(scope.mockSharedPreferences.setString(any, any)).thenAnswer((_) async => true);
  });

  tearDown(() async {
    final entryRepository = getIt<EntryRepository>();
    entryRepository.dispose();

    await getIt.reset();
    await scope.dispose();
  });

  group('Dashboard Display', () {
    testWidgets(
      'Given user opens app, When dashboard loads, Then entries and categories are displayed',
      (WidgetTester tester) async {
        // Given - User opens the app
        await givenDashboardHasEntries(tester, scope);

        // Then - Dashboard should be visible with entries
        thenDashboardV2PageIsDisplayed(tester);
        thenRecentEntriesCarouselIsDisplayed(tester);
        // Categories display in uppercase on entry cards (Misc -> NONE)
        thenAllCategoriesAreDisplayed(tester, ['NONE', 'WORK']);
      },
    );

    testWidgets(
      'Given dashboard with entries, When viewing recent entries, Then carousel displays entry text',
      (WidgetTester tester) async {
        // Given - Dashboard is displayed with entries
        await givenDashboardHasEntries(tester, scope);

        // Then - Recent entries carousel should be visible with entries
        thenRecentEntriesCarouselIsDisplayed(tester);
        // Verify that entry text is visible in the carousel
        thenEntryIsDisplayed(tester, TestData.entryToday1.text);
      },
    );

  });

  group('Category Entries Page', () {
    testWidgets(
      'Given user opens category entries page, When entries exist, Then entries are displayed',
      (WidgetTester tester) async {
        // Given - Category entries page is displayed for a category with entries
        await givenCategoryEntriesPageIsDisplayed(tester, scope, 'Work');

        // Then - Entries should be displayed
        thenCategoryEntriesPageIsDisplayed(tester);
        thenCategoryEntriesPageShowsCategory(tester, 'Work');
        // TestData.entryToday2 has category 'Work'
        thenEntryIsDisplayed(tester, TestData.entryToday2.text);
      },
    );

    testWidgets(
      'Given user opens category entries page, When no entries exist, Then empty state is shown',
      (WidgetTester tester) async {
        // Given - Category entries page for a category with no entries
        scope.stubPersistenceWithEmptyEntries();
        await givenCategoryEntriesPageIsDisplayed(tester, scope, 'Misc');

        // Then - Empty state should be shown
        thenCategoryEmptyStateIsShown(tester);
      },
    );

    testWidgets(
      'Given user is on category entries page, When page loads, Then category count is shown',
      (WidgetTester tester) async {
        // Given - Category entries page for Misc
        await givenCategoryEntriesPageIsDisplayed(tester, scope, 'Misc');

        // Then - Entry count should be displayed
        // TestData has 2 entries in Misc category (entryToday1 and entryOlder)
        thenCategoryCountIsDisplayed(tester, 'Misc', 2);
      },
    );
  });

  group('Empty State Scenarios', () {
    testWidgets(
      'Given user has no entries, When viewing dashboard, Then empty state is shown',
      (WidgetTester tester) async {
        // Given - No entries exist
        await givenDashboardHasNoEntries(tester, scope);

        // Then - Empty state should be displayed
        thenEmptyStateIsShown(tester);
      },
    );
  });
}
