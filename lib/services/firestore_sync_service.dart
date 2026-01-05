import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../entry/entry.dart';
import '../entry/category.dart';
import '../utils/logger.dart';

/// Service for syncing entries and categories to/from Cloud Firestore.
///
/// Data structure:
/// users/{uid}/entries/{entryId} -> Entry JSON
/// users/{uid}/categories/{categoryName} -> Category JSON
class FirestoreSyncService {
  // CP: Sanitize cloud entry by clearing transient state flags.
  // isGeneratingInsight and processingState should never persist - they're runtime state only.
  // If processingState is non-null, the entry was synced mid-processing and needs cleanup.
  Entry _sanitizeCloudEntry(Entry entry) {
    bool needsSanitization = false;
    final hasIncompleteProcessing = entry.processingState != null;

    if (entry.isGeneratingInsight) {
      AppLogger.info('[FirestoreSyncService] Sanitizing entry ${entry.id}: clearing isGeneratingInsight=true');
      needsSanitization = true;
    }

    if (hasIncompleteProcessing) {
      AppLogger.info('[FirestoreSyncService] Sanitizing entry ${entry.id}: incomplete processingState=${entry.processingState}, assigning to Misc');
      needsSanitization = true;
    }

    if (needsSanitization) {
      return entry.copyWith(
        isGeneratingInsight: false,
        category: hasIncompleteProcessing ? 'Misc' : null,
        clearProcessingState: true,
      );
    }
    return entry;
  }

  final FirebaseFirestore _firestore;
  StreamSubscription<QuerySnapshot>? _entriesSubscription;
  StreamSubscription<QuerySnapshot>? _categoriesSubscription;

  // CP: Callback for when remote entries change
  void Function(List<Entry>)? onRemoteEntriesChanged;
  void Function(List<Category>)? onRemoteCategoriesChanged;

  FirestoreSyncService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // CP: Get user's entries collection reference
  CollectionReference<Map<String, dynamic>> _entriesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('entries');

  // CP: Get user's categories collection reference
  CollectionReference<Map<String, dynamic>> _categoriesRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('categories');

  /// Start listening to real-time changes from Firestore for a user.
  void startListening(String uid) {
    AppLogger.info('[FirestoreSyncService] Starting real-time listeners for user: $uid');

    // CP: Listen to entries changes
    _entriesSubscription = _entriesRef(uid).snapshots().listen(
      (snapshot) {
        final entries = snapshot.docs.map((doc) {
          try {
            final entry = Entry.fromJson(doc.data());
            return _sanitizeCloudEntry(entry);
          } catch (e) {
            AppLogger.error('[FirestoreSyncService] Error parsing entry ${doc.id}', error: e);
            return null;
          }
        }).whereType<Entry>().toList();

        AppLogger.info('[FirestoreSyncService] Received ${entries.length} entries from cloud');
        onRemoteEntriesChanged?.call(entries);
      },
      onError: (e) {
        AppLogger.error('[FirestoreSyncService] Entries listener error', error: e);
      },
    );

    // CP: Listen to categories changes
    _categoriesSubscription = _categoriesRef(uid).snapshots().listen(
      (snapshot) {
        final categories = snapshot.docs.map((doc) {
          try {
            return Category.fromJson(doc.data());
          } catch (e) {
            AppLogger.error('[FirestoreSyncService] Error parsing category ${doc.id}', error: e);
            return null;
          }
        }).whereType<Category>().toList();

        AppLogger.info('[FirestoreSyncService] Received ${categories.length} categories from cloud');
        onRemoteCategoriesChanged?.call(categories);
      },
      onError: (e) {
        AppLogger.error('[FirestoreSyncService] Categories listener error', error: e);
      },
    );
  }

  /// Stop listening to Firestore changes.
  void stopListening() {
    AppLogger.info('[FirestoreSyncService] Stopping real-time listeners');
    _entriesSubscription?.cancel();
    _entriesSubscription = null;
    _categoriesSubscription?.cancel();
    _categoriesSubscription = null;
  }

  /// Fetch all entries from Firestore for a user (one-time fetch).
  Future<List<Entry>> fetchEntries(String uid) async {
    try {
      final snapshot = await _entriesRef(uid).get();
      final entries = snapshot.docs.map((doc) {
        try {
          final entry = Entry.fromJson(doc.data());
          return _sanitizeCloudEntry(entry);
        } catch (e) {
          AppLogger.error('[FirestoreSyncService] Error parsing entry ${doc.id}', error: e);
          return null;
        }
      }).whereType<Entry>().toList();

      AppLogger.info('[FirestoreSyncService] Fetched ${entries.length} entries for user $uid');
      return entries;
    } catch (e) {
      AppLogger.error('[FirestoreSyncService] Error fetching entries', error: e);
      return [];
    }
  }

  /// Fetch all categories from Firestore for a user (one-time fetch).
  Future<List<Category>> fetchCategories(String uid) async {
    try {
      final snapshot = await _categoriesRef(uid).get();
      final categories = snapshot.docs.map((doc) {
        try {
          return Category.fromJson(doc.data());
        } catch (e) {
          AppLogger.error('[FirestoreSyncService] Error parsing category ${doc.id}', error: e);
          return null;
        }
      }).whereType<Category>().toList();

      AppLogger.info('[FirestoreSyncService] Fetched ${categories.length} categories for user $uid');
      return categories;
    } catch (e) {
      AppLogger.error('[FirestoreSyncService] Error fetching categories', error: e);
      return [];
    }
  }

