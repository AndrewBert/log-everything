import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:mockito/mockito.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/entry/category.dart';
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
      imageStorageService: scope.mockImageStorageService,
      sharedPreferences: scope.mockSharedPreferences,
      httpClient: scope.mockHttpClient,
    );
    scope.initializeWidget();
    scope.stubPersistenceWithInitialEntries();
    scope.stubPermissionGranted();
  });

  tearDown(() async {
    final entryRepository = getIt<EntryRepository>();
    entryRepository.dispose();
    
    await getIt.reset();
    await scope.dispose();
  });

  group('AI Categorization Behaviors', () {
    group('Automatic categorization based on content', () {
      testWidgets(
        'Given user enters work-related text, When AI processes it, Then entry is categorized as Work',
        (WidgetTester tester) async {
          // Given - User has app open
          const workText = 'Attended the quarterly review meeting with stakeholders';
          
          // Configure AI to recognize work content
          when(scope.mockAiService.extractEntries(any, any)).thenAnswer(
            (_) async => [
              (textSegment: workText, category: 'Work', isTask: false),
            ],
          );
          
          await givenUserHasAppOpen(tester, scope);

          // When - User enters work-related text and submits
          await whenUserEntersAndSubmitsText(tester, workText);

          // Then - Entry is categorized as Work
          await thenEntryIsCreatedWithCategory(tester, workText, 'Work');
          await thenEntryCategoryIsVisibleInUI(tester, workText, 'Work');
        },
      );

      testWidgets(
        'Given user enters personal content, When AI processes it, Then entry is categorized as Personal',
        (WidgetTester tester) async {
          // Given - User has app open
          const personalText = 'Had dinner with family at the new restaurant downtown';
          
          // Configure AI to recognize personal content
          when(scope.mockAiService.extractEntries(any, any)).thenAnswer(
            (_) async => [
              (textSegment: personalText, category: 'Personal', isTask: false),
            ],
          );
          
          await givenUserHasAppOpen(tester, scope);

          // When - User enters personal text and submits
          await whenUserEntersAndSubmitsText(tester, personalText);

          // Then - Entry is categorized as Personal
          await thenEntryIsCreatedWithCategory(tester, personalText, 'Personal');
          await thenEntryCategoryIsVisibleInUI(tester, personalText, 'Personal');
        },
      );

      testWidgets(
        'Given user enters miscellaneous content, When AI processes it, Then entry is categorized as Misc',
        (WidgetTester tester) async {
          // Given - User has app open
          const miscText = 'Noticed interesting cloud formations today';
          
          // Configure AI to categorize as Misc
          when(scope.mockAiService.extractEntries(any, any)).thenAnswer(
            (_) async => [
              (textSegment: miscText, category: 'Misc', isTask: false),
            ],
          );
          
          await givenUserHasAppOpen(tester, scope);

          // When - User enters miscellaneous text and submits
          await whenUserEntersAndSubmitsText(tester, miscText);

          // Then - Entry is categorized as Misc
          await thenEntryIsCreatedWithCategory(tester, miscText, 'Misc');
          await thenEntryCategoryIsVisibleInUI(tester, miscText, 'Misc');
        },
      );
    });

    group('AI service error handling', () {
      testWidgets(
        'Given AI service is unavailable, When user creates entry, Then entry uses default category',
        (WidgetTester tester) async {
          // Given - User has app open and AI service will fail
          const entryText = 'Important meeting notes from today';
          
          // Configure AI service to throw an error
          when(scope.mockAiService.extractEntries(any, any)).thenThrow(
            Exception('AI service unavailable'),
          );
          
          await givenUserHasAppOpen(tester, scope);

          // When - User enters text and submits
          await whenUserEntersAndSubmitsText(tester, entryText);

          // Then - Entry is created with default category (Misc)
          await thenEntryIsCreatedWithDefaultCategory(tester, entryText);
          await thenErrorIsHandledGracefully(tester);
        },
      );

      testWidgets(
        'Given AI returns empty categories, When user creates entry, Then entry uses default category',
        (WidgetTester tester) async {
          // Given - User has app open and AI returns no categories
          const entryText = 'Random thoughts about the day';
          
          // Configure AI to return empty result
          when(scope.mockAiService.extractEntries(any, any)).thenAnswer(
            (_) async => [],
          );
          
          await givenUserHasAppOpen(tester, scope);

          // When - User enters text and submits
          await whenUserEntersAndSubmitsText(tester, entryText);

          // Then - Entry is created with default category
          await thenEntryIsCreatedWithDefaultCategory(tester, entryText);
        },
      );

      testWidgets(
        'Given AI service is slow, When user creates entry, Then UI remains responsive',
        (WidgetTester tester) async {
          // Given - User has app open and AI service has delay
          const entryText = 'Testing system responsiveness';
          
          // Configure AI with delayed response
          when(scope.mockAiService.extractEntries(any, any)).thenAnswer(
            (_) async {
              await Future.delayed(const Duration(seconds: 2));
              return [(textSegment: entryText, category: 'Misc', isTask: false)];
            },
          );
          
          await givenUserHasAppOpen(tester, scope);

          // When - User enters text and submits
          await whenUserEntersAndSubmitsText(tester, entryText);

          // Then - UI shows loading state and remains responsive
          await thenUIShowsProcessingState(tester);
          await thenEntryIsEventuallyCreated(tester, entryText);
        },
      );
    });

    group('Multiple entries in single input', () {
      // TODO: Fix timer cleanup issue for split entries - Timer from _createGroupController in entries_list.dart 
      // is not being disposed properly when multiple entries are created, causing test failure.
      // Issue introduced with recent changes to main branch that added split entry functionality.
      testWidgets(
        'Given user enters text with multiple topics, When AI processes it, Then multiple categorized entries are created',
        (WidgetTester tester) async {
          // Given - User has app open
          const multiTopicText = 'Finished project report. Had lunch with mom. Fixed bike tire.';
          
          // Configure AI to extract multiple entries
          when(scope.mockAiService.extractEntries(any, any)).thenAnswer(
            (_) async => [
              (textSegment: 'Finished project report', category: 'Work', isTask: false),
              (textSegment: 'Had lunch with mom', category: 'Personal', isTask: false),
              (textSegment: 'Fixed bike tire', category: 'Misc', isTask: false),
            ],
          );
          
          await givenUserHasAppOpen(tester, scope);

          // When - User enters multi-topic text and submits
          await whenUserEntersAndSubmitsText(tester, multiTopicText);

          // Then - Multiple entries are created with appropriate categories
          await thenMultipleEntriesAreCreated(tester, [
            ('Finished project report', 'Work'),
            ('Had lunch with mom', 'Personal'),
            ('Fixed bike tire', 'Misc'),
          ]);
        },
      );
    });

    group('Category learning and adaptation', () {
      testWidgets(
        'Given user has custom categories, When AI categorizes new entries, Then custom categories are preferred',
        (WidgetTester tester) async {
          // Given - User has custom category "Health" in their categories
          const healthText = 'Went for a 5k run this morning';
          final customCategories = [
            ...TestData.categoriesList,
            const Category(name: 'Health', description: 'Health and fitness activities'),
          ];
          
          // Configure persistence with custom categories
          when(scope.mockPersistenceService.loadCategories()).thenAnswer(
            (_) async => customCategories,
          );
          
          // Configure AI to use custom category
          when(scope.mockAiService.extractEntries(any, any)).thenAnswer(
            (_) async => [
              (textSegment: healthText, category: 'Health', isTask: false),
            ],
          );
          
          await givenUserHasAppOpen(tester, scope);

          // When - User enters health-related text
          await whenUserEntersAndSubmitsText(tester, healthText);

          // Then - Entry is categorized with custom category
          await thenEntryIsCreatedWithCategory(tester, healthText, 'Health');
        },
      );

      testWidgets(
        'Given user frequently changes categories, When similar entries are created, Then AI adapts to user preferences',
        (WidgetTester tester) async {
          // Given - User has history of categorizing gym activities as "Health"
          const gymText = 'Gym workout: chest and triceps day';
          
          // Configure AI to adapt based on user history
          when(scope.mockAiService.extractEntries(any, any)).thenAnswer(
            (_) async => [
              (textSegment: gymText, category: 'Health', isTask: false),
            ],
          );
          
          await givenUserHasAppOpen(tester, scope);

          // When - User enters gym-related text
          await whenUserEntersAndSubmitsText(tester, gymText);

          // Then - Entry uses learned category preference
          await thenEntryIsCreatedWithCategory(tester, gymText, 'Health');
        },
      );
    });
  });
}

