import 'dart:convert';
import 'dart:async'; // CP: Added for Completer
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // CP: Added back for DateFormat
import 'package:myapp/entry/entry.dart'; // CP: Added import for Entry
import 'package:myapp/services/entry_persistence_service.dart'; // CP: Added import for EntryPersistenceService
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

// CP: Define SharedPreferences keys for backfill state
const String _backfillLastSuccessfulDateKey = 'vector_store_backfill_last_successful_date';
const String _fullBackfillRunAttemptedKey = 'vector_store_full_backfill_run_attempted';

// CP: Define the base URL for OpenAI API
const String _openAIBaseUrl = 'https://api.openai.com/v1';

// CP: Define SharedPreferences key for storing monthly log file IDs
const String _monthlyLogFileIdsKey = 'vector_store_monthly_log_file_ids';

// CP: Custom Exception for Vector Store API errors
class VectorStoreApiException implements Exception {
  final String message;
  final dynamic underlyingError;
  final String? responseBody;

  VectorStoreApiException(this.message, {this.underlyingError, this.responseBody});

  @override
  String toString() {
    String errorDetails = message;
    if (underlyingError != null) {
      errorDetails += '\nUnderlying error: $underlyingError';
    }
    if (responseBody != null) {
      errorDetails += '\nResponse body: $responseBody';
    }
    return 'VectorStoreApiException: $errorDetails';
  }
}

// CP: Custom Exception for Vector Store synchronization errors
class VectorStoreSyncException implements Exception {
  final String message;
  final dynamic underlyingError;

  VectorStoreSyncException(this.message, {this.underlyingError});

  @override
  String toString() {
    return 'VectorStoreSyncException: $message${underlyingError != null ? '\nUnderlying error: $underlyingError' : ''}';
  }
}

class VectorStoreService {
  final SharedPreferences _prefs;
  final http.Client _httpClient;
  final String _apiKey;
  final EntryPersistenceService _entryPersistenceService;
  // CP: Add lock map to prevent concurrent syncs of the same month
  final Map<String, Future<void>> _monthSyncLocks = {};

  static const String _vectorStoreIdKey = 'openai_vector_store_id';

  VectorStoreService({
    required SharedPreferences sharedPreferences,
    required http.Client httpClient,
    required String apiKey,
    required EntryPersistenceService entryPersistenceService, // CP: Added to constructor
  }) : _prefs = sharedPreferences,
       _httpClient = httpClient,
       _apiKey = apiKey,
       _entryPersistenceService = entryPersistenceService; // CP: Initialize field

  Future<String?> getOrCreateVectorStoreId() async {
    String? vectorStoreId = _prefs.getString(_vectorStoreIdKey);

    if (vectorStoreId == null || vectorStoreId.isEmpty) {
      try {
        // CP: Generate a more unique name for the vector store
        final String uniqueSuffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
        final String vectorStoreName = 'LogEverythingApp_User_$uniqueSuffix';

        final response = await _httpClient.post(
          Uri.parse('$_openAIBaseUrl/vector_stores'), // CP: Use _openAIBaseUrl
          headers: _getHeaders(),
          body: jsonEncode({'name': vectorStoreName}),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseBody = jsonDecode(response.body);
          final String? createdId = responseBody['id'] as String?;
          if (createdId == null || createdId.isEmpty) {
            throw VectorStoreApiException(
              'Failed to create vector store: ID missing in response.',
              responseBody: response.body,
            );
          }
          vectorStoreId = createdId;
          await _prefs.setString(_vectorStoreIdKey, vectorStoreId);
        } else {
          AppLogger.error(
            '[VectorStoreService] Failed to create vector store. Status: ${response.statusCode}, Body: ${response.body}',
          );
          throw VectorStoreApiException(
            'Failed to create vector store. Status: ${response.statusCode}',
            responseBody: response.body,
          );
        }
      } catch (e, stackTrace) {
        AppLogger.error('[VectorStoreService] Error creating vector store: $e', error: e, stackTrace: stackTrace);
        if (e is VectorStoreApiException) rethrow;
        throw VectorStoreApiException('Error creating vector store: $e', underlyingError: e);
      }
    } else {
    }
    return vectorStoreId;
  }

