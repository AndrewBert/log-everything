import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'utils/logger.dart';

class SpeechService {
  final String _apiKey =
      dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_API_KEY_NOT_FOUND';
  final String _apiUrl = 'https://api.openai.com/v1/audio/transcriptions';

  // Define characters to consider as "only punctuation/symbols"
  // This can be expanded if needed
  static final _punctuationOnlyRegex = RegExp(r'^[\.,\?!;\s]*$');

  Future<String?> transcribeAudio(
    String filePath, {
    String language = 'en',
  }) async {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      AppLogger.error("OpenAI API Key not found.");
      return null;
    }

    final audioFile = File(filePath);
    if (!await audioFile.exists()) {
      AppLogger.error("Audio file not found at path: $filePath");
      return null;
    }

    final fileLength = await audioFile.length();
    if (fileLength == 0) {
      AppLogger.warn("Audio file exists but is empty: $filePath");
    }
    AppLogger.info("Audio file size: $fileLength bytes");

    AppLogger.info(
      "Attempting to transcribe audio file: $filePath using gpt-4o-transcribe (Language: $language)",
    );

    try {
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      request.headers['Authorization'] = 'Bearer $_apiKey';
      request.fields['model'] = 'gpt-4o-transcribe';
      request.fields['language'] = language;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      AppLogger.info("Transcription API Status Code: ${response.statusCode}");
      AppLogger.log("Transcription API Raw Response Body:\n${response.body}");

      if (response.statusCode == 200) {
        try {
          var responseBody = jsonDecode(response.body);
          AppLogger.log("Decoded JSON Body: ${jsonEncode(responseBody)}");

          if (responseBody is Map && responseBody.containsKey('text')) {
            final transcribedText = responseBody['text'];
            if (transcribedText is String) {
              // *** Start Sanitization ***
              final trimmedText = transcribedText.trim();

              // 1. Check if empty after trimming
              if (trimmedText.isEmpty) {
                AppLogger.warn(
                  "Transcription result is empty after trimming. Returning null.",
                  error: "Original text: '$transcribedText'",
                );
                return null;
              }

              // 2. Check if it consists only of punctuation/whitespace
              if (_punctuationOnlyRegex.hasMatch(trimmedText)) {
                AppLogger.warn(
                  "Transcription result contains only punctuation/whitespace. Returning null.",
                  error: "Original text: '$transcribedText'",
                );
                return null;
              }

              // 3. Check for excessive replacement characters
              final replacementCharCount =
                  '\uFFFD'.allMatches(trimmedText).length;
              if (replacementCharCount / trimmedText.length > 0.8) {
                AppLogger.warn(
                  "Transcription result seems garbled (mostly replacement characters). Returning null.",
                  error: "Original text: '$transcribedText'",
                );
                return null;
              }
              // *** End Sanitization ***

              AppLogger.info(
                "Transcription successful. Extracted text (first 50 chars): ${trimmedText.substring(0, trimmedText.length > 50 ? 50 : trimmedText.length)}...",
              );
              return trimmedText;
            } else {
              AppLogger.error(
                "'text' field is not a String.",
                error: "Found type: ${transcribedText.runtimeType}",
              );
              return null;
            }
          } else {
            AppLogger.error(
              "'text' field not found or response is not a Map.",
              error: "Response Body Structure: ${response.body}",
            );
            return null;
          }
        } catch (e, stackTrace) {
          AppLogger.error(
            "Error decoding JSON response from transcription API.",
            error: e,
            stackTrace: stackTrace,
          );
          AppLogger.error("Raw response body was: ${response.body}");
          return null;
        }
      } else {
        AppLogger.error(
          "Transcription API request failed.",
          error:
              "Status Code: ${response.statusCode}, Response Body: ${response.body}",
        );
        if (response.statusCode == 400 &&
            response.body.contains('model_not_found')) {
          AppLogger.warn(
            "Ensure the model 'gpt-4o-transcribe' is available for your API key.",
          );
        } else if (response.statusCode == 400 &&
            response.body.contains('language')) {
          AppLogger.warn("Invalid language code '$language' provided.");
        }
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        "Exception during transcription request",
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
