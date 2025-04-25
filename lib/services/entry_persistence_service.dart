import 'package:shared_preferences/shared_preferences.dart';
import '../entry/entry.dart';
import '../utils/logger.dart';

// Interface for Entry Persistence
abstract class EntryPersistenceService {
  Future<List<Entry>> loadEntries();
  Future<void> saveEntries(List<Entry> entries);
  Future<List<String>> loadCategories();
  Future<void> saveCategories(List<String> categories);
}

// Implementation using SharedPreferences
class SharedPreferencesEntryPersistenceService implements EntryPersistenceService {
  // Keys moved from EntryCubit
  static const String _entriesKey = 'saved_entries_v3_categorized';
  static const String _categoriesKey = 'custom_categories_v1';

  // Default categories moved here for loading fallback
  final List<String> _defaultCategories = const [
    'Misc',
    'Work',
    'Personal',
    'Ideas',
    'To-Do',
    'Journal',
    'Learning',
    'Health',
    'Finance',
    'Goals',
  ];

  @override
  Future<List<Entry>> loadEntries() async {
    List<Entry> loadedEntries = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEntriesJson = prefs.getStringList(_entriesKey) ?? [];
      if (savedEntriesJson.isNotEmpty) {
        loadedEntries =
            savedEntriesJson.map((jsonString) {
              try {
                return Entry.fromJsonString(jsonString);
              } catch (e) {
                AppLogger.error("Error parsing entry JSON", error: e);
                // Return a placeholder or skip - here we skip by returning null
                return null;
              }
            }).whereType<Entry>().toList(); // Filter out nulls
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
  Future<List<String>> loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCategories = prefs.getStringList(_categoriesKey);
      if (savedCategories == null || savedCategories.isEmpty) {
        AppLogger.info(
          'Persistence: No categories found, saving defaults.',
        );
        // Save defaults if none exist
        await saveCategories(_defaultCategories);
        return _defaultCategories;
      } else {
        List<String> currentCategories = List<String>.from(savedCategories);
        // Ensure 'Misc' always exists
        if (!currentCategories.contains('Misc')) {
          currentCategories.add('Misc');
          // Optionally save back immediately if Misc was missing
          // await saveCategories(currentCategories);
        }
        AppLogger.info(
          "Persistence: Loaded Categories: $currentCategories",
        );
        return currentCategories;
      }
    } catch (e) {
      AppLogger.error("Persistence: Error loading categories", error: e);
      // Return default categories as a fallback?
      // throw Exception("Failed to load categories.");
      return _defaultCategories;
    }
  }

  @override
  Future<void> saveCategories(List<String> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_categoriesKey, categories);
      AppLogger.info("Persistence: Saved Categories: $categories");
    } catch (e) {
      AppLogger.error("Persistence: Error saving categories", error: e);
      // Re-throw or handle?
      throw Exception("Failed to save categories.");
    }
  }
}
