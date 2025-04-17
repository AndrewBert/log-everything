import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SpeechService {
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_API_KEY_NOT_FOUND';
  final String _apiUrl = 'https://api.openai.com/v1/audio/transcriptions';

  Future<String?> transcribeAudio(String filePath) async {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      print("SpeechService Error: OpenAI API Key not found.");
      return null; // Or throw an exception
    }
    if (!await File(filePath).exists()) {
       print("SpeechService Error: Audio file not found at path: $filePath");
       return null;
    }


    print("SpeechService: Attempting to transcribe audio file: $filePath using gpt-4o-transcribe");

    try {
      var request = http.MultipartRequest('POST', Uri.parse(_apiUrl));

      // Add headers
      request.headers['Authorization'] = 'Bearer $_apiKey';
      // Content-Type is automatically set by MultipartRequest

      // Add model
      request.fields['model'] = 'gpt-4o-transcribe'; // Use the specified model
      // Note: gpt-4o-transcribe only supports 'json' (default) or 'text' response_format
      // request.fields['response_format'] = 'text'; // Optional: uncomment if plain text is desired

      // Add file
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      // Send request
      var streamedResponse = await request.send();

      // Get response
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var responseBody = jsonDecode(response.body);
        if (responseBody['text'] != null) {
          print("SpeechService: Transcription successful.");
          return responseBody['text'];
        } else {
          print("SpeechService Error: 'text' field not found in response body.");
          print("Response Body: ${response.body}");
          return null;
        }
      } else {
        print("SpeechService Error: Transcription API request failed.");
        print("Status Code: ${response.statusCode}");
        print("Response Body: ${response.body}");
        // Add specific check for model incompatibility if needed
        if (response.statusCode == 400 && response.body.contains('model_not_found')) {
             print("Hint: Ensure the model 'gpt-4o-transcribe' is available for your API key.");
        }
        return null; // Indicate error
      }
    } catch (e, stacktrace) {
      print("SpeechService Error: Exception during transcription request: $e");
      print("Stacktrace: $stacktrace");
      return null; // Indicate error
    }
  }
}
