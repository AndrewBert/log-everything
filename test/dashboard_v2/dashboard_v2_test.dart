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

  group('Category Navigation', () {
    testWidgets(
      'Given user opens app, When dashboard loads, Then all categories are displayed',
      (WidgetTester tester) async {
        // Given - User opens the app
        await givenDashboardHasEntries(tester, scope);

        // Then - All categories should be visible
        thenDashboardV2PageIsDisplayed(tester);
        thenCategoriesCarouselIsDisplayed(tester);
        // TestData has Misc, Work, Personal categories
        thenAllCategoriesAreDisplayed(tester, ['Misc', 'Work', 'Personal']);
      },
    );

    testWidgets(
      'Given user is on dashboard, When user taps a category, Then category entries page opens',
      (WidgetTester tester) async {
        // Given - Dashboard is displayed with entries
        await givenDashboardHasEntries(tester, scope);
        thenDashboardV2PageIsDisplayed(tester);

        // When - User taps on a category card
        await whenCategoryCardIsTapped(tester, 'Work');

        // Then - Category entries page should open
        thenCategoryEntriesPageIsDisplayed(tester);
        thenCategoryEntriesPageShowsCategory(tester, 'Work');
      },
    );

    testWidgets(
      'Given user is on category entries page, When user taps back, Then returns to dashboard',
      (WidgetTester tester) async {
        // Given - User navigated to category entries page
        await givenDashboardHasEntries(tester, scope);
        await whenCategoryCardIsTapped(tester, 'Work');
        thenCategoryEntriesPageIsDisplayed(tester);

        // When - User taps back button
        await whenBackButtonIsTapped(tester);

        // Then - User returns to dashboard
        thenDashboardV2PageIsDisplayed(tester);
      },
    );
  });

  group('Viewing Entries by Category', () {
    testWidgets(
      'Given user is on category entries page, When entries exist, Then entries are displayed in list',
      (WidgetTester tester) async {
        // Given - Category entries page is displayed for a category with entries
        await givenCategoryEntriesPageIsDisplayed(tester, scope, 'Work');

        // Then - Entries should be displayed
        // TestData.entryToday2 has category 'Work'
        thenEntryIsDisplayed(tester, TestData.entryToday2.text);
      },
    );

    testWidgets(
      'Given user is on category entries page, When no entries exist, Then empty state is shown',
      (WidgetTester tester) async {
        // Given - Category entries page for a category with no entries
        // We'll create a category that has no entries in TestData
        scope.stubPersistenceWithEmptyEntries();
        await givenCategoryEntriesPageIsDisplayed(tester, scope, 'Misc');

        // Then - Empty state should be shown
        thenCategoryEmptyStateIsShown(tester);
      },
    );

    testWidgets(
      'Given user views entries, When entry has timestamp, Then date header is displayed correctly',
      (WidgetTester tester) async {
        // Given - Dashboard is displayed with entries
        await givenDashboardHasEntries(tester, scope);

        // Then - Date headers should be displayed (TODAY, YESTERDAY, etc)
        // TestData has entries for today and yesterday
        thenDateHeaderIsDisplayed(tester, 'TODAY');
      },
    );
  });

  group('Dashboard State', () {
    testWidgets(
      'Given user has entries in multiple categories, When viewing dashboard, Then category counts are accurate',
      (WidgetTester tester) async {
        // Given - Dashboard is displayed with entries in multiple categories
        await givenDashboardHasEntries(tester, scope);

        // Then - Category with entries should show accurate count
        // Navigate to a category to see its entry count
        await whenCategoryCardIsTapped(tester, 'Misc');
        thenCategoryEntriesPageIsDisplayed(tester);
        // TestData has 2 entries in Misc category (entryToday1 and entryOlder)
        thenCategoryCountIsDisplayed(tester, 'Misc', 2);
      },
    );

    testWidgets(
      'Given dashboard with entries, When viewing recent entries, Then carousel displays entries',
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
