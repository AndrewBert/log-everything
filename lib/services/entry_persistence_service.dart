import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../entry/entry.dart';
import '../entry/category.dart'; // CP: Import Category model
import '../utils/logger.dart';

// Interface for Entry Persistence
abstract class EntryPersistenceService {
  Future<List<Entry>> loadEntries();
  Future<void> saveEntries(List<Entry> entries);
  Future<List<Category>> loadCategories(); // CP: Use Category
  Future<void> saveCategories(List<Category> categories); // CP: Use Category
}

// Implementation using SharedPreferences
class SharedPreferencesEntryPersistenceService
    implements EntryPersistenceService {
  // Keys moved from EntryCubit
  static const String _entriesKey = 'saved_entries_v3_categorized';
  static const String _categoriesKey = 'custom_categories_v1';

  // Default categories moved here for loading fallback
  final List<Category> _defaultCategories = const [
    Category(name: 'Misc'),
    Category(name: 'Work'),
    Category(name: 'Personal'),
    Category(name: 'Ideas'),
    Category(name: 'To-Do'),
    Category(name: 'Journal'),
    Category(name: 'Learning'),
    Category(name: 'Health'),
    Category(name: 'Finance'),
    Category(name: 'Goals'),
  ];

  @override
  Future<List<Entry>> loadEntries() async {
    List<Entry> loadedEntries = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEntriesJson = prefs.getStringList(_entriesKey) ?? [];
      if (savedEntriesJson.isNotEmpty) {
        loadedEntries =
            savedEntriesJson
                .map((jsonString) {
                  try {
                    return Entry.fromJsonString(jsonString);
                  } catch (e) {
                    AppLogger.error("Error parsing entry JSON", error: e);
                    // Return a placeholder or skip - here we skip by returning null
                    return null;
                  }
                })
                .whereType<Entry>()
                .toList(); // Filter out nulls
      }
      AppLogger.info(
        'Persistence: Successfully loaded ${loadedEntries.length} entries.',
      );
      return loadedEntries;
    } catch (e) {
      AppLogger.error(
        'Persistence: Error loading entries. Clearing potentially incompatible data.',
        error: e,
      );
      // Attempt to clear bad data
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_entriesKey);
      } catch (clearError) {
        AppLogger.error(
          'Persistence: Failed to clear entries after load error.',
          error: clearError,
        );
      }
      // Re-throw or return empty list? Returning empty list might be safer.
      // throw Exception("Failed to load entries, data cleared.");
      return [];
    }
  }

  @override
  Future<void> saveEntries(List<Entry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Ensure 'isNew' is false before saving
      final entriesToSave =
          entries.map((e) => e.copyWith(isNew: false)).toList();
      final entriesJson =
          entriesToSave.map((entry) => entry.toJsonString()).toList();
      await prefs.setStringList(_entriesKey, entriesJson);
      AppLogger.info('Persistence: Saved ${entries.length} entries.');
    } catch (e) {
      AppLogger.error('Persistence: Error saving entries', error: e);
      // Re-throw or handle? Re-throwing allows caller (Cubit) to know.
      throw Exception("Failed to save entries.");
    }
  }

  @override
  Future<List<Category>> loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCategoriesJson = prefs.getStringList(_categoriesKey);
      if (savedCategoriesJson == null || savedCategoriesJson.isEmpty) {
        AppLogger.info('Persistence: No categories found, saving defaults.');
        await saveCategories(_defaultCategories);
        return _defaultCategories;
      } else {
        final List<Category> loaded =
            savedCategoriesJson
                .map((jsonStr) {
                  try {
                    // CP: Migration - handle old format (plain string) and new format (JSON)
                    if (jsonStr.trim().startsWith('{')) {
                      return Category.fromJson(jsonDecode(jsonStr));
                    } else {
                      return Category(name: jsonStr.trim());
                    }
                  } catch (e) {
                    AppLogger.error('Error parsing category JSON', error: e);
                    return null;
                  }
                })
                .whereType<Category>()
                .toList();
        // CP: Optionally re-save in new format to prevent future errors
        await saveCategories(loaded);
        // Ensure 'Misc' always exists
        if (!loaded.any((cat) => cat.name == 'Misc')) {
          loaded.add(Category(name: 'Misc'));
        }
        // AppLogger.info('Persistence: Loaded Categories: $loaded');
        return loaded;
      }
    } catch (e) {
      AppLogger.error('Persistence: Error loading categories', error: e);
      return _defaultCategories;
    }
  }

  @override
  Future<void> saveCategories(List<Category> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList =
          categories.map((cat) => jsonEncode(cat.toJson())).toList();
      await prefs.setStringList(_categoriesKey, jsonList);
      // AppLogger.info('Persistence: Saved Categories: $categories');
    } catch (e) {
      AppLogger.error('Persistence: Error saving categories', error: e);
      throw Exception('Failed to save categories.');
    }
  }
}