  Future<Map<String, String>> _getMonthlyLogFileIds() async {
    // CP: Add retry logic for SharedPreferences reads to handle potential corruption
    for (int attempt = 0; attempt < 3; attempt++) {
      final String? jsonString = _prefs.getString(
        _monthlyLogFileIdsKey, // CP: Use new monthly key
      );
      if (jsonString != null && jsonString.isNotEmpty) {
        try {
          final decoded = Map<String, String>.from(jsonDecode(jsonString) as Map);
          return decoded;
        } catch (e) {
          AppLogger.error(
            '[VectorStoreService] Error decoding monthly_log_file_ids from JSON (attempt ${attempt + 1}): $e', // CP: Updated log
          );
          if (attempt == 2) {
            // CP: On final attempt, clear corrupted data and return empty map
              await _prefs.remove(_monthlyLogFileIdsKey);
            return {};
          }
          // CP: Wait a bit before retrying
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } else {
        return {};
      }
    }
    return {};
  }

  Future<void> _saveMonthlyLogFileIds(Map<String, String> ids) async {
    // CP: Add atomic save operation with verification
    final jsonString = jsonEncode(ids);
    try {
      await _prefs.setString(
        _monthlyLogFileIdsKey, // CP: Use new monthly key
        jsonString,
      );

      // CP: Verify the save was successful by reading back
      final savedJson = _prefs.getString(_monthlyLogFileIdsKey);
      if (savedJson != jsonString) {
        throw VectorStoreSyncException('SharedPreferences save verification failed - data corruption detected');
      }

    } catch (e) {
      AppLogger.error(
        '[VectorStoreService] Error saving monthly_log_file_ids to SharedPreferences: $e', // CP: Updated log
      );
      throw VectorStoreSyncException(
        'Failed to save monthly log file IDs to SharedPreferences', // CP: Updated message
        underlyingError: e,
      );
    }
  }

  Future<String> _uploadLogContentToOpenAIFile(String fileName, String content) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_openAIBaseUrl/files'));
      request.headers.addAll(_getHeaders(isJsonContent: false));
      request.fields['purpose'] = 'assistants';
      request.files.add(http.MultipartFile.fromString('file', content, filename: fileName));

      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        final fileId = responseBody['id'] as String?;
        if (fileId == null || fileId.isEmpty) {
          throw VectorStoreApiException('Failed to upload file: ID missing in response.', responseBody: response.body);
        }
        return fileId;
      } else {
        AppLogger.error(
          '[VectorStoreService] Failed to upload file "$fileName". Status: ${response.statusCode}, Body: ${response.body}',
        );
        throw VectorStoreApiException(
          'Failed to upload file "$fileName". Status: ${response.statusCode}',
          responseBody: response.body,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('[VectorStoreService] Error uploading file "$fileName": $e', error: e, stackTrace: stackTrace);
      if (e is VectorStoreApiException) rethrow;
      throw VectorStoreApiException('Error uploading file "$fileName": $e', underlyingError: e);
    }
  }

