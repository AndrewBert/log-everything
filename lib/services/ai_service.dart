import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/entry/category.dart';
import 'package:shared_preferences/shared_preferences.dart'; // CP: Added SharedPreferences
import '../utils/logger.dart';
import '../chat/model/chat_message.dart';
import '../utils/sse_parser.dart';
import '../dashboard_v2/model/insight.dart';
import '../dashboard_v2/model/simple_insight.dart';

// Rename field in typedef to follow Dart conventions
typedef EntryPrototype = ({String textSegment, String category, bool isTask});

typedef ImageAnalysisResult = ({
  String category,
  bool isTask,
  String imageTitle,
  String imageDescription,
  String insight,
});

// CP: Sealed class for streaming chat events
sealed class ChatStreamEvent {}

class ChatStreamDelta extends ChatStreamEvent {
  final String text;
  ChatStreamDelta(this.text);
}

class ChatStreamCompleted extends ChatStreamEvent {
  final String fullText;
  final String? responseId;
  ChatStreamCompleted(this.fullText, this.responseId);
}

class ChatStreamError extends ChatStreamEvent {
  final String message;
  ChatStreamError(this.message);
}

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

  /// Streams a chat response from the AI model using server-sent events.
  ///
  /// Similar to [getChatResponse] but returns a stream of events for real-time
  /// response generation. The stream will emit:
  /// - [ChatStreamDelta] events for incremental text
  /// - [ChatStreamCompleted] event when the response is fully generated
  /// - [ChatStreamError] event if an error occurs
  ///
  /// The stream will close after emitting a completed or error event.
  Stream<ChatStreamEvent> streamChatResponse({
    required List<ChatMessage> messages,
    DateTime? currentDate,
    bool store = true,
    String? previousResponseId,
  });

  /// Generates comprehensive insights for a log entry.
  ///
  /// Takes the [entryText] to analyze and [entryId] for identification.
  /// Optionally takes [currentDate] to provide temporal context for pattern analysis.
  /// Returns a [ComprehensiveInsight] object containing multi-dimensional
  /// insights including summary, patterns, recommendations, etc.
  /// The AI will also suggest which insight type is most valuable via the "priority" field.
  ///
  /// When a vector store is available, the AI will search historical entries
  /// to identify patterns across the user's log history.
  ///
  /// Returns a [ComprehensiveInsight] object with the analysis results.
  /// Throws an [AiServiceException] if the process fails.
  Future<ComprehensiveInsight> generateEntryInsights(String entryText, String entryId, {DateTime? currentDate});

  /// Generates a simple, playful insight for a log entry.
  ///
  /// Takes the [entryText] to analyze and [entryId] for identification.
  /// Optionally takes [currentDate] to provide temporal context.
  /// Returns a [SimpleInsight] with a brief (1-2 sentence) helpful insight.
  ///
  /// The AI uses a playful, friendly tone by default, with sensitivity on
  /// serious topics (health, anxiety, relationships).
  ///
  /// Note: This method does NOT use vector store search for pattern detection.
  /// Historical pattern analysis may be added in a future update.
  Future<SimpleInsight> generateSimpleInsight(String entryText, String entryId, {DateTime? currentDate});

  /// Analyzes an image and returns categorization and description.
  Future<ImageAnalysisResult> analyzeImage({
    required Uint8List imageBytes,
    required List<Category> categories,
    String? userNote,
  });

  /// Generates personalized chat prompt suggestions based on recent entries.
  ///
  /// Takes a list of recent [entries] and the [currentDate] for temporal context.
  /// Returns 2-3 short prompt strings that the user might want to ask about
  /// their logged data.
  ///
  /// Returns an empty list if there are fewer than 5 entries or if generation fails.
  Future<List<String>> generatePromptSuggestions({
    required List<Map<String, dynamic>> entries,
    required DateTime currentDate,
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
  static const fourPoint1Nano = 'gpt-4.1-nano-2025-04-14';
  static const gpt5 = 'gpt-5';
  static const gpt5Mini = 'gpt-5-mini';
  static const gpt5Nano = 'gpt-5-nano';
  final String _chatModelId = gpt5Mini; // Using GPT-5-mini for chat (good balance)
  final String _defaultModelId = gpt5Mini; // Using GPT-5-mini for extraction (best accuracy in tests)
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
    AppLogger.info("Calling OpenAI API ($_defaultModelId) to extract entries for text: '$text'");

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
              "is_task": {
                "type": "boolean",
                "description":
                    "Whether this entry represents a task, todo item, or action item that can be completed. True for actionable items like 'call mom', 'buy groceries', 'finish report'. False for observations, thoughts, or completed activities like 'had lunch', 'feeling good', 'it was sunny'.",
              },
            },
            "required": ["text_segment", "category", "is_task"],
            "additionalProperties": false,
          },
        },
      },
      "required": ["entries"],
      "additionalProperties": false,
    };

    // CP: Build a string listing all categories and their descriptions for the AI
    final categoriesListString = categories
        .map((cat) => cat.description.trim().isNotEmpty ? '- ${cat.name}: ${cat.description}' : '- ${cat.name}')
        .join('\n');

    // CC: Using streamlined prompt as default
    final systemPrompt =
        """You are a note-taking assistant that helps organize user logs.

Process the user's input and return JSON with:
- text: cleaned and organized version of the input
- category: select from the provided categories (use ONLY the exact category names provided)
- is_task: true if this is something to be done, false if it's an observation or completed action

BE VERY CONSERVATIVE with task detection. When in doubt, mark as NOT a task.

Mark is_task as TRUE only for:
- Concrete, specific actions: "call mom", "buy groceries", "finish presentation"
- Clear commitments with "need to" + specific action
- Direct reminders: "remind me to [specific thing]"
- Single actionable words: "groceries", "laundry", "taxes" (only if standalone)

Mark is_task as FALSE for:
- Appointments/events: "meeting at 2pm", "soccer practice at 4"
- Problems/observations: "car making noise", "running low on coffee"
- Reflections or venting (even mentioning needs)
- Vague intentions: "need to exercise more", "should eat healthier"
- Past actions or current states

Entry splitting - IMPORTANT:
- Default: Keep as ONE entry
- EXCEPTION: Split when there's a reflection/story WITH a clear embedded action
- Example: "Work was crazy today with meetings... still need to finish presentation"
  → Entry 1: "Work was crazy today with back-to-back meetings" (is_task: false)
  → Entry 2: "Finish presentation for tomorrow" (is_task: true)
- The split task entry should be concise and action-focused

Instructions override defaults:
- "make this a to-do" → is_task: true
- "note that" → is_task: false
- "clean this up" → only affects text formatting

Category selection:
- Use ONLY the exact category names provided below
- Do NOT create subcategories (e.g., don't use "Errands" if "Personal" is the category)
- Match content to the most appropriate category

Minimal text cleaning - remove filler words (um, uh) but preserve meaning.

Categories available:
$categoriesListString

Respond with a JSON object containing an "entries" array.""";

    final requestBody = {
      'model': _defaultModelId, // CC: Use GPT-5-mini for extraction
      'input': [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": text},
      ],
      'text': {
        'format': {'type': 'json_schema', 'name': 'multiple_entry_extraction', 'schema': schema, 'strict': true},
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
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_apiKey'},
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

        // CC: GPT-5 returns output with reasoning as first item, message as second
        Map<String, dynamic>? messageOutput;
        for (var output in responseBody['output']) {
          if (output['type'] == 'message' && output['content'] != null) {
            messageOutput = output;
            break;
          }
        }

        if (messageOutput != null && messageOutput['content'] is List && messageOutput['content'].isNotEmpty) {
          final contentItem = messageOutput['content'][0];

          if (contentItem['type'] == 'output_text' && contentItem['text'] != null) {
            final jsonOutputString = contentItem['text'];
            AppLogger.info("Received JSON string from OpenAI: $jsonOutputString");

            try {
              final Map<String, dynamic> parsedJson = jsonDecode(jsonOutputString);

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
                      item['category'] is String &&
                      item.containsKey('is_task') &&
                      item['is_task'] is bool) {
                    String segment = item['text_segment']; // Read from JSON key
                    String category = item['category'];
                    bool isTask = item['is_task']; // Read task detection

                    if (categoryNames.contains(category)) {
                      // Assign to the renamed typedef field
                      extractedEntries.add((textSegment: segment, category: category, isTask: isTask));
                    } else {
                      AppLogger.warn("OpenAI category ('$category') not in allowed list. Using 'Misc' for: '$segment'");
                      // Assign to the renamed typedef field
                      extractedEntries.add((textSegment: segment, category: 'Misc', isTask: isTask));
                    }
                  } else {
                    AppLogger.warn("Invalid item format in 'entries' array: $item");
                    formatErrorOccurred = true;
                  }
                }

                if (formatErrorOccurred) {
                  // Decide if partial success is acceptable or throw an error
                  throw AiServiceException("Invalid item format received in OpenAI response.");
                  // Or return extractedEntries; if partial results are okay
                }

                AppLogger.info("Successfully extracted ${extractedEntries.length} entries.");
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
      throw AiServiceException('Network error during API call.', underlyingError: e);
    } catch (e, stacktrace) {
      // Catch other exceptions (like JSON parsing, etc.)
      AppLogger.error('Unexpected error during AI categorization', error: e, stackTrace: stacktrace);
      // Re-throw specific exception or a generic one
      if (e is AiServiceException) {
        rethrow; // Re-throw if it's already our specific type
      }
      throw AiServiceException('An unexpected error occurred during categorization.', underlyingError: e);
    }
  }

  String _buildSystemInstructions(DateTime? currentDate) {
    // CP: Helper to build system instructions for chat
    final dateString = currentDate != null ? " Today's date is ${currentDate.toLocal().toString().split(' ')[0]}." : "";
    return "You are a helpful AI assistant named Trilby. Use the File Search tool to access and search the user's log entries to answer their questions. The logs are organized into daily files.$dateString When answering, speak directly about what the user did rather than referencing 'your logs show' or 'according to your data' - just state the facts naturally. When mentioning dates and times, use natural formats like 'Today at 9:36 PM', 'Yesterday at 10:15 AM', or 'Dec 28 at 3:00 PM' instead of technical formats.";
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
      throw AiServiceException('Cannot get chat response for an empty message list.');
    }

    AppLogger.info("Calling OpenAI API ($_chatModelId) for chat response. Message count: ${messages.length}");

    // CP: Log start time for chat response
    final chatStartTime = DateTime.now();

    // CP: Retrieve vector_store_id from SharedPreferences
    final String? vectorStoreId = _prefs.getString('openai_vector_store_id');
    if (vectorStoreId != null && vectorStoreId.isNotEmpty) {
      AppLogger.info("Using Vector Store ID: $vectorStoreId for File Search.");
    } else {
      AppLogger.warn("No Vector Store ID found. File Search will not be enabled.");
    }

    final List<Map<String, dynamic>> inputMessages = messages.map((msg) {
      return {"role": msg.sender == ChatSender.user ? "user" : "assistant", "content": msg.text};
    }).toList(); // CP: Updated system instructions for File Search with temporal context
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
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_apiKey'},
        body: jsonEncode(requestBody),
      );

      // CP: Log chat response duration
      final chatDuration = DateTime.now().difference(chatStartTime);
      AppLogger.info('CP: Chat response took ${chatDuration.inMilliseconds} ms');

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
                AppLogger.info("Received chat response from OpenAI (preview): '$preview'");
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
      throw AiServiceException('Network error during chat API call.', underlyingError: e);
    } catch (e, stacktrace) {
      AppLogger.error('Unexpected error during AI chat processing', error: e, stackTrace: stacktrace);
      if (e is AiServiceException) {
        rethrow;
      }
      throw AiServiceException('An unexpected error occurred during chat processing.', underlyingError: e);
    }
  }

  @override
  Stream<ChatStreamEvent> streamChatResponse({
    required List<ChatMessage> messages,
    DateTime? currentDate,
    bool store = true,
    String? previousResponseId,
  }) async* {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      yield ChatStreamError('OpenAI API Key not found.');
      return;
    }
    if (messages.isEmpty) {
      yield ChatStreamError('Cannot get chat response for an empty message list.');
      return;
    }

    // CP: Retrieve vector_store_id from SharedPreferences
    final String? vectorStoreId = _prefs.getString('openai_vector_store_id');
    if (vectorStoreId != null && vectorStoreId.isNotEmpty) {
      AppLogger.info("Using Vector Store ID: $vectorStoreId for File Search.");
    }

    final List<Map<String, dynamic>> inputMessages = messages.map((msg) {
      return {"role": msg.sender == ChatSender.user ? "user" : "assistant", "content": msg.text};
    }).toList();

    final String systemInstructions = _buildSystemInstructions(currentDate);

    final Map<String, dynamic> requestBody = {
      'model': _chatModelId,
      'input': [
        {"role": "system", "content": systemInstructions},
        ...inputMessages,
      ],
      'stream': true, // CP: Enable streaming
      'store': store,
      'metadata': {
        'request_type': 'chat_response_streaming',
        'app_name': 'log-everything',
        'message_count': messages.length.toString(),
        'has_vector_store': vectorStoreId != null && vectorStoreId.isNotEmpty ? 'true' : 'false',
        'timestamp': DateTime.now().toIso8601String(),
        'model_used': _chatModelId,
        'has_previous_response': previousResponseId != null ? 'true' : 'false',
      },
    };

    if (previousResponseId != null) {
      requestBody['previous_response_id'] = previousResponseId;
    }

    if (vectorStoreId != null && vectorStoreId.isNotEmpty) {
      requestBody['tools'] = [
        {
          "type": "file_search",
          "vector_store_ids": [vectorStoreId],
        },
      ];
    }

    try {
      final request = http.Request('POST', Uri.parse(_apiUrl));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      });
      request.body = jsonEncode(requestBody);

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        String errorMessage;
        if (streamedResponse.statusCode == 400) {
          errorMessage = 'OpenAI API error (Code: 400) for streaming chat.';
        } else if (streamedResponse.statusCode == 401) {
          errorMessage = 'Invalid OpenAI API Key for streaming chat.';
        } else if (streamedResponse.statusCode == 429) {
          errorMessage = 'OpenAI rate limit exceeded for streaming chat.';
        } else {
          errorMessage = 'OpenAI API HTTP error for streaming chat (Code: ${streamedResponse.statusCode})';
        }
        AppLogger.error('$errorMessage Response Body: $body');
        yield ChatStreamError(errorMessage);
        return;
      }

      // CP: Parse SSE stream
      final parser = SseParser();
      final StringBuffer accumulatedText = StringBuffer();
      String? responseId;

      // CP: Create a StreamController to handle the conversion
      final controller = StreamController<ChatStreamEvent>();

      // CP: Listen to parser events in the background
      parser.events.listen(
        (event) {
          try {
            final jsonData = event.jsonData;
            if (jsonData == null) return;

            switch (event.type) {
              case 'response.output_text.delta':
                final delta = jsonData['delta'] as String?;
                if (delta != null) {
                  accumulatedText.write(delta);
                  controller.add(ChatStreamDelta(delta));
                }
                break;

              case 'response.completed':
                final response = jsonData['response'] as Map<String, dynamic>?;
                responseId = response?['id'] as String?;
                controller.add(ChatStreamCompleted(accumulatedText.toString(), responseId));
                controller.close();
                break;

              case 'response.failed':
              case 'error':
                final errorMsg = jsonData['error']?['message'] ?? 'Stream failed';
                AppLogger.error('Streaming error: $errorMsg');
                controller.add(ChatStreamError(errorMsg));
                controller.close();
                break;
            }
          } catch (e) {
            AppLogger.error('Error processing SSE event: $e');
          }
        },
        onError: (error) {
          controller.add(ChatStreamError('Stream error: $error'));
          controller.close();
        },
        onDone: () {
          if (!controller.isClosed) {
            controller.close();
          }
        },
      );

      // CP: Process the HTTP stream and feed to parser
      streamedResponse.stream
          .transform(utf8.decoder)
          .listen(
            (chunk) {
              parser.processChunk(chunk);
            },
            onError: (error) {
              AppLogger.error('HTTP stream error: $error');
              controller.add(ChatStreamError('Connection error: $error'));
              controller.close();
            },
            onDone: () {
              parser.close();
            },
          );

      // CP: Yield events from our controller
      yield* controller.stream;
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error during streaming chat', error: e, stackTrace: stackTrace);
      yield ChatStreamError('An unexpected error occurred during streaming: $e');
    }
  }

  @override
  Future<ComprehensiveInsight> generateEntryInsights(String entryText, String entryId, {DateTime? currentDate}) async {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      throw AiServiceException('OpenAI API Key not found.');
    }

    AppLogger.info(
      "Generating insights for entry: '${entryText.substring(0, entryText.length > 50 ? 50 : entryText.length)}...'",
    );

    // CC: Retrieve vector_store_id for historical pattern analysis
    final String? vectorStoreId = _prefs.getString('openai_vector_store_id');
    if (vectorStoreId != null && vectorStoreId.isNotEmpty) {
      AppLogger.info("Using Vector Store ID: $vectorStoreId for historical pattern analysis.");
    } else {
      AppLogger.warn("No Vector Store ID found. Insights will be based on single entry only.");
    }

    final dateString = currentDate != null ? " Today's date is ${currentDate.toLocal().toString().split(' ')[0]}." : "";
    final prompt =
        '''
Analyze this log entry and provide a comprehensive multi-dimensional analysis in JSON format:

"$entryText"

${vectorStoreId != null ? "IMPORTANT: Use the File Search tool to search through the user's historical log entries to identify patterns, recurring themes, and behavioral trends across their entire log history. Do not analyze this entry in isolation." : ""}

IMPORTANT: Refer to the user as "you".

Provide the following insights (CRITICAL: Each insight must be brief, actionable, and suggest clear next steps):
1. Summary: One sentence capturing the essence of this entry
2. Emotion: State the primary emotion in 1-3 words, with intensity (e.g., "Excited - high", "Anxious - medium")
3. Pattern: ${vectorStoreId != null ? "Actionable insight with suggested next step based on recurring behaviors across MULTIPLE historical entries" : "Leave empty - patterns require historical data"} (leave empty if none found)
4. Theme: The topic in 1-5 words (e.g., "Work stress", "Family time", "Personal growth")
5. Recommendation: One specific, actionable step the user should take next (leave empty if none needed)

MAKE INSIGHTS ACTIONABLE: Instead of just stating what happened, suggest what the user should DO about it.

Examples of actionable insights:
- Instead of: "You've been logging food reactions frequently"
- Write: "You've logged 12 food reactions this month. Track symptoms to identify triggers?"

- Instead of: "You often work late and feel tired"
- Write: "Late work sessions causing fatigue. Set a 9pm work cutoff this week?"

- Instead of: "You're consistently exercising"
- Write: "5 workouts this week! Add strength training to your routine?"

Additionally, analyze the entry type and choose the most valuable insight to show as "priority".

First, identify the entry type:
- Brainstorming: Contains "thinking", "wondering", "maybe", "could", exploring options
- Decision-making: Contains "should I", "or", weighing choices
- Problem-solving: Contains "how to", "need to figure out", "not sure"
- Reflection: Past tense, analyzing what happened
- Activity log: Simple record of events or tasks

Then set priority based on what helps most:
- "summary": Best for brainstorming, complex thoughts, or decision-making (distills the core idea)
- "recommendation": Best when there's a clear problem to solve or decision point
- "pattern": ONLY when you find actionable patterns across their history with suggested next steps

Example priority selection:
- Brainstorming note → "summary" (e.g., "Considering auto-clean vs manual button for text editing")
- "Should I apply for this job?" → "recommendation" (e.g., "List pros/cons, then decide by Friday")
- Multiple food logs → "pattern" (e.g., "12 food reactions logged. Track symptoms to identify triggers?")

BREVITY + ACTION: Keep responses extremely concise but always suggest a clear next step when possible.

Return ONLY a JSON object with this structure:
{
  "summary": "One impactful sentence",
  "emotion": {
    "primary": "Happy",
    "secondary": [],
    "intensity": "high"
  },
  "pattern": "Actionable pattern insight with suggested next step or empty string",
  "theme": "Work productivity",
  "recommendation": "Specific action the user should take next or empty string",
  "priority": "pattern|recommendation|summary"
}
''';

    // CC: Build system instructions with file search capability for actionable insights
    final systemContent = vectorStoreId != null
        ? "You are a concise assistant that analyzes personal log entries and provides actionable insights with clear next steps. Use the File Search tool to search historical entries for patterns. Focus on what the user should DO, not just what happened. Keep all insights extremely brief (1-2 sentences max) for display on small UI cards. The logs are organized into daily files.$dateString"
        : "You are a concise assistant that analyzes personal log entries and provides actionable insights with clear next steps. Focus on what the user should DO, not just what happened. Keep all insights extremely brief (1-2 sentences max) for display on small UI cards.$dateString";

    final requestBody = {
      'model': _defaultModelId, // CC: Use GPT-4.1-mini for insights
      'input': [
        {
          'role': 'system',
          'content': systemContent,
        },
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      'text': {
        'format': {
          'type': 'json_object',
        },
      },
      'metadata': {
        'request_type': 'insight_generation',
        'app_name': 'log-everything',
        'has_vector_store': vectorStoreId != null && vectorStoreId.isNotEmpty ? 'true' : 'false',
        'timestamp': DateTime.now().toIso8601String(),
        'model_used': _defaultModelId,
      },
      // CC: GPT-5 doesn't support temperature parameter
    };

    // CC: Conditionally add tools for File Search
    if (vectorStoreId != null && vectorStoreId.isNotEmpty) {
      requestBody['tools'] = [
        {
          "type": "file_search",
          "vector_store_ids": [vectorStoreId],
        },
      ];
    }

    AppLogger.info('CC: Sending insights request with model: ${requestBody['model']}');

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(requestBody),
      );

      AppLogger.info('CC: Insights API response received. Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        if (responseBody['status'] != 'completed' || responseBody['error'] != null) {
          final errorMsg =
              'OpenAI request failed or returned an error. Status: ${responseBody['status']}. Error: ${responseBody['error']}';
          AppLogger.error(errorMsg);
          throw AiServiceException(errorMsg);
        }

        // CC: Handle different response structure when file search is used
        if (responseBody['output'] != null &&
            responseBody['output'] is List &&
            (responseBody['output'] as List).isNotEmpty) {
          // CC: When file search is enabled, need to search for the message type
          Map<String, dynamic>? messageOutputElement;
          for (final item in responseBody['output'] as List) {
            if (item is Map<String, dynamic> && item['type'] == 'message') {
              messageOutputElement = item;
              break;
            }
          }

          if (messageOutputElement != null) {
            final dynamic content = messageOutputElement['content'];
            if (content != null && content is List && content.isNotEmpty) {
              String? jsonOutputString;
              for (final item in content) {
                if (item is Map<String, dynamic> && item['type'] == 'output_text' && item['text'] != null) {
                  jsonOutputString = item['text'] as String;
                  break;
                }
              }

              if (jsonOutputString != null) {
                AppLogger.info('Successfully generated insights for entry');

                // CC: Parse JSON and create ComprehensiveInsight object
                try {
                  final json = jsonDecode(jsonOutputString);
                  return _createComprehensiveInsight(json, entryText, entryId);
                } catch (e) {
                  AppLogger.error('Failed to parse insights JSON', error: e);
                  throw AiServiceException('Failed to parse insights response', underlyingError: e);
                }
              }
            }
          } else {
            // CC: Fallback to original parsing for non-file-search responses
            if (responseBody['output'][0]['content'] != null &&
                responseBody['output'][0]['content'] is List &&
                responseBody['output'][0]['content'].isNotEmpty) {
              final contentItem = responseBody['output'][0]['content'][0];

              if (contentItem['type'] == 'output_text' && contentItem['text'] != null) {
                final jsonOutputString = contentItem['text'];
                AppLogger.info('Successfully generated insights for entry');

                try {
                  final json = jsonDecode(jsonOutputString);
                  return _createComprehensiveInsight(json, entryText, entryId);
                } catch (e) {
                  AppLogger.error('Failed to parse insights JSON', error: e);
                  throw AiServiceException('Failed to parse insights response', underlyingError: e);
                }
              }
            }
          }
        }

        throw AiServiceException('Unexpected response format from OpenAI');
      } else {
        String errorMessage;
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['error']?['message'] ?? 'Unknown error occurred';
        } catch (_) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.body}';
        }
        AppLogger.error('Failed to generate insights. Status: ${response.statusCode}, Error: $errorMessage');
        throw AiServiceException(
          'Failed to generate insights: $errorMessage',
          underlyingError: response.body,
        );
      }
    } catch (e, stackTrace) {
      if (e is AiServiceException) {
        rethrow;
      }
      AppLogger.error('Error generating entry insights', error: e, stackTrace: stackTrace);
      throw AiServiceException(
        'Failed to generate insights: ${e.toString()}',
        underlyingError: e,
      );
    }
  }

  ComprehensiveInsight _createComprehensiveInsight(Map<String, dynamic> json, String entryText, String entryId) {
    final insights = <Insight>[];
    final now = DateTime.now();
    String? priority = json['priority'] as String?;

    if (json.containsKey('summary')) {
      insights.add(
        Insight(
          id: '${entryId}_summary',
          type: InsightType.summary,
          title: 'Summary',
          content: json['summary'] as String,
          generatedAt: now,
        ),
      );
    }

    if (json.containsKey('emotion') && json['emotion'] is Map) {
      final emotionData = json['emotion'] as Map<String, dynamic>;
      final primary = emotionData['primary'] as String? ?? '';
      final secondary = (emotionData['secondary'] as List?)?.cast<String>() ?? [];
      final intensity = emotionData['intensity'] as String? ?? 'medium';

      insights.add(
        Insight(
          id: '${entryId}_emotion',
          type: InsightType.emotion,
          title: 'Emotional Analysis',
          content: primary,
          generatedAt: now,
          metadata: {
            'secondary': secondary,
            'intensity': intensity,
          },
        ),
      );
    }

    if (json.containsKey('pattern') && json['pattern'] != null && json['pattern'].toString().isNotEmpty) {
      insights.add(
        Insight(
          id: '${entryId}_pattern',
          type: InsightType.pattern,
          title: 'Pattern Recognition',
          content: json['pattern'] as String,
          generatedAt: now,
        ),
      );
    }

    if (json.containsKey('theme')) {
      insights.add(
        Insight(
          id: '${entryId}_theme',
          type: InsightType.theme,
          title: 'Theme',
          content: json['theme'] as String,
          generatedAt: now,
        ),
      );
    }

    if (json.containsKey('recommendation') &&
        json['recommendation'] != null &&
        json['recommendation'].toString().isNotEmpty) {
      insights.add(
        Insight(
          id: '${entryId}_recommendation',
          type: InsightType.recommendation,
          title: 'Recommendation',
          content: json['recommendation'] as String,
          generatedAt: now,
        ),
      );
    }

    // CP: If parsing failed, create a basic summary insight
    if (insights.isEmpty) {
      insights.add(
        Insight(
          id: '${entryId}_summary',
          type: InsightType.summary,
          title: 'Summary',
          content: 'Analysis complete.',
          generatedAt: now,
        ),
      );
    }

    return ComprehensiveInsight(
      entryId: entryId,
      entryText: entryText,
      insights: insights,
      generatedAt: now,
      priority: priority,
    );
  }

  @override
  Future<SimpleInsight> generateSimpleInsight(String entryText, String entryId, {DateTime? currentDate}) async {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      throw AiServiceException('OpenAI API Key not found.');
    }

    final dateString = currentDate != null ? " Today's date is ${currentDate.toLocal().toString().split(' ')[0]}." : "";

    final prompt =
        '''Analyze this log entry and provide a brief, helpful insight.

"$entryText"

Default tone: Playful and warm, like a witty friend who cares.
Be helpful when there's something actionable. Be encouraging for wins.
Avoid sarcasm on sensitive topics (health issues, sadness, anxiety, relationships).

Keep it to 1-2 sentences max.

Return ONLY a JSON object with this structure:
{
  "content": "Your brief insight here"
}''';

    final systemContent =
        "You are a helpful assistant that provides brief, engaging insights on personal log entries. Keep responses to 1-2 sentences for display on small UI cards.$dateString";

    final requestBody = {
      'model': _defaultModelId,
      'input': [
        {
          'role': 'system',
          'content': systemContent,
        },
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      'text': {
        'format': {
          'type': 'json_object',
        },
      },
      'metadata': {
        'request_type': 'simple_insight_generation',
        'app_name': 'log-everything',
        'timestamp': DateTime.now().toIso8601String(),
        'model_used': _defaultModelId,
      },
    };

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

        if (responseBody['status'] != 'completed' || responseBody['error'] != null) {
          final errorMsg =
              'OpenAI request failed or returned an error. Status: ${responseBody['status']}. Error: ${responseBody['error']}';
          AppLogger.error(errorMsg);
          throw AiServiceException(errorMsg);
        }

        if (responseBody['output'] != null &&
            responseBody['output'] is List &&
            (responseBody['output'] as List).isNotEmpty) {
          Map<String, dynamic>? messageOutputElement;
          for (final item in responseBody['output'] as List) {
            if (item is Map<String, dynamic> && item['type'] == 'message') {
              messageOutputElement = item;
              break;
            }
          }

          if (messageOutputElement != null) {
            final dynamic content = messageOutputElement['content'];
            if (content != null && content is List && content.isNotEmpty) {
              String? jsonOutputString;
              for (final item in content) {
                if (item is Map<String, dynamic> && item['type'] == 'output_text' && item['text'] != null) {
                  jsonOutputString = item['text'] as String;
                  break;
                }
              }

              if (jsonOutputString != null) {
                try {
                  final json = jsonDecode(jsonOutputString);
                  final content = json['content'] as String? ?? 'Insight generated.';

                  return SimpleInsight(
                    content: content,
                    generatedAt: DateTime.now(),
                  );
                } catch (e) {
                  throw AiServiceException('Failed to parse insight response', underlyingError: e);
                }
              }
            }
          }
        }

        throw AiServiceException('Unexpected response format from OpenAI');
      } else {
        String errorMessage;
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['error']?['message'] ?? 'Unknown error occurred';
        } catch (_) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.body}';
        }
        AppLogger.error('Failed to generate simple insight. Status: ${response.statusCode}, Error: $errorMessage');
        throw AiServiceException(
          'Failed to generate insight: $errorMessage',
          underlyingError: response.body,
        );
      }
    } catch (e, stackTrace) {
      if (e is AiServiceException) {
        rethrow;
      }
      AppLogger.error('Error generating simple insight', error: e, stackTrace: stackTrace);
      throw AiServiceException(
        'Failed to generate insight: ${e.toString()}',
        underlyingError: e,
      );
    }
  }

  @override
  Future<ImageAnalysisResult> analyzeImage({
    required Uint8List imageBytes,
    required List<Category> categories,
    String? userNote,
  }) async {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      throw AiServiceException('OpenAI API Key not found.');
    }
    if (categories.isEmpty) {
      throw AiServiceException('No categories provided for classification.');
    }

    AppLogger.info("Calling OpenAI Vision API (gpt-4.1) to analyze image");

    final categoryNames = categories.map((cat) => cat.name).toList();
    final categoriesListString = categories
        .map((cat) => cat.description.trim().isNotEmpty ? '- ${cat.name}: ${cat.description}' : '- ${cat.name}')
        .join('\n');

    final base64Image = base64Encode(imageBytes);
    final userNoteContext = userNote != null && userNote.isNotEmpty
        ? "\n\nUser's note about this image: \"$userNote\""
        : "";

    final prompt =
        '''Analyze this image for a personal logging app.$userNoteContext

Available categories:
$categoriesListString

Return a JSON object with:
{
  "category": "best matching category from the list above",
  "isTask": true/false (is this something actionable like a receipt to file, a whiteboard todo, etc.),
  "imageTitle": "2-4 word title for the image",
  "imageDescription": "1-2 sentence factual description of what's in the image",
  "insight": "brief interpretive reflection or helpful observation"
}

Be concise. Use ONLY category names from the provided list.''';

    final requestBody = {
      'model': fourPoint1,
      'input': [
        {
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': prompt},
            {
              'type': 'input_image',
              'image_url': 'data:image/jpeg;base64,$base64Image',
            },
          ],
        },
      ],
      'text': {
        'format': {'type': 'json_object'},
      },
      'metadata': {
        'request_type': 'image_analysis',
        'app_name': 'log-everything',
        'timestamp': DateTime.now().toIso8601String(),
        'model_used': fourPoint1,
      },
    };

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_apiKey'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        if (responseBody['status'] != 'completed' || responseBody['error'] != null) {
          throw AiServiceException(
            'OpenAI request failed. Status: ${responseBody['status']}. Error: ${responseBody['error']}',
          );
        }

        Map<String, dynamic>? messageOutput;
        for (var output in responseBody['output']) {
          if (output['type'] == 'message' && output['content'] != null) {
            messageOutput = output;
            break;
          }
        }

        if (messageOutput != null && messageOutput['content'] is List && messageOutput['content'].isNotEmpty) {
          for (final item in messageOutput['content']) {
            if (item['type'] == 'output_text' && item['text'] != null) {
              final json = jsonDecode(item['text']);

              final category = json['category'] as String? ?? 'Misc';
              final validCategory = categoryNames.contains(category) ? category : 'Misc';

              return (
                category: validCategory,
                isTask: json['isTask'] as bool? ?? false,
                imageTitle: json['imageTitle'] as String? ?? 'Image',
                imageDescription: json['imageDescription'] as String? ?? '',
                insight: json['insight'] as String? ?? '',
              );
            }
          }
        }

        throw AiServiceException('Unexpected response format from OpenAI Vision API');
      } else {
        throw AiServiceException('OpenAI Vision API HTTP error (Code: ${response.statusCode})');
      }
    } catch (e) {
      if (e is AiServiceException) rethrow;
      throw AiServiceException('Image analysis failed: ${e.toString()}', underlyingError: e);
    }
  }

  @override
  Future<List<String>> generatePromptSuggestions({
    required List<Map<String, dynamic>> entries,
    required DateTime currentDate,
  }) async {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      throw AiServiceException('OpenAI API Key not found.');
    }

    // CP: Minimum threshold - need at least 5 entries for meaningful suggestions
    if (entries.length < 5) {
      return [];
    }

    AppLogger.info("Generating prompt suggestions for ${entries.length} entries");

    final dateString = currentDate.toLocal().toString().split(' ')[0];

    // CP: Build a summary of recent entries for the AI
    final entriesSummary = entries
        .take(20)
        .map((e) {
          final text = e['text'] as String? ?? '';
          final category = e['category'] as String? ?? 'Unknown';
          final isTask = e['isTask'] as bool? ?? false;
          final isCompleted = e['isCompleted'] as bool? ?? false;
          final timestamp = e['timestamp'] as String? ?? '';
          return '- [$category] $text (task: $isTask, completed: $isCompleted, date: $timestamp)';
        })
        .join('\n');

    final prompt =
        '''Based on these recent log entries, generate 2-3 short chat prompts the user might want to ask about their data.

Today's date: $dateString

Recent entries:
$entriesSummary

Guidelines:
- Keep prompts under 8 words
- Use "I" perspective ("What did I...", "How's my...")
- Make them feel natural and conversational
- Vary the types: reflection, summary, or actionable

Quality rules:
- Reference ACTUAL content from entries, not just categories
- Don't infer goals, habits, or routines unless explicitly logged multiple times
- Prioritize patterns that appear 2+ times over single entries
- Be specific: "What did I eat?" beats "How's my nutrition?"

Examples:
- Good: "What tasks did I finish this week?" (references completed tasks)
- Good: "Summarize my work meetings" (references actual meeting entries)
- Bad: "Did I meet my fitness goals?" (no goals were set)
- Bad: "How's my health journey?" (vague, not grounded in data)

Return ONLY a JSON object with this structure:
{
  "prompts": ["prompt 1", "prompt 2", "prompt 3"]
}''';

    final requestBody = {
      'model': gpt5Mini,
      'input': [
        {
          'role': 'system',
          'content':
              'You generate short, personalized chat prompts for a personal logging app. Keep suggestions concise and relevant to the user\'s actual data.',
        },
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      'text': {
        'format': {'type': 'json_object'},
      },
      'metadata': {
        'request_type': 'prompt_suggestions',
        'app_name': 'log-everything',
        'entry_count': entries.length.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'model_used': gpt5Mini,
      },
    };

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

        if (responseBody['status'] != 'completed' || responseBody['error'] != null) {
          AppLogger.error('Prompt suggestions request failed. Status: ${responseBody['status']}');
          return [];
        }

        if (responseBody['output'] != null &&
            responseBody['output'] is List &&
            (responseBody['output'] as List).isNotEmpty) {
          Map<String, dynamic>? messageOutputElement;
          for (final item in responseBody['output'] as List) {
            if (item is Map<String, dynamic> && item['type'] == 'message') {
              messageOutputElement = item;
              break;
            }
          }

          if (messageOutputElement != null) {
            final dynamic content = messageOutputElement['content'];
            if (content != null && content is List && content.isNotEmpty) {
              String? jsonOutputString;
              for (final item in content) {
                if (item is Map<String, dynamic> && item['type'] == 'output_text' && item['text'] != null) {
                  jsonOutputString = item['text'] as String;
                  break;
                }
              }

              if (jsonOutputString != null) {
                try {
                  final json = jsonDecode(jsonOutputString);
                  final prompts = (json['prompts'] as List?)?.cast<String>() ?? [];
                  AppLogger.info('Generated ${prompts.length} prompt suggestions');
                  return prompts.take(3).toList();
                } catch (e) {
                  AppLogger.error('Failed to parse prompt suggestions JSON', error: e);
                  return [];
                }
              }
            }
          }
        }

        return [];
      } else {
        AppLogger.error('Prompt suggestions HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error generating prompt suggestions', error: e, stackTrace: stackTrace);
      return [];
    }
  }
}
