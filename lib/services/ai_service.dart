import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // CP: Added SharedPreferences
import '../utils/logger.dart';
import '../chat/model/chat_message.dart';

// Rename field in typedef to follow Dart conventions
typedef EntryPrototype = ({String textSegment, String category});

// Interface for AI Service
abstract class AiService {
  /// Extracts categorized entry prototypes from the given text using an AI model.
  ///
  /// Takes the [text] to analyze and the list of available [categories].
  /// Returns a list of [EntryPrototype] objects.
  /// Throws an [AiServiceException] if the process fails.
  Future<List<EntryPrototype>> extractEntries(
    String text,
    List<String> categories,
  );

  /// Gets a chat response from the AI model based on the provided message history
  /// and optional log context.
  ///
  /// Takes a list of [ChatMessage] objects representing the conversation history
  /// and an optional [logContext] string containing relevant log entries.
  /// Returns a plain text response from the AI model.
  /// Throws an [AiServiceException] if the process fails.
  Future<String> getChatResponse({
    required List<ChatMessage> messages,
    // CP: Removed logContext String? logContext,
  });
}

// Custom Exception for the service
class AiServiceException implements Exception {
  final String message;
  final dynamic underlyingError; // Optional: Store the original error

  AiServiceException(this.message, {this.underlyingError});

  @override
  String toString() {
    if (underlyingError != null) {
      return 'AiServiceException: $message (Caused by: $underlyingError)';
    }
    return 'AiServiceException: $message';
  }
}

// Concrete implementation using OpenAI
class OpenAiService implements AiService {
  final String _apiKey =
      dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_API_KEY_NOT_FOUND';
  final String _apiUrl = 'https://api.openai.com/v1/responses';
  final String _modelId = 'gpt-4o-mini';
  final SharedPreferences _prefs; // CP: Added SharedPreferences field

  // CP: Updated constructor to accept SharedPreferences
  OpenAiService({required SharedPreferences sharedPreferences})
    : _prefs = sharedPreferences;

  @override
  Future<List<EntryPrototype>> extractEntries(
    String text,
    List<String> categories,
  ) async {
    // 1. Pre-flight checks
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      throw AiServiceException('OpenAI API Key not found.');
    }
    if (categories.isEmpty) {
      throw AiServiceException('No categories provided for classification.');
    }

    // 2. Prepare API Call
    AppLogger.info(
      "Calling OpenAI API ($_modelId) to extract entries for text: '$text'",
    );

    final schema = {
      "type": "object",
      "properties": {
        "entries": {
          "type": "array",
          "description":
              "An array of text segments extracted from the input, each assigned a category.",
          "items": {
            "type": "object",
            "properties": {
              "text_segment": {
                "type": "string",
                "description":
                    "The specific portion of the input text relevant to this entry.",
              },
              "category": {
                "type": "string",
                "description": "The category assigned to this text segment.",
                "enum": categories, // Use provided categories
              },
            },
            "required": ["text_segment", "category"],
            "additionalProperties": false,
          },
        },
      },
      "required": ["entries"],
      "additionalProperties": false,
    };

    final requestBody = {
      'model': _modelId,
      'input': [
        {
          "role": "system",
          "content":
              "Analyze the user's text. Identify distinct pieces of information or tasks. **Group related sentences or ideas into a single entry whenever possible.** Avoid splitting closely related concepts into separate entries. For each logical entry, extract the relevant text segment (which might span multiple sentences) and assign the most appropriate category from the provided list using the JSON schema. If a segment doesn't fit any specific category, use 'Misc'. Respond with a JSON object containing an array named 'entries' holding these structured segments.",
        },
        {"role": "user", "content": text},
      ],
      'text': {
        'format': {
          'type': 'json_schema',
          'name': 'multiple_entry_extraction',
          'schema': schema,
          'strict': true,
        },
      },
      'temperature': 0.2,
    };

