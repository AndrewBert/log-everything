import 'dart:async';

import 'package:intl/intl.dart'; // CP: Added for date formatting
import '../entry.dart';
import '../../services/ai_service.dart';
import '../../services/entry_persistence_service.dart';
import '../../services/vector_store_service.dart'; // CP: Added VectorStoreService import
import '../../utils/logger.dart';

class EntryRepository {
  final EntryPersistenceService _persistenceService;
  final AiService _aiService;
  final VectorStoreService
  _vectorStoreService; // CP: Added VectorStoreService field

  // Internal state for entries and categories
  List<Entry> _entries = [];
  List<String> _categories = [];

  // Public getters for current state (read-only view)
  List<Entry> get currentEntries => List.unmodifiable(_entries);
  List<String> get currentCategories => List.unmodifiable(_categories);

  EntryRepository({
    required EntryPersistenceService persistenceService,
    required AiService aiService,
    required VectorStoreService
    vectorStoreService, // CP: Added VectorStoreService to constructor
  }) : _persistenceService = persistenceService,
       _aiService = aiService,
       _vectorStoreService =
           vectorStoreService; // CP: Initialize VectorStoreService

  // --- Initialization ---
  Future<void> initialize() async {
    await _loadCategories();
    await _loadEntries();
    // CP: Trigger initial sync for today's logs
    _triggerVectorStoreSyncForDate(DateTime.now()).catchError((e, stackTrace) {
      AppLogger.error(
        "Repository: Background vector store sync failed during initialization",
        error: e,
        stackTrace: stackTrace,
      );
    });
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
    } on AiServiceException catch (e) {
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
          // Use the renamed field textSegment
          text: data.textSegment,
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

    // CP: Trigger vector store sync for the date of the new entries
    _triggerVectorStoreSyncForDate(processingTimestamp).catchError((
      e,
      stackTrace,
    ) {
      AppLogger.error(
        "Repository: Background vector store sync failed for addEntry",
        error: e,
        stackTrace: stackTrace,
      );
    });

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
      // CP: Trigger vector store sync for the date of the deleted entry
      _triggerVectorStoreSyncForDate(entryToDelete.timestamp).catchError((
        e,
        stackTrace,
      ) {
        AppLogger.error(
          "Repository: Background vector store sync failed for deleteEntry",
          error: e,
          stackTrace: stackTrace,
        );
      });
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
      final entryToSave = updatedEntry.copyWith(isNew: _entries[index].isNew);
      _entries[index] = entryToSave;
      await _saveEntries();
      // CP: Trigger vector store sync for the date of the updated entry
      // CP: (uses originalEntry.timestamp as that's the key for the daily log file)
      _triggerVectorStoreSyncForDate(originalEntry.timestamp).catchError((
        e,
        stackTrace,
      ) {
        AppLogger.error(
          "Repository: Background vector store sync failed for updateEntry",
          error: e,
          stackTrace: stackTrace,
        );
      });
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
    } on AiServiceException catch (e) {
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
      _entries.removeAt(tempIndex);
    } else {
      AppLogger.warn(
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
          // Use the renamed field textSegment
          text: data.textSegment,
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
    // CP: Trigger vector store sync for the date of the processed entries
    _triggerVectorStoreSyncForDate(tempEntryTimestamp).catchError((
      e,
      stackTrace,
    ) {
      AppLogger.error(
        "Repository: Background vector store sync failed for processCombinedEntry",
        error: e,
        stackTrace: stackTrace,
      );
    });
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
    if (categoryToDelete == 'Misc') {
      return (entries: currentEntries, categories: currentCategories);
    }

    if (_categories.contains(categoryToDelete)) {
      _categories.remove(categoryToDelete);
      bool entriesChanged = false;
      // CP: Collect all unique dates of modified entries
      final Set<DateTime> affectedDates = {};
      _entries =
          _entries.map((entry) {
            if (entry.category == categoryToDelete) {
              entriesChanged = true;
              // CP: Add date to set before modifying entry (use y/m/d for uniqueness)
              affectedDates.add(
                DateTime(
                  entry.timestamp.year,
                  entry.timestamp.month,
                  entry.timestamp.day,
                ),
              );
              return entry.copyWith(category: 'Misc');
            }
            return entry;
          }).toList();

      await _saveCategories();
      if (entriesChanged) {
        await _saveEntries();
        // CP: Trigger sync for all affected dates
        for (final date in affectedDates) {
          _triggerVectorStoreSyncForDate(date).catchError((e, stackTrace) {
            AppLogger.error(
              "Repository: Background vector store sync failed for deleteCategory (date: $date)",
              error: e,
              stackTrace: stackTrace,
            );
          });
        }
      }
    }
    return (entries: currentEntries, categories: currentCategories);
  }

  // CP: Method to mark an entry as not new
  Future<bool> markEntryAsNotNew(DateTime timestamp, String text) async {
    final index = _entries.indexWhere(
      (entry) => entry.timestamp == timestamp && entry.text == text,
    );
    if (index != -1 && _entries[index].isNew) {
      _entries[index] = _entries[index].copyWith(isNew: false);
      await _saveEntries();
      // CP: No vector store sync needed for just changing isNew flag
      return true;
    }
    return false;
  }

  // CP: Method to rename a category
  Future<({List<Entry> entries, List<String> categories})> renameCategory(
    String oldName,
    String newName,
  ) async {
    // todo this was the old code, the misc check was removed by accident i think. investigate

    //   if (oldName == 'Misc' ||
    //   trimmedNewName.isEmpty ||
    //   oldName == trimmedNewName ||
    //   _categories.any(
    //     (c) => c.toLowerCase() == trimmedNewName.toLowerCase(),
    //   )) {
    // AppLogger.warn(
    //   'Repository: Rename category validation failed ($oldName -> $trimmedNewName).',
    // );

    final trimmedNewName = newName.trim();
    if (trimmedNewName.isEmpty ||
        trimmedNewName == oldName ||
        _categories.contains(trimmedNewName)) {
      // CP: Avoid empty, no-change, or duplicate new names
      return (entries: currentEntries, categories: currentCategories);
    }

    final oldCategoryIndex = _categories.indexOf(oldName);
    if (oldCategoryIndex == -1) {
      // CP: Old category doesn't exist
      return (entries: currentEntries, categories: currentCategories);
    }

    _categories[oldCategoryIndex] = trimmedNewName;

    bool entriesChanged = false;
    // CP: Collect all unique dates of modified entries
    final Set<DateTime> affectedDates = {};
    _entries =
        _entries.map((entry) {
          if (entry.category == oldName) {
            entriesChanged = true;
            // CP: Add date to set before modifying entry (use y/m/d for uniqueness)
            affectedDates.add(
              DateTime(
                entry.timestamp.year,
                entry.timestamp.month,
                entry.timestamp.day,
              ),
            );
            return entry.copyWith(category: trimmedNewName);
          }
          return entry;
        }).toList();

    await _saveCategories();
    if (entriesChanged) {
      await _saveEntries();
      // CP: Trigger sync for all affected dates
      for (final date in affectedDates) {
        _triggerVectorStoreSyncForDate(date).catchError((e, stackTrace) {
          AppLogger.error(
            "Repository: Background vector store sync failed for renameCategory (date: $date)",
            error: e,
            stackTrace: stackTrace,
          );
        });
      }
    }
    return (entries: currentEntries, categories: currentCategories);
  }

  // --- Helper Methods ---
  String getAllEntriesAsLogContext() {
    if (_entries.isEmpty) return "No log entries yet.";

    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return _entries
        .map((entry) {
          return "[${formatter.format(entry.timestamp)}] (${entry.category}): ${entry.text}";
        })
        .join('\n');
  }

  // CP: New private method to trigger vector store sync for a specific date
  Future<void> _triggerVectorStoreSyncForDate(DateTime date) async {
    AppLogger.info(
      "[EntryRepository] Triggering vector store sync for date: $date",
    );
    try {
      final String vectorStoreId =
          await _vectorStoreService.getOrCreateVectorStoreId();

      // Format entries for the given day
      final DateFormat dayFormatter = DateFormat('yyyy-MM-dd');
      final String targetDayString = dayFormatter.format(date);

      final List<Entry> entriesForDay =
          _entries.where((entry) {
            return dayFormatter.format(entry.timestamp) == targetDayString;
          }).toList();

      String formattedContent = "";
      if (entriesForDay.isNotEmpty) {
        final DateFormat entryFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');
        formattedContent = entriesForDay
            .map((entry) {
              return "[${entryFormatter.format(entry.timestamp)}] (${entry.category}): ${entry.text}";
            })
            .join('\n');
      }
      AppLogger.info(
        "[EntryRepository] Content for $targetDayString: ${formattedContent.substring(0, (formattedContent.length > 100) ? 100 : formattedContent.length)}...",
      );

      await _vectorStoreService.synchronizeDailyLogFile(
        vectorStoreId,
        date,
        formattedContent,
      );
      AppLogger.info(
        "[EntryRepository] Vector store sync for date $date completed successfully.",
      );
    } on VectorStoreSyncException catch (e, stackTrace) {
      AppLogger.error(
        "[EntryRepository] VectorStoreService sync failed for date $date",
        error: e.message,
        stackTrace: stackTrace,
      );
      // CP: Do not rethrow, allow main operation to continue
    } catch (e, stackTrace) {
      AppLogger.error(
        "[EntryRepository] Unexpected error during vector store sync for date $date",
        error: e,
        stackTrace: stackTrace,
      );
      // CP: Do not rethrow
    }
  }
}
