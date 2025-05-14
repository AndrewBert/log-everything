import 'dart:convert';
// CP: Removed unused import 'dart:io';
// CP: Removed unused import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// CP: Removed unused import 'package:intl/intl.dart';
import 'package:myapp/entry/entry.dart'; // CP: Added import for Entry
import 'package:myapp/services/entry_persistence_service.dart'; // CP: Added import for EntryPersistenceService
// CP: Removed unused import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

// CP: Define SharedPreferences keys for backfill state
const String _backfillLastSuccessfulDateKey =
    'vector_store_backfill_last_successful_date';
const String _fullBackfillRunAttemptedKey =
    'vector_store_full_backfill_run_attempted';

// CP: Define the base URL for OpenAI API
const String _openAIBaseUrl = 'https://api.openai.com/v1';

// CP: Define SharedPreferences key for storing daily log file IDs
const String _dailyLogFileIdsKey = 'vector_store_daily_log_file_ids';

// CP: Custom Exception for Vector Store API errors
class VectorStoreApiException implements Exception {
  final String message;
  final dynamic underlyingError;
  final String? responseBody;

  VectorStoreApiException(
    this.message, {
    this.underlyingError,
    this.responseBody,
  });

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

  static const String _vectorStoreIdKey = 'openai_vector_store_id';

  VectorStoreService({
    required SharedPreferences sharedPreferences,
    required http.Client httpClient,
    required String apiKey,
    required EntryPersistenceService
    entryPersistenceService, // CP: Added to constructor
  }) : _prefs = sharedPreferences,
       _httpClient = httpClient,
       _apiKey = apiKey,
       _entryPersistenceService =
           entryPersistenceService; // CP: Initialize field

  Future<String?> getOrCreateVectorStoreId() async {
    String? vectorStoreId = _prefs.getString(_vectorStoreIdKey);

    if (vectorStoreId == null || vectorStoreId.isEmpty) {
      AppLogger.info(
        '[VectorStoreService] No existing Vector Store ID found or it was empty. Creating a new one.',
      );
      try {
        // CP: Generate a more unique name for the vector store
        final String uniqueSuffix = DateTime.now().millisecondsSinceEpoch
            .toRadixString(36);
        final String vectorStoreName = 'LogEverythingApp_User_$uniqueSuffix';
        AppLogger.info(
          '[VectorStoreService] Attempting to create vector store with name: $vectorStoreName',
        );

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
          AppLogger.info(
            '[VectorStoreService] New Vector Store created with ID: $vectorStoreId and Name: $vectorStoreName',
          );
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
        AppLogger.error(
          '[VectorStoreService] Error creating vector store: $e',
          error: e,
          stackTrace: stackTrace,
        );
        if (e is VectorStoreApiException) rethrow;
        throw VectorStoreApiException(
          'Error creating vector store: $e',
          underlyingError: e,
        );
      }
    } else {
      AppLogger.info(
        '[VectorStoreService] Using existing real Vector Store ID: $vectorStoreId',
      );
    }
    return vectorStoreId;
  }