  Future<void> _addFileToVectorStore(
    String vectorStoreId,
    String fileId, {
    List<Entry>? entries,
    DateTime? monthDate,
  }) async {
    try {
      // CP: Calculate metadata if we have entries
      Map<String, dynamic>? attributes;
      if (entries != null && entries.isNotEmpty && monthDate != null) {
        attributes = _calculateMonthlyMetadata(entries, monthDate);
      }

      final Map<String, dynamic> body = {'file_id': fileId};
      if (attributes != null) {
        body['attributes'] = attributes;
      }

      final response = await _httpClient.post(
        Uri.parse('$_openAIBaseUrl/vector_stores/$vectorStoreId/files'), // CP: Use _openAIBaseUrl
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        final addedFileId = responseBody['id'] as String?;
        // CC: Status field exists in response but not currently used

        if (addedFileId != fileId) {
          AppLogger.warn('[VectorStoreService] Added file ID $addedFileId does not match expected $fileId.');
        }

        // CP: Polling for file processing completion
        int pollCount = 0;
        const maxPolls = 30; // CP: Poll for a maximum of ~5 minutes (30 * 10s)
        const pollInterval = Duration(seconds: 10);

        while (pollCount < maxPolls) {
          pollCount++;
          await Future.delayed(pollInterval);

          final pollResponse = await _httpClient.get(
            Uri.parse(
              '$_openAIBaseUrl/vector_stores/$vectorStoreId/files/$fileId', // CP: Use _openAIBaseUrl
            ),
            headers: _getHeaders(),
          );

          if (pollResponse.statusCode == 200) {
            final pollBody = jsonDecode(pollResponse.body);
            final fileStatus = pollBody['status'] as String?;
            if (fileStatus == 'completed') {
              return; // CP: Success
            } else if (fileStatus == 'failed' || fileStatus == 'cancelled') {
              AppLogger.error(
                '[VectorStoreService] File "$fileId" processing failed or was cancelled in vector store "$vectorStoreId". Status: $fileStatus',
              );
              throw VectorStoreApiException(
                'File processing failed or was cancelled. Status: $fileStatus',
                responseBody: pollBody.toString(), // CP: stringify body
              );
            }
            // CP: Other statuses like 'in_progress' mean continue polling.
          } else {
            AppLogger.warn(
              '[VectorStoreService] Polling file "$fileId" failed. Status: ${pollResponse.statusCode}, Body: ${pollResponse.body}. Retrying.',
            );
            // CP: Optionally, implement more robust retry logic for network errors during polling
          }
        }
        AppLogger.error(
          '[VectorStoreService] File "$fileId" processing timed out after $maxPolls attempts in vector store "$vectorStoreId".',
        );
        throw VectorStoreApiException('File processing timed out in vector store.');
      } else {
        AppLogger.error(
          '[VectorStoreService] Failed to add file "$fileId" to vector store "$vectorStoreId". Status: ${response.statusCode}, Body: ${response.body}',
        );
        throw VectorStoreApiException(
          'Failed to add file to vector store. Status: ${response.statusCode}',
          responseBody: response.body,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        '[VectorStoreService] Error adding file "$fileId" to vector store "$vectorStoreId": $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is VectorStoreApiException) rethrow;
      throw VectorStoreApiException('Error adding file to vector store: $e', underlyingError: e);
    }
  }

  Future<void> _deleteOpenAIFile(String fileId) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('$_openAIBaseUrl/files/$fileId'), // CP: Use _openAIBaseUrl
        headers: _getHeaders(isJsonContent: false),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['deleted'] == true) {
        } else {
          AppLogger.warn(
            '[VectorStoreService] OpenAI file "$fileId" deletion response did not confirm deletion: ${response.body}',
          );
          // CP: Consider if this should be an exception based on strictness
        }
      } else if (response.statusCode == 404) {
        AppLogger.warn(
          '[VectorStoreService] OpenAI file "$fileId" not found for deletion (404). Assuming already deleted.',
        );
      } else {
        AppLogger.error(
          '[VectorStoreService] Failed to delete OpenAI file "$fileId". Status: ${response.statusCode}, Body: ${response.body}',
        );
        throw VectorStoreApiException(
          'Failed to delete OpenAI file. Status: ${response.statusCode}',
          responseBody: response.body,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        '[VectorStoreService] Error deleting OpenAI file "$fileId": $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is VectorStoreApiException) rethrow;
      throw VectorStoreApiException('Error deleting OpenAI file: $e', underlyingError: e);
    }
  }

