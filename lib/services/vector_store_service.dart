import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/utils/logger.dart'; // CP: Corrected import path for AppLogger

// Custom Exceptions
class VectorStoreApiException implements Exception {
  final String message;
  final dynamic underlyingError;
  VectorStoreApiException(this.message, {this.underlyingError});
  @override
  String toString() =>
      'VectorStoreApiException: $message (Underlying error: $underlyingError)';
}

class VectorStoreSyncException implements Exception {
  final String message;
  final dynamic underlyingError;
  final StackTrace? stackTrace;

  VectorStoreSyncException(
    this.message, {
    this.underlyingError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'VectorStoreSyncException: $message'
        '${underlyingError != null ? "\nUnderlying error: $underlyingError" : ""}'
        '${stackTrace != null ? "\nStackTrace: $stackTrace" : ""}';
  }
}

class VectorStoreService {
  final SharedPreferences _prefs;
  final http.Client _httpClient;
  final String _apiKey;

  static const String _vectorStoreIdKey = 'openai_vector_store_id';
  static const String _dailyLogFileIdsKey = 'openai_daily_log_file_ids';
  static const String _openAIBaseUrl = 'https://api.openai.com/v1';

  VectorStoreService({
    required SharedPreferences sharedPreferences,
    required http.Client httpClient,
    required String apiKey,
  }) : _prefs = sharedPreferences,
       _httpClient = httpClient,
       _apiKey = apiKey;

  Map<String, String> _getHeaders({bool isJsonContent = true}) {
    final headers = {
      'Authorization': 'Bearer $_apiKey',
      'OpenAI-Beta': 'assistants=v2',
    };
    if (isJsonContent) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  Future<String> getOrCreateVectorStoreId() async {
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
          Uri.parse('$_openAIBaseUrl/vector_stores'),
          headers: _getHeaders(),
          body: jsonEncode({
            'name':
                vectorStoreName, // CP: Use the dynamically generated unique name
            // CP: You can add metadata here if needed, e.g., app version
            // CP: "metadata": { "app_version": "1.0.0" }
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseBody = jsonDecode(response.body);
          final String? createdId = responseBody['id'] as String?;
          if (createdId == null || createdId.isEmpty) {
            throw VectorStoreApiException(
              'Failed to create vector store: ID missing in response.',
              underlyingError: response.body,
            );
          }
          vectorStoreId = createdId; // CP: Assign to the broader scope variable
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
            underlyingError: response.body,
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
    // CP: If execution reaches here, vectorStoreId should be non-null and non-empty.
    // CP: Either it was valid from SharedPreferences, or it was successfully created and assigned.
    // CP: If creation failed, an exception should have been thrown.
    // CP: The method signature is Future<String>, so a non-null String is expected.
    return vectorStoreId; // CP: Removed redundant null assertion.
  }

  Future<Map<String, String>> _getDailyLogFileIds() async {
    final String? jsonString = _prefs.getString(_dailyLogFileIdsKey);
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
      await _prefs.setString(_dailyLogFileIdsKey, jsonEncode(ids));
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
        Uri.parse('$_openAIBaseUrl/files'),
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
            underlyingError: response.body,
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
          underlyingError: response.body,
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
        Uri.parse('$_openAIBaseUrl/vector_stores/$vectorStoreId/files'),
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
              '$_openAIBaseUrl/vector_stores/$vectorStoreId/files/$fileId',
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
                underlyingError: pollBody,
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
          underlyingError: response.body,
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
        Uri.parse('$_openAIBaseUrl/files/$fileId'),
        headers: _getHeaders(
          isJsonContent: false,
        ), // CP: DELETE often doesn't need Content-Type
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
          underlyingError: response.body,
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
        Uri.parse('$_openAIBaseUrl/vector_stores/$vectorStoreId/files/$fileId'),
        headers: _getHeaders(
          isJsonContent: false,
        ), // CP: DELETE often doesn't need Content-Type
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
          underlyingError: response.body,
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
}