  Future<Map<String, String>> _getDailyLogFileIds() async {
    final String? jsonString = _prefs.getString(
      _dailyLogFileIdsKey,
    ); // CP: Use defined key
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        return Map<String, String>.from(jsonDecode(jsonString) as Map);
      } catch (e) {
        AppLogger.error(
          '[VectorStoreService] Error decoding daily_log_file_ids from JSON: $e. Returning empty map.',
        );
        return {};
      }
    }
    return {};
  }

  Future<void> _saveDailyLogFileIds(Map<String, String> ids) async {
    try {
      await _prefs.setString(
        _dailyLogFileIdsKey,
        jsonEncode(ids),
      ); // CP: Use defined key
    } catch (e) {
      AppLogger.error(
        '[VectorStoreService] Error encoding daily_log_file_ids to JSON: $e',
      );
      throw VectorStoreSyncException(
        'Failed to save daily log file IDs to SharedPreferences',
        underlyingError: e,
      );
    }
  }

  Future<String> _uploadLogContentToOpenAIFile(
    String fileName,
    String content,
  ) async {
    AppLogger.info(
      '[VectorStoreService] Uploading file "$fileName" to OpenAI.',
    );
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_openAIBaseUrl/files'), // CP: Use _openAIBaseUrl
      );
      request.headers.addAll(_getHeaders(isJsonContent: false));
      request.fields['purpose'] = 'assistants';
      request.files.add(
        http.MultipartFile.fromString('file', content, filename: fileName),
      );

      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        final fileId = responseBody['id'] as String?;
        if (fileId == null || fileId.isEmpty) {
          throw VectorStoreApiException(
            'Failed to upload file: ID missing in response.',
            responseBody: response.body,
          );
        }
        AppLogger.info(
          '[VectorStoreService] File "$fileName" uploaded successfully. File ID: $fileId',
        );
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
      AppLogger.error(
        '[VectorStoreService] Error uploading file "$fileName": $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (e is VectorStoreApiException) rethrow;
      throw VectorStoreApiException(
        'Error uploading file "$fileName": $e',
        underlyingError: e,
      );
    }
  }

  Future<void> _addFileToVectorStore(
    String vectorStoreId,
    String fileId,
  ) async {
    AppLogger.info(
      '[VectorStoreService] Adding file "$fileId" to Vector Store "$vectorStoreId".',
    );
    try {
      final response = await _httpClient.post(
        Uri.parse(
          '$_openAIBaseUrl/vector_stores/$vectorStoreId/files',
        ), // CP: Use _openAIBaseUrl
        headers: _getHeaders(),
        body: jsonEncode({'file_id': fileId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        final addedFileId = responseBody['id'] as String?;
        final status = responseBody['status'] as String?;

        if (addedFileId != fileId) {
          AppLogger.warn(
            '[VectorStoreService] Added file ID $addedFileId does not match expected $fileId.',
          );
        }
        AppLogger.info(
          '[VectorStoreService] File "$fileId" added to vector store "$vectorStoreId". Initial status: $status. Starting polling for completion.',
        );

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
            AppLogger.info(
              '[VectorStoreService] Polling file "$fileId" in vector store "$vectorStoreId" (Attempt $pollCount/$maxPolls): Status: $fileStatus',
            );
            if (fileStatus == 'completed') {
              AppLogger.info(
                '[VectorStoreService] File "$fileId" processing completed in vector store "$vectorStoreId".',
              );
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
        throw VectorStoreApiException(
          'File processing timed out in vector store.',
        );
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
      throw VectorStoreApiException(
        'Error adding file to vector store: $e',
        underlyingError: e,
      );
    }
  }

  Future<void> _deleteOpenAIFile(String fileId) async {
    AppLogger.info('[VectorStoreService] Deleting OpenAI file "$fileId".');
    try {
      final response = await _httpClient.delete(
        Uri.parse('$_openAIBaseUrl/files/$fileId'), // CP: Use _openAIBaseUrl
        headers: _getHeaders(isJsonContent: false),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['deleted'] == true) {
          AppLogger.info(
            '[VectorStoreService] OpenAI file "$fileId" deleted successfully.',
          );
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
      throw VectorStoreApiException(
        'Error deleting OpenAI file: $e',
        underlyingError: e,
      );
    }
  }

  Future<void> _deleteFileFromVectorStore(
    String vectorStoreId,
    String fileId,
  ) async {
    AppLogger.info(
      '[VectorStoreService] Deleting file "$fileId" from Vector Store "$vectorStoreId".',
    );
    try {
      final response = await _httpClient.delete(
        Uri.parse(
          '$_openAIBaseUrl/vector_stores/$vectorStoreId/files/$fileId',
        ), // CP: Use _openAIBaseUrl
        headers: _getHeaders(isJsonContent: false),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['deleted'] == true) {
          AppLogger.info(
            '[VectorStoreService] File "$fileId" deleted successfully from vector store "$vectorStoreId".',
          );
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
      throw VectorStoreApiException(
        'Error deleting file from vector store: $e',
        underlyingError: e,
      );
    }
  }

  Future<void> synchronizeDailyLogFile(
    String vectorStoreId,
    DateTime date,
    String formattedDailyLogContent,
  ) async {
    final dateKey =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final fileName = "logs_$dateKey.txt";
    AppLogger.info(
      '[VectorStoreService] Starting synchronization for date: $dateKey, file: $fileName',
    );

    Map<String, String> dailyLogFileIds = await _getDailyLogFileIds();
    final String? existingFileId = dailyLogFileIds[dateKey];

    if (existingFileId != null) {
      AppLogger.info(
        '[VectorStoreService] Existing file found for $dateKey: $existingFileId. Deleting it first.',
      );
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

    if (formattedDailyLogContent.isEmpty) {
      AppLogger.info(
        '[VectorStoreService] Formatted daily log content for $dateKey is empty.',
      );
      if (existingFileId != null) {
        AppLogger.info(
          '[VectorStoreService] Removing $dateKey from daily_log_file_ids as content is now empty.',
        );
        dailyLogFileIds.remove(dateKey);
        await _saveDailyLogFileIds(dailyLogFileIds);
      }
      AppLogger.info(
        '[VectorStoreService] Synchronization for $dateKey skipped as content is empty.',
      );
      return;
    }

    AppLogger.info('[VectorStoreService] Uploading new content for $dateKey.');
    String newFileId;
    try {
      newFileId = await _uploadLogContentToOpenAIFile(
        fileName,
        formattedDailyLogContent,
      );
      AppLogger.info(
        '[VectorStoreService] Content for $dateKey uploaded. New file ID: $newFileId',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        '[VectorStoreService] Failed to upload log content for $dateKey to OpenAI.',
        error: e,
        stackTrace: stackTrace,
      );
      throw VectorStoreSyncException(
        'Failed to upload log content for $dateKey',
        underlyingError: e,
      );
    }

    try {
      AppLogger.info(
        '[VectorStoreService] Adding new file $newFileId to vector store $vectorStoreId.',
      );
      await _addFileToVectorStore(vectorStoreId, newFileId);
      AppLogger.info(
        '[VectorStoreService] File $newFileId successfully added and processed in vector store $vectorStoreId.',
      );
    } catch (e, stackTrace) {
      AppLogger.error(
        '[VectorStoreService] Failed to add file $newFileId for $dateKey to vector store $vectorStoreId.',
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
        'Failed to add file $newFileId for $dateKey to vector store',
        underlyingError: e,
      );
    }

    dailyLogFileIds[dateKey] = newFileId;
    await _saveDailyLogFileIds(dailyLogFileIds);
    AppLogger.info(
      '[VectorStoreService] Successfully synchronized file for $dateKey. New ID $newFileId stored.',
    );
  }

  // CP: New method to perform initial backfill of historical logs.
  Future<void> performInitialBackfillIfNeeded() async {
    AppLogger.info(
      "[VectorStoreService] Checking if initial backfill is needed.",
    );

    final bool fullRunPreviouslyAttempted =
        _prefs.getBool(_fullBackfillRunAttemptedKey) ?? false;

    if (fullRunPreviouslyAttempted) {
      AppLogger.info(
        "[VectorStoreService] Full historical log backfill run previously attempted. Skipping.",
      );
      return;
    }

    AppLogger.info(
      "[VectorStoreService] Starting historical log backfill process.",
    );
    String? currentVectorStoreId;

    try {
      currentVectorStoreId = await getOrCreateVectorStoreId();
      if (currentVectorStoreId == null || currentVectorStoreId.isEmpty) {
        AppLogger.error(
          "[VectorStoreService] Backfill: Could not obtain Vector Store ID. Aborting backfill.",
        );
        return;
      }

      final List<Entry> allEntries =
          await _entryPersistenceService.loadEntries();
      AppLogger.info(
        "[VectorStoreService] Backfill: Loaded ${allEntries.length} total entries for potential backfill.",
      );

      if (allEntries.isEmpty) {
        AppLogger.info(
          "[VectorStoreService] Backfill: No entries found in persistence. Marking backfill as attempted.",
        );
        await _prefs.setBool(_fullBackfillRunAttemptedKey, true);
        return;
      }

      // CP: Group entries by date (day only, ignoring time)
      final Map<DateTime, List<Entry>> entriesByDate = {};
      for (final entry in allEntries) {
        final dateKey = DateTime(
          entry.timestamp.year,
          entry.timestamp.month,
          entry.timestamp.day,
        );
        if (entriesByDate.containsKey(dateKey)) {
          entriesByDate[dateKey]!.add(entry);
        } else {
          entriesByDate[dateKey] = [entry];
        }
      }

      final List<DateTime> sortedDates = entriesByDate.keys.toList();
      // CP: Sort dates ascending to process oldest first
      sortedDates.sort((a, b) => a.compareTo(b));

      final String? lastSuccessfulDateString = _prefs.getString(
        _backfillLastSuccessfulDateKey,
      );
      DateTime? lastSuccessfulDate;
      if (lastSuccessfulDateString != null) {
        try {
          lastSuccessfulDate = DateTime.parse(lastSuccessfulDateString);
        } catch (e) {
          AppLogger.warn(
            "[VectorStoreService] Backfill: Could not parse last successful date: $lastSuccessfulDateString. Processing all discovered historical logs.",
          );
        }
      }

      final List<DateTime> datesToProcess =
          sortedDates
              .where(
                (date) =>
                    lastSuccessfulDate == null ||
                    date.isAfter(lastSuccessfulDate),
              )
              .toList();

      if (datesToProcess.isEmpty) {
        AppLogger.info(
          "[VectorStoreService] Backfill: No new historical dates to process since last successful backfill ($lastSuccessfulDateString). Marking as fully attempted.",
        );
        await _prefs.setBool(_fullBackfillRunAttemptedKey, true);
        return;
      }

      AppLogger.info(
        "[VectorStoreService] Backfill: Found ${datesToProcess.length} historical dates to process. Starting from ${_formatDateKey(datesToProcess.first)}.",
      );

      int successCount = 0;
      int failureCount = 0;
      DateTime? latestSuccessfullyProcessedDateInThisRun;

      for (final date in datesToProcess) {
        final List<Entry> entriesForDate =
            entriesByDate[date]!..sort(
              (a, b) => a.timestamp.compareTo(b.timestamp),
            ); // CP: Sort entries by timestamp to maintain order within the day's log

        // CP: Format content for the day - simple concatenation for now
        // CP: Consider adding timestamps or categories if needed for AI context
        final String dailyLogContent = entriesForDate
            .map((e) => e.text)
            .join("\\n---\\n");

        if (dailyLogContent.isNotEmpty) {
          AppLogger.info(
            "[VectorStoreService] Backfill: Processing logs for date: ${_formatDateKey(date)}",
          );
          try {
            await synchronizeDailyLogFile(
              currentVectorStoreId,
              date,
              dailyLogContent,
            );
            successCount++;
            latestSuccessfullyProcessedDateInThisRun = date;
            // CP: Update last successful date immediately after each successful sync
            await _prefs.setString(
              _backfillLastSuccessfulDateKey,
              _formatDateKey(date),
            );
            AppLogger.info(
              "[VectorStoreService] Backfill: Successfully processed and updated last successful date to ${_formatDateKey(date)}.",
            );
          } catch (e, stackTrace) {
            failureCount++;
            AppLogger.error(
              "[VectorStoreService] Backfill: Failed to synchronize log for date ${_formatDateKey(date)}.",
              error: e,
              stackTrace: stackTrace,
            );
            // CP: If a day fails, we stop this backfill run here to allow retry from this point.
            // CP: The _fullBackfillRunAttemptedKey will not be set to true.
            AppLogger.warn(
              "[VectorStoreService] Backfill: Halting current backfill run due to error. Will retry from ${_formatDateKey(date)} on next attempt.",
            );
            break;
          }
        } else {
          AppLogger.info(
            "[VectorStoreService] Backfill: Skipping date ${_formatDateKey(date)} as it has no content after formatting.",
          );
          // CP: If a day has no content, we can consider it "successfully processed" for backfill progress
          // CP: to avoid getting stuck on empty log days.
          latestSuccessfullyProcessedDateInThisRun = date;
          await _prefs.setString(
            _backfillLastSuccessfulDateKey,
            _formatDateKey(date),
          );
        }
        // CP: Optional: Add a small delay to be kind to the API and device resources, especially for many historical files.
        await Future.delayed(const Duration(milliseconds: 500));
      }

      AppLogger.info(
        "[VectorStoreService] Backfill: Iteration finished. Processed this session: Successes: $successCount, Failures: $failureCount.",
      );

      // CP: If all dates in datesToProcess were handled (either successfully or skipped due to no content)
      // CP: and no errors caused an early break, then mark the full run as attempted.
      if (failureCount == 0 &&
          (datesToProcess.isEmpty ||
              latestSuccessfullyProcessedDateInThisRun ==
                  datesToProcess.last)) {
        await _prefs.setBool(_fullBackfillRunAttemptedKey, true);
        AppLogger.info(
          "[VectorStoreService] Backfill: Successfully processed all pending historical dates. Marked full backfill run as attempted.",
        );
      } else if (failureCount > 0) {
        AppLogger.info(
          "[VectorStoreService] Backfill: Run completed with failures. Last successful date recorded was ${_formatDateKey(latestSuccessfullyProcessedDateInThisRun!)}. Full backfill not marked as attempted.",
        );
      } else {
        // CP: This case might occur if datesToProcess was not empty, but loop didn't run or finish as expected without errors.
        AppLogger.warn(
          "[VectorStoreService] Backfill: Run completed, but not all dates may have been processed. Last successful: ${latestSuccessfullyProcessedDateInThisRun != null ? _formatDateKey(latestSuccessfullyProcessedDateInThisRun) : 'None'}. Full backfill not marked as attempted.",
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
}
