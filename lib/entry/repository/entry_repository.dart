import 'dart:async';

import '../entry.dart';
import '../../services/ai_categorization_service.dart';
import '../../services/entry_persistence_service.dart';
import '../../utils/logger.dart';

class EntryRepository {
  final EntryPersistenceService _persistenceService;
  final AiCategorizationService _aiService;

  // Internal state for entries and categories
  List<Entry> _entries = [];
  List<String> _categories = [];

  // Public getters for current state (read-only view)
  List<Entry> get currentEntries => List.unmodifiable(_entries);
  List<String> get currentCategories => List.unmodifiable(_categories);

  EntryRepository({
    required EntryPersistenceService persistenceService,
    required AiCategorizationService aiService,
  }) : _persistenceService = persistenceService,
       _aiService = aiService;

  // --- Initialization ---
  Future<void> initialize() async {
    await _loadCategories();
    await _loadEntries();
  }

  // --- Loading/Saving (Internal) ---
  Future<void> _loadCategories() async {
    try {
      _categories = await _persistenceService.loadCategories();
      AppLogger.info("Repository: Loaded Categories: $_categories");
    } catch (e) {
      AppLogger.error("Repository: Error loading categories", error: e);
      // Decide on error handling - maybe load defaults?
      _categories = []; // Fallback to empty or defaults
      // Re-throw to notify caller?
      // throw Exception("Failed to load categories in repository.");
    }
  }

  Future<void> _loadEntries() async {
    try {
      _entries = await _persistenceService.loadEntries();
      AppLogger.info(
        'Repository: Successfully loaded ${_entries.length} entries.',
      );
    } catch (e) {
      AppLogger.error('Repository: Error loading entries.', error: e);
      _entries = []; // Fallback to empty
      // Re-throw to notify caller?
      // throw Exception("Failed to load entries in repository.");
    }
  }

  Future<void> _saveCategories() async {
    try {
      await _persistenceService.saveCategories(_categories);
      AppLogger.info("Repository: Saved Categories: $_categories");
    } catch (e) {
      AppLogger.error("Repository: Error saving categories", error: e);
      // Re-throw?
      // throw Exception("Failed to save categories in repository.");
    }
  }

  Future<void> _saveEntries() async {
    try {
      await _persistenceService.saveEntries(_entries);
      AppLogger.info('Repository: Saved ${_entries.length} entries.');
    } catch (e) {
      AppLogger.error('Repository: Error saving entries', error: e);
      // Re-throw?
      // throw Exception("Failed to save entries in repository.");
    }
  }

  // --- Public Data Manipulation Methods ---

  Future<List<Entry>> addEntry(String text) async {
    if (text.isEmpty) return _entries;

    // Use a temporary timestamp for grouping AI results
    final DateTime processingTimestamp = DateTime.now();
    List<EntryPrototype> extractedData = [];
    String? serviceError;

    try {
      extractedData = await _aiService.extractEntries(text, _categories);
    } on AiCategorizationException catch (e) {
      AppLogger.error(
        "Repository: AI Service failed: ${e.message}",
        error: e.underlyingError,
      );
      serviceError = e.message;
    } catch (e, stacktrace) {
      AppLogger.error(
        "Repository: Unexpected error calling AI Service",
        error: e,
        stackTrace: stacktrace,
      );
      serviceError = "An unexpected error occurred during categorization.";
    }

    final List<Entry> addedEntries = [];
    if (serviceError != null || extractedData.isEmpty) {
      // AI failed or returned nothing, add as Misc
      final fallbackEntry = Entry(
        text: text,
        timestamp: processingTimestamp,
        category: 'Misc',
        isNew: true, // Mark as new for UI highlight
      );
      addedEntries.add(fallbackEntry);
    } else {
      // AI succeeded
      for (var data in extractedData) {
        final newEntry = Entry(
          text: data.text_segment,
          timestamp: processingTimestamp,
          category:
              _categories.contains(data.category) ? data.category : 'Misc',
          isNew: true, // Mark as new for UI highlight
        );
        addedEntries.add(newEntry);
      }
    }

    // Add to the internal list (prepend)
    _entries.insertAll(0, addedEntries);
    await _saveEntries();
    return currentEntries; // Return a copy
  }

  // Direct entry add (e.g., for undo)
  Future<List<Entry>> addEntryObject(Entry entryToAdd) async {
    _entries.add(entryToAdd);
    await _saveEntries();
    AppLogger.info("Repository: Added entry object - ${entryToAdd.text}");
    return currentEntries; // Return a copy
  }

  Future<List<Entry>> deleteEntry(Entry entryToDelete) async {
    final originalLength = _entries.length;
    _entries.removeWhere(
      (entry) =>
          entry.timestamp == entryToDelete.timestamp &&
          entry.text == entryToDelete.text,
    );
    if (_entries.length < originalLength) {
      await _saveEntries();
    }
    return currentEntries; // Return a copy
  }

  Future<List<Entry>> updateEntry(
    Entry originalEntry,
    Entry updatedEntry,
  ) async {
    final index = _entries.indexWhere(
      (entry) =>
          entry.timestamp == originalEntry.timestamp &&
          entry.text == originalEntry.text,
    );
    if (index != -1) {
      // Preserve the isNew status from the original entry in the list
      _entries[index] = updatedEntry.copyWith(isNew: _entries[index].isNew);
      await _saveEntries();
    }
    return currentEntries; // Return a copy
  }

