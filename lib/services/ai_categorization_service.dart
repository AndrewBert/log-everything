import '../entry.dart'; // Assuming EntryPrototype is defined or accessible
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart'; // Assuming logger is accessible

// Helper type for extracted entry data (can be moved here or kept in cubit)
typedef EntryPrototype = ({String text_segment, String category});

// Interface for AI Categorization Service
abstract class AiCategorizationService {
  /// Extracts categorized entry prototypes from the given text using an AI model.
  ///
  /// Takes the [text] to analyze and the list of available [categories].
  /// Returns a list of [EntryPrototype] objects.
  /// Throws an [AiCategorizationException] if the process fails.
  Future<List<EntryPrototype>> extractEntries(
    String text,
    List<String> categories,
  );
}

// Custom Exception for the service
class AiCategorizationException implements Exception {
  final String message;
  final dynamic underlyingError; // Optional: Store the original error

  AiCategorizationException(this.message, {this.underlyingError});

  @override
  String toString() {
    if (underlyingError != null) {
      return 'AiCategorizationException: $message (Caused by: $underlyingError)';
    }
    return 'AiCategorizationException: $message';
  }
}

// Concrete implementation using OpenAI
class OpenAiCategorizationService implements AiCategorizationService {
  final String _apiKey =
      dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_API_KEY_NOT_FOUND';
  final String _apiUrl = 'https://api.openai.com/v1/responses';
  final String _modelId = 'gpt-4.1-mini'; // Or 'gpt-4o'

  @override
  Future<List<EntryPrototype>> extractEntries(
    String text,
    List<String> categories,
  ) async {
    // 1. Pre-flight checks
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      throw AiCategorizationException('OpenAI API Key not found.');
    }
    if (categories.isEmpty) {
      throw AiCategorizationException(
        'No categories provided for classification.',
      );
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

      // --- Response Parsing Logic (Moved from Cubit) ---
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        if (responseBody['status'] != 'completed' ||
            responseBody['error'] != null) {
          final errorMsg =
              'OpenAI request failed or returned an error. Status: ${responseBody['status']}. Error: ${responseBody['error']}';
          AppLogger.error(errorMsg);
          AppLogger.error('Full Response Body: ${response.body}');
          throw AiCategorizationException(errorMsg);
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
                  if (item is Map<String, dynamic> &&
                      item.containsKey('text_segment') &&
                      item['text_segment'] is String &&
                      item.containsKey('category') &&
                      item['category'] is String) {
                    String segment = item['text_segment'];
                    String category = item['category'];

                    if (categories.contains(category)) {
                      extractedEntries.add((
                        text_segment: segment,
                        category: category,
                      ));
                    } else {
                      AppLogger.warning(
                        "OpenAI category ('$category') not in allowed list. Using 'Misc' for: '$segment'",
                      );
                      extractedEntries.add((
                        text_segment: segment,
                        category: 'Misc',
                      ));
                    }
                  } else {
                    AppLogger.warning(
                      "Invalid item format in 'entries' array: $item",
                    );
                    formatErrorOccurred = true;
                  }
                }

                if (formatErrorOccurred) {
                  // Decide if partial success is acceptable or throw an error
                  throw AiCategorizationException(
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
                throw AiCategorizationException(errorMsg);
              }
            } catch (e) {
              final errorMsg = 'Failed to parse JSON response from OpenAI.';
              AppLogger.error(errorMsg, error: e);
              throw AiCategorizationException(errorMsg, underlyingError: e);
            }
          } else if (contentItem['type'] == 'refusal' &&
              contentItem['refusal'] != null) {
            final errorMsg =
                'OpenAI refused the request: ${contentItem['refusal']}';
            AppLogger.error(errorMsg);
            throw AiCategorizationException(errorMsg);
          } else {
            final errorMsg =
                'Unexpected content type or format in OpenAI response.';
            AppLogger.error('$errorMsg Content Item: $contentItem');
            throw AiCategorizationException(errorMsg);
          }
        } else {
          final errorMsg = 'Failed to parse overall OpenAI response structure.';
          AppLogger.error('$errorMsg Body: ${response.body}');
          throw AiCategorizationException(errorMsg);
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
        throw AiCategorizationException(errorMessage);
      }
      // --- End of Moved Response Parsing Logic ---
    } on http.ClientException catch (e) {
      AppLogger.error('Network error calling OpenAI API', error: e);
      throw AiCategorizationException(
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
      if (e is AiCategorizationException) {
        rethrow; // Re-throw if it's already our specific type
      }
      throw AiCategorizationException(
        'An unexpected error occurred during categorization.',
        underlyingError: e,
      );
    }
  }
}
