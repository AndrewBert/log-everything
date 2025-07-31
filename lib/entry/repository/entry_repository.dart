import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entry.dart';
import '../category.dart'; // CP: Import Category model
import '../../services/ai_service.dart';
import '../../services/entry_persistence_service.dart';
import '../../services/vector_store_service.dart'; // CP: Added VectorStoreService import
import '../../services/timer_factory.dart'; // CP: Added TimerFactory import
import '../../utils/logger.dart';

/// Manages the storage and retrieval of entries, synchronizing with vector store and handling AI categorization.
class EntryRepository {
  final EntryPersistenceService _persistenceService;
  final AiService _aiService;
  final VectorStoreService _vectorStoreService;
  final TimerFactory _timerFactory;
  List<Entry> _entries = [];
  List<Category> _categories = [];
  // CP: Map to store debounce timers for each month's sync
  final Map<String, Timer> _syncDebounceTimers = {};
  static const _syncDebounceMs = 2000; // CP: 2 second debounce

  // CC: Stream controller for reactive updates
  final _entriesStreamController = StreamController<List<Entry>>.broadcast();
  Stream<List<Entry>> get entriesStream => _entriesStreamController.stream;

  List<Entry> get currentEntries => List.unmodifiable(_entries);
  List<Category> get currentCategories => List.unmodifiable(_categories);

  EntryRepository({
    required EntryPersistenceService persistenceService,
    required AiService aiService,
    required VectorStoreService vectorStoreService,
    required TimerFactory timerFactory,
  }) : _persistenceService = persistenceService,
       _aiService = aiService,
       _vectorStoreService = vectorStoreService,
       _timerFactory = timerFactory;

  Future<void> initialize() async {
    await _loadCategories();
    await _loadEntries();

    // CC: Migrate category colors from CategoryColors utility to Category model
    await _migrateCategoryColorsIfNeeded();

    // CC: Emit initial entries to stream
    _entriesStreamController.add(currentEntries);

    AppLogger.info("Repository: Triggering initial vector store backfill check (background).");
    _vectorStoreService
        .performInitialBackfillIfNeeded()
        .then((_) {
          AppLogger.info("Repository: Initial vector store backfill process completed (background).");
        })
        .catchError((e, stackTrace) {
          AppLogger.error(
            "Repository: Initial vector store backfill failed (background)",
            error: e,
            stackTrace: stackTrace,
          );
        });

    _triggerVectorStoreSyncForMonth(DateTime.now()).catchError((e, stackTrace) {
      AppLogger.error(
        "Repository: Background vector store sync failed during initialization",
        error: e,
        stackTrace: stackTrace,
      );
    });

    // CP: Trigger automatic cleanup of duplicate vector store files in background
    AppLogger.info("Repository: Triggering vector store cleanup check (background).");
    _vectorStoreService
        .cleanupDuplicateFiles()
        .then((_) {
          AppLogger.info("Repository: Vector store cleanup process completed (background).");
        })
        .catchError((e, stackTrace) {
          AppLogger.error("Repository: Vector store cleanup failed (background)", error: e, stackTrace: stackTrace);
        });
  }

  Future<void> _loadCategories() async {
    try {
      final loadedCategories = await _persistenceService.loadCategories();
      // CP: Ensure we have a modifiable list to avoid "unmodifiable list" errors
      _categories = List<Category>.from(loadedCategories);
      // AppLogger.info("Repository: Loaded Categories: $_categories");
    } catch (e) {
      AppLogger.error("Repository: Error loading categories", error: e);
      _categories = [];
    }
  }

  Future<void> _loadEntries() async {
    try {
      _entries = await _persistenceService.loadEntries();
      AppLogger.info('Repository: Successfully loaded ${_entries.length} entries.');
    } catch (e) {
      AppLogger.error('Repository: Error loading entries.', error: e);
      _entries = [];
    }
  }

  Future<void> _saveCategories() async {
    try {
      await _persistenceService.saveCategories(_categories);
      // AppLogger.info("Repository: Saved Categories: $_categories");
    } catch (e) {
      AppLogger.error("Repository: Error saving categories", error: e);
    }
  }

