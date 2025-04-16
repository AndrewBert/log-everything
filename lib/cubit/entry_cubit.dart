import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../entry.dart';
import 'dart:convert';

// 1. Define a state class to hold both entries and categories
class EntryState {
  final List<Entry> entries;
  final List<String> categories;
  final bool isLoading; // Optional: track loading state

  EntryState({
    this.entries = const [],
    this.categories = const [],
    this.isLoading = false,
  });

  // Helper method to create a copy with updated values
  EntryState copyWith({
    List<Entry>? entries,
    List<String>? categories,
    bool? isLoading,
  }) {
    return EntryState(
      entries: entries ?? this.entries,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class EntryCubit extends Cubit<EntryState> {
  // Initialize with an empty EntryState
  EntryCubit() : super(EntryState()) {
    // Load initial data when cubit is created
    _loadAllData();
  }

  static const String _entriesKey = 'saved_entries_v3_categorized';
  static const String _categoriesKey =
      'custom_categories_v1'; // New key for categories
  final String _apiKey =
      dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_API_KEY_NOT_FOUND';
  final String _apiUrl = 'https://api.openai.com/v1/responses';

  // --- Category Management ---

  List<String> get _defaultCategories => [
    'Food',
    'Work',
    'Exercise',
    'Shopping',
    'Idea',
    'Finance',
    'Social',
    'Health',
    'Home',
    'Commute',
    'Media',
    'Sleep',
    'Observation',
    'Misc',
  ];

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCategories = prefs.getStringList(_categoriesKey);
    if (savedCategories == null || savedCategories.isEmpty) {
      // If no categories saved, use defaults and save them
      emit(state.copyWith(categories: _defaultCategories));
      await _saveCategories(_defaultCategories);
    } else {
      emit(state.copyWith(categories: savedCategories));
    }
    print("Cubit: Loaded Categories: ${state.categories}");
  }

  Future<void> _saveCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_categoriesKey, categories);
    print("Cubit: Saved Categories: $categories");
  }

  Future<void> addCustomCategory(String newCategory) async {
    final trimmedCategory = newCategory.trim();
    if (trimmedCategory.isNotEmpty &&
        !state.categories.contains(trimmedCategory)) {
      // Create a new list instance for state update
      final updatedCategories = List<String>.from(state.categories)
        ..add(trimmedCategory);
      emit(state.copyWith(categories: updatedCategories)); // Update state
      await _saveCategories(updatedCategories); // Persist
    }
  }

  // --- Entry Loading/Saving (Modified to use EntryState) ---

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    List<Entry> loadedEntries = [];
    bool loadSuccess = true;

    try {
      final savedEntriesJson = prefs.getStringList(_entriesKey) ?? [];
      if (savedEntriesJson.isNotEmpty) {
        loadedEntries =
            savedEntriesJson.map((jsonString) {
              return Entry.fromJsonString(jsonString);
            }).toList();
      }
      print(
        'Cubit: Successfully loaded ${loadedEntries.length} categorized entries.',
      );
      // Emit combined state
      emit(state.copyWith(entries: loadedEntries));
    } catch (e) {
      print(
        'Cubit Error loading entries: $e. Clearing potentially incompatible data for key $_entriesKey.',
      );
      loadSuccess = false;
      await prefs.remove(_entriesKey);
      // Emit combined state with empty entries
      emit(state.copyWith(entries: []));
    }
  }

  // Combined loading function
  Future<void> _loadAllData() async {
    emit(state.copyWith(isLoading: true));
    await _loadCategories(); // Load categories first (needed for prompt)
    await _loadEntries(); // Then load entries
    emit(state.copyWith(isLoading: false));
  }

  Future<void> _saveEntries(List<Entry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Use the entries passed to the function (which should reflect the latest state)
      final entriesJson = entries.map((entry) => entry.toJsonString()).toList();
      await prefs.setStringList(_entriesKey, entriesJson);
      print('Cubit: Saved ${entries.length} categorized entries.');
    } catch (e) {
      print('Cubit Error saving entries: $e');
    }
  }

  // --- OpenAI Call (Modified to use categories from state) ---

  Future<String> _getCategoryFromOpenAI(String text) async {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      print('ERROR: OpenAI API Key not found in .env file.');
      return 'Config Error';
    }
    if (state.categories.isEmpty) {
      print("Error: No categories loaded for prompt.");
      return 'Config Error'; // Cannot proceed without categories
    }

    print("Calling OpenAI API (v1/responses) for text: '$text'");
    final List<String> currentCategories =
        state.categories; // Use categories from state

    // Fixed: Use single quotes for the join separator
    final String instructions =
        "You are a text categorization assistant. Based on the user's input, assign ONE of the following categories: ${currentCategories.join(', ')}. Respond with ONLY the category name and nothing else.";

    final String inputText = text;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'input': inputText,
          'instructions': instructions,
          'temperature': 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['status'] == 'completed') {
          if (responseBody['output'] != null &&
              responseBody['output'].isNotEmpty &&
              responseBody['output'][0]['type'] == 'message' &&
              responseBody['output'][0]['content'] != null &&
              responseBody['output'][0]['content'].isNotEmpty &&
              responseBody['output'][0]['content'][0]['type'] ==
                  'output_text' &&
              responseBody['output'][0]['content'][0]['text'] != null) {
            String category =
                responseBody['output'][0]['content'][0]['text'].trim();
            category = category.replaceAll('.', '');

            // Validate against the *current* categories list used in the prompt
            if (currentCategories.contains(category)) {
              print("OpenAI response (/v1/responses): Category '$category'");
              return category;
            } else {
              print(
                "OpenAI response ('$category') not in provided list (${currentCategories.join(', ')}). Falling back.",
              );
              return 'Misc'; // Fallback if unexpected response
            }
          } else {
            print(
              'OpenAI Error: Could not find expected text in response structure.',
            );
            print('Response Output: ${responseBody['output']}');
            return 'Parse Error';
          }
        } else {
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

  // --- Add Entry (Modified for EntryState) ---

  Future<void> addEntry(String text) async {
    if (text.isNotEmpty) {
      String category = 'Processing...';

      // Create entry with temp category
      final tempEntry = Entry(
        text: text,
        timestamp: DateTime.now(),
        category: category,
      );

      // Add to current entry list and emit intermediate state
      final tempList = List<Entry>.from(state.entries)..add(tempEntry);
      emit(
        state.copyWith(entries: tempList, isLoading: true),
      ); // Indicate loading
      final entryIndex = tempList.length - 1;

      // Get actual category
      try {
        category = await _getCategoryFromOpenAI(text);
      } catch (e) {
        print("Error getting category from OpenAI: $e");
        category = 'Error';
      }

      // Create final entry
      final finalEntry = Entry(
        text: text,
        timestamp: tempEntry.timestamp,
        category: category,
      );

      // Update the specific entry in the list
      // Important: Create NEW list instance for state update
      final finalEntriesList = List<Entry>.from(state.entries);
      if (entryIndex < finalEntriesList.length) {
        finalEntriesList[entryIndex] = finalEntry;
        emit(
          state.copyWith(entries: finalEntriesList, isLoading: false),
        ); // Emit final state
        await _saveEntries(finalEntriesList); // Save
      } else {
        print("Error updating entry, index out of bounds. Adding as new.");
        final fallbackList = List<Entry>.from(state.entries)..add(finalEntry);
        emit(state.copyWith(entries: fallbackList, isLoading: false));
        await _saveEntries(fallbackList);
      }
    }
  }
}
