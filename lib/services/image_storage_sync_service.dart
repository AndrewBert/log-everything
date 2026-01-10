import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:myapp/settings/services/auth_service.dart';
import 'package:myapp/utils/logger.dart';

/// CP: Service for syncing images to/from Firebase Storage.
/// Handles upload, download, and caching of images in the cloud.
abstract class ImageStorageSyncService {
  /// Uploads an image file to Firebase Storage.
  /// Returns the cloud path (users/{uid}/images/{uuid}.jpg) on success, null on failure.
  Future<String?> uploadImage(File imageFile, String uuid);

  /// Downloads an image from Firebase Storage to local cache.
  /// Returns true on success, false on failure.
  Future<bool> downloadImage(String cloudPath, String localPath);

  /// Deletes an image from Firebase Storage.
  /// Returns true on success, false on failure.
  Future<bool> deleteImage(String cloudPath);

  /// Gets the download URL for a cloud image.
  /// Returns null if not available.
  Future<String?> getDownloadUrl(String cloudPath);
}

/// CP: Firebase Storage implementation of ImageStorageSyncService.
class FirebaseImageStorageSyncService implements ImageStorageSyncService {
  final AuthService _authService;
  final FirebaseStorage _storage;

  // CP: Retry configuration
  static const _maxRetries = 3;
  static const _initialBackoffMs = 500;

  FirebaseImageStorageSyncService({
    required AuthService authService,
    FirebaseStorage? storage,
  })  : _authService = authService,
        _storage = storage ?? FirebaseStorage.instance;

  /// CP: Check if a Firebase error code is retryable (transient network issue)
  bool _isRetryableError(String code) {
    return code == 'unknown' ||
           code == 'canceled' ||
           code == 'retry-limit-exceeded' ||
           code.contains('network') ||
           code.contains('timeout');
  }

  /// CP: Validate cloud path format to prevent path traversal attacks.
  /// Path must exactly match: users/{uid}/images/{filename}.jpg
  bool _isValidCloudPath(String cloudPath, String uid) {
    // Check prefix
    if (!cloudPath.startsWith('users/$uid/images/')) {
      return false;
    }
    // Validate full path structure with regex (no path traversal like ../)
    final pathPattern = RegExp(r'^users/[^/]+/images/[a-zA-Z0-9_-]+\.jpg$');
    return pathPattern.hasMatch(cloudPath);
  }

