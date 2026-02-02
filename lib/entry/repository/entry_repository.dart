import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import '../../services/image_storage_sync_service.dart'; // CP: Added for cloud image sync
import '../../services/firestore_sync_service.dart'; // CP: Added for cloud sync
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
  final ImageStorageSyncService _imageStorageSyncService; // CP: Cloud image sync
  final FirestoreSyncService _firestoreSyncService; // CP: Cloud sync service
  List<Entry> _entries = [];
  List<Category> _categories = [];
  // CP: Map to store debounce timers for each month's sync
  final Map<String, Timer> _syncDebounceTimers = {};
  static const _syncDebounceMs = 2000; // CP: 2 second debounce

  // CC: Track entry IDs currently being processed to prevent concurrent processing
  final Set<String> _processingEntryIds = {};

  // CP: Track cloud image paths that failed to delete for later retry
  final Set<String> _pendingCloudImageDeletions = {};

  // CP: Current user ID for cloud sync (null = not signed in)
  String? _currentUserId;

  // CC: Stream controller for reactive updates
  final _entriesStreamController = StreamController<List<Entry>>.broadcast();
  Stream<List<Entry>> get entriesStream => _entriesStreamController.stream;

  // CP: Initialization guard to prevent race condition with sign-in
  Completer<void>? _initCompleter;
  bool _isInitialized = false;

  List<Entry> get currentEntries => List.unmodifiable(_entries);
  List<Category> get currentCategories => List.unmodifiable(_categories);
  // CP: Get only active (non-archived) categories for AI categorization
  List<Category> get activeCategories => _categories.where((cat) => !cat.isArchived).toList();

  /// Whether there are more entries available to fetch from Firestore.
  /// Returns false if user is not signed in (pagination only applies to cloud data).
  bool get hasMoreFirestoreEntries => _currentUserId != null && _firestoreSyncService.hasMoreEntries;

  EntryRepository({
    required EntryPersistenceService persistenceService,
    required AiService aiService,
    required VectorStoreService vectorStoreService,
    required TimerFactory timerFactory,
    required ImageStorageService imageStorageService,
    required ImageStorageSyncService imageStorageSyncService,
    required FirestoreSyncService firestoreSyncService,
  }) : _persistenceService = persistenceService,
       _aiService = aiService,
       _vectorStoreService = vectorStoreService,
       _timerFactory = timerFactory,
       _imageStorageService = imageStorageService,
       _imageStorageSyncService = imageStorageSyncService,
       _firestoreSyncService = firestoreSyncService {
    // CP: Set up callback for remote category changes (entries use pull-to-refresh)
    _firestoreSyncService.onRemoteCategoriesChanged = _handleRemoteCategoriesChanged;
  }

  Future<void> initialize() async {
    // CP: Prevent double initialization (can happen if multiple cubits call this)
    if (_isInitialized) {
      return;
    }

    // CP: If already initializing, wait for the existing initialization to complete
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }

    // CP: Mark as initializing
    _initCompleter = Completer<void>();

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

    // CP: Mark initialization complete and signal any waiting sign-in calls
    _isInitialized = true;
    _initCompleter?.complete();
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

  Future<void> _saveCategories({List<Category>? categoriesToSync}) async {
    try {
      await _persistenceService.saveCategories(_categories);
      // AppLogger.info("Repository: Saved Categories: $_categories");

      // CP: Sync to cloud if signed in
      if (_currentUserId != null && categoriesToSync != null) {
        for (final category in categoriesToSync) {
          _syncCategoryToCloud(category);
        }
      }
    } catch (e) {
      AppLogger.error("Repository: Error saving categories", error: e);
    }
  }

  Future<void> _saveEntries({List<Entry>? entriesToSync}) async {
    try {
      await _persistenceService.saveEntries(_entries);
      AppLogger.info('Repository: Saved ${_entries.length} entries.');
      // CC: Emit updated entries to stream
      _entriesStreamController.add(currentEntries);

      // CP: Sync to cloud if signed in
      if (_currentUserId != null && entriesToSync != null) {
        for (final entry in entriesToSync) {
          _syncEntryToCloud(entry);
        }
      }
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
    AppLogger.info(
      "Repository: Pre-persisted pending entry for: ${text.substring(0, text.length > 50 ? 50 : text.length)}...",
    );

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
          AppLogger.info(
            "Repository: Entry ${pendingEntry.id} marked as failed (retry $newRetryCount/${Entry.maxProcessingRetries})",
          );
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
        AppLogger.error(
          "Repository: Background vector store sync failed for addEntry",
          error: e,
          stackTrace: stackTrace,
        );
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

  /// CP: Adds multiple entry objects in batch (used for recovery).
  /// Triggers cloud sync and vector store sync for affected months.
  Future<List<Entry>> addEntryObjects(List<Entry> entriesToAdd) async {
    if (entriesToAdd.isEmpty) return currentEntries;

    _entries.insertAll(0, entriesToAdd);
    await _saveEntries(entriesToSync: entriesToAdd);
    AppLogger.info("Repository: Added ${entriesToAdd.length} entry objects in batch");

    // CP: Trigger vector store sync for all affected months
    final affectedMonths = <DateTime>{};
    for (final entry in entriesToAdd) {
      affectedMonths.add(DateTime(entry.timestamp.year, entry.timestamp.month, 1));
    }
    for (final month in affectedMonths) {
      _triggerVectorStoreSyncForMonth(month).catchError((e, stackTrace) {
        AppLogger.error("Repository: Background vector store sync failed", error: e, stackTrace: stackTrace);
      });
    }

    return currentEntries;
  }

  /// CP: Adds multiple category objects in batch (used for recovery).
  /// Merges with existing categories - new categories are added, existing ones are skipped.
  Future<List<Category>> addCategoryObjects(List<Category> categoriesToAdd) async {
    if (categoriesToAdd.isEmpty) return currentCategories;

    final existingNames = _categories.map((c) => c.name).toSet();
    final newCategories = categoriesToAdd.where((c) => !existingNames.contains(c.name)).toList();

    if (newCategories.isEmpty) {
      AppLogger.info("Repository: All ${categoriesToAdd.length} categories already exist, skipping");
      return currentCategories;
    }

    _categories.addAll(newCategories);
    await _saveCategories(categoriesToSync: newCategories);
    _entriesStreamController.add(currentEntries);
    AppLogger.info("Repository: Added ${newCategories.length} category objects in batch");

    return currentCategories;
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

      // Create entry with image fields (cloudImagePath set later if upload succeeds)
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

      // CP: Upload image to Firebase Storage in background (if signed in)
      // Note: If upload fails, it will be retried on next app restart via _uploadPendingImages()
      // which is called in onUserSignedIn() when the auth stream fires
      _uploadImageForEntry(newEntry).catchError((e, stackTrace) {
        AppLogger.error(
          "Repository: Background image upload failed for ${newEntry.id}",
          error: e,
          stackTrace: stackTrace,
        );
      });

      _triggerVectorStoreSyncForMonth(processingTimestamp).catchError((e, stackTrace) {
        AppLogger.error(
          "Repository: Background vector store sync failed for addImageEntry",
          error: e,
          stackTrace: stackTrace,
        );
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

      // CP: Attempt upload for fallback entry too
      _uploadImageForEntry(fallbackEntry).catchError((e, stackTrace) {
        AppLogger.error(
          "Repository: Background image upload failed for fallback entry",
          error: e,
          stackTrace: stackTrace,
        );
      });

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
    // CP: Delete cloud image if exists, track failures for retry
    if (entryToRemove.cloudImagePath != null) {
      final cloudPath = entryToRemove.cloudImagePath!;
      _imageStorageSyncService
          .deleteImage(cloudPath)
          .then((success) {
            if (!success) {
              AppLogger.warn('[EntryRepository] Cloud image deletion failed, queuing for retry: $cloudPath');
              _pendingCloudImageDeletions.add(cloudPath);
            }
          })
          .catchError((Object e) {
            AppLogger.error('[EntryRepository] Error deleting cloud image, queuing for retry', error: e);
            _pendingCloudImageDeletions.add(cloudPath);
          });
    }

    _entries.removeWhere((entry) => entry.timestamp == entryToDelete.timestamp && entry.text == entryToDelete.text);
    if (_entries.length < originalLength) {
      await _saveEntries();
      // CP: Delete from cloud
      _deleteEntryFromCloud(entryToRemove.id);
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
      await _saveEntries(entriesToSync: [entryToSave]); // CP: Sync to cloud
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
        AppLogger.error(
          "Repository: Background AI processing failed for combined entry",
          error: e,
          stackTrace: stackTrace,
        );
      });

      return (entries: currentEntries, splitCount: 1);
    }

    // CC: If no temp entry found, create a new pending entry
    AppLogger.warn(
      '[Repo.processCombinedEntry] Temporary entry with timestamp $tempEntryTimestamp not found, creating new pending entry',
    );
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
      AppLogger.error(
        "Repository: Background AI processing failed for combined entry",
        error: e,
        stackTrace: stackTrace,
      );
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
      final newCategory = Category(
        name: trimmedName,
        description: trimmedDescription,
        isChecklist: isChecklist,
        color: color,
      );
      _categories.add(newCategory);
      await _saveCategories(categoriesToSync: [newCategory]); // CP: Sync to cloud
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
      final List<Entry> updatedEntries = [];
      _entries = _entries.map((entry) {
        if (entry.category == categoryToDelete) {
          entriesChanged = true;
          affectedDates.add(DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day));
          final updated = entry.copyWith(category: 'Misc');
          updatedEntries.add(updated);
          return updated;
        }
        return entry;
      }).toList();

      await _saveCategories();
      // CP: Delete category from cloud
      _deleteCategoryFromCloud(categoryToDelete);

      if (entriesChanged) {
        await _saveEntries(entriesToSync: updatedEntries); // CP: Sync updated entries to cloud
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
    final updatedCategory = oldCategory.copyWith(
      name: trimmedNewName,
      description: description ?? oldCategory.description,
      isChecklist: isChecklist ?? oldCategory.isChecklist,
      color: color ?? oldCategory.color,
    );
    _categories[oldCategoryIndex] = updatedCategory;
    bool entriesChanged = false;
    final Set<DateTime> affectedDates = {};
    final List<Entry> updatedEntries = [];
    if (isNameChanged) {
      _entries = _entries.map((entry) {
        if (entry.category == oldName) {
          entriesChanged = true;
          affectedDates.add(DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day));
          final updated = entry.copyWith(category: trimmedNewName);
          updatedEntries.add(updated);
          return updated;
        }
        return entry;
      }).toList();
    }
    // CP: Sync category changes to cloud
    if (isNameChanged) {
      _deleteCategoryFromCloud(oldName); // Delete old name
    }
    await _saveCategories(categoriesToSync: [updatedCategory]); // Sync new/updated category

    if (entriesChanged) {
      await _saveEntries(entriesToSync: updatedEntries); // Sync updated entries
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
    final updatedCategory = category.copyWith(isArchived: !category.isArchived);
    _categories[categoryIndex] = updatedCategory;

    await _saveCategories(categoriesToSync: [updatedCategory]); // CP: Sync to cloud
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

  // ============================================================================
  // CP: Cloud Sync Methods (Phase 2: Firestore)
  // ============================================================================

  /// Called when user signs in. Merges local and cloud data, starts listening.
  Future<void> onUserSignedIn(String uid) async {
    AppLogger.info('[EntryRepository] User signed in: $uid - starting cloud sync');

    // CP: Wait for initialization to complete before proceeding with sign-in
    // This prevents the race condition where sign-in fires before entries are loaded
    if (!_isInitialized && _initCompleter != null) {
      await _initCompleter!.future;
    }

    _currentUserId = uid;

    // CP: Fetch cloud data and merge with local
    final cloudEntries = await _firestoreSyncService.fetchEntries(uid);
    final cloudCategories = await _firestoreSyncService.fetchCategories(uid);

    // CP: Merge entries (cloud wins for same ID)
    final mergedEntries = _firestoreSyncService.mergeEntries(_entries, cloudEntries);
    final mergedCategories = _firestoreSyncService.mergeCategories(_categories, cloudCategories);

    // CP: Update local state
    _entries = mergedEntries;
    _categories = List<Category>.from(mergedCategories);

    // CP: Save merged data locally
    await _saveEntries();
    await _saveCategories();

    // CP: Push any local-only entries to cloud
    await _firestoreSyncService.syncAllEntries(uid, _entries);
    await _firestoreSyncService.syncAllCategories(uid, _categories);

    // CP: Start listening for real-time changes from other devices
    _firestoreSyncService.startListening(uid);

    // CP: Upload any local images that haven't been synced to cloud yet
    _uploadPendingImages().catchError((e, stackTrace) {
      AppLogger.error('[EntryRepository] Background pending image upload failed', error: e, stackTrace: stackTrace);
    });

    // CP: Retry any cloud image deletions that previously failed
    _retryPendingCloudImageDeletions().catchError((e, stackTrace) {
      AppLogger.error(
        '[EntryRepository] Background cloud image deletion retry failed',
        error: e,
        stackTrace: stackTrace,
      );
    });

    AppLogger.info(
      '[EntryRepository] Cloud sync complete - ${_entries.length} entries, ${_categories.length} categories',
    );
  }

  /// Load more entries from Firestore using cursor-based pagination.
  /// Merges new entries with existing list, avoiding duplicates.
  Future<void> loadMoreEntries() async {
    if (_currentUserId == null) {
      AppLogger.warn('[EntryRepository] Cannot load more entries - not signed in');
      return;
    }

    if (!hasMoreFirestoreEntries) {
      AppLogger.info('[EntryRepository] No more entries to load from Firestore');
      return;
    }

    final moreEntries = await _firestoreSyncService.fetchMoreEntries(_currentUserId!);
    if (moreEntries.isEmpty) {
      AppLogger.info('[EntryRepository] Fetched 0 more entries');
      return;
    }

    // CP: Merge new entries with existing, avoiding duplicates by ID
    final existingIds = _entries.map((e) => e.id).toSet();
    final newEntries = moreEntries.where((e) => !existingIds.contains(e.id)).toList();

    if (newEntries.isEmpty) {
      AppLogger.info('[EntryRepository] All fetched entries already exist locally');
      return;
    }

    _entries.addAll(newEntries);
    // CP: Re-sort to maintain timestamp descending order
    _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    await _saveEntries();
    AppLogger.info('[EntryRepository] Loaded ${newEntries.length} more entries, total: ${_entries.length}');
  }

  /// Refresh entries and categories from cloud (pull-to-refresh).
  /// Resets pagination and fetches first page of entries.
  Future<void> refreshFromCloud() async {
    if (_currentUserId == null) {
      AppLogger.warn('[EntryRepository] Cannot refresh from cloud - not signed in');
      return;
    }

    _firestoreSyncService.resetPagination();
    final entries = await _firestoreSyncService.fetchEntries(_currentUserId!);
    final categories = await _firestoreSyncService.fetchCategories(_currentUserId!);

    // CP: Merge cloud data with local (cloud wins for conflicts)
    _entries = _firestoreSyncService.mergeEntries(_entries, entries);
    _categories = List.from(_firestoreSyncService.mergeCategories(_categories, categories));

    await _saveEntries();
    await _saveCategories();

    AppLogger.info(
      '[EntryRepository] Refreshed from cloud - ${_entries.length} entries, ${_categories.length} categories',
    );
  }

  /// Called when user signs out. Stops listening, clears user ID and all local data.
  Future<void> onUserSignedOut() async {
    // CP: Log entry count before clearing to help debug data loss issues
    AppLogger.info(
      '[EntryRepository] User signed out - clearing ${_entries.length} entries and ${_categories.length} categories',
    );
    _firestoreSyncService.stopListening();
    // CP: Reset pagination cursor to prevent stale state on next sign-in
    _firestoreSyncService.resetPagination();
    _currentUserId = null;

    // Clear all local data to prevent mixing with another account
    await _persistenceService.clearAllData();
    await _vectorStoreService.clearLocalCache();
    _imageStorageSyncService.clearUrlCache();

    // Clear entries but restore default categories so app can still categorize
    _entries = [];
    _categories = await _persistenceService.loadCategories();

    // Notify listeners of the cleared state
    _entriesStreamController.add(currentEntries);

    AppLogger.info('[EntryRepository] Local data cleared, categories restored to defaults');
  }

  /// Handle remote categories update from Firestore listener.
  void _handleRemoteCategoriesChanged(List<Category> remoteCategories) {
    if (_currentUserId == null) return;

    final merged = _firestoreSyncService.mergeCategories(_categories, remoteCategories);

    if (merged.length != _categories.length) {
      _categories = List<Category>.from(merged);
      _persistenceService.saveCategories(_categories).catchError((e) {
        AppLogger.error('[EntryRepository] Error saving categories after remote update', error: e);
      });
      _entriesStreamController.add(currentEntries);
      AppLogger.info('[EntryRepository] Updated local categories from remote: ${_categories.length} categories');
    }
  }

  /// Sync a single entry to cloud (called after local save).
  void _syncEntryToCloud(Entry entry) {
    if (_currentUserId == null) return;
    _firestoreSyncService.syncEntry(_currentUserId!, entry).catchError((e) {
      AppLogger.error('[EntryRepository] Error syncing entry to cloud', error: e);
    });
  }

  /// Sync a single category to cloud.
  void _syncCategoryToCloud(Category category) {
    if (_currentUserId == null) return;
    _firestoreSyncService.syncCategory(_currentUserId!, category).catchError((e) {
      AppLogger.error('[EntryRepository] Error syncing category to cloud', error: e);
    });
  }

  /// Delete an entry from cloud.
  void _deleteEntryFromCloud(String entryId) {
    if (_currentUserId == null) return;
    _firestoreSyncService.deleteEntry(_currentUserId!, entryId).catchError((e) {
      AppLogger.error('[EntryRepository] Error deleting entry from cloud', error: e);
    });
  }

  /// Delete a category from cloud.
  void _deleteCategoryFromCloud(String categoryName) {
    if (_currentUserId == null) return;
    _firestoreSyncService.deleteCategory(_currentUserId!, categoryName).catchError((e) {
      AppLogger.error('[EntryRepository] Error deleting category from cloud', error: e);
    });
  }

  // ============================================================================
  // CP: Image Cloud Sync Methods (Phase 3: Firebase Storage)
  // ============================================================================

  /// Upload image for an entry to Firebase Storage.
  /// Updates the entry's cloudImagePath on success.
  Future<void> _uploadImageForEntry(Entry entry) async {
    if (_currentUserId == null) {
      AppLogger.info('[EntryRepository] Skipping image upload - not signed in');
      return;
    }

    if (entry.imagePath == null) {
      AppLogger.info('[EntryRepository] Skipping image upload - no local image');
      return;
    }

    if (entry.cloudImagePath != null) {
      AppLogger.info('[EntryRepository] Skipping image upload - already uploaded');
      return;
    }

    // Get the full local path for the image
    final fullPath = await _imageStorageService.getFullPath(entry.imagePath!);
    final imageFile = File(fullPath);
    if (!await imageFile.exists()) {
      AppLogger.warn('[EntryRepository] Cannot upload - image file does not exist: $fullPath');
      return;
    }

    // CP: Use the entry ID as the UUID for the cloud path
    final cloudPath = await _imageStorageSyncService.uploadImage(imageFile, entry.id);

    if (cloudPath != null) {
      // CP: Transaction safety - validate entry state before updating
      final entryIndex = _entries.indexWhere((e) => e.id == entry.id);
      if (entryIndex == -1) {
        AppLogger.warn('[EntryRepository] Entry deleted during upload, skipping update: ${entry.id}');
        // CP: Delete the orphaned cloud image since entry no longer exists
        _imageStorageSyncService.deleteImage(cloudPath).catchError((e) {
          AppLogger.error('[EntryRepository] Failed to delete orphaned cloud image', error: e);
          _pendingCloudImageDeletions.add(cloudPath);
          return false;
        });
        return;
      }

      final currentEntry = _entries[entryIndex];

      // CP: Check if entry already has a cloudImagePath (another upload succeeded first)
      if (currentEntry.cloudImagePath != null) {
        AppLogger.info('[EntryRepository] Entry already has cloud path, skipping update: ${entry.id}');
        return;
      }

      // CP: Check if the imagePath changed (entry was modified during upload)
      if (currentEntry.imagePath != entry.imagePath) {
        AppLogger.warn('[EntryRepository] Entry imagePath changed during upload, skipping update: ${entry.id}');
        return;
      }

      // Update the entry with the cloud path
      final updatedEntry = currentEntry.copyWith(cloudImagePath: cloudPath);
      _entries[entryIndex] = updatedEntry;
      await _saveEntries(entriesToSync: [updatedEntry]);
      AppLogger.info('[EntryRepository] Image uploaded and entry updated: ${entry.id}');
    } else {
      AppLogger.warn('[EntryRepository] Image upload failed for entry: ${entry.id}');
    }
  }

  /// Upload all local images that don't have cloudImagePath yet.
  /// Called on sign-in and app initialization for already signed-in users.
  Future<void> _uploadPendingImages() async {
    if (_currentUserId == null) {
      return;
    }

    final pendingEntries = _entries.where((e) => e.imagePath != null && e.cloudImagePath == null).toList();

    if (pendingEntries.isEmpty) {
      AppLogger.info('[EntryRepository] No pending images to upload');
      return;
    }

    AppLogger.info('[EntryRepository] Uploading ${pendingEntries.length} pending images');

    for (final entry in pendingEntries) {
      await _uploadImageForEntry(entry);
    }

    AppLogger.info('[EntryRepository] Finished uploading pending images');
  }

  /// CP: Retry deleting cloud images that previously failed.
  /// Called on sign-in to clean up orphaned cloud files.
  Future<void> _retryPendingCloudImageDeletions() async {
    if (_currentUserId == null || _pendingCloudImageDeletions.isEmpty) {
      return;
    }

    final pendingPaths = List<String>.from(_pendingCloudImageDeletions);
    AppLogger.info('[EntryRepository] Retrying ${pendingPaths.length} pending cloud image deletions');

    for (final cloudPath in pendingPaths) {
      final success = await _imageStorageSyncService.deleteImage(cloudPath);
      if (success) {
        _pendingCloudImageDeletions.remove(cloudPath);
        AppLogger.info('[EntryRepository] Successfully deleted orphaned cloud image: $cloudPath');
      } else {
        AppLogger.warn('[EntryRepository] Still unable to delete cloud image: $cloudPath');
      }
    }

    if (_pendingCloudImageDeletions.isEmpty) {
      AppLogger.info('[EntryRepository] All pending cloud image deletions completed');
    } else {
      AppLogger.warn('[EntryRepository] ${_pendingCloudImageDeletions.length} cloud image deletions still pending');
    }
  }

  /// Download a cloud image to local storage if not already cached.
  /// Returns the local image path on success, null on failure.
  Future<String?> downloadCloudImage(Entry entry) async {
    if (entry.cloudImagePath == null) {
      return entry.imagePath;
    }

    // CP: If we already have a valid local file, return it
    // Check both existence AND size > 0 to detect corrupted files
    if (entry.imagePath != null) {
      final fullPath = await _imageStorageService.getFullPath(entry.imagePath!);
      final file = File(fullPath);
      if (await file.exists() && await file.length() > 0) {
        return entry.imagePath;
      }
      // CP: File exists but is empty/corrupted - will re-download from cloud
      if (await file.exists()) {
        AppLogger.warn(
          '[EntryRepository] Local image file corrupted (0 bytes), will re-download: ${entry.imagePath}',
        );
      }
    }

    // Download from cloud
    final localFileName = '${entry.id}.jpg';
    final basePath = await _imageStorageService.getFullPath(localFileName);

    final success = await _imageStorageSyncService.downloadImage(
      entry.cloudImagePath!,
      basePath,
    );

    if (success) {
      // Update entry with local path
      final entryIndex = _entries.indexWhere((e) => e.id == entry.id);
      if (entryIndex != -1) {
        final updatedEntry = _entries[entryIndex].copyWith(imagePath: localFileName);
        _entries[entryIndex] = updatedEntry;
        await _saveEntries();
        AppLogger.info('[EntryRepository] Cloud image downloaded and cached: ${entry.id}');
        return localFileName;
      }
    }

    AppLogger.warn('[EntryRepository] Failed to download cloud image for entry: ${entry.id}');
    return null;
  }

  /// Ensures an entry's cloud image is available locally.
  /// If the entry has a cloudImagePath but no local imagePath, triggers a download.
  /// Returns the local path on success, null if no download needed or on failure.
  Future<String?> ensureImageAvailable(Entry entry) async {
    if (entry.cloudImagePath != null && entry.imagePath == null) {
      return downloadCloudImage(entry);
    }
    return entry.imagePath;
  }

  /// CP: Exports all entries and categories to a JSON string for backup
  String exportToJson() {
    final exportData = {
      'exportDate': DateTime.now().toIso8601String(),
      'entryCount': _entries.length,
      'categoryCount': _categories.length,
      'entries': _entries.map((e) => e.toJson()).toList(),
      'categories': _categories.map((c) => c.toJson()).toList(),
    };
    return jsonEncode(exportData);
  }

  /// CP: Disposes the repository and cancels all pending timers
  void dispose() {
    for (final timer in _syncDebounceTimers.values) {
      timer.cancel();
    }
    _syncDebounceTimers.clear();
    // CP: Stop cloud sync
    _firestoreSyncService.stopListening();
    // CC: Close the stream controller
    _entriesStreamController.close();
    AppLogger.info("[EntryRepository] Disposed and cancelled all pending timers");
  }
}