  Future<void> _saveEntries() async {
    try {
      await _persistenceService.saveEntries(_entries);
      AppLogger.info('Repository: Saved ${_entries.length} entries.');
      // CC: Emit updated entries to stream
      _entriesStreamController.add(currentEntries);
    } catch (e) {
      AppLogger.error('Repository: Error saving entries', error: e);
    }
  }

  Future<({List<Entry> entries, int splitCount})> addEntry(String text) async {
    if (text.isEmpty) return (entries: _entries, splitCount: 0);

    final DateTime processingTimestamp = DateTime.now();
    List<EntryPrototype> extractedData = [];
    String? serviceError;

    try {
      // CP: Pass List<Category> to AI service for type safety
      extractedData = await _aiService.extractEntries(text, _categories);
    } on AiServiceException catch (e) {
      AppLogger.error("Repository: AI Service failed: ${e.message}", error: e.underlyingError);
      serviceError = e.message;
    } catch (e, stacktrace) {
      AppLogger.error("Repository: Unexpected error calling AI Service", error: e, stackTrace: stacktrace);
      serviceError = "An unexpected error occurred during categorization.";
    }

    final List<Entry> addedEntries = [];
    if (serviceError != null || extractedData.isEmpty) {
      final fallbackEntry = Entry(
        text: text,
        timestamp: processingTimestamp,
        category: 'Misc',
        isNew: true,
        isTask: false,
      );
      addedEntries.add(fallbackEntry);
    } else {
      for (var data in extractedData) {
        final newEntry = Entry(
          text: data.textSegment,
          timestamp: processingTimestamp,
          category: _categories.any((cat) => cat.name == data.category) ? data.category : 'Misc',
          isNew: true,
          isTask: data.isTask,
        );
        addedEntries.add(newEntry);
      }
    }

    _entries.insertAll(0, addedEntries);
    await _saveEntries();

    // CP: Log split information for debugging
    final splitCount = addedEntries.length;
    if (splitCount > 1) {
      AppLogger.info("Repository: Entry was split into $splitCount parts");
    }

    _triggerVectorStoreSyncForMonth(processingTimestamp).catchError((e, stackTrace) {
      AppLogger.error("Repository: Background vector store sync failed for addEntry", error: e, stackTrace: stackTrace);
    });

    return (entries: currentEntries, splitCount: splitCount);
  }

  Future<List<Entry>> addEntryObject(Entry entryToAdd) async {
    _entries.add(entryToAdd);
    await _saveEntries();
    AppLogger.info("Repository: Added entry object - ${entryToAdd.text}");
    return currentEntries;
  }

  Future<List<Entry>> deleteEntry(Entry entryToDelete) async {
    final originalLength = _entries.length;
    _entries.removeWhere((entry) => entry.timestamp == entryToDelete.timestamp && entry.text == entryToDelete.text);
    if (_entries.length < originalLength) {
      await _saveEntries();
      _triggerVectorStoreSyncForMonth(entryToDelete.timestamp).catchError((e, stackTrace) {
        AppLogger.error(
          "Repository: Background vector store sync failed for deleteEntry",
          error: e,
          stackTrace: stackTrace,
        );
      });
    }
    return currentEntries;
  }

  Future<List<Entry>> updateEntry(Entry originalEntry, Entry updatedEntry) async {
    final index = _entries.indexWhere(
      (entry) => entry.timestamp == originalEntry.timestamp && entry.text == originalEntry.text,
    );
    if (index != -1) {
      final entryToSave = updatedEntry.copyWith(isNew: _entries[index].isNew);
      _entries[index] = entryToSave;
      await _saveEntries();
      _triggerVectorStoreSyncForMonth(originalEntry.timestamp).catchError((e, stackTrace) {
        AppLogger.error(
          "Repository: Background vector store sync failed for updateEntry",
          error: e,
          stackTrace: stackTrace,
        );
      });
    }
    return currentEntries;
  }

