import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/entry/category.dart';
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
    List<Category> categories, // CP: Use Category model for type safety
  );

  /// Gets a chat response from the AI model based on the provided message history
  /// and current date.
  ///
  /// Takes a list of [ChatMessage] objects representing the conversation history,
  /// the current [DateTime] to provide temporal context for queries, and optionally
  /// a previous response ID to maintain conversation context.
  ///
  /// Set [store] to false to prevent saving the response on OpenAI's servers.
  /// Set [previousResponseId] to chain this response to a previous conversation.
  ///
  /// Returns a tuple containing the response text and the response ID.
  /// Throws an [AiServiceException] if the process fails.
  Future<(String text, String? responseId)> getChatResponse({
    required List<ChatMessage> messages,
    DateTime? currentDate,
    bool store = true,
    String? previousResponseId,
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
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_API_KEY_NOT_FOUND';
  final String _apiUrl = 'https://api.openai.com/v1/responses';
  static const fourOMini = 'gpt-4o-mini';
  static const fourPoint1 = 'gpt-4.1-2025-04-14';
  static const fourPoint1Mini = 'gpt-4.1-mini-2025-04-14';
  final String _chatModelId = fourPoint1Mini;
  final String _defaultModelId = fourOMini;
  final SharedPreferences _prefs; // CP: Added SharedPreferences field

  // CP: Updated constructor to accept SharedPreferences
  OpenAiService({required SharedPreferences sharedPreferences}) : _prefs = sharedPreferences;

  @override
  Future<List<EntryPrototype>> extractEntries(
    String text,
    List<Category> categories, // CP: Use Category model for type safety
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
      "Calling OpenAI API ($_defaultModelId) to extract entries for text: '$text'",
    );

    // CP: Build enum list and schema for OpenAI using only the name field
    final categoryNames = categories.map((cat) => cat.name).toList();
    final schema = {
      "type": "object",
      "properties": {
        "entries": {
          "type": "array",
          "description": "An array of text segments extracted from the input, each assigned a category.",
          "items": {
            "type": "object",
            "properties": {
              "text_segment": {
                "type": "string",
                "description": "The specific portion of the input text relevant to this entry.",
              },
              "category": {
                "type": "string",
                "description":
                    "The category assigned to this text segment. Use only the category name from the provided list, not the description.",
                "enum": categoryNames, // Use only names
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

    // CP: Build a string listing all categories and their descriptions for the AI
    final categoriesListString = categories
        .map(
          (cat) => cat.description.trim().isNotEmpty ? '- ${cat.name}: ${cat.description}' : '- ${cat.name}',
        )
        .join('\n');

    final systemPrompt =
        """You are helping organize a user's personal log. Your job is to clean up the input text and organize it into entries without adding any new information or elaborating on what the user said.

CRITICAL RULES:
- DO NOT add, infer, or elaborate on the user's input
- DO NOT make assumptions about what the user might have meant
- Use ONLY the exact words and information provided by the user
- STRONGLY PREFER keeping related content together as ONE entry
- Multiple sentences about the same activity/topic should stay together
- Only create separate entries if they are completely unrelated activities or clearly different topics that belong to different categories
- Clean up grammar and remove filler words, but preserve the user's original meaning and tone

SPLITTING GUIDELINES:
- If all sentences relate to the same activity (like volleyball), keep them as ONE entry
- If all sentences relate to the same topic or experience, keep them as ONE entry  
- If sentences are thoughts/reflections about the same thing, keep them as ONE entry
- Only split if you have clearly different activities (like "played volleyball" AND "went grocery shopping")

Here are the available categories:
$categoriesListString

When deciding which category to use, consider both the name and the description for the best fit. When returning your answer, use only the category name from the provided list, not the description. Respond with a JSON object containing an "entries" array.""";

    final requestBody = {
      'model': _defaultModelId, // CP: Use GPT-4o mini for extraction
      'input': [
        {"role": "system", "content": systemPrompt},
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
      // CP: Add metadata to help track and organize requests in OpenAI dashboard
      'metadata': {
        'request_type': 'entry_extraction',
        'app_name': 'log-splitter',
        'category_count': categories.length.toString(),
        'input_length': text.length.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'model_used': _defaultModelId,
      },
      // 'temperature': 0.2,
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

        if (responseBody['status'] != 'completed' || responseBody['error'] != null) {
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

          if (contentItem['type'] == 'output_text' && contentItem['text'] != null) {
            final jsonOutputString = contentItem['text'];
            AppLogger.info(
              "Received JSON string from OpenAI: $jsonOutputString",
            );

            try {
              final Map<String, dynamic> parsedJson = jsonDecode(
                jsonOutputString,
              );

              if (parsedJson.containsKey('entries') && parsedJson['entries'] is List) {
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

                    if (categoryNames.contains(category)) {
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
                final errorMsg = 'Parsed JSON from OpenAI does not contain a valid "entries" key or it\'s not a list.';
                AppLogger.error('$errorMsg JSON: $parsedJson');
                throw AiServiceException(errorMsg);
              }
            } catch (e) {
              final errorMsg = 'Failed to parse JSON response from OpenAI.';
              AppLogger.error(errorMsg, error: e);
              throw AiServiceException(errorMsg, underlyingError: e);
            }
          } else if (contentItem['type'] == 'refusal' && contentItem['refusal'] != null) {
            final errorMsg = 'OpenAI refused the request: ${contentItem['refusal']}';
            AppLogger.error(errorMsg);
            throw AiServiceException(errorMsg);
          } else {
            final errorMsg = 'Unexpected content type or format in OpenAI response.';
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
              'OpenAI API error (Code: 400). Check model compatibility ($_defaultModelId) with structured output.';
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

  String _buildSystemInstructions(DateTime? currentDate) {
    // CP: Helper to build system instructions for chat
    final dateString = currentDate != null ? " Today's date is ${currentDate.toLocal().toString().split(' ')[0]}." : "";
    return "You are a helpful AI assistant. Use the File Search tool to access and search the user's log entries to answer their questions. The logs are organized into daily files.$dateString";
  }

  @override
  Future<(String text, String? responseId)> getChatResponse({
    required List<ChatMessage> messages,
    DateTime? currentDate,
    bool store = true,
    String? previousResponseId,
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
      "Calling OpenAI API ($_chatModelId) for chat response. Message count: ${messages.length}",
    );

    // CP: Log start time for chat response
    final chatStartTime = DateTime.now();

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
        messages.map(
          (msg) {
            return {
              "role": msg.sender == ChatSender.user ? "user" : "assistant",
              "content": msg.text,
            };
          },
        ).toList(); // CP: Updated system instructions for File Search with temporal context
    final String systemInstructions = _buildSystemInstructions(
      currentDate,
    ); // CP: Prepare the request body, including system instructions as the first message
    final Map<String, dynamic> requestBody = {
      'model': _chatModelId,
      'input': [
        {"role": "system", "content": systemInstructions},
        ...inputMessages, // Spread the rest of the messages
      ],
      'store': store, // CP: Control whether to store the response
      // CP: Add metadata to help track and organize chat requests in OpenAI dashboard
      'metadata': {
        'request_type': 'chat_response',
        'app_name': 'log-everything',
        'message_count': messages.length.toString(),
        'has_vector_store': vectorStoreId != null && vectorStoreId.isNotEmpty ? 'true' : 'false',
        'timestamp': DateTime.now().toIso8601String(),
        'model_used': _chatModelId,
        'has_previous_response': previousResponseId != null ? 'true' : 'false',
      },
    };

    // CP: Add previous response ID if provided
    if (previousResponseId != null) {
      requestBody['previous_response_id'] = previousResponseId;
    }

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

      // CP: Log chat response duration
      final chatDuration = DateTime.now().difference(chatStartTime);
      AppLogger.info(
        'CP: Chat response took ${chatDuration.inMilliseconds} ms',
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        if (responseBody['status'] != 'completed' || responseBody['error'] != null) {
          final errorMsg =
              'OpenAI chat request failed or returned an error. Status: ${responseBody['status']}. Error: ${responseBody['error']}';
          AppLogger.error(errorMsg);
          AppLogger.error('Full Chat Response Body: ${response.body}');
          throw AiServiceException(errorMsg);
        }

        // CP: Start of new parsing logic for chat response
        if (responseBody['output'] != null &&
            responseBody['output'] is List &&
            (responseBody['output'] as List).isNotEmpty) {
          // CP: Iterate through the output array to find the message
          Map<String, dynamic>? messageOutputElement;
          for (final item in responseBody['output'] as List) {
            if (item is Map<String, dynamic> && item['type'] == 'message') {
              messageOutputElement = item;
              break;
            }
          }
          if (messageOutputElement != null) {
            // CP: We already know this is a message type from the search above
            final dynamic content = messageOutputElement['content'];
            if (content != null && content is List && content.isNotEmpty) {
              String? aiResponseText;
              for (final item in content) {
                if (item is Map<String, dynamic> && item['type'] == 'output_text' && item['text'] != null) {
                  aiResponseText = item['text'] as String;
                  break;
                }
              }

              if (aiResponseText != null) {
                // CP: Limit logged chat response to first 200 characters for brevity
                final preview = aiResponseText.length > 200 ? '${aiResponseText.substring(0, 200)}...' : aiResponseText;
                AppLogger.info(
                  "Received chat response from OpenAI (preview): '$preview'",
                );
                return (aiResponseText, responseBody['id'] as String?);
              } else {
                // CP: No 'output_text' found in message content
                final errorMsg = 'AI message content did not contain usable text output.';
                AppLogger.error('$errorMsg Body: ${response.body}');
                throw AiServiceException(errorMsg);
              }
            } else {
              // CP: Message content is null, not a list, or empty
              final errorMsg = 'AI message content was missing, malformed, or empty.';
              AppLogger.error('$errorMsg Body: ${response.body}');
              throw AiServiceException(errorMsg);
            }
            // CP: } else if (outputType == 'refusal') { // CP: This block might be unreachable if we only look for 'message' type.
            // CP: Consider if 'refusal' can appear within the 'output' array alongside 'file_search_call'
            // CP: For now, this specific error was about not finding 'message' due to 'file_search_call' being first.
            // CP: If a 'refusal' can be the *only* relevant item, the logic might need adjustment.
            //   final refusalMessage = firstOutputElement['refusal'] as String?;
            //   final errorMsg =
            //       'OpenAI refused the chat request: ${refusalMessage ?? "No refusal message provided."}';
            //   AppLogger.error(errorMsg);
            //   throw AiServiceException(errorMsg);
            // } else {
            //   // CP: Unknown output type
            //   final errorMsg =
            //       'Unexpected output type (\'$outputType\') in OpenAI response when expecting a message.';
            //   AppLogger.error('$errorMsg Body: ${response.body}');
            //   throw AiServiceException(errorMsg);
            // }
          } else {
            // CP: No 'message' type found in the output array.
            // CP: Check for refusal as a top-level output item if no message is found.
            Map<String, dynamic>? refusalOutputElement;
            for (final item in responseBody['output'] as List) {
              if (item is Map<String, dynamic> && item['type'] == 'refusal') {
                refusalOutputElement = item;
                break;
              }
            }
            if (refusalOutputElement != null) {
              final refusalMessage = refusalOutputElement['refusal'] as String?;
              final errorMsg = 'OpenAI refused the chat request: ${refusalMessage ?? "No refusal message provided."}';
              AppLogger.error(errorMsg);
              throw AiServiceException(errorMsg);
            } else {
              final errorMsg = 'No usable message or refusal found in OpenAI response output.';
              AppLogger.error('$errorMsg Body: ${response.body}');
              throw AiServiceException(errorMsg);
            }
          }
        } else {
          // CP: 'output' array is null, not a list, or empty
          final errorMsg = 'Failed to parse chat response: \'output\' array was missing, malformed, or empty.';
          AppLogger.error('$errorMsg Body: ${response.body}');
          throw AiServiceException(errorMsg);
        }
        // CP: End of new parsing logic
      } else {
        String errorMessage;
        if (response.statusCode == 400) {
          errorMessage = 'OpenAI API error (Code: 400) for chat. Check request format or model: $_chatModelId.';
        } else if (response.statusCode == 401) {
          errorMessage = 'Invalid OpenAI API Key for chat.';
        } else if (response.statusCode == 429) {
          errorMessage = 'OpenAI rate limit exceeded for chat.';
        } else {
          errorMessage = 'OpenAI API HTTP error for chat (Code: ${response.statusCode})';
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