  Future<void> _deleteFileFromVectorStore(String vectorStoreId, String fileId) async {
    try {
      final response = await _httpClient.delete(
        Uri.parse('$_openAIBaseUrl/vector_stores/$vectorStoreId/files/$fileId'), // CP: Use _openAIBaseUrl
        headers: _getHeaders(isJsonContent: false),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['deleted'] == true) {
        } else {
          AppLogger.warn(
            '[VectorStoreService] File "$fileId" deletion from vector store "$vectorStoreId" response did not confirm deletion: ${response.body}',
          );
          // CP: Consider if this should be an exception
        }
      } else if (response.statusCode == 404) {
        AppLogger.warn(
          '[VectorStoreService] File "$fileId" not found in vector store "$vectorStoreId" for deletion (404). Assuming already deleted or never added.',
        );
      } else {
        AppLogger.error(
          '[VectorStoreService] Failed to delete file "$fileId" from vector store "$vectorStoreId". Status: ${response.statusCode}, Body: ${response.body}',
        );
        throw VectorStoreApiException(
          'Failed to delete file from vector store. Status: ${response.statusCode}',
          responseBody: response.body,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        '[VectorStoreService] Error deleting file "$fileId" from vector store "$vectorStoreId": $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is VectorStoreApiException) rethrow;
      throw VectorStoreApiException('Error deleting file from vector store: $e', underlyingError: e);
    }
  }

  // CP: Method to acquire sync lock for a month with improved cleanup
  Future<T> _withMonthSyncLock<T>(String monthKey, Future<T> Function() action) async {
    // CP: Use a persistent lock mechanism via SharedPreferences to prevent
    // CP: concurrent operations across app restarts/multiple instances
    final lockKey = 'vector_store_sync_lock_$monthKey';
    final lockTimestamp = _prefs.getInt(lockKey);
    final now = DateTime.now().millisecondsSinceEpoch;

    // CP: If lock exists and is less than 10 minutes old, wait
    if (lockTimestamp != null && (now - lockTimestamp) < 600000) {
      // CP: Wait a bit and check again
      await Future.delayed(const Duration(seconds: 2));
      // CP: Recursive call to check lock again
      return _withMonthSyncLock(monthKey, action);
    }

    // Wait for any existing in-memory sync to complete
    while (_monthSyncLocks.containsKey(monthKey)) {
      try {
        await _monthSyncLocks[monthKey];
      } catch (_) {
        // Previous sync failed, but we still want to continue with new sync
      }
    }

    // CP: Set persistent lock
    await _prefs.setInt(lockKey, now);

    // Create new sync future
    final completer = Completer<void>();
    _monthSyncLocks[monthKey] = completer.future;

    try {
      final result = await action();
      completer.complete();
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _monthSyncLocks.remove(monthKey);
      // CP: Clear persistent lock
      await _prefs.remove(lockKey);
    }
  }

  // CP: Renamed from synchronizeDailyLogFile and updated for monthly aggregation
  Future<void> synchronizeMonthlyLogFile(String vectorStoreId, DateTime date, String formattedMonthlyLogContent) async {
    final monthKey = _formatMonthKeyForStorage(date);
    final fileName = "logs_$monthKey.txt";

    return _withMonthSyncLock(monthKey, () async {

      Map<String, String> monthlyLogFileIds = await _getMonthlyLogFileIds();
      final String? existingFileId = monthlyLogFileIds[monthKey];

      if (existingFileId != null) {
        try {
          await _deleteFileFromVectorStore(vectorStoreId, existingFileId);
        } catch (e) {
          AppLogger.warn(
            '[VectorStoreService] Error deleting file $existingFileId from vector store $vectorStoreId during sync: $e. Will attempt to delete OpenAI file anyway.',
          );
        }
        try {
          await _deleteOpenAIFile(existingFileId);
        } catch (e) {
          AppLogger.warn(
            '[VectorStoreService] Error deleting OpenAI file $existingFileId during sync: $e. Proceeding with upload of new file.',
          );
        }
      }

      if (formattedMonthlyLogContent.isEmpty) {
        if (existingFileId != null) {
          monthlyLogFileIds.remove(monthKey); // CP: Use monthKey
          await _saveMonthlyLogFileIds(monthlyLogFileIds);
        }
        return;
      }

      String newFileId;
      try {
        newFileId = await _uploadLogContentToOpenAIFile(fileName, formattedMonthlyLogContent);
      } catch (e, stackTrace) {
        AppLogger.error(
          '[VectorStoreService] Failed to upload log content for $monthKey to OpenAI.',
          error: e,
          stackTrace: stackTrace,
        );
        throw VectorStoreSyncException('Failed to upload log content for $monthKey', underlyingError: e);
      }

      try {
        // Get entries for metadata
        final List<Entry> allEntries = await _entryPersistenceService.loadEntries();
        final List<Entry> monthEntries =
            allEntries.where((e) {
              return e.timestamp.year == date.year && e.timestamp.month == date.month;
            }).toList();
        await _addFileToVectorStore(vectorStoreId, newFileId, entries: monthEntries, monthDate: date);
      } catch (e, stackTrace) {
        AppLogger.error(
          '[VectorStoreService] Failed to add file $newFileId for $monthKey to vector store $vectorStoreId.',
          error: e,
          stackTrace: stackTrace,
        );
        try {
          AppLogger.warn(
            '[VectorStoreService] Attempting to delete orphaned OpenAI file $newFileId after vector store add failure.',
          );
          await _deleteOpenAIFile(newFileId);
        } catch (cleanupError) {
          AppLogger.error(
            '[VectorStoreService] Failed to delete orphaned OpenAI file $newFileId during cleanup.',
            error: cleanupError,
          );
        }
        throw VectorStoreSyncException(
          'Failed to add file $newFileId for $monthKey to vector store',
          underlyingError: e,
        );
      }

      monthlyLogFileIds[monthKey] = newFileId; // CP: Use monthKey
      await _saveMonthlyLogFileIds(monthlyLogFileIds);
    });
  }

  // CP: New method to perform initial backfill of historical logs.
  Future<void> performInitialBackfillIfNeeded() async {

    final bool fullRunPreviouslyAttempted = _prefs.getBool(_fullBackfillRunAttemptedKey) ?? false;

    if (fullRunPreviouslyAttempted) {
      return;
    }

    String? currentVectorStoreId;

    try {
      currentVectorStoreId = await getOrCreateVectorStoreId();
      if (currentVectorStoreId == null || currentVectorStoreId.isEmpty) {
        AppLogger.error("[VectorStoreService] Backfill: Could not obtain Vector Store ID. Aborting backfill.");
        return;
      }

      final List<Entry> allEntries = await _entryPersistenceService.loadEntries();

      if (allEntries.isEmpty) {
        await _prefs.setBool(_fullBackfillRunAttemptedKey, true);
        return;
      }

      // CP: Group entries by month (first day of the month as key)
      final Map<DateTime, List<Entry>> entriesByMonth = {};
      for (final entry in allEntries) {
        final monthKeyDate = DateTime(
          entry.timestamp.year,
          entry.timestamp.month,
          1, // CP: Use first day of the month for grouping
        );
        if (entriesByMonth.containsKey(monthKeyDate)) {
          entriesByMonth[monthKeyDate]!.add(entry);
        } else {
          entriesByMonth[monthKeyDate] = [entry];
        }
      }

      final List<DateTime> sortedMonths = entriesByMonth.keys.toList();
      // CP: Sort months ascending to process oldest first
      sortedMonths.sort((a, b) => a.compareTo(b));

      final String? lastSuccessfulDateString = _prefs.getString(_backfillLastSuccessfulDateKey);
      DateTime? lastSuccessfulBackfillMonth; // CP: Renamed for clarity
      if (lastSuccessfulDateString != null) {
        try {
          lastSuccessfulBackfillMonth = DateTime.parse(lastSuccessfulDateString);
          // CP: Ensure it's the first of the month for consistent comparison
          lastSuccessfulBackfillMonth = DateTime(
            lastSuccessfulBackfillMonth.year,
            lastSuccessfulBackfillMonth.month,
            1,
          );
        } catch (e) {
          AppLogger.warn(
            "[VectorStoreService] Backfill: Could not parse last successful backfill month: $lastSuccessfulDateString. Processing all discovered historical logs.",
          );
        }
      }

      final List<DateTime> monthsToProcess =
          sortedMonths.where((monthDate) {
            if (lastSuccessfulBackfillMonth == null) {
              return true; // CP: Process all if no last successful date
            }
            // CP: Process if current month is after the last successfully backfilled month
            return monthDate.isAfter(lastSuccessfulBackfillMonth);
          }).toList();

      if (monthsToProcess.isEmpty) {
        await _prefs.setBool(_fullBackfillRunAttemptedKey, true);
        return;
      }


      int successCount = 0;
      int failureCount = 0;
      DateTime? latestSuccessfullyProcessedMonthInThisRun;

      for (final monthDate in monthsToProcess) {
        // CP: Iterate through months
        // CP: Sort entries within the month by timestamp
        final List<Entry> entriesForMonth =
            entriesByMonth[monthDate]!..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // CP: Format content for the entire month
        final String monthlyLogContent = entriesForMonth
            .map((e) => "${_formatTimestampForLog(e.timestamp)}: ${e.text}") // CP: Add timestamp to each entry
            .join("\\n---\\n");

        if (monthlyLogContent.isNotEmpty) {
          try {
            await synchronizeMonthlyLogFile(
              currentVectorStoreId,
              monthDate, // CP: Pass the DateTime representing the month
              monthlyLogContent,
            );
            successCount++;
            latestSuccessfullyProcessedMonthInThisRun = monthDate;
            // CP: Update last successful date to the first day of the processed month
            await _prefs.setString(
              _backfillLastSuccessfulDateKey,
              _formatDateKey(monthDate), // CP: Store as YYYY-MM-DD (first day of month)
            );
          } catch (e, stackTrace) {
            failureCount++;
            AppLogger.error(
              "[VectorStoreService] Backfill: Failed to synchronize log for month ${_formatMonthKeyForStorage(monthDate)}.",
              error: e,
              stackTrace: stackTrace,
            );
            AppLogger.warn(
              "[VectorStoreService] Backfill: Halting current backfill run due to error. Will retry from month ${_formatMonthKeyForStorage(monthDate)} on next attempt.",
            );
            break;
          }
        } else {
          latestSuccessfullyProcessedMonthInThisRun = monthDate;
          await _prefs.setString(_backfillLastSuccessfulDateKey, _formatDateKey(monthDate));
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }


      if (failureCount == 0 &&
          (monthsToProcess.isEmpty ||
              (latestSuccessfullyProcessedMonthInThisRun != null &&
                  latestSuccessfullyProcessedMonthInThisRun.year == monthsToProcess.last.year &&
                  latestSuccessfullyProcessedMonthInThisRun.month == monthsToProcess.last.month))) {
        await _prefs.setBool(_fullBackfillRunAttemptedKey, true);
      } else if (failureCount > 0) {
      } else {
        AppLogger.warn(
          "[VectorStoreService] Backfill: Run completed, but not all months may have been processed. Last successful: ${latestSuccessfullyProcessedMonthInThisRun != null ? _formatMonthKeyForStorage(latestSuccessfullyProcessedMonthInThisRun) : 'None'}. Full backfill not marked as attempted.",
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        "[VectorStoreService] Backfill: Critical error during the backfill process: $e",
        error: e,
        stackTrace: stackTrace,
      );
      // CP: Do not set _fullBackfillRunAttemptedKey to true if the process itself had a critical setup failure.
    }
  }

  // CP: Helper to format date consistently for SharedPreferences keys and logging.
  String _formatDateKey(DateTime date) {
    // CP: Ensure month and day are two digits
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  // CP: Helper to format date as YYYY-MM for monthly keys
  String _formatMonthKeyForStorage(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}";
  }

  // CP: Helper to format timestamp for individual log entries within a monthly file  // CP: Helper to format timestamp for individual log entries within log files
  String _formatTimestampForLog(DateTime timestamp) {
    final timeFormat = DateFormat('h:mm a'); // CP: Changed from 24-hour to 12-hour format
    final dateFormat = DateFormat('yyyy-MM-dd');
    return "${dateFormat.format(timestamp)} ${timeFormat.format(timestamp)}:${timestamp.second.toString().padLeft(2, '0')}";
  } // CP: Helper to calculate metadata attributes for a month's entries

  // Follows OpenAI API requirements:
  // - Max 16 key-value pairs
  // - Keys: max 64 chars
  // - Values: max 512 chars, can be string/bool/number
  Map<String, dynamic> _calculateMonthlyMetadata(List<Entry> entries, DateTime monthDate) {
    // Sort entries to find first and last timestamps
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return {
      'month': _formatMonthKeyForStorage(monthDate),
      'entry_count': entries.length,
      'first_entry_ts': entries.first.timestamp.millisecondsSinceEpoch,
      'last_entry_ts': entries.last.timestamp.millisecondsSinceEpoch,
      'last_sync_ts': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // CP: Helper to get headers for OpenAI API calls
  Map<String, String> _getHeaders({bool isJsonContent = true}) {
    // CP: Added isJsonContent parameter
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'OpenAI-Beta': 'assistants=v2', // CP: Required for Vector Store features
    };
    if (isJsonContent) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  // CP: Helper method to clean up duplicate files in vector store
  Future<void> cleanupDuplicateFiles() async {

    try {
      final vectorStoreId = await getOrCreateVectorStoreId();
      if (vectorStoreId == null) {
        AppLogger.error('[VectorStoreService] Cannot cleanup - no vector store ID available.');
        return;
      }

      // CP: Get all files in the vector store
      final response = await _httpClient.get(
        Uri.parse('$_openAIBaseUrl/vector_stores/$vectorStoreId/files'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200) {
        AppLogger.error('[VectorStoreService] Failed to list vector store files: ${response.statusCode}');
        return;
      }

      final responseBody = jsonDecode(response.body);
      final files = responseBody['data'] as List<dynamic>;


      // CP: Group files by month based on filename pattern
      final Map<String, List<Map<String, dynamic>>> filesByMonth = {};

      // CP: For each file, get its filename from the files API
      for (final file in files) {
        final fileId = file['id'] as String;

        try {
          // CP: Get file details including filename from files API
          final fileResponse = await _httpClient.get(
            Uri.parse('$_openAIBaseUrl/files/$fileId'),
            headers: _getHeaders(),
          );

          if (fileResponse.statusCode == 200) {
            final fileData = jsonDecode(fileResponse.body);
            final filename = fileData['filename'] as String? ?? '';

            if (filename.startsWith('logs_') && filename.endsWith('.txt')) {
              // CP: Extract month from filename (e.g., "logs_2025-05.txt" -> "2025-05")
              final monthMatch = RegExp(r'logs_(\d{4}-\d{2})\.txt').firstMatch(filename);
              if (monthMatch != null) {
                final month = monthMatch.group(1)!;
                if (!filesByMonth.containsKey(month)) {
                  filesByMonth[month] = [];
                }
                // CP: Add both vector store file info and filename
                final fileWithName = Map<String, dynamic>.from(file);
                fileWithName['filename'] = filename;
                filesByMonth[month]!.add(fileWithName);
              }
            }
          } else {
            AppLogger.warn('[VectorStoreService] Failed to get filename for file $fileId: ${fileResponse.statusCode}');
          }
        } catch (e) {
          AppLogger.warn('[VectorStoreService] Error getting filename for file $fileId: $e');
        }
      }


      // CP: Find and remove duplicates (keep the most recent)
      for (final month in filesByMonth.keys) {
        final monthFiles = filesByMonth[month]!;
        if (monthFiles.length > 1) {
          AppLogger.warn('[VectorStoreService] Found ${monthFiles.length} duplicate files for month $month');

          // CP: Sort by created_at timestamp, keep the newest
          monthFiles.sort((a, b) {
            final aCreated = a['created_at'] as int;
            final bCreated = b['created_at'] as int;
            return bCreated.compareTo(aCreated); // Newest first
          });

          final keepFile = monthFiles.first;
          final deleteFiles = monthFiles.skip(1).toList();


          for (final fileToDelete in deleteFiles) {
            final fileId = fileToDelete['id'] as String;
            final filename = fileToDelete['filename'] as String;
            try {
              await _deleteFileFromVectorStore(vectorStoreId, fileId);
              await _deleteOpenAIFile(fileId);
            } catch (e) {
              AppLogger.error('[VectorStoreService] Failed to delete duplicate file $fileId ($filename): $e');
            }
          }

          // CP: Update our local storage to reflect the kept file
          final monthlyLogFileIds = await _getMonthlyLogFileIds();
          monthlyLogFileIds[month] = keepFile['id'] as String;
          await _saveMonthlyLogFileIds(monthlyLogFileIds);
        }
      }

    } catch (e, stackTrace) {
      AppLogger.error('[VectorStoreService] Error during cleanup: $e', error: e, stackTrace: stackTrace);
    }
  }

  /// Clears all local vector store cache data from SharedPreferences.
  /// Does NOT delete files from OpenAI - the vector store remains intact
  /// for when the user signs back in.
  Future<void> clearLocalCache() async {
    AppLogger.info('[VectorStoreService] Clearing local cache...');

    // Clear vector store ID
    await _prefs.remove(_vectorStoreIdKey);

    // Clear monthly file ID mappings
    await _prefs.remove(_monthlyLogFileIdsKey);

    // Clear backfill state
    await _prefs.remove(_backfillLastSuccessfulDateKey);
    await _prefs.remove(_fullBackfillRunAttemptedKey);

    // Clear any sync locks
    final allKeys = _prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith('vector_store_sync_lock_')) {
        await _prefs.remove(key);
      }
    }

    // Clear in-memory locks
    _monthSyncLocks.clear();

    AppLogger.info('[VectorStoreService] Local cache cleared');
  }

  // CP: Debug method to list all files in vector store
  Future<void> debugListVectorStoreFiles() async {
    try {
      final vectorStoreId = await getOrCreateVectorStoreId();
      if (vectorStoreId == null) {
        return;
      }

      final response = await _httpClient.get(
        Uri.parse('$_openAIBaseUrl/vector_stores/$vectorStoreId/files'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final files = responseBody['data'] as List<dynamic>;


        // CP: For each file, get its filename from the files API
        for (final file in files) {
          final fileId = file['id'] as String;
          final createdAt = file['created_at'] as int;
          // CC: Created date from timestamp (currently unused)

          try {
            // CP: Get file details including filename from files API
            final fileResponse = await _httpClient.get(
              Uri.parse('$_openAIBaseUrl/files/$fileId'),
              headers: _getHeaders(),
            );

            // CC: Filename retrieval for debugging (currently unused)
            if (fileResponse.statusCode == 200) {
              // CC: File data available in response but not currently used
              jsonDecode(fileResponse.body);
            }

          } catch (e) {
            // CC: Silently ignore file retrieval errors for cleanup
          }
        }
      } else {
        AppLogger.error('[VectorStoreService] DEBUG: Failed to list files: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('[VectorStoreService] DEBUG: Error listing files: $e');
    }
  }
}
