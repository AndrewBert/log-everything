import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../entry.dart';
import 'dart:convert';

class EntryCubit extends Cubit<List<Entry>> {
  EntryCubit() : super([]);

  static const String _entriesKey = 'saved_entries_v3_categorized';
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_API_KEY_NOT_FOUND';
  // Updated API URL based on the provided documentation
  final String _apiUrl = 'https://api.openai.com/v1/responses'; 

  // Get category from OpenAI API using the /v1/responses endpoint
  Future<String> _getCategoryFromOpenAI(String text) async {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      print('ERROR: OpenAI API Key not found in .env file.');
      return 'Config Error';
    }

    print("Calling OpenAI API (v1/responses) for text: '$text'");
    final List<String> possibleCategories = [
      'Food', 'Work', 'Exercise', 'Shopping', 'Idea', 'Finance',
      'Social', 'Health', 'Home', 'Commute', 'Media', 'Sleep', 'Observation', 'Misc'
    ];

    // Use the 'instructions' field for the system prompt
    final String instructions = 
        "You are a text categorization assistant. Based on the user's input, assign ONE of the following categories: ${possibleCategories.join(", ")}. Respond with ONLY the category name and nothing else.";
    
    final String inputText = text;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
          // Consider adding 'OpenAI-Beta': 'assistants=v1' or similar if required by the specific API version/features, but start without.
        },
        // Structure the body according to the /v1/responses documentation
        body: jsonEncode({
          'model': 'gpt-4o', // Using a capable model like gpt-4o is recommended 
          'input': inputText, 
          'instructions': instructions,
          'temperature': 0.1, // Keep low for deterministic category
          // max_output_tokens removed - relying on default behavior and prompt strength
          // Removed 'messages' key
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        // Check response status as per the documentation
        if (responseBody['status'] == 'completed') {
          // Navigate the new response structure
          if (responseBody['output'] != null && 
              responseBody['output'].isNotEmpty &&
              responseBody['output'][0]['type'] == 'message' &&
              responseBody['output'][0]['content'] != null &&
              responseBody['output'][0]['content'].isNotEmpty &&
              responseBody['output'][0]['content'][0]['type'] == 'output_text' &&
              responseBody['output'][0]['content'][0]['text'] != null) 
          {
            String category = responseBody['output'][0]['content'][0]['text'].trim();
            
            // Simple validation/cleanup
            category = category.replaceAll('.', ''); // Remove trailing periods if any
            if (possibleCategories.contains(category)) {
               print("OpenAI response (/v1/responses): Category '$category'");
              return category;
            } else {
              print("OpenAI response ('$category') not in predefined list or unexpected format. Falling back.");
              return 'Misc'; // Fallback if unexpected response format/content
            }
          } else {
             print('OpenAI Error: Could not find expected text in response structure.');
             print('Response Output: ${responseBody['output']}');
             return 'Parse Error';
          }
        } else {
           // Handle non-completed statuses (e.g., 'failed', 'in_progress')
           print('OpenAI Error: Response status is ${responseBody['status']}');
           if (responseBody['error'] != null) {
              print('Error Details: ${responseBody['error']}');
           }
           return 'API Status Error';
        }
      } else {
        print('OpenAI Error: Status Code ${response.statusCode}');
        print('OpenAI Error Body: ${response.body}');
        return 'API Network Error';
      }
    } catch (e) {
      print('Error calling OpenAI API: $e');
      return 'Network Exception';
    }
  }

  // Load entries (remains the same)
  Future<void> loadEntries() async {
     final prefs = await SharedPreferences.getInstance();
    List<Entry> loadedEntries = [];
    bool loadSuccess = true;

    try {
      final savedEntriesJson = prefs.getStringList(_entriesKey) ?? [];
      if (savedEntriesJson.isNotEmpty) {
        loadedEntries = savedEntriesJson.map((jsonString) {
          return Entry.fromJsonString(jsonString);
        }).toList();
      }
      print('Cubit: Successfully loaded ${loadedEntries.length} categorized entries.');
      emit(loadedEntries);
    } catch (e) {
      print('Cubit Error loading entries: $e. Clearing potentially incompatible data for key $_entriesKey.');
      loadSuccess = false;
      await prefs.remove(_entriesKey);
      emit([]);
    }
  }

  // Save entries (remains the same)
  Future<void> _saveEntries(List<Entry> entries) async {
     try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = entries.map((entry) => entry.toJsonString()).toList();
      await prefs.setStringList(_entriesKey, entriesJson);
      print('Cubit: Saved ${entries.length} categorized entries.');
    } catch (e) {
      print('Cubit Error saving entries: $e');
    }
  }

  // Add a new entry using OpenAI API (v1/responses) for category
  Future<void> addEntry(String text) async {
    if (text.isNotEmpty) {
      String category = 'Processing...';

      final tempEntry = Entry(
        text: text,
        timestamp: DateTime.now(),
        category: category,
      );
      final tempList = List<Entry>.from(state)..add(tempEntry);
      emit(tempList);
      final entryIndex = tempList.length - 1;

      try {
        category = await _getCategoryFromOpenAI(text);
      } catch (e) {
        print("Error getting category from OpenAI: $e");
        category = 'Error'; 
      }

      final finalEntry = Entry(
        text: text,
        timestamp: tempEntry.timestamp,
        category: category, 
      );

      final updatedList = List<Entry>.from(state);
      if(entryIndex < updatedList.length){ 
         updatedList[entryIndex] = finalEntry;
         emit(updatedList);
         await _saveEntries(updatedList);
      } else {
        print("Error updating entry, index out of bounds. Adding as new.");
         final fallbackList = List<Entry>.from(state)..add(finalEntry);
         emit(fallbackList);
         await _saveEntries(fallbackList);
      }
    }
  }
}
