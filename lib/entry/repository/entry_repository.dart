import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entry.dart';
import '../category.dart'; // CP: Import Category model
import '../../services/ai_service.dart';
import '../../services/entry_persistence_service.dart';
import '../../services/vector_store_service.dart'; // CP: Added VectorStoreService import
import '../../services/timer_factory.dart'; // CP: Added TimerFactory import
import '../../services/image_storage_service.dart';
import '../../utils/logger.dart';
import '../../dashboard_v2/model/simple_insight.dart';
import '../processing_state.dart';

/// Manages the storage and retrieval of entries, synchronizing with vector store and handling AI categorization.
class EntryRepository {
  final EntryPersistenceService _persistenceService;
  final AiService _aiService;
  final VectorStoreService _vectorStoreService;
  final TimerFactory _timerFactory;
  final ImageStorageService _imageStorageService;
  List<Entry> _entries = [];
  List<Category> _categories = [];
  // CP: Map to store debounce timers for each month's sync
  final Map<String, Timer> _syncDebounceTimers = {};
  static const _syncDebounceMs = 2000; // CP: 2 second debounce

  // CC: Track entry IDs currently being processed to prevent concurrent processing
  final Set<String> _processingEntryIds = {};

  // CC: Stream controller for reactive updates
  final _entriesStreamController = StreamController<List<Entry>>.broadcast();
  Stream<List<Entry>> get entriesStream => _entriesStreamController.stream;

  List<Entry> get currentEntries => List.unmodifiable(_entries);
  List<Category> get currentCategories => List.unmodifiable(_categories);
  // CP: Get only active (non-archived) categories for AI categorization
  List<Category> get activeCategories => _categories.where((cat) => !cat.isArchived).toList();

  EntryRepository({
    required EntryPersistenceService persistenceService,
    required AiService aiService,
    required VectorStoreService vectorStoreService,
    required TimerFactory timerFactory,
    required ImageStorageService imageStorageService,
  }) : _persistenceService = persistenceService,
       _aiService = aiService,
       _vectorStoreService = vectorStoreService,
       _timerFactory = timerFactory,
       _imageStorageService = imageStorageService;

  Future<void> initialize() async {
    await _loadCategories();
    await _loadEntries();

    // CC: Migrate category colors from CategoryColors utility to Category model
    await _migrateCategoryColorsIfNeeded();

    // CC: Retry any pending/failed entries from previous sessions
    retryPendingEntries();

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

    // CC: Create pending entry and save BEFORE AI call to prevent data loss
    final pendingEntry = Entry(
      text: text,
      timestamp: processingTimestamp,
      category: 'Processing...',
      isNew: true,
      processingState: ProcessingState.pending,
    );

    _entries.insert(0, pendingEntry);
    await _saveEntries();
    AppLogger.info("Repository: Pre-persisted pending entry for: ${text.substring(0, text.length > 50 ? 50 : text.length)}...");

    // CC: Process in background - fire-and-forget
    _processEntryWithAI(pendingEntry).catchError((e, stackTrace) {
      AppLogger.error("Repository: Background AI processing failed", error: e, stackTrace: stackTrace);
    });

    return (entries: currentEntries, splitCount: 1);
  }

