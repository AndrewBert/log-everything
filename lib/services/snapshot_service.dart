import 'package:cloud_firestore/cloud_firestore.dart';
import '../entry/entry.dart';
import '../entry/category.dart';
import '../utils/logger.dart';

/// Data class representing a pre-sign-in snapshot.
class Snapshot {
  final String deviceId;
  final List<Entry> entries;
  final List<Category> categories;
  final String? vectorStoreId;
  final Map<String, String> monthlyLogFileIds;
  final DateTime createdAt;
  final DateTime? expiresAt;

  Snapshot({
    required this.deviceId,
    required this.entries,
    required this.categories,
    this.vectorStoreId,
    this.monthlyLogFileIds = const {},
    required this.createdAt,
    this.expiresAt,
  });

  int get entryCount => entries.length;
  int get categoryCount => categories.length;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

/// Service for creating and retrieving pre-sign-in data snapshots.
///
/// Snapshots are stored in Firestore at:
/// ```
/// snapshots/{deviceId}/
///   ├── metadata (document with vectorStoreId, monthlyLogFileIds, timestamps)
///   ├── entries/{entryId} (subcollection)
///   └── categories/{categoryName} (subcollection)
/// ```
abstract class SnapshotService {
  /// Creates a snapshot of the current local data before sign-in.
  Future<void> createSnapshot({
    required String deviceId,
    required List<Entry> entries,
    required List<Category> categories,
    String? vectorStoreId,
    Map<String, String> monthlyLogFileIds,
  });

  /// Fetches an existing snapshot for the device, if one exists.
  Future<Snapshot?> fetchSnapshot(String deviceId);

  /// Deletes a snapshot immediately.
  Future<void> deleteSnapshot(String deviceId);

  /// Schedules a snapshot for deletion after a delay (e.g., 7 days).
  /// The actual deletion happens via the expiresAt field.
  Future<void> scheduleSnapshotDeletion(String deviceId, Duration delay);

  /// Checks if a valid (non-expired) snapshot exists.
  Future<bool> hasValidSnapshot(String deviceId);
}

class FirestoreSnapshotService implements SnapshotService {
  final FirebaseFirestore _firestore;

  FirestoreSnapshotService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _metadataRef(String deviceId) =>
      _firestore.collection('snapshots').doc(deviceId);

  CollectionReference<Map<String, dynamic>> _entriesRef(String deviceId) =>
      _metadataRef(deviceId).collection('entries');

  CollectionReference<Map<String, dynamic>> _categoriesRef(String deviceId) =>
      _metadataRef(deviceId).collection('categories');

  @override
  Future<void> createSnapshot({
    required String deviceId,
    required List<Entry> entries,
    required List<Category> categories,
    String? vectorStoreId,
    Map<String, String> monthlyLogFileIds = const {},
  }) async {
    AppLogger.info('[SnapshotService] Creating snapshot for device: $deviceId');
    AppLogger.info('[SnapshotService] Entries: ${entries.length}, Categories: ${categories.length}');

    try {
      // CP: Delete any existing snapshot first to ensure clean state
      await _deleteSnapshotData(deviceId);

      // CP: Write metadata document
      await _metadataRef(deviceId).set({
        'deviceId': deviceId,
        'vectorStoreId': vectorStoreId,
        'monthlyLogFileIds': monthlyLogFileIds,
        'entryCount': entries.length,
        'categoryCount': categories.length,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': null, // CP: No expiration until sign-in succeeds
      });

      // CP: Write entries in batches (max 500 per batch)
      final syncableEntries = entries.where((e) => e.processingState == null).toList();
      if (syncableEntries.isNotEmpty) {
        final entryBatches = <WriteBatch>[];
        var currentBatch = _firestore.batch();
        var operationCount = 0;

        for (final entry in syncableEntries) {
          currentBatch.set(_entriesRef(deviceId).doc(entry.id), entry.toJson());
          operationCount++;

          if (operationCount >= 500) {
            entryBatches.add(currentBatch);
            currentBatch = _firestore.batch();
            operationCount = 0;
          }
        }

        if (operationCount > 0) {
          entryBatches.add(currentBatch);
        }

        for (final batch in entryBatches) {
          await batch.commit();
        }
      }

      // CP: Write categories (usually small, single batch is fine)
      if (categories.isNotEmpty) {
        final categoryBatch = _firestore.batch();
        for (final category in categories) {
          categoryBatch.set(_categoriesRef(deviceId).doc(category.name), category.toJson());
        }
        await categoryBatch.commit();
      }

      AppLogger.info('[SnapshotService] Snapshot created successfully');
    } catch (e) {
      AppLogger.error('[SnapshotService] Error creating snapshot', error: e);
      rethrow;
    }
  }

