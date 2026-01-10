import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';
import 'package:myapp/dashboard_v2/widgets/recent_entries_carousel.dart';
import 'package:myapp/dashboard_v2/widgets/categories_carousel.dart';
import 'package:myapp/dashboard_v2/pages/category_entries_page.dart';
import 'package:myapp/dashboard_v2/pages/dashboard_v2_page.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/locator.dart';

import '../helpers/widget_test_scope.dart';

// =============================================================================
// GIVEN helpers - Set up preconditions
// =============================================================================

Future<void> givenDashboardV2IsDisplayed(
  WidgetTester tester,
  WidgetTestScope scope,
) async {
  // Initialize repository FIRST so currentEntries is populated
  // when DashboardV2Cubit's loadEntries() is called
  final repository = getIt<EntryRepository>();
  await tester.runAsync(() async {
    await repository.initialize();
  });

  // Debug: verify repository has data
  assert(repository.currentEntries.isNotEmpty,
      'Repository should have entries after initialization');
  assert(repository.currentCategories.isNotEmpty,
      'Repository should have categories after initialization');

  print('DEBUG: Repository entries count: ${repository.currentEntries.length}');
  print('DEBUG: Repository categories count: ${repository.currentCategories.length}');
  print('DEBUG: Repository categories: ${repository.currentCategories.map((c) => c.name).toList()}');

  // Now pump widget - cubit will get entries from already-initialized repository
  await tester.pumpWidget(scope.widgetUnderTest);

  // Let async operations (like PackageInfo) settle
  await tester.runAsync(() async {
    await Future.delayed(const Duration(milliseconds: 100));
  });

  // Pump frames to let widget tree build and state settle
  for (int i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> givenCategoryEntriesPageIsDisplayed(
  WidgetTester tester,
  WidgetTestScope scope,
  String categoryName,
) async {
  // Initialize repository to load entries from mocked persistence
  final repository = getIt<EntryRepository>();
  await tester.runAsync(() async {
    await repository.initialize();
  });

  scope.initializeWidgetWithCategoryEntriesPage(categoryName);
  await tester.pumpWidget(scope.widgetUnderTest);
  // Pump frames to let widget tree build and state settle
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> givenDashboardHasEntries(
  WidgetTester tester,
  WidgetTestScope scope,
) async {
  scope.stubPersistenceWithInitialEntries();
  await givenDashboardV2IsDisplayed(tester, scope);
}

Future<void> givenDashboardHasNoEntries(
  WidgetTester tester,
  WidgetTestScope scope,
) async {
  scope.stubPersistenceWithEmptyEntries();
  await givenDashboardV2IsDisplayed(tester, scope);
}

// =============================================================================
// WHEN helpers - Perform actions
// =============================================================================

Future<void> whenCategoryCardIsTapped(
  WidgetTester tester,
  String categoryName,
) async {
  // Find category card by looking for text within the categories carousel area
  final categoriesCarousel = find.byType(CategoriesCarousel);
  expect(categoriesCarousel, findsOneWidget,
      reason: 'CategoriesCarousel should be displayed');

  // Find the category name text within the carousel
  final categoryTextFinder = find.descendant(
    of: categoriesCarousel,
    matching: find.text(categoryName),
  );
  expect(categoryTextFinder, findsAtLeastNWidgets(1),
      reason: 'Category "$categoryName" should be in carousel');

  await tester.tap(categoryTextFinder.first);
  // Use pump instead of pumpAndSettle to avoid hanging
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> whenBackButtonIsTapped(WidgetTester tester) async {
  final backButton = find.byType(BackButton);
  if (backButton.evaluate().isNotEmpty) {
    await tester.tap(backButton);
  } else {
    // Try finding the back arrow icon
    final backIcon = find.byIcon(Icons.arrow_back);
    expect(backIcon, findsOneWidget, reason: 'Back button should be available');
    await tester.tap(backIcon);
  }
  // Use pump instead of pumpAndSettle to avoid hanging
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> whenEntryCardIsTapped(
  WidgetTester tester,
  String entryText,
) async {
  final entryTextFinder = find.text(entryText);
  expect(entryTextFinder, findsAtLeastNWidgets(1),
      reason: 'Entry with text "$entryText" should be displayed');
  await tester.tap(entryTextFinder.first);
  // Use pump instead of pumpAndSettle to avoid hanging
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

// =============================================================================
// THEN helpers - Verify outcomes
// =============================================================================

void thenDashboardV2PageIsDisplayed(WidgetTester tester) {
  final dashboardPage = find.byType(DashboardV2Page);
  expect(dashboardPage, findsOneWidget,
      reason: 'DashboardV2Page should be displayed');
}

void thenDashboardV2PageKeyIsPresent(WidgetTester tester) {
  final scaffoldFinder = find.byKey(dashboardV2PageKey);
  expect(scaffoldFinder, findsOneWidget,
      reason: 'DashboardV2Page scaffold with key should be displayed');
}

void thenAppBarIsDisplayed(WidgetTester tester) {
  final appBarFinder = find.byKey(dashboardV2AppBarKey);
  expect(appBarFinder, findsOneWidget,
      reason: 'DashboardV2 AppBar should be displayed');
}

void thenAllCategoriesAreDisplayed(
  WidgetTester tester,
  List<String> categoryNames,
) {
  for (final categoryName in categoryNames) {
    final categoryFinder = find.text(categoryName);
    expect(categoryFinder, findsAtLeastNWidgets(1),
        reason: 'Category "$categoryName" should be displayed');
  }
}

void thenCategoriesCarouselIsDisplayed(WidgetTester tester) {
  // Debug: Check if empty state is displayed instead
  final emptyState = find.text('No entries yet');
  if (emptyState.evaluate().isNotEmpty) {
    print('DEBUG: "No entries yet" is displayed - entries.isEmpty is true in state');
  }

  // Debug: Check for various widgets to understand the tree
  final dashboardPage = find.byType(DashboardV2Page);
  print('DEBUG: DashboardV2Page found: ${dashboardPage.evaluate().length}');
  final recentCarousel = find.byType(RecentEntriesCarousel);
  print('DEBUG: RecentEntriesCarousel found: ${recentCarousel.evaluate().length}');
  final categoriesCarousel = find.byType(CategoriesCarousel);
  print('DEBUG: CategoriesCarousel found: ${categoriesCarousel.evaluate().length}');

  final carousel = find.byType(CategoriesCarousel);
  expect(carousel, findsOneWidget,
      reason: 'Categories carousel should be displayed');
}

void thenRecentEntriesCarouselIsDisplayed(WidgetTester tester) {
  final carousel = find.byType(RecentEntriesCarousel);
  expect(carousel, findsOneWidget,
      reason: 'Recent entries carousel should be displayed');
}

void thenCategoryEntriesPageIsDisplayed(WidgetTester tester) {
  final categoryEntriesPage = find.byType(CategoryEntriesPage);
  expect(categoryEntriesPage, findsOneWidget,
      reason: 'CategoryEntriesPage should be displayed after navigation');
}

void thenCategoryEntriesPageShowsCategory(
  WidgetTester tester,
  String categoryName,
) {
  // The category name should appear in the app bar title
  final categoryNameFinder = find.text(categoryName);
  expect(categoryNameFinder, findsAtLeastNWidgets(1),
      reason: 'Category name "$categoryName" should be displayed in app bar');
}

void thenEntriesAreDisplayedInList(
  WidgetTester tester,
  List<String> entryTexts,
) {
  for (final text in entryTexts) {
    final entryFinder = find.text(text);
    expect(entryFinder, findsAtLeastNWidgets(1),
        reason: 'Entry with text "$text" should be displayed');
  }
}

void thenEntryIsDisplayed(WidgetTester tester, String entryText) {
  final entryFinder = find.text(entryText);
  expect(entryFinder, findsAtLeastNWidgets(1),
      reason: 'Entry with text "$entryText" should be displayed');
}

void thenEmptyStateIsShown(WidgetTester tester) {
  // Look for common empty state indicators
  final noEntriesYet = find.text('No entries yet');
  final noEntriesYetAlt = find.text('No Entries Yet');
  expect(
    noEntriesYet.evaluate().isNotEmpty || noEntriesYetAlt.evaluate().isNotEmpty,
    isTrue,
    reason: 'Empty state message should be displayed',
  );
}

void thenCategoryEmptyStateIsShown(WidgetTester tester) {
  final noEntriesYet = find.text('No Entries Yet');
  expect(noEntriesYet, findsOneWidget,
      reason: 'Category empty state should be displayed');
}

void thenCategoryCountIsDisplayed(
  WidgetTester tester,
  String categoryName,
  int expectedCount,
) {
  // Look for entry count text like "2 entries" or "1 entry"
  final countText = expectedCount == 1 ? '1 entry' : '$expectedCount entries';
  final countFinder = find.text(countText);
  expect(countFinder, findsAtLeastNWidgets(1),
      reason: 'Category count "$countText" should be displayed');
}

void thenTimestampIsDisplayed(WidgetTester tester, String timestamp) {
  final timestampFinder = find.text(timestamp);
  expect(timestampFinder, findsAtLeastNWidgets(1),
      reason: 'Timestamp "$timestamp" should be displayed');
}

void thenDateHeaderIsDisplayed(WidgetTester tester, String dateHeader) {
  final headerFinder = find.text(dateHeader);
  expect(headerFinder, findsAtLeastNWidgets(1),
      reason: 'Date header "$dateHeader" should be displayed');
}