  @override
  Future<String?> uploadImage(File imageFile, String uuid) async {
    final user = _authService.currentUser;
    if (user == null) {
      AppLogger.warn('[ImageStorageSyncService] Cannot upload - user not signed in');
      return null;
    }

    if (!await imageFile.exists()) {
      AppLogger.warn('[ImageStorageSyncService] Cannot upload - file does not exist: ${imageFile.path}');
      return null;
    }

    // CP: Validate UUID format to prevent path injection
    final uuidPattern = RegExp(r'^[a-zA-Z0-9_-]+$');
    if (!uuidPattern.hasMatch(uuid)) {
      AppLogger.warn('[ImageStorageSyncService] Invalid UUID format: $uuid');
      return null;
    }

    final cloudPath = 'users/${user.uid}/images/$uuid.jpg';
    final ref = _storage.ref().child(cloudPath);

    // CP: Upload with metadata for content type
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'uploadedAt': DateTime.now().toIso8601String(),
        'uuid': uuid,
      },
    );

    // CP: Retry with exponential backoff for transient errors
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        if (attempt == 0) {
          AppLogger.info('[ImageStorageSyncService] Uploading image to $cloudPath');
        } else {
          AppLogger.info('[ImageStorageSyncService] Retry attempt ${attempt + 1}/$_maxRetries for $cloudPath');
        }

        await ref.putFile(imageFile, metadata);
        AppLogger.info('[ImageStorageSyncService] Successfully uploaded image to $cloudPath');
        return cloudPath;
      } on FirebaseException catch (e) {
        if (_isRetryableError(e.code) && attempt < _maxRetries - 1) {
          final backoffMs = _initialBackoffMs * (1 << attempt); // Exponential backoff
          AppLogger.warn('[ImageStorageSyncService] Transient error (${e.code}), retrying in ${backoffMs}ms');
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
        AppLogger.error('[ImageStorageSyncService] Firebase error uploading image: ${e.code} - ${e.message}');
        return null;
      } catch (e) {
        AppLogger.error('[ImageStorageSyncService] Error uploading image: $e');
        return null;
      }
    }
    return null;
  }

  @override
  Future<bool> downloadImage(String cloudPath, String localPath) async {
    final user = _authService.currentUser;
    if (user == null) {
      AppLogger.warn('[ImageStorageSyncService] Cannot download - user not signed in');
      return false;
    }

    // CP: Strict path validation to prevent path traversal
    if (!_isValidCloudPath(cloudPath, user.uid)) {
      AppLogger.warn('[ImageStorageSyncService] Cannot download - invalid path format: $cloudPath');
      return false;
    }

    final ref = _storage.ref().child(cloudPath);
    final localFile = File(localPath);

    // CP: Ensure parent directory exists
    final parentDir = localFile.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    // CP: Retry with exponential backoff for transient errors
    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        if (attempt == 0) {
          AppLogger.info('[ImageStorageSyncService] Downloading image from $cloudPath');
        } else {
          AppLogger.info('[ImageStorageSyncService] Retry attempt ${attempt + 1}/$_maxRetries for download');
        }

        await ref.writeToFile(localFile);
        AppLogger.info('[ImageStorageSyncService] Successfully downloaded image to $localPath');
        return true;
      } on FirebaseException catch (e) {
        if (_isRetryableError(e.code) && attempt < _maxRetries - 1) {
          final backoffMs = _initialBackoffMs * (1 << attempt);
          AppLogger.warn('[ImageStorageSyncService] Transient error (${e.code}), retrying in ${backoffMs}ms');
          await Future.delayed(Duration(milliseconds: backoffMs));
          continue;
        }
        AppLogger.error('[ImageStorageSyncService] Firebase error downloading image: ${e.code} - ${e.message}');
        return false;
      } catch (e) {
        AppLogger.error('[ImageStorageSyncService] Error downloading image: $e');
        return false;
      }
    }
    return false;
  }

  @override
  Future<bool> deleteImage(String cloudPath) async {
    final user = _authService.currentUser;
    if (user == null) {
      AppLogger.warn('[ImageStorageSyncService] Cannot delete - user not signed in');
      return false;
    }

    // CP: Strict path validation to prevent path traversal
    if (!_isValidCloudPath(cloudPath, user.uid)) {
      AppLogger.warn('[ImageStorageSyncService] Cannot delete - invalid path format: $cloudPath');
      return false;
    }

    final ref = _storage.ref().child(cloudPath);

    try {
      AppLogger.info('[ImageStorageSyncService] Deleting image at $cloudPath');
      await ref.delete();
      AppLogger.info('[ImageStorageSyncService] Successfully deleted image at $cloudPath');
      return true;
    } on FirebaseException catch (e) {
      // CP: Object not found is not an error - it's already deleted
      if (e.code == 'object-not-found') {
        AppLogger.info('[ImageStorageSyncService] Image already deleted at $cloudPath');
        return true;
      }
      AppLogger.error('[ImageStorageSyncService] Firebase error deleting image: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      AppLogger.error('[ImageStorageSyncService] Error deleting image: $e');
      return false;
    }
  }

  @override
  Future<String?> getDownloadUrl(String cloudPath) async {
    final user = _authService.currentUser;
    if (user == null) {
      return null;
    }

    // CP: Strict path validation to prevent path traversal
    if (!_isValidCloudPath(cloudPath, user.uid)) {
      return null;
    }

    try {
      final ref = _storage.ref().child(cloudPath);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      AppLogger.error('[ImageStorageSyncService] Firebase error getting download URL: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      AppLogger.error('[ImageStorageSyncService] Error getting download URL: $e');
      return null;
    }
  }
}