    // 3. Execute API Call and Handle Response/Errors
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(requestBody),
      );

      // --- Response Parsing Logic ---
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        if (responseBody['status'] != 'completed' ||
            responseBody['error'] != null) {
          final errorMsg =
              'OpenAI request failed or returned an error. Status: ${responseBody['status']}. Error: ${responseBody['error']}';
          AppLogger.error(errorMsg);
          AppLogger.error('Full Response Body: ${response.body}');
          throw AiServiceException(errorMsg);
        }

        if (responseBody['output'] != null &&
            responseBody['output'] is List &&
            responseBody['output'].isNotEmpty &&
            responseBody['output'][0]['content'] != null &&
            responseBody['output'][0]['content'] is List &&
            responseBody['output'][0]['content'].isNotEmpty) {
          final contentItem = responseBody['output'][0]['content'][0];

          if (contentItem['type'] == 'output_text' &&
              contentItem['text'] != null) {
            final jsonOutputString = contentItem['text'];
            AppLogger.info(
              "Received JSON string from OpenAI: $jsonOutputString",
            );

            try {
              final Map<String, dynamic> parsedJson = jsonDecode(
                jsonOutputString,
              );

              if (parsedJson.containsKey('entries') &&
                  parsedJson['entries'] is List) {
                final List<dynamic> entriesListJson = parsedJson['entries'];
                final List<EntryPrototype> extractedEntries = [];
                bool formatErrorOccurred = false;

                for (var item in entriesListJson) {
                  // Use string literal 'text_segment' for JSON key access
                  if (item is Map<String, dynamic> &&
                      item.containsKey('text_segment') &&
                      item['text_segment'] is String &&
                      item.containsKey('category') &&
                      item['category'] is String) {
                    String segment = item['text_segment']; // Read from JSON key
                    String category = item['category'];

                    if (categories.contains(category)) {
                      // Assign to the renamed typedef field
                      extractedEntries.add((
                        textSegment: segment,
                        category: category,
                      ));
                    } else {
                      AppLogger.warn(
                        "OpenAI category ('$category') not in allowed list. Using 'Misc' for: '$segment'",
                      );
                      // Assign to the renamed typedef field
                      extractedEntries.add((
                        textSegment: segment,
                        category: 'Misc',
                      ));
                    }
                  } else {
                    AppLogger.warn(
                      "Invalid item format in 'entries' array: $item",
                    );
                    formatErrorOccurred = true;
                  }
                }

                if (formatErrorOccurred) {
                  // Decide if partial success is acceptable or throw an error
                  throw AiServiceException(
                    "Invalid item format received in OpenAI response.",
                  );
                  // Or return extractedEntries; if partial results are okay
                }

                AppLogger.info(
                  "Successfully extracted ${extractedEntries.length} entries.",
                );
                return extractedEntries;
              } else {
                final errorMsg =
                    'Parsed JSON from OpenAI does not contain a valid "entries" key or it\'s not a list.';
                AppLogger.error('$errorMsg JSON: $parsedJson');
                throw AiServiceException(errorMsg);
              }
            } catch (e) {
              final errorMsg = 'Failed to parse JSON response from OpenAI.';
              AppLogger.error(errorMsg, error: e);
              throw AiServiceException(errorMsg, underlyingError: e);
            }
          } else if (contentItem['type'] == 'refusal' &&
              contentItem['refusal'] != null) {
            final errorMsg =
                'OpenAI refused the request: ${contentItem['refusal']}';
            AppLogger.error(errorMsg);
            throw AiServiceException(errorMsg);
          } else {
            final errorMsg =
                'Unexpected content type or format in OpenAI response.';
            AppLogger.error('$errorMsg Content Item: $contentItem');
            throw AiServiceException(errorMsg);
          }
        } else {
          final errorMsg = 'Failed to parse overall OpenAI response structure.';
          AppLogger.error('$errorMsg Body: ${response.body}');
          throw AiServiceException(errorMsg);
        }
      } else {
        // Handle HTTP errors
        String errorMessage;
        if (response.statusCode == 400) {
          errorMessage =
              'OpenAI API error (Code: 400). Check model compatibility ($_modelId) with structured output.';
        } else if (response.statusCode == 401) {
          errorMessage = 'Invalid OpenAI API Key.';
        } else if (response.statusCode == 429) {
          errorMessage = 'OpenAI rate limit exceeded.';
        } else {
          errorMessage = 'OpenAI API HTTP error (Code: ${response.statusCode})';
        }
        AppLogger.error('$errorMessage Response Body: ${response.body}');
        throw AiServiceException(errorMessage);
      }
      // --- End of Moved Response Parsing Logic ---
    } on http.ClientException catch (e) {
      AppLogger.error('Network error calling OpenAI API', error: e);
      throw AiServiceException(
        'Network error during API call.',
        underlyingError: e,
      );
    } catch (e, stacktrace) {
      // Catch other exceptions (like JSON parsing, etc.)
      AppLogger.error(
        'Unexpected error during AI categorization',
        error: e,
        stackTrace: stacktrace,
      );
      // Re-throw specific exception or a generic one
      if (e is AiServiceException) {
        rethrow; // Re-throw if it's already our specific type
      }
      throw AiServiceException(
        'An unexpected error occurred during categorization.',
        underlyingError: e,
      );
    }
  }

  @override
  Future<String> getChatResponse({
    required List<ChatMessage> messages,
    // CP: Removed logContext
  }) async {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      throw AiServiceException('OpenAI API Key not found.');
    }
    if (messages.isEmpty) {
      throw AiServiceException(
        'Cannot get chat response for an empty message list.',
      );
    }

    AppLogger.info(
      "Calling OpenAI API ($_modelId) for chat response. Message count: ${messages.length}",
    );

    // CP: Retrieve vector_store_id from SharedPreferences
    final String? vectorStoreId = _prefs.getString('openai_vector_store_id');
    if (vectorStoreId != null && vectorStoreId.isNotEmpty) {
      AppLogger.info("Using Vector Store ID: $vectorStoreId for File Search.");
    } else {
      AppLogger.warn(
        "No Vector Store ID found. File Search will not be enabled.",
      );
    }

    final List<Map<String, dynamic>> inputMessages =
        messages.map((msg) {
          return {
            "role": msg.sender == ChatSender.user ? "user" : "assistant",
            "content": msg.text,
          };
        }).toList();

    // CP: Updated system instructions for File Search
    const String systemInstructions =
        "You are a helpful AI assistant. Use the File Search tool to access and search the user's log entries to answer their questions. The logs are organized into daily files.";

    // CP: Prepare the request body, including system instructions as the first message
    final Map<String, dynamic> requestBody = {
      'model': _modelId,
      'input': [
        {"role": "system", "content": systemInstructions},
        ...inputMessages, // Spread the rest of the messages
      ],
      'temperature': 0.7,
    };

    // CP: Conditionally add tools for File Search
    if (vectorStoreId != null && vectorStoreId.isNotEmpty) {
      requestBody['tools'] = [
        {
          "type": "file_search",
          "vector_store_ids": [vectorStoreId],
        },
      ];
      // CP: As per OpenAI documentation, when 'tools' are used, 'instructions' parameter should not be used.
      // The system message is now part of the 'input' array.
    } else {
      // CP: If no vector store, ensure the 'input' still contains the system message.
      // This is already handled by the structure above.
      // The 'instructions' parameter is not used in this new structure.
    }

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        if (responseBody['status'] != 'completed' ||
            responseBody['error'] != null) {
          final errorMsg =
              'OpenAI chat request failed or returned an error. Status: ${responseBody['status']}. Error: ${responseBody['error']}';
          AppLogger.error(errorMsg);
          AppLogger.error('Full Chat Response Body: ${response.body}');
          throw AiServiceException(errorMsg);
        }

        if (responseBody['output'] != null &&
            responseBody['output'] is List &&
            responseBody['output'].isNotEmpty &&
            responseBody['output'][0]['type'] == 'message' &&
            responseBody['output'][0]['content'] != null &&
            responseBody['output'][0]['content'] is List &&
            responseBody['output'][0]['content'].isNotEmpty &&
            responseBody['output'][0]['content'][0]['type'] == 'output_text' &&
            responseBody['output'][0]['content'][0]['text'] != null) {
          final String aiResponseText =
              responseBody['output'][0]['content'][0]['text'];
          AppLogger.info(
            "Received chat response from OpenAI: '$aiResponseText'",
          );
          return aiResponseText;
        } else if (responseBody['output'] != null &&
            responseBody['output'] is List &&
            responseBody['output'].isNotEmpty &&
            responseBody['output'][0]['type'] == 'refusal' &&
            responseBody['output'][0]['refusal'] != null) {
          final errorMsg =
              'OpenAI refused the chat request: ${responseBody['output'][0]['refusal']}';
          AppLogger.error(errorMsg);
          throw AiServiceException(errorMsg);
        } else {
          final errorMsg =
              'Failed to parse chat response from OpenAI or unexpected structure.';
          AppLogger.error('$errorMsg Body: ${response.body}');
          throw AiServiceException(errorMsg);
        }
      } else {
        String errorMessage;
        if (response.statusCode == 400) {
          errorMessage =
              'OpenAI API error (Code: 400) for chat. Check request format or model: $_modelId.';
        } else if (response.statusCode == 401) {
          errorMessage = 'Invalid OpenAI API Key for chat.';
        } else if (response.statusCode == 429) {
          errorMessage = 'OpenAI rate limit exceeded for chat.';
        } else {
          errorMessage =
              'OpenAI API HTTP error for chat (Code: ${response.statusCode})';
        }
        AppLogger.error('$errorMessage Response Body: ${response.body}');
        throw AiServiceException(errorMessage);
      }
    } on http.ClientException catch (e) {
      AppLogger.error('Network error calling OpenAI API for chat', error: e);
      throw AiServiceException(
        'Network error during chat API call.',
        underlyingError: e,
      );
    } catch (e, stacktrace) {
      AppLogger.error(
        'Unexpected error during AI chat processing',
        error: e,
        stackTrace: stacktrace,
      );
      if (e is AiServiceException) {
        rethrow;
      }
      throw AiServiceException(
        'An unexpected error occurred during chat processing.',
        underlyingError: e,
      );
    }
  }
}