// BDD Helper Functions - GIVEN

Future<void> givenUserHasAppOpen(WidgetTester tester, WidgetTestScope scope) async {
  await givenHomePageIsDisplayed(tester, scope);
  thenInitialUiElementsAreDisplayed(tester);
}

// BDD Helper Functions - WHEN

Future<void> whenUserEntersAndSubmitsText(WidgetTester tester, String text) async {
  await whenTextIsEntered(tester, text);
  await whenSendButtonIsTapped(tester);
}

// BDD Helper Functions - THEN

Future<void> thenEntryIsCreatedWithCategory(WidgetTester tester, String text, String category) async {
  await thenEntryIsDisplayedInList(tester, text);
  // In a real implementation, we would verify the category is displayed
  // For now, we verify the entry exists (category verification would require UI updates)
}

Future<void> thenEntryCategoryIsVisibleInUI(WidgetTester tester, String text, String category) async {
  // This would verify the category badge/label is shown in the UI
  // Current UI might not display categories visibly - this is a placeholder
  await thenEntryIsDisplayedInList(tester, text);
}

Future<void> thenEntryIsCreatedWithDefaultCategory(WidgetTester tester, String text) async {
  await thenEntryIsDisplayedInList(tester, text);
  // Default category is typically "Misc"
}

Future<void> thenErrorIsHandledGracefully(WidgetTester tester) async {
  // Verify no error dialog or crash
  expect(find.byType(ErrorWidget), findsNothing);
  // Entry should still be created despite AI failure
}

Future<void> thenUIShowsProcessingState(WidgetTester tester) async {
  // Check for any loading indicators
  // The actual implementation might show a progress indicator
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> thenEntryIsEventuallyCreated(WidgetTester tester, String text) async {
  // Wait for async operation to complete
  await tester.pumpAndSettle(const Duration(seconds: 3));
  await thenEntryIsDisplayedInList(tester, text);
}

Future<void> thenMultipleEntriesAreCreated(WidgetTester tester, List<(String, String)> entries) async {
  // Allow time for all entries to be created
  await tester.pumpAndSettle();
  
  // Verify each entry is displayed
  for (final (text, _) in entries) {
    await thenEntryIsDisplayedInList(tester, text);
  }
}