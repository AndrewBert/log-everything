import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../../utils/logger.dart';

class IntentDetectionService {
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_API_KEY_NOT_FOUND';
  final String _apiUrl = 'https://api.openai.com/v1/responses';
  static const String _modelId = 'gpt-5-nano';

  Future<IntentClassification> classifyIntent(String userInput) async {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      throw IntentDetectionException('OpenAI API Key not found.');
    }

    if (userInput.trim().isEmpty) {
      throw IntentDetectionException('User input cannot be empty.');
    }

    AppLogger.info("Classifying intent for input: '$userInput'");

    final systemPrompt = '''You are an intent classifier for a personal logging app.
Classify user input as either:
- "note": A statement to be logged (observations, activities, thoughts)
- "chat": A question about past logs (queries, requests for information)
- "ambiguous": Cannot confidently determine intent

Respond with JSON: {"intent": "note"|"chat"|"ambiguous", "confidence": 0.0-1.0}

Examples:
Input: "Had coffee with Sarah" → {"intent": "note", "confidence": 0.95}
Input: "When did I last have coffee?" → {"intent": "chat", "confidence": 0.92}
Input: "Coffee" → {"intent": "ambiguous", "confidence": 0.45}''';

    final requestBody = {
      'model': _modelId,
      'input': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userInput},
      ],
      'text': {
        'format': {
          'type': 'json_object',
        },
      },
      'metadata': {
        'request_type': 'intent_classification',
        'app_name': 'log-everything',
        'timestamp': DateTime.now().toIso8601String(),
        'input_length': userInput.length.toString(),
      },
    };

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        final outputs = responseData['output'] as List;
        final messageOutput = outputs.firstWhere(
          (output) => output['type'] == 'message',
          orElse: () => throw IntentDetectionException('No message output found in API response'),
        );

        final outputText = messageOutput['content'][0]['text'] as String;
        final classification = jsonDecode(outputText);

        final intentString = classification['intent'] as String;
        final confidence = (classification['confidence'] as num).toDouble();

        IntentType intentType;
        if (confidence < 0.7) {
          intentType = IntentType.ambiguous;
        } else {
          switch (intentString) {
            case 'note':
              intentType = IntentType.note;
              break;
            case 'chat':
              intentType = IntentType.chat;
              break;
            case 'ambiguous':
              intentType = IntentType.ambiguous;
              break;
            default:
              throw IntentDetectionException('Unknown intent type: $intentString');
          }
        }

        return IntentClassification(
          type: intentType,
          confidence: confidence,
          timestamp: DateTime.now(),
        );
      } else if (response.statusCode == 400) {
        throw IntentDetectionException('Bad request: ${response.body}');
      } else if (response.statusCode == 401) {
        throw IntentDetectionException('Authentication failed: Invalid API key');
      } else if (response.statusCode == 429) {
        throw IntentDetectionException('Rate limit exceeded');
      } else {
        throw IntentDetectionException('API error (${response.statusCode}): ${response.body}');
      }
    } on FormatException catch (e) {
      throw IntentDetectionException('Failed to parse API response', underlyingError: e);
    } catch (e) {
      if (e is IntentDetectionException) rethrow;
      throw IntentDetectionException('Unexpected error during intent classification', underlyingError: e);
    }
  }
}

class IntentDetectionException implements Exception {
  final String message;
  final dynamic underlyingError;

  IntentDetectionException(this.message, {this.underlyingError});

  @override
  String toString() {
    if (underlyingError != null) {
      return 'IntentDetectionException: $message (Caused by: $underlyingError)';
    }
    return 'IntentDetectionException: $message';
  }
}