  /// Processes a pending entry with AI categorization and replaces it with final entries.
  ///
  /// Flow:
  /// 1. Checks if entry is already being processed (prevents concurrent processing)
  /// 2. Marks entry as [ProcessingState.processing]
  /// 3. Calls AI service for categorization
  /// 4. On success: replaces pending entry with categorized entries
  /// 5. On failure: marks entry as [ProcessingState.failed] for retry
  Future<void> _processEntryWithAI(Entry pendingEntry) async {
    // CC: Prevent concurrent processing of the same entry
    if (_processingEntryIds.contains(pendingEntry.id)) {
      AppLogger.info("Repository: Entry ${pendingEntry.id} is already being processed, skipping");
      return;
    }
    _processingEntryIds.add(pendingEntry.id);

    try {
      // CC: Mark as processing
      final processingEntry = pendingEntry.copyWith(processingState: ProcessingState.processing);
      final processingIndex = _entries.indexWhere((e) => e.id == pendingEntry.id);
      if (processingIndex != -1) {
        _entries[processingIndex] = processingEntry;
        await _saveEntries();
      }

      List<EntryPrototype> extractedData = [];
      String? serviceError;

      try {
        // CP: Pass only active categories to AI service (excludes archived)
        extractedData = await _aiService.extractEntries(pendingEntry.text, activeCategories);
      } on AiServiceException catch (e) {
        AppLogger.error("Repository: AI Service failed: ${e.message}", error: e.underlyingError);
        serviceError = e.message;
      } catch (e, stacktrace) {
        AppLogger.error("Repository: Unexpected error calling AI Service", error: e, stackTrace: stacktrace);
        serviceError = "An unexpected error occurred during categorization.";
      }

      // CC: Find the pending entry
      final entryIndex = _entries.indexWhere((e) => e.id == pendingEntry.id);
      if (entryIndex == -1) {
        AppLogger.warn("Repository: Pending entry ${pendingEntry.id} not found, may have been deleted");
        return;
      }

      // CC: If AI failed, mark as failed for retry (unless max retries exceeded)
      if (serviceError != null && extractedData.isEmpty) {
        final newRetryCount = pendingEntry.processingRetryCount + 1;
        if (newRetryCount >= Entry.maxProcessingRetries) {
          // CC: Max retries exceeded - convert to fallback entry
          AppLogger.warn("Repository: Entry ${pendingEntry.id} exceeded max retries, converting to fallback");
          _entries.removeAt(entryIndex);
          final fallbackEntry = Entry(
            text: pendingEntry.text,
            timestamp: pendingEntry.timestamp,
            category: 'Misc',
            isNew: true,
            isTask: false,
          );
          _entries.insert(entryIndex, fallbackEntry);
          await _saveEntries();
          _triggerVectorStoreSyncForMonth(pendingEntry.timestamp).catchError((e, stackTrace) {
            AppLogger.error("Repository: Background vector store sync failed", error: e, stackTrace: stackTrace);
          });
        } else {
          // CC: Mark as failed for retry on next app launch
          final failedEntry = pendingEntry.copyWith(
            processingState: ProcessingState.failed,
            processingRetryCount: newRetryCount,
          );
          _entries[entryIndex] = failedEntry;
          await _saveEntries();
          AppLogger.info("Repository: Entry ${pendingEntry.id} marked as failed (retry ${newRetryCount}/${Entry.maxProcessingRetries})");
        }
        return;
      }

      // CC: Remove the pending entry and add final entries
      _entries.removeAt(entryIndex);

      final List<Entry> addedEntries = [];
      // CC: Add microsecond offsets to ensure unique timestamps for each entry
      for (var i = 0; i < extractedData.length; i++) {
        final data = extractedData[i];
        // CC: Add i microseconds to ensure each entry has a unique timestamp
        final uniqueTimestamp = pendingEntry.timestamp.add(Duration(microseconds: i));
        final newEntry = Entry(
          text: data.textSegment,
          timestamp: uniqueTimestamp,
          category: _categories.any((cat) => cat.name == data.category) ? data.category : 'Misc',
          isNew: true,
          isTask: data.isTask,
        );
        addedEntries.add(newEntry);
      }

      // CC: Insert at original position to maintain order
      _entries.insertAll(entryIndex, addedEntries);
      await _saveEntries();

      // CP: Log split information for debugging
      final splitCount = addedEntries.length;
      if (splitCount > 1) {
        AppLogger.info("Repository: Entry was split into $splitCount parts");
      }

      _triggerVectorStoreSyncForMonth(pendingEntry.timestamp).catchError((e, stackTrace) {
        AppLogger.error("Repository: Background vector store sync failed for addEntry", error: e, stackTrace: stackTrace);
      });
    } finally {
      // CC: Always remove from processing set
      _processingEntryIds.remove(pendingEntry.id);
    }
  }

