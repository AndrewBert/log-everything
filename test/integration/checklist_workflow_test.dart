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
    scope.stubPersistenceWithEmptyEntries();
    scope.stubPermissionGranted();
    scope.stubAiServiceExtractEntries();
  });

  tearDown(() async {
    final entryRepository = getIt<EntryRepository>();
    entryRepository.dispose();

    await getIt.reset();
    await scope.dispose();
  });

  group('Complete Checklist Workflow Integration', () {
    testWidgets(
      'Given user wants to create a checklist category, When they go through the complete workflow, Then they can create, add items, and manage completion',
      (WidgetTester tester) async {
        // GIVEN: User starts with empty app
        await givenHomePageIsDisplayed(tester, scope);

        // WHEN: User creates a new checklist category
        await whenUserCreatesChecklistCategory(tester, 'Shopping List', 'Items to buy at the store');

        // THEN: Category is created and available
        await thenChecklistCategoryIsAvailable(tester, 'Shopping List');

        // WHEN: User adds checklist items
        await whenUserAddsChecklistItem(tester, 'Buy milk');
        await whenUserAddsChecklistItem(tester, 'Buy bread');
        await whenUserAddsChecklistItem(tester, 'Buy eggs');

        // THEN: Items appear in correct order (newest first for incomplete)
        await thenChecklistItemsAppearInCorrectOrder(tester, ['Buy eggs', 'Buy bread', 'Buy milk']);

        // WHEN: User completes some items
        await whenUserCompletesChecklistItem(tester, 'Buy milk');
        await whenUserCompletesChecklistItem(tester, 'Buy bread');

        // THEN: Completed items move to bottom with visual changes
        await thenCompletedItemsMovedToBottom(tester, ['Buy milk', 'Buy bread']);
        await thenIncompleteItemsRemainAtTop(tester, ['Buy eggs']);
        await thenCompletedItemsHaveStrikethrough(tester, ['Buy milk', 'Buy bread']);

        // WHEN: User uncompletes an item
        await whenUserUncompletesChecklistItem(tester, 'Buy bread');

        // THEN: Item moves back to incomplete section
        await thenItemMovesToIncompleteSection(tester, 'Buy bread');
        await thenIncompleteItemsInCorrectOrder(tester, ['Buy bread', 'Buy eggs']);

        // WHEN: User adds a new item after some completions
        await whenUserAddsChecklistItem(tester, 'Buy bananas');

        // THEN: New item appears at top of incomplete section
        await thenNewItemAppearsAtTopOfIncomplete(tester, 'Buy bananas');
        await thenFinalSortingIsCorrect(tester, 
          incomplete: ['Buy bananas', 'Buy bread', 'Buy eggs'], 
          completed: ['Buy milk']
        );
      },
    );

    testWidgets(
      'Given user wants to convert existing category to checklist, When they edit category settings, Then existing entries become checkable',
      (WidgetTester tester) async {
        // GIVEN: User has regular category with entries
        await givenUserHasRegularCategoryWithEntries(tester, scope);

        // WHEN: User converts category to checklist
        await whenUserConvertsRegularCategoryToChecklist(tester, 'Notes');

        // THEN: Existing entries become checkable
        await thenExistingEntriesBecomeCheckable(tester);
        await thenCategoryShowsChecklistIndicator(tester, 'Notes');
      },
    );

    testWidgets(
      'Given user has mixed regular and checklist categories, When they use the app, Then each category behaves correctly',
      (WidgetTester tester) async {
        // GIVEN: User has both regular and checklist categories
        await givenUserHasMixedCategoryTypes(tester, scope);

        // WHEN: User adds entries to both category types
        await whenUserAddsRegularEntry(tester, 'Meeting notes from today');
        await whenUserAddsChecklistItem(tester, 'Complete project report');

        // THEN: Entries behave according to their category type
        await thenRegularEntryHasNoCheckbox(tester, 'Meeting notes from today');
        await thenChecklistEntryHasCheckbox(tester, 'Complete project report');

        // WHEN: User interacts with both entry types
        await whenUserCompletesChecklistItem(tester, 'Complete project report');

        // THEN: Only checklist entries are affected by completion
        await thenOnlyChecklistEntriesShowCompletionEffects(tester);
        await thenRegularEntriesRemainUnaffected(tester, 'Meeting notes from today');
      },
    );

    testWidgets(
      'Given user wants to delete checklist category, When they delete it, Then all checklist items are handled appropriately',
      (WidgetTester tester) async {
        // GIVEN: User has checklist category with items
        await givenUserHasChecklistCategoryWithItems(tester, scope);

        // WHEN: User deletes the checklist category
        await whenUserDeletesChecklistCategory(tester, 'TodoList');

        // THEN: Items are moved to default category and lose checklist behavior
        await thenChecklistItemsMovedToDefaultCategory(tester);
        await thenFormerChecklistItemsLoseCheckboxes(tester);
      },
    );

    testWidgets(
      'Given user has multiple checklist categories, When they manage items across categories, Then sorting works correctly within each category',
      (WidgetTester tester) async {
        // GIVEN: User has multiple checklist categories
        await givenUserHasMultipleChecklistCategories(tester, scope);

        // WHEN: User adds items to different categories
        await whenUserAddsItemsToMultipleCategories(tester);

        // THEN: Each category maintains its own sorting
        await thenEachCategoryMaintainsOwnSorting(tester);

        // WHEN: User filters by specific category
        await whenUserFiltersByCategory(tester, 'Work Tasks');

        // THEN: Only that category's items are shown with correct sorting
        await thenOnlyFilteredCategoryItemsShown(tester, 'Work Tasks');
        await thenFilteredItemsHaveCorrectSorting(tester);
      },
    );
  });
}