  /// Sync a single entry to Firestore (upsert).
  Future<void> syncEntry(String uid, Entry entry) async {
    // CP: Skip image entries for Phase 2
    if (entry.imagePath != null) {
      AppLogger.info('[FirestoreSyncService] Skipping image entry ${entry.id} (Phase 2)');
      return;
    }

    // CP: Skip entries still being processed - they shouldn't be synced until complete
    if (entry.processingState != null) {
      AppLogger.info('[FirestoreSyncService] Skipping incomplete entry ${entry.id}: processingState=${entry.processingState}');
      return;
    }

    try {
      await _entriesRef(uid).doc(entry.id).set(entry.toJson());
      AppLogger.info('[FirestoreSyncService] Synced entry ${entry.id}');
    } catch (e) {
      AppLogger.error('[FirestoreSyncService] Error syncing entry ${entry.id}', error: e);
      // CP: Don't throw - sync failures shouldn't break the app
    }
  }

  /// Delete an entry from Firestore.
  Future<void> deleteEntry(String uid, String entryId) async {
    try {
      await _entriesRef(uid).doc(entryId).delete();
      AppLogger.info('[FirestoreSyncService] Deleted entry $entryId from cloud');
    } catch (e) {
      AppLogger.error('[FirestoreSyncService] Error deleting entry $entryId', error: e);
    }
  }

  /// Sync a single category to Firestore (upsert).
  Future<void> syncCategory(String uid, Category category) async {
    try {
      // CP: Use category name as document ID for easy lookup
      await _categoriesRef(uid).doc(category.name).set(category.toJson());
      AppLogger.info('[FirestoreSyncService] Synced category ${category.name}');
    } catch (e) {
      AppLogger.error('[FirestoreSyncService] Error syncing category ${category.name}', error: e);
    }
  }

  /// Delete a category from Firestore.
  Future<void> deleteCategory(String uid, String categoryName) async {
    try {
      await _categoriesRef(uid).doc(categoryName).delete();
      AppLogger.info('[FirestoreSyncService] Deleted category $categoryName from cloud');
    } catch (e) {
      AppLogger.error('[FirestoreSyncService] Error deleting category $categoryName', error: e);
    }
  }

  /// Bulk sync all entries to Firestore (for initial upload after sign-in).
  Future<void> syncAllEntries(String uid, List<Entry> entries) async {
    // CP: Filter out image entries (Phase 2) and incomplete entries (still processing)
    final syncableEntries = entries.where((e) =>
      e.imagePath == null && e.processingState == null
    ).toList();

    if (syncableEntries.isEmpty) {
      AppLogger.info('[FirestoreSyncService] No entries to sync');
      return;
    }

    try {
      // CP: Use batched writes for efficiency (max 500 per batch)
      final batches = <WriteBatch>[];
      var currentBatch = _firestore.batch();
      var operationCount = 0;

      for (final entry in syncableEntries) {
        currentBatch.set(_entriesRef(uid).doc(entry.id), entry.toJson());
        operationCount++;

        if (operationCount >= 500) {
          batches.add(currentBatch);
          currentBatch = _firestore.batch();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        batches.add(currentBatch);
      }

      for (final batch in batches) {
        await batch.commit();
      }

      AppLogger.info('[FirestoreSyncService] Bulk synced ${syncableEntries.length} entries');
    } catch (e) {
      AppLogger.error('[FirestoreSyncService] Error bulk syncing entries', error: e);
    }
  }

  /// Bulk sync all categories to Firestore.
  Future<void> syncAllCategories(String uid, List<Category> categories) async {
    if (categories.isEmpty) {
      AppLogger.info('[FirestoreSyncService] No categories to sync');
      return;
    }

    try {
      final batch = _firestore.batch();

      for (final category in categories) {
        batch.set(_categoriesRef(uid).doc(category.name), category.toJson());
      }

      await batch.commit();
      AppLogger.info('[FirestoreSyncService] Bulk synced ${categories.length} categories');
    } catch (e) {
      AppLogger.error('[FirestoreSyncService] Error bulk syncing categories', error: e);
    }
  }

  /// Merge local and cloud entries by ID.
  /// Returns the merged list with cloud entries taking precedence for conflicts.
  List<Entry> mergeEntries(List<Entry> localEntries, List<Entry> cloudEntries) {
    final mergedMap = <String, Entry>{};

    // CP: Add all local entries first
    for (final entry in localEntries) {
      mergedMap[entry.id] = entry;
    }

    // CP: Cloud entries overwrite local entries with same ID
    // This handles the case where an entry was modified on another device
    for (final entry in cloudEntries) {
      mergedMap[entry.id] = entry;
    }

    final merged = mergedMap.values.toList();
    // CP: Sort by timestamp descending (newest first)
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    AppLogger.info(
      '[FirestoreSyncService] Merged ${localEntries.length} local + ${cloudEntries.length} cloud = ${merged.length} entries'
    );

    return merged;
  }

  /// Merge local and cloud categories by name.
  List<Category> mergeCategories(List<Category> localCategories, List<Category> cloudCategories) {
    final mergedMap = <String, Category>{};

    // CP: Add all local categories first
    for (final category in localCategories) {
      mergedMap[category.name] = category;
    }

    // CP: Cloud categories overwrite local with same name
    for (final category in cloudCategories) {
      mergedMap[category.name] = category;
    }

    AppLogger.info(
      '[FirestoreSyncService] Merged ${localCategories.length} local + ${cloudCategories.length} cloud = ${mergedMap.length} categories'
    );

    return mergedMap.values.toList();
  }
}