  Future<({List<Entry> entries, int splitCount})> processCombinedEntry(
    String combinedText,
    DateTime tempEntryTimestamp,
  ) async {
    AppLogger.info(
      '[Repo.processCombinedEntry] Processing combined text: "$combinedText" for temp timestamp: $tempEntryTimestamp',
    );
    if (combinedText.isEmpty) {
      _entries.removeWhere((e) => e.timestamp == tempEntryTimestamp && e.category == 'Processing...');
      await _saveEntries();
      return (entries: currentEntries, splitCount: 0);
    }

    List<EntryPrototype> extractedData = [];
    String? serviceError;
    try {
      // CP: Pass List<Category> to AI service for type safety
      extractedData = await _aiService.extractEntries(combinedText, _categories);
    } on AiServiceException catch (e) {
      AppLogger.error("Repository: AI Service failed for combined entry: ${e.message}", error: e.underlyingError);
      serviceError = e.message;
    } catch (e, stacktrace) {
      AppLogger.error(
        "Repository: Unexpected error calling AI Service for combined entry",
        error: e,
        stackTrace: stacktrace,
      );
      serviceError = "An unexpected error occurred during categorization.";
    }

    int tempIndex = _entries.indexWhere((e) => e.timestamp == tempEntryTimestamp && e.category == 'Processing...');
    if (tempIndex != -1) {
      _entries.removeAt(tempIndex);
    } else {
      AppLogger.warn('[Repo.processCombinedEntry] Temporary entry with timestamp $tempEntryTimestamp not found!');
      tempIndex = 0;
    }

    final List<Entry> addedEntries = [];
    if (serviceError != null || extractedData.isEmpty) {
      final fallbackEntry = Entry(text: combinedText, timestamp: tempEntryTimestamp, category: 'Misc', isNew: true);
      addedEntries.add(fallbackEntry);
    } else {
      for (var data in extractedData) {
        final newEntry = Entry(
          text: data.textSegment,
          timestamp: tempEntryTimestamp,
          category: _categories.any((cat) => cat.name == data.category) ? data.category : 'Misc',
          isNew: true,
        );
        addedEntries.add(newEntry);
      }
    }

    if (tempIndex >= 0 && tempIndex <= _entries.length) {
      _entries.insertAll(tempIndex, addedEntries);
    } else {
      _entries.insertAll(0, addedEntries);
    }

    await _saveEntries();

    // CP: Log split information for debugging
    final splitCount = addedEntries.length;
    if (splitCount > 1) {
      AppLogger.info("Repository: Combined entry was split into $splitCount parts");
    }

    _triggerVectorStoreSyncForMonth(tempEntryTimestamp).catchError((e, stackTrace) {
      AppLogger.error(
        "Repository: Background vector store sync failed for processCombinedEntry",
        error: e,
        stackTrace: stackTrace,
      );
    });
    return (entries: currentEntries, splitCount: splitCount);
  }

  Future<List<Category>> addCustomCategory(String newCategory) async {
    final trimmedCategory = newCategory.trim();
    if (trimmedCategory.isNotEmpty &&
        trimmedCategory != 'Misc' &&
        !_categories.any((cat) => cat.name == trimmedCategory)) {
      _categories.add(Category(name: trimmedCategory));
      await _saveCategories();
    }
    return currentCategories;
  }

  Future<List<Category>> addCustomCategoryWithDescription(
    String name,
    String description, {
    bool isChecklist = false,
    Color? color,
  }) async {
    final trimmedName = name.trim();
    final trimmedDescription = description.trim();
    if (trimmedName.isNotEmpty && trimmedName != 'Misc' && !_categories.any((cat) => cat.name == trimmedName)) {
      _categories.add(
        Category(
          name: trimmedName,
          description: trimmedDescription,
          isChecklist: isChecklist,
          color: color,
        ),
      );
      await _saveCategories();
    }
    return currentCategories;
  }

