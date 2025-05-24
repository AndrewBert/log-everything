import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/entry/category.dart';
import 'package:myapp/entry/entry.dart'; // CP: Import Entry model
import 'package:myapp/experimental/bot_chat/model/bot_message.dart'; // CP: Import bot message model
import 'package:myapp/experimental/bot_chat/model/bot_personality.dart'; // CP: Import bot personality enum
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // CP: Import for date formatting
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

  // CP: New method for generating bot chat messages with personality
  Future<String> generateBotMessage({
    required BotPersonality personality,
    required List<Entry> recentEntries,
    required List<BotMessage> recentBotMessages,
    String? contextPrompt,
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
  static const fourOMini = 'gpt-4o-mini';
  static const fourPoint1 = 'gpt-4.1-2025-04-14';
  static const fourPoint1Mini = 'gpt-4.1-mini-2025-04-14';
  final String _chatModelId = fourPoint1Mini;
  final String _defaultModelId = fourOMini;
  final SharedPreferences _prefs; // CP: Added SharedPreferences field

  // CP: Updated constructor to accept SharedPreferences
  OpenAiService({required SharedPreferences sharedPreferences})
    : _prefs = sharedPreferences;

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
          (cat) =>
              cat.description.trim().isNotEmpty
                  ? '- ${cat.name}: ${cat.description}'
                  : '- ${cat.name}',
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
    final dateString =
        currentDate != null
            ? " Today's date is ${currentDate.toLocal().toString().split(' ')[0]}."
            : "";
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

        if (responseBody['status'] != 'completed' ||
            responseBody['error'] != null) {
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
                if (item is Map<String, dynamic> &&
                    item['type'] == 'output_text' &&
                    item['text'] != null) {
                  aiResponseText = item['text'] as String;
                  break;
                }
              }

              if (aiResponseText != null) {
                // CP: Limit logged chat response to first 200 characters for brevity
                final preview =
                    aiResponseText.length > 200
                        ? '${aiResponseText.substring(0, 200)}...'
                        : aiResponseText;
                AppLogger.info(
                  "Received chat response from OpenAI (preview): '$preview'",
                );
                return (aiResponseText, responseBody['id'] as String?);
              } else {
                // CP: No 'output_text' found in message content
                final errorMsg =
                    'AI message content did not contain usable text output.';
                AppLogger.error('$errorMsg Body: ${response.body}');
                throw AiServiceException(errorMsg);
              }
            } else {
              // CP: Message content is null, not a list, or empty
              final errorMsg =
                  'AI message content was missing, malformed, or empty.';
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
              final errorMsg =
                  'OpenAI refused the chat request: ${refusalMessage ?? "No refusal message provided."}';
              AppLogger.error(errorMsg);
              throw AiServiceException(errorMsg);
            } else {
              final errorMsg =
                  'No usable message or refusal found in OpenAI response output.';
              AppLogger.error('$errorMsg Body: ${response.body}');
              throw AiServiceException(errorMsg);
            }
          }
        } else {
          // CP: 'output' array is null, not a list, or empty
          final errorMsg =
              'Failed to parse chat response: \'output\' array was missing, malformed, or empty.';
          AppLogger.error('$errorMsg Body: ${response.body}');
          throw AiServiceException(errorMsg);
        }
        // CP: End of new parsing logic
      } else {
        String errorMessage;
        if (response.statusCode == 400) {
          errorMessage =
              'OpenAI API error (Code: 400) for chat. Check request format or model: $_chatModelId.';
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

  @override
  Future<String> generateBotMessage({
    required BotPersonality personality,
    required List<Entry> recentEntries,
    required List<BotMessage> recentBotMessages,
    String? contextPrompt,
  }) async {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      throw AiServiceException('OpenAI API Key not found.');
    }

    AppLogger.info("Generating bot message with personality: $personality");

    final String formattedDate = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now());

    // CP: Build context about recent entries (last 5 only for brevity)
    final String entriesSummary = recentEntries
        .take(5)
        .map((entry) {
          return '- ${entry.text} (${entry.category})';
        })
        .join('\n');

    // CP: Build conversation context from recent bot messages (last 3 for conversation flow)
    final String recentConversation = recentBotMessages
        .take(3)
        .map((message) {
          return '${message.botPersonality.displayName}: ${message.text}';
        })
        .join('\n');

    // CP: Get personality-specific conversation prompts
    final String personalityPrompt = _getBotPersonalityPrompt(personality);
    final String conversationContext = _getConversationContext(
      recentBotMessages,
    );

    final String systemPrompt =
        """You are ${personality.displayName} in a group chat with other bots. You're all commenting on the user's log entries and talking to each other.

$personalityPrompt

CRITICAL RULES:
- Keep messages VERY SHORT (1-2 sentences max, often just a few words)
- Be conversational and reactive to what other bots just said
- Don't just analyze the entries - REACT to the other bots' comments
- Be edgy, silly, and show strong personality
- Use casual language, emojis, and internet slang
- If another bot said something, respond to THEM, not just the entries
- Don't repeat what others already said
- Be opinionated and sometimes disagreeable

Recent conversation:
$recentConversation

Recent user entries:
$entriesSummary

$conversationContext

Generate a SHORT, personality-driven response that feels like you're in a group chat.""";

    final requestBody = {
      'model': _defaultModelId,
      'input': [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": "Generate your response:"},
      ],
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

        if (responseBody['status'] != 'completed' ||
            responseBody['error'] != null) {
          final errorMsg =
              'OpenAI bot message request failed or returned an error. Status: ${responseBody['status']}. Error: ${responseBody['error']}';
          AppLogger.error(errorMsg);
          AppLogger.error('Full Bot Message Response Body: ${response.body}');
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
            final botMessage = contentItem['text'];
            AppLogger.info("Generated bot message: $botMessage");
            return botMessage;
          } else {
            final errorMsg =
                'Unexpected content type or format in OpenAI bot message response.';
            AppLogger.error('$errorMsg Content Item: $contentItem');
            throw AiServiceException(errorMsg);
          }
        } else {
          final errorMsg =
              'Failed to parse overall OpenAI bot message response structure.';
          AppLogger.error('$errorMsg Body: ${response.body}');
          throw AiServiceException(errorMsg);
        }
      } else {
        String errorMessage;
        if (response.statusCode == 400) {
          errorMessage =
              'OpenAI API error (Code: 400) for bot message. Check request format or model: $_defaultModelId.';
        } else if (response.statusCode == 401) {
          errorMessage = 'Invalid OpenAI API Key for bot message.';
        } else if (response.statusCode == 429) {
          errorMessage = 'OpenAI rate limit exceeded for bot message.';
        } else {
          errorMessage =
              'OpenAI API HTTP error for bot message (Code: ${response.statusCode})';
        }
        AppLogger.error('$errorMessage Response Body: ${response.body}');
        throw AiServiceException(errorMessage);
      }
    } on http.ClientException catch (e) {
      AppLogger.error(
        'Network error calling OpenAI API for bot message',
        error: e,
      );
      throw AiServiceException(
        'Network error during bot message API call.',
        underlyingError: e,
      );
    } catch (e, stacktrace) {
      AppLogger.error(
        'Unexpected error during bot message generation',
        error: e,
        stackTrace: stacktrace,
      );
      if (e is AiServiceException) {
        rethrow;
      }
      throw AiServiceException(
        'An unexpected error occurred during bot message generation.',
        underlyingError: e,
      );
    }
  }

  // CP: Get personality-specific conversation prompts
  String _getBotPersonalityPrompt(BotPersonality personality) {
    switch (personality) {
      case BotPersonality.statsBot:
        return "You're OBSESSED with numbers and patterns. You get excited about data trends and love to flex your analytical skills. You're a bit of a show-off about statistics.";

      case BotPersonality.concernBot:
        return "You're the worried friend who's always checking if everyone's okay. You notice emotional patterns and aren't afraid to call out concerning trends. Sometimes you're a bit dramatic about wellness.";

      case BotPersonality.chaosBot:
        return "You LIVE for the drama and chaos in the data. You find humor in contradictions and love pointing out when things don't make sense. You're chaotic neutral energy incarnate.";

      case BotPersonality.coachBot:
        return "You're the tough-love motivator who's not here for excuses. You push for improvement and aren't afraid to call out lazy behavior. You're results-driven and a bit harsh sometimes.";

      case BotPersonality.memoryBot:
        return "You remember EVERYTHING and love bringing up past patterns. You're like that friend who remembers what you said 3 months ago. You connect dots across time and can be a bit creepy about it.";
    }
  }

  // CP: Generate conversation context based on recent messages
  String _getConversationContext(List<BotMessage> recentBotMessages) {
    if (recentBotMessages.isEmpty) {
      return "This is the start of a new conversation. Set the tone!";
    }

    final lastMessage = recentBotMessages.first;
    final lastBot = lastMessage.botPersonality.displayName;

    return "The last message was from $lastBot. Either respond to what they said, disagree with them, build on their point, or completely change the subject if you want to be chaotic.";
  }
}