  @override
  Future<Snapshot?> fetchSnapshot(String deviceId) async {
    AppLogger.info('[SnapshotService] Fetching snapshot for device: $deviceId');

    try {
      final metadataDoc = await _metadataRef(deviceId).get();

      if (!metadataDoc.exists) {
        AppLogger.info('[SnapshotService] No snapshot found for device: $deviceId');
        return null;
      }

      final metadata = metadataDoc.data()!;

      // CP: Check if snapshot has expired
      final expiresAtTimestamp = metadata['expiresAt'] as Timestamp?;
      if (expiresAtTimestamp != null) {
        final expiresAt = expiresAtTimestamp.toDate();
        if (DateTime.now().isAfter(expiresAt)) {
          AppLogger.info('[SnapshotService] Snapshot has expired, deleting...');
          await deleteSnapshot(deviceId);
          return null;
        }
      }

      // CP: Fetch entries
      final entriesSnapshot = await _entriesRef(deviceId).get();
      final entries = entriesSnapshot.docs.map((doc) {
        try {
          return Entry.fromJson(doc.data());
        } catch (e) {
          AppLogger.error('[SnapshotService] Error parsing entry ${doc.id}', error: e);
          return null;
        }
      }).whereType<Entry>().toList();

      // CP: Fetch categories
      final categoriesSnapshot = await _categoriesRef(deviceId).get();
      final categories = categoriesSnapshot.docs.map((doc) {
        try {
          return Category.fromJson(doc.data());
        } catch (e) {
          AppLogger.error('[SnapshotService] Error parsing category ${doc.id}', error: e);
          return null;
        }
      }).whereType<Category>().toList();

      final createdAtTimestamp = metadata['createdAt'] as Timestamp?;

      final snapshot = Snapshot(
        deviceId: deviceId,
        entries: entries,
        categories: categories,
        vectorStoreId: metadata['vectorStoreId'] as String?,
        monthlyLogFileIds: Map<String, String>.from(metadata['monthlyLogFileIds'] ?? {}),
        createdAt: createdAtTimestamp?.toDate() ?? DateTime.now(),
        expiresAt: expiresAtTimestamp?.toDate(),
      );

      AppLogger.info('[SnapshotService] Fetched snapshot: ${snapshot.entryCount} entries, ${snapshot.categoryCount} categories');
      return snapshot;
    } catch (e) {
      AppLogger.error('[SnapshotService] Error fetching snapshot', error: e);
      return null;
    }
  }

  @override
  Future<void> deleteSnapshot(String deviceId) async {
    AppLogger.info('[SnapshotService] Deleting snapshot for device: $deviceId');

    try {
      await _deleteSnapshotData(deviceId);
      AppLogger.info('[SnapshotService] Snapshot deleted successfully');
    } catch (e) {
      AppLogger.error('[SnapshotService] Error deleting snapshot', error: e);
    }
  }

  Future<void> _deleteSnapshotData(String deviceId) async {
    // CP: Delete entries subcollection
    final entriesSnapshot = await _entriesRef(deviceId).get();
    if (entriesSnapshot.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in entriesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // CP: Delete categories subcollection
    final categoriesSnapshot = await _categoriesRef(deviceId).get();
    if (categoriesSnapshot.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (final doc in categoriesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    // CP: Delete metadata document
    await _metadataRef(deviceId).delete();
  }

  @override
  Future<void> scheduleSnapshotDeletion(String deviceId, Duration delay) async {
    AppLogger.info('[SnapshotService] Scheduling snapshot deletion in ${delay.inDays} days');

    try {
      final expiresAt = DateTime.now().add(delay);
      await _metadataRef(deviceId).update({
        'expiresAt': Timestamp.fromDate(expiresAt),
      });
      AppLogger.info('[SnapshotService] Snapshot scheduled for deletion at: $expiresAt');
    } catch (e) {
      AppLogger.error('[SnapshotService] Error scheduling snapshot deletion', error: e);
    }
  }

  @override
  Future<bool> hasValidSnapshot(String deviceId) async {
    try {
      final metadataDoc = await _metadataRef(deviceId).get();

      if (!metadataDoc.exists) {
        return false;
      }

      final metadata = metadataDoc.data()!;
      final expiresAtTimestamp = metadata['expiresAt'] as Timestamp?;

      if (expiresAtTimestamp != null) {
        final expiresAt = expiresAtTimestamp.toDate();
        if (DateTime.now().isAfter(expiresAt)) {
          return false;
        }
      }

      return true;
    } catch (e) {
      AppLogger.error('[SnapshotService] Error checking for valid snapshot', error: e);
      return false;
    }
  }
}
