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
  final String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  // Get category from OpenAI API
  Future<String> _getCategoryFromOpenAI(String text) async {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      print('ERROR: OpenAI API Key not found in .env file.');
      return 'Config Error'; // Return specific error category
    }

    print("Calling OpenAI API for text: '$text'");
    final List<String> possibleCategories = [
      'Food', 'Work', 'Exercise', 'Shopping', 'Idea', 'Finance',
      'Social', 'Health', 'Home', 'Commute', 'Media', 'Sleep', 'Observation', 'Misc'
    ];

    final String systemPrompt = 
        'You are a text categorization assistant. Based on the user's input, assign one of the following categories: ${possibleCategories.join(", ")}. Respond with ONLY the category name and nothing else.';
    
    final String userPrompt = text;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo', // Or use a newer/cheaper model if preferred
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.2, // Lower temperature for more deterministic category
          'max_tokens': 10, // Limit tokens as we only need one word
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['choices'] != null && responseBody['choices'].isNotEmpty) {
          String category = responseBody['choices'][0]['message']['content'].trim();
          
          // Simple validation/cleanup
          category = category.replaceAll('.', ''); // Remove trailing periods if any
          if (possibleCategories.contains(category)) {
             print("OpenAI response: Category '$category'");
            return category;
          } else {
            print("OpenAI response ('$category') not in predefined list. Falling back.");
            return 'Misc'; // Fallback if unexpected response format
          }
        } else {
          print('OpenAI Error: No choices found in response body.');
          return 'API Error';
        }
      } else {
        print('OpenAI Error: Status Code ${response.statusCode}');
        print('OpenAI Error Body: ${response.body}');
        return 'API Error'; // Return specific error category
      }
    } catch (e) {
      print('Error calling OpenAI API: $e');
      return 'Network Error'; // Return specific error category
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

  // Add a new entry using OpenAI API for category
  Future<void> addEntry(String text) async {
    if (text.isNotEmpty) {
      String category = 'Processing...'; // Indicate processing

      // Immediately add entry with processing category
      final tempEntry = Entry(
        text: text,
        timestamp: DateTime.now(),
        category: category,
      );
      // Find index if needed later for update
      final tempList = List<Entry>.from(state)..add(tempEntry);
      emit(tempList); // Emit intermediate state
      final entryIndex = tempList.length - 1; // Index of the entry we just added

      try {
        // Get category from OpenAI
        category = await _getCategoryFromOpenAI(text);
      } catch (e) {
        print("Error getting category from OpenAI: $e");
        category = 'Error'; // Assign error category if API call fails
      }

      // Create the final entry with the determined category
      final finalEntry = Entry(
        text: text, // Keep original text
        timestamp: tempEntry.timestamp, // Keep original timestamp
        category: category, 
      );

      // Update the list with the final entry
      final updatedList = List<Entry>.from(state);
      if(entryIndex < updatedList.length){ // Sanity check index
         updatedList[entryIndex] = finalEntry;
         emit(updatedList);
         await _saveEntries(updatedList); // Save the final list
      } else {
        print("Error updating entry, index out of bounds");
        // Could attempt to just add the final entry if index is wrong
         final fallbackList = List<Entry>.from(state)..add(finalEntry); // May create duplicate on race condition
         emit(fallbackList);
         await _saveEntries(fallbackList);
      }

    }
  }
}