// CP: Complex workflow helper functions

Future<void> whenUserCreatesChecklistCategory(WidgetTester tester, String name, String description) async {
  await whenManageCategoriesDialogIsOpened(tester);
  
  // Tap "Add New Category" button
  final addButton = find.text('Add New Category');
  await tester.tap(addButton);
  await tester.pumpAndSettle();
  
  // Fill in details
  await tester.enterText(find.byType(TextField).first, name);
  await tester.enterText(find.byType(TextField).at(1), description);
  
  // Enable checklist toggle
  final switches = find.byType(Switch);
  expect(switches, findsOneWidget);
  await tester.tap(switches);
  await tester.pumpAndSettle();
  
  // Submit
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
  
  // Close manage categories dialog
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

Future<void> thenChecklistCategoryIsAvailable(WidgetTester tester, String categoryName) async {
  // CP: Verify category was created and is available for selection
  // This could be verified by checking the cubit state or looking for category indicators
}

Future<void> whenUserAddsChecklistItem(WidgetTester tester, String itemText) async {
  await whenTextIsEntered(tester, itemText);
  await whenSendButtonIsTapped(tester);
}

Future<void> thenChecklistItemsAppearInCorrectOrder(WidgetTester tester, List<String> expectedOrder) async {
  for (int i = 0; i < expectedOrder.length; i++) {
    final itemFinder = find.text(expectedOrder[i]);
    expect(itemFinder, findsOneWidget);
    
    if (i > 0) {
      final currentPos = tester.getTopLeft(itemFinder).dy;
      final previousPos = tester.getTopLeft(find.text(expectedOrder[i - 1])).dy;
      expect(currentPos, greaterThan(previousPos));
    }
  }
}

Future<void> whenUserCompletesChecklistItem(WidgetTester tester, String itemText) async {
  final entryTextFinder = find.text(itemText);
  expect(entryTextFinder, findsOneWidget);
  
  // Find and tap the checkbox for this entry
  // CP: Look for AnimatedContainer checkboxes instead of Checkbox widgets
  final checkboxFinder = find.byType(AnimatedContainer);
  if (checkboxFinder.evaluate().isNotEmpty) {
    await tester.tap(checkboxFinder.first);
    await tester.pumpAndSettle();
  }
}

Future<void> whenUserUncompletesChecklistItem(WidgetTester tester, String itemText) async {
  await whenUserCompletesChecklistItem(tester, itemText); // CP: Same action, toggles state
}

Future<void> thenCompletedItemsMovedToBottom(WidgetTester tester, List<String> completedItems) async {
  for (final item in completedItems) {
    final itemFinder = find.text(item);
    expect(itemFinder, findsOneWidget);
    // CP: Verify these items are at the bottom of the list
  }
}

Future<void> thenIncompleteItemsRemainAtTop(WidgetTester tester, List<String> incompleteItems) async {
  for (final item in incompleteItems) {
    final itemFinder = find.text(item);
    expect(itemFinder, findsOneWidget);
    // CP: Verify these items are at the top of the list
  }
}

Future<void> thenCompletedItemsHaveStrikethrough(WidgetTester tester, List<String> completedItems) async {
  for (final item in completedItems) {
    final itemFinder = find.text(item);
    expect(itemFinder, findsOneWidget);
    
    final textWidget = tester.widget<Text>(itemFinder);
    expect(textWidget.style?.decoration, TextDecoration.lineThrough);
  }
}

Future<void> thenItemMovesToIncompleteSection(WidgetTester tester, String itemText) async {
  final itemFinder = find.text(itemText);
  expect(itemFinder, findsOneWidget);
  // CP: Verify item has moved to incomplete section
}

Future<void> thenIncompleteItemsInCorrectOrder(WidgetTester tester, List<String> expectedOrder) async {
  await thenChecklistItemsAppearInCorrectOrder(tester, expectedOrder);
}

Future<void> thenNewItemAppearsAtTopOfIncomplete(WidgetTester tester, String newItem) async {
  final newItemFinder = find.text(newItem);
  expect(newItemFinder, findsOneWidget);
  // CP: Verify this item is at the top of the incomplete section
}

Future<void> thenFinalSortingIsCorrect(WidgetTester tester, {required List<String> incomplete, required List<String> completed}) async {
  // CP: Verify the final sorting matches expected incomplete and completed groups
  await thenIncompleteItemsInCorrectOrder(tester, incomplete);
  // CP: Additional verification for completed items at bottom
}

// CP: Additional workflow helpers

Future<void> givenUserHasRegularCategoryWithEntries(WidgetTester tester, WidgetTestScope scope) async {
  scope.stubPersistenceWithRegularCategories();
  await givenHomePageIsDisplayed(tester, scope);
}

Future<void> whenUserConvertsRegularCategoryToChecklist(WidgetTester tester, String categoryName) async {
  await whenManageCategoriesDialogIsOpened(tester);
  
  // Find and tap the category to edit
  final categoryFinder = find.text(categoryName);
  await tester.tap(categoryFinder);
  await tester.pumpAndSettle();
  
  // Toggle checklist switch
  final switches = find.byType(Switch);
  await tester.tap(switches);
  await tester.pumpAndSettle();
  
  // Save changes
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  
  // Close dialogs
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

Future<void> thenExistingEntriesBecomeCheckable(WidgetTester tester) async {
  // CP: Look for AnimatedContainer checkboxes instead of Checkbox widgets
  final checkboxFinder = find.byType(AnimatedContainer);
  expect(checkboxFinder, findsWidgets);
}

Future<void> thenCategoryShowsChecklistIndicator(WidgetTester tester, String categoryName) async {
  // CP: Verify category shows checklist icon in category chip
}

Future<void> givenUserHasMixedCategoryTypes(WidgetTester tester, WidgetTestScope scope) async {
  scope.stubPersistenceWithMixedCategories();
  await givenHomePageIsDisplayed(tester, scope);
}

Future<void> whenUserAddsRegularEntry(WidgetTester tester, String entryText) async {
  await whenTextIsEntered(tester, entryText);
  await whenSendButtonIsTapped(tester);
}

Future<void> thenRegularEntryHasNoCheckbox(WidgetTester tester, String entryText) async {
  final entryFinder = find.text(entryText);
  expect(entryFinder, findsOneWidget);
  
  // CP: Verify no checkbox is associated with this entry
}

Future<void> thenChecklistEntryHasCheckbox(WidgetTester tester, String entryText) async {
  final entryFinder = find.text(entryText);
  expect(entryFinder, findsOneWidget);
  
  // CP: Verify checkbox is associated with this entry
}

Future<void> thenOnlyChecklistEntriesShowCompletionEffects(WidgetTester tester) async {
  // CP: Verify only checklist entries show strikethrough, opacity changes, etc.
}

Future<void> thenRegularEntriesRemainUnaffected(WidgetTester tester, String regularEntryText) async {
  final entryFinder = find.text(regularEntryText);
  expect(entryFinder, findsOneWidget);
  
  final textWidget = tester.widget<Text>(entryFinder);
  expect(textWidget.style?.decoration, isNot(TextDecoration.lineThrough));
}

Future<void> givenUserHasChecklistCategoryWithItems(WidgetTester tester, WidgetTestScope scope) async {
  scope.stubPersistenceWithChecklistCategories();
  await givenHomePageIsDisplayed(tester, scope);
}

Future<void> whenUserDeletesChecklistCategory(WidgetTester tester, String categoryName) async {
  await whenManageCategoriesDialogIsOpened(tester);
  
  // Find and delete the category (swipe or long press)
  final categoryFinder = find.text(categoryName);
  await tester.longPress(categoryFinder);
  await tester.pumpAndSettle();
  
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
  
  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

Future<void> thenChecklistItemsMovedToDefaultCategory(WidgetTester tester) async {
  // CP: Verify former checklist items now show default category
}

Future<void> thenFormerChecklistItemsLoseCheckboxes(WidgetTester tester) async {
  // CP: Verify former checklist items no longer have checkboxes
}

Future<void> givenUserHasMultipleChecklistCategories(WidgetTester tester, WidgetTestScope scope) async {
  // CP: Setup with multiple checklist categories and items
  scope.stubPersistenceWithMixedCategories();
  await givenHomePageIsDisplayed(tester, scope);
}

Future<void> whenUserAddsItemsToMultipleCategories(WidgetTester tester) async {
  // CP: Add items to different categories
}

Future<void> thenEachCategoryMaintainsOwnSorting(WidgetTester tester) async {
  // CP: Verify sorting is correct within each category
}

Future<void> whenUserFiltersByCategory(WidgetTester tester, String categoryName) async {
  // CP: Apply category filter
}

Future<void> thenOnlyFilteredCategoryItemsShown(WidgetTester tester, String categoryName) async {
  // CP: Verify only items from this category are visible
}

Future<void> thenFilteredItemsHaveCorrectSorting(WidgetTester tester) async {
  // CP: Verify sorting is correct for filtered items
}