  /// Retries processing for any pending or failed entries from previous sessions.
  /// Called on app initialization and when app resumes from background.
  void retryPendingEntries() {
    final pendingEntries = _entries.where((e) => e.needsProcessing).toList();

    if (pendingEntries.isEmpty) {
      AppLogger.info("Repository: No pending entries to retry");
      return;
    }

    AppLogger.info("Repository: Retrying ${pendingEntries.length} pending entries");

    for (final entry in pendingEntries) {
      // CC: Process each pending entry in background (non-blocking)
      _processEntryWithAI(entry).catchError((e, stackTrace) {
        AppLogger.error("Repository: Failed to retry entry ${entry.id}", error: e, stackTrace: stackTrace);
      });
    }
  }

  Future<List<Entry>> addEntryObject(Entry entryToAdd) async {
    _entries.insert(0, entryToAdd);
    await _saveEntries();
    AppLogger.info("Repository: Added entry object - ${entryToAdd.text}");
    return currentEntries;
  }

  Future<List<Entry>> addEntryObjects(List<Entry> entriesToAdd) async {
    _entries.insertAll(0, entriesToAdd);
    await _saveEntries();
    AppLogger.info("Repository: Added ${entriesToAdd.length} entry objects in batch");
    return currentEntries;
  }

  Future<({List<Entry> entries, Entry? addedEntry})> addImageEntry({
    required Uint8List imageBytes,
    String? userNote,
  }) async {
    final DateTime processingTimestamp = DateTime.now();

    try {
      // Save image to local storage
      final imagePath = await _imageStorageService.saveImageBytes(imageBytes, 'jpg');

      // Analyze image with AI
      final analysis = await _aiService.analyzeImage(
        imageBytes: imageBytes,
        categories: _categories,
        userNote: userNote,
      );

      // Create entry with image fields
      final newEntry = Entry(
        text: userNote ?? '',
        timestamp: processingTimestamp,
        category: analysis.category,
        isNew: true,
        isTask: analysis.isTask,
        imagePath: imagePath,
        imageTitle: analysis.imageTitle,
        imageDescription: analysis.imageDescription,
        simpleInsight: SimpleInsight(
          content: analysis.insight,
          generatedAt: DateTime.now(),
        ),
      );

      _entries.insert(0, newEntry);
      await _saveEntries();

      _triggerVectorStoreSyncForMonth(processingTimestamp).catchError((e, stackTrace) {
        AppLogger.error("Repository: Background vector store sync failed for addImageEntry",
          error: e, stackTrace: stackTrace);
      });

      return (entries: currentEntries, addedEntry: newEntry);
    } catch (e) {
      AppLogger.error("Repository: Error adding image entry", error: e);

      // Fallback: save with minimal data
      final imagePath = await _imageStorageService.saveImageBytes(imageBytes, 'jpg');
      final fallbackEntry = Entry(
        text: userNote ?? '',
        timestamp: processingTimestamp,
        category: 'Misc',
        isNew: true,
        imagePath: imagePath,
        imageTitle: 'Image',
      );

      _entries.insert(0, fallbackEntry);
      await _saveEntries();

      return (entries: currentEntries, addedEntry: fallbackEntry);
    }
  }