  Future<List<Entry>> processCombinedEntry(
    String combinedText,
    DateTime tempEntryTimestamp,
  ) async {
    AppLogger.info(
      '[Repo.processCombinedEntry] Processing combined text: "$combinedText" for temp timestamp: $tempEntryTimestamp',
    );
    if (combinedText.isEmpty) {
      // If combined text is empty, just remove the temp entry
      _entries.removeWhere(
        (e) =>
            e.timestamp == tempEntryTimestamp && e.category == 'Processing...',
      );
      await _saveEntries();
      return currentEntries;
    }

    // 1. Call AI Service
    List<EntryPrototype> extractedData = [];
    String? serviceError;
    try {
      extractedData = await _aiService.extractEntries(
        combinedText,
        _categories,
      );
    } on AiCategorizationException catch (e) {
      AppLogger.error(
        "Repository: AI Service failed for combined entry: ${e.message}",
        error: e.underlyingError,
      );
      serviceError = e.message;
    } catch (e, stacktrace) {
      AppLogger.error(
        "Repository: Unexpected error calling AI Service for combined entry",
        error: e,
        stackTrace: stacktrace,
      );
      serviceError = "An unexpected error occurred during categorization.";
    }

    // 2. Find and remove the temporary entry
    int tempIndex = _entries.indexWhere(
      (e) => e.timestamp == tempEntryTimestamp && e.category == 'Processing...',
    );
    if (tempIndex != -1) {
      AppLogger.debug(
        '[Repo.processCombinedEntry] Found and removing temp entry at index $tempIndex',
      );
      _entries.removeAt(tempIndex);
    } else {
      AppLogger.warning(
        '[Repo.processCombinedEntry] Temporary entry with timestamp $tempEntryTimestamp not found!',
      );
      // If temp entry not found, proceed to add the new one anyway, but insert at top
      tempIndex = 0;
    }

    // 3. Create new entries based on AI result or fallback
    final List<Entry> addedEntries = [];
    if (serviceError != null || extractedData.isEmpty) {
      // AI failed or returned nothing, add as Misc
      final fallbackEntry = Entry(
        text: combinedText,
        timestamp: tempEntryTimestamp, // Use original timestamp
        category: 'Misc',
        isNew: true,
      );
      addedEntries.add(fallbackEntry);
    } else {
      // AI succeeded
      for (var data in extractedData) {
        final newEntry = Entry(
          text: data.text_segment,
          timestamp: tempEntryTimestamp, // Use original timestamp
          category:
              _categories.contains(data.category) ? data.category : 'Misc',
          isNew: true,
        );
        addedEntries.add(newEntry);
      }
    }

    // 4. Insert new entries at the correct position
    if (tempIndex >= 0 && tempIndex <= _entries.length) {
      _entries.insertAll(tempIndex, addedEntries);
    } else {
      _entries.insertAll(0, addedEntries); // Fallback to inserting at top
    }

    // 5. Save and return
    await _saveEntries();
    return currentEntries; // Return copy
  }

  Future<List<String>> addCustomCategory(String newCategory) async {
    final trimmedCategory = newCategory.trim();
    if (trimmedCategory.isNotEmpty &&
        trimmedCategory != 'Misc' &&
        !_categories.contains(trimmedCategory)) {
      _categories.add(trimmedCategory);
      await _saveCategories();
    }
    return currentCategories;
  }

  Future<({List<Entry> entries, List<String> categories})> deleteCategory(
    String categoryToDelete,
  ) async {
    if (categoryToDelete == 'Misc')
      return (entries: currentEntries, categories: currentCategories);

    if (_categories.contains(categoryToDelete)) {
      _categories.remove(categoryToDelete);
      bool entriesChanged = false;
      _entries =
          _entries.map((entry) {
            if (entry.category == categoryToDelete) {
              entriesChanged = true;
              return entry.copyWith(category: 'Misc');
            }
            return entry;
          }).toList();

      await _saveCategories();
      if (entriesChanged) {
        await _saveEntries();
      }
    }
    return (entries: currentEntries, categories: currentCategories);
  }

  Future<({List<Entry> entries, List<String> categories})> renameCategory(
    String oldName,
    String newName,
  ) async {
    final trimmedNewName = newName.trim();
    if (oldName == 'Misc' ||
        trimmedNewName.isEmpty ||
        oldName == trimmedNewName ||
        _categories.any(
          (c) => c.toLowerCase() == trimmedNewName.toLowerCase(),
        )) {
      AppLogger.warning(
        'Repository: Rename category validation failed ($oldName -> $trimmedNewName).',
      );
      return (entries: currentEntries, categories: currentCategories);
    }

    _categories =
        _categories.map((c) => c == oldName ? trimmedNewName : c).toList();
    bool entriesChanged = false;
    _entries =
        _entries.map((entry) {
          if (entry.category == oldName) {
            entriesChanged = true;
            return entry.copyWith(category: trimmedNewName);
          }
          return entry;
        }).toList();

    await _saveCategories();
    if (entriesChanged) {
      await _saveEntries();
    }
    return (entries: currentEntries, categories: currentCategories);
  }

  // Method to update isNew status (called by Cubit after delay)
  // Returns true if an update occurred
  Future<bool> markEntryAsNotNew(DateTime timestamp, String text) async {
    final index = _entries.indexWhere(
      (e) => e.timestamp == timestamp && e.text == text && e.isNew,
    );
    if (index != -1) {
      _entries[index] = _entries[index].copyWith(isNew: false);
      await _saveEntries();
      return true;
    }
    return false;
  }
}