  Future<({List<Entry> entries, List<Category> categories})> deleteCategory(String categoryToDelete) async {
    if (categoryToDelete == 'Misc') {
      return (entries: currentEntries, categories: currentCategories);
    }

    final categoryIndex = _categories.indexWhere((cat) => cat.name == categoryToDelete);
    if (categoryIndex != -1) {
      _categories.removeAt(categoryIndex);
      bool entriesChanged = false;
      final Set<DateTime> affectedDates = {};
      _entries = _entries.map((entry) {
        if (entry.category == categoryToDelete) {
          entriesChanged = true;
          affectedDates.add(DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day));
          return entry.copyWith(category: 'Misc');
        }
        return entry;
      }).toList();

      await _saveCategories();
      if (entriesChanged) {
        await _saveEntries();
        for (final date in affectedDates) {
          _triggerVectorStoreSyncForMonth(date).catchError((e, stackTrace) {
            AppLogger.error(
              "Repository: Background vector store sync failed for deleteCategory (date: $date)",
              error: e,
              stackTrace: stackTrace,
            );
          });
        }
      }

      // CC: Emit updated entries to stream to notify listeners of category changes
      _entriesStreamController.add(currentEntries);
    }
    return (entries: currentEntries, categories: currentCategories);
  }

  Future<bool> markEntryAsNotNew(DateTime timestamp, String text) async {
    bool anyUpdated = false;
    for (int i = 0; i < _entries.length; i++) {
      if (_entries[i].timestamp == timestamp && _entries[i].isNew) {
        _entries[i] = _entries[i].copyWith(isNew: false);
        anyUpdated = true;
      }
    }
    if (anyUpdated) {
      await _saveEntries();
      return true;
    }
    return false;
  }

  Future<({List<Entry> entries, List<Category> categories})> renameCategory(
    String oldName,
    String newName, {
    String? description,
    bool? isChecklist,
    Color? color,
  }) async {
    final trimmedNewName = newName.trim();
    final oldCategoryIndex = _categories.indexWhere((cat) => cat.name == oldName);
    if (oldCategoryIndex == -1) {
      return (entries: currentEntries, categories: currentCategories);
    }
    // CP: Allow updating description even if name is unchanged
    final isNameChanged = trimmedNewName != oldName;
    final nameExists = _categories.any((cat) => cat.name == trimmedNewName);
    if (isNameChanged && nameExists) {
      return (entries: currentEntries, categories: currentCategories);
    }
    final oldCategory = _categories[oldCategoryIndex];
    _categories[oldCategoryIndex] = oldCategory.copyWith(
      name: trimmedNewName,
      description: description ?? oldCategory.description,
      isChecklist: isChecklist ?? oldCategory.isChecklist,
      color: color ?? oldCategory.color,
    );
    bool entriesChanged = false;
    final Set<DateTime> affectedDates = {};
    if (isNameChanged) {
      _entries = _entries.map((entry) {
        if (entry.category == oldName) {
          entriesChanged = true;
          affectedDates.add(DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day));
          return entry.copyWith(category: trimmedNewName);
        }
        return entry;
      }).toList();
    }
    await _saveCategories();
    if (entriesChanged) {
      await _saveEntries();
      for (final date in affectedDates) {
        _triggerVectorStoreSyncForMonth(date).catchError((e, stackTrace) {
          AppLogger.error(
            "Repository: Background vector store sync failed for renameCategory (date: $date)",
            error: e,
            stackTrace: stackTrace,
          );
        });
      }
    }

    // CC: Emit updated entries to stream to notify listeners of category changes
    _entriesStreamController.add(currentEntries);

    return (entries: currentEntries, categories: currentCategories);
  }

  String getAllEntriesAsLogContext() {
    if (_entries.isEmpty) return "No log entries yet.";

    final DateFormat formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return _entries
        .map((entry) {
          return "[${formatter.format(entry.timestamp)}] (${entry.category}): ${entry.text}";
        })
        .join('\n');
  }

  Future<void> _triggerVectorStoreSyncForMonth(DateTime date) async {
    final DateTime monthToSync = DateTime(date.year, date.month, 1);
    final String monthKeyString = "${monthToSync.year}-${monthToSync.month.toString().padLeft(2, '0')}";

    // CP: Cancel any existing timer for this month
    _syncDebounceTimers[monthKeyString]?.cancel();

    // CP: Create a new timer that will trigger the sync after the debounce period
    _syncDebounceTimers[monthKeyString] = _timerFactory.createTimer(Duration(milliseconds: _syncDebounceMs), () async {
      _syncDebounceTimers.remove(monthKeyString);

      AppLogger.info("[EntryRepository] Triggering vector store sync for month: $monthKeyString");
      try {
        final String? vectorStoreId = await _vectorStoreService.getOrCreateVectorStoreId();

        if (vectorStoreId == null) {
          AppLogger.warn("[EntryRepository] Vector store ID is null. Skipping sync for month: $monthKeyString");
          return;
        }

        final List<Entry> entriesForMonth = _entries.where((entry) {
          return entry.timestamp.year == monthToSync.year && entry.timestamp.month == monthToSync.month;
        }).toList();

        entriesForMonth.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        String formattedContent = "";
        if (entriesForMonth.isNotEmpty) {
          formattedContent = entriesForMonth
              .map((entry) {
                final String timestampStr = _formatTimestampForLogEntry(entry.timestamp);
                return "[$timestampStr] (${entry.category}): ${entry.text}";
              })
              .join('\n---\n');
        }
        AppLogger.info(
          "[EntryRepository] Content for $monthKeyString (first 100 chars): ${formattedContent.substring(0, (formattedContent.length > 100) ? 100 : formattedContent.length)}...",
        );

        await _vectorStoreService.synchronizeMonthlyLogFile(vectorStoreId, monthToSync, formattedContent);
        AppLogger.info("[EntryRepository] Vector store sync for month $monthKeyString completed successfully.");
      } on VectorStoreSyncException catch (e, stackTrace) {
        AppLogger.error(
          "[EntryRepository] VectorStoreService sync failed for month $monthKeyString",
          error: e.message,
          stackTrace: stackTrace,
        );
      } catch (e, stackTrace) {
        AppLogger.error(
          "[EntryRepository] Unexpected error during vector store sync for month $monthKeyString",
          error: e,
          stackTrace: stackTrace,
        );
      }
    });
  }

  String _formatTimestampForLogEntry(DateTime timestamp) {
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('yyyy-MM-dd');
    return "${dateFormat.format(timestamp)} ${timeFormat.format(timestamp)}:${timestamp.second.toString().padLeft(2, '0')}";
  }

  /// CC: Migrate colors from CategoryColors utility to Category model (one-time migration)
  Future<void> _migrateCategoryColorsIfNeeded() async {
    try {
      // CC: Check if migration is already complete by looking for any categories with colors
      final hasColorsInCategories = _categories.any((cat) => cat.color != null);
      if (hasColorsInCategories) {
        AppLogger.info("Repository: Category color migration already completed - skipping.");
        return;
      }

      // CC: Load existing category colors from CategoryColors
      final prefs = await SharedPreferences.getInstance();
      const prefsKey = 'category_colors_v1';
      final savedColors = prefs.getString(prefsKey);

      if (savedColors == null) {
        AppLogger.info("Repository: No legacy category colors found - skipping migration.");
        return;
      }

      Map<String, Color> legacyColors = {};
      try {
        final Map<String, dynamic> decodedMap = jsonDecode(savedColors);
        for (var entry in decodedMap.entries) {
          try {
            final color = _colorFromHex(entry.value as String);
            legacyColors[entry.key] = color;
          } catch (e) {
            AppLogger.warn('Error parsing legacy color for category "${entry.key}": $e');
          }
        }
      } catch (e) {
        AppLogger.error('Error decoding legacy category colors JSON: $e');
        return;
      }

      if (legacyColors.isEmpty) {
        AppLogger.info("Repository: No valid legacy category colors found - skipping migration.");
        return;
      }

      // CC: Update categories with migrated colors
      bool migrationMade = false;
      for (int i = 0; i < _categories.length; i++) {
        final category = _categories[i];
        if (legacyColors.containsKey(category.name)) {
          _categories[i] = category.copyWith(color: legacyColors[category.name]);
          migrationMade = true;
        }
      }

      if (migrationMade) {
        await _saveCategories();
        AppLogger.info("Repository: Successfully migrated ${legacyColors.length} category colors to Category model.");
      }
    } catch (e, stackTrace) {
      AppLogger.error("Repository: Error during category color migration", error: e, stackTrace: stackTrace);
    }
  }

  /// CC: Helper method to convert hex string to Color (copied from CategoryColors)
  Color _colorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceAll('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// CP: Disposes the repository and cancels all pending timers
  void dispose() {
    for (final timer in _syncDebounceTimers.values) {
      timer.cancel();
    }
    _syncDebounceTimers.clear();
    // CC: Close the stream controller
    _entriesStreamController.close();
    AppLogger.info("[EntryRepository] Disposed and cancelled all pending timers");
  }
}