  Future<List<Entry>> deleteEntry(Entry entryToDelete) async {
    final originalLength = _entries.length;

    // Delete associated image if exists
    final entryToRemove = _entries.firstWhere(
      (entry) => entry.timestamp == entryToDelete.timestamp && entry.text == entryToDelete.text,
      orElse: () => entryToDelete,
    );
    if (entryToRemove.imagePath != null) {
      await _imageStorageService.deleteImage(entryToRemove.imagePath!);
    }

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

  Future<List<Entry>> updateEntry(Entry originalEntry, Entry updatedEntry, {bool skipAiRegeneration = false}) async {
    final index = _entries.indexWhere(
      (entry) => entry.timestamp == originalEntry.timestamp && entry.text == originalEntry.text,
    );
    if (index != -1) {
      final entryToSave = updatedEntry.copyWith(isNew: _entries[index].isNew);
      _entries[index] = entryToSave;
      await _saveEntries();
      if (!skipAiRegeneration) {
        _triggerVectorStoreSyncForMonth(originalEntry.timestamp).catchError((e, stackTrace) {
          AppLogger.error(
            "Repository: Background vector store sync failed for updateEntry",
            error: e,
            stackTrace: stackTrace,
          );
        });
      }
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

    // CC: Find existing temp entry and update it with processingState
    int tempIndex = _entries.indexWhere((e) => e.timestamp == tempEntryTimestamp && e.category == 'Processing...');
    if (tempIndex != -1) {
      // CC: Update the existing entry with processing state and combined text
      final pendingEntry = _entries[tempIndex].copyWith(
        text: combinedText,
        processingState: ProcessingState.pending,
      );
      _entries[tempIndex] = pendingEntry;
      await _saveEntries();
      AppLogger.info("Repository: Updated combined entry with pending state");

      // CC: Process in background - fire-and-forget
      _processEntryWithAI(pendingEntry).catchError((e, stackTrace) {
        AppLogger.error("Repository: Background AI processing failed for combined entry", error: e, stackTrace: stackTrace);
      });

      return (entries: currentEntries, splitCount: 1);
    }

    // CC: If no temp entry found, create a new pending entry
    AppLogger.warn('[Repo.processCombinedEntry] Temporary entry with timestamp $tempEntryTimestamp not found, creating new pending entry');
    final pendingEntry = Entry(
      text: combinedText,
      timestamp: tempEntryTimestamp,
      category: 'Processing...',
      isNew: true,
      processingState: ProcessingState.pending,
    );
    _entries.insert(0, pendingEntry);
    await _saveEntries();

    // CC: Process in background - fire-and-forget
    _processEntryWithAI(pendingEntry).catchError((e, stackTrace) {
      AppLogger.error("Repository: Background AI processing failed for combined entry", error: e, stackTrace: stackTrace);
    });

    return (entries: currentEntries, splitCount: 1);
  }

  Future<List<Category>> addCustomCategory(String newCategory) async {
    final trimmedCategory = newCategory.trim();
    if (trimmedCategory.isNotEmpty &&
        trimmedCategory != 'Misc' &&
        !_categories.any((cat) => cat.name == trimmedCategory)) {
      _categories.add(Category(name: trimmedCategory));
      await _saveCategories();
      // CC: Emit updated entries to stream to notify listeners of category changes
      _entriesStreamController.add(currentEntries);
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
      // CC: Emit updated entries to stream to notify listeners of category changes
      _entriesStreamController.add(currentEntries);
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

  // CP: Toggle archive status for a category (Misc cannot be archived)
  Future<List<Category>> toggleCategoryArchive(String categoryName) async {
    // CP: Misc is the default category and cannot be archived
    if (categoryName == 'Misc') {
      return currentCategories;
    }

    final categoryIndex = _categories.indexWhere((cat) => cat.name == categoryName);
    if (categoryIndex == -1) {
      return currentCategories;
    }

    final category = _categories[categoryIndex];
    _categories[categoryIndex] = category.copyWith(isArchived: !category.isArchived);

    await _saveCategories();
    _entriesStreamController.add(currentEntries);

    return currentCategories;
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
                final buffer = StringBuffer("[$timestampStr] (${entry.category})");
                if (entry.imagePath != null) {
                  buffer.write(" [IMAGE: ${entry.imageTitle ?? 'Untitled'}]");
                  if (entry.imageDescription != null) {
                    buffer.write(" ${entry.imageDescription}");
                  }
                }
                if (entry.text.isNotEmpty) {
                  buffer.write(": ${entry.text}");
                }
                return buffer.toString();
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
