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
  static const String _categoriesKey = 'custom_categories_v1'; // New key for categories
  final String _apiKey = dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_API_KEY_NOT_FOUND';
  final String _apiUrl = 'https://api.openai.com/v1/responses';

  // --- Category Management ---

  // Modified: Only include 'Misc' as the default category
  List<String> get _defaultCategories => [
      'Misc'
  ];

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCategories = prefs.getStringList(_categoriesKey);
    if (savedCategories == null || savedCategories.isEmpty) {
      // If no categories saved, use the minimal default and save it
      emit(state.copyWith(categories: _defaultCategories));
      await _saveCategories(_defaultCategories);
    } else {
      // Ensure 'Misc' is always present if loading saved categories
      List<String> currentCategories = List<String>.from(savedCategories);
      if (!currentCategories.contains('Misc')) {
          currentCategories.add('Misc');
      }
      emit(state.copyWith(categories: currentCategories));
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
    // Prevent adding 'Misc' again if it exists
    if (trimmedCategory.isNotEmpty && trimmedCategory != 'Misc' && !state.categories.contains(trimmedCategory)) {
      final updatedCategories = List<String>.from(state.categories)..add(trimmedCategory);
      emit(state.copyWith(categories: updatedCategories));
      await _saveCategories(updatedCategories);
    }
  }

  Future<void> deleteCategory(String categoryToDelete) async {
    // Prevent deleting the essential 'Misc' category
    if (categoryToDelete == 'Misc') {
      print("Cubit: Cannot delete the default 'Misc' category.");
      return;
    }

    if (state.categories.contains(categoryToDelete)) {
      print("Cubit: Deleting category '$categoryToDelete' and re-assigning entries to 'Misc'.");

      // 1. Remove the category from the list
      final updatedCategories = List<String>.from(state.categories)
        ..remove(categoryToDelete);

      // 2. Re-categorize existing entries that used the deleted category
      final updatedEntries = state.entries.map((entry) {
        if (entry.category == categoryToDelete) {
          return Entry(
              text: entry.text,
              timestamp: entry.timestamp,
              category: 'Misc'); 
        } else {
          return entry; 
        }
      }).toList();

      // 3. Emit the updated state with both lists changed
      emit(state.copyWith(
          categories: updatedCategories,
          entries: updatedEntries,
      ));

      // 4. Save both updated lists
      await _saveCategories(updatedCategories);
      await _saveEntries(updatedEntries);
    } else {
       print("Cubit: Category '$categoryToDelete' not found for deletion.");
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
        loadedEntries = savedEntriesJson.map((jsonString) {
          return Entry.fromJsonString(jsonString);
        }).toList();
      }
       print('Cubit: Successfully loaded ${loadedEntries.length} categorized entries.');
      emit(state.copyWith(entries: loadedEntries));
    } catch (e) {
      print('Cubit Error loading entries: $e. Clearing potentially incompatible data for key $_entriesKey.');
      loadSuccess = false;
      await prefs.remove(_entriesKey);
      emit(state.copyWith(entries: []));
    }
  }

  // Combined loading function
  Future<void> _loadAllData() async {
    emit(state.copyWith(isLoading: true));
    await _loadCategories();
    await _loadEntries();
    emit(state.copyWith(isLoading: false));
  }


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


  // --- OpenAI Call (Modified to use categories from state) ---

  Future<String> _getCategoryFromOpenAI(String text) async {
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      print('ERROR: OpenAI API Key not found in .env file.');
      return 'Config Error';
    }
     if (state.categories.isEmpty) {
        print("Error: No categories loaded for prompt.");
        return 'Config Error';
    }

    print("Calling OpenAI API (v1/responses) for text: '$text'");
    final List<String> currentCategories = state.categories;

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
              responseBody['output'][0]['content'][0]['text'] != null)
          {
            String category = responseBody['output'][0]['content'][0]['text'].trim();
            category = category.replaceAll('.', '');

            if (currentCategories.contains(category)) {
               print("OpenAI response (/v1/responses): Category '$category'");
              return category;
            } else {
              print("OpenAI response ('$category') not in provided list (${currentCategories.join(', ')}). Falling back to Misc.");
              return 'Misc';
            }
          } else {
             print('OpenAI Error: Could not find expected text in response structure.');
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

      final tempEntry = Entry(
        text: text,
        timestamp: DateTime.now(),
        category: category,
      );
      final tempList = List<Entry>.from(state.entries)..add(tempEntry);
      emit(state.copyWith(entries: tempList, isLoading: true));
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

      final finalEntriesList = List<Entry>.from(state.entries);
      if(entryIndex < finalEntriesList.length && finalEntriesList[entryIndex].category == 'Processing...'){
         finalEntriesList[entryIndex] = finalEntry;
         emit(state.copyWith(entries: finalEntriesList, isLoading: false));
         await _saveEntries(finalEntriesList);
      } else {
        print("Warning: Could not update entry at index $entryIndex, state might have changed. Adding as new.");
         final fallbackList = List<Entry>.from(state.entries)..add(finalEntry);
         emit(state.copyWith(entries: fallbackList, isLoading: false));
         await _saveEntries(fallbackList);
      }
    }
  }

  // Add a specific entry object back (for Undo)
  Future<void> addEntryObject(Entry entryToAdd) async {
    // Add the entry back to the list
    final updatedEntries = List<Entry>.from(state.entries)..add(entryToAdd);
    // Sort entries by timestamp descending (newest first) to maintain order
    updatedEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    emit(state.copyWith(entries: updatedEntries));
    await _saveEntries(updatedEntries);
    print("Cubit: Undid delete for entry - ${entryToAdd.text}");
  }

  // --- Delete Entry --- 
  Future<void> deleteEntry(Entry entryToDelete) async {
    final updatedEntries = state.entries.where((entry) =>
        entry.timestamp != entryToDelete.timestamp || entry.text != entryToDelete.text
    ).toList();

    if (updatedEntries.length < state.entries.length) {
      print("Cubit: Deleting entry - ${entryToDelete.text}");
      emit(state.copyWith(entries: updatedEntries));
      await _saveEntries(updatedEntries);
    } else {
       print("Cubit: Delete entry - Entry not found in current state.");
    }
  }

}
