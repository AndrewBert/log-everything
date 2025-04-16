import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../entry.dart';
import 'dart:convert';

// 1. Define a state class to hold entries, categories, loading status, and errors
class EntryState {
  final List<Entry> entries;
  final List<String> categories;
  final bool isLoading; // For general loading like initial load
  final String?
  lastErrorMessage; // To hold the latest error message for UI feedback

  EntryState({
    this.entries = const [],
    this.categories = const [],
    this.isLoading = false,
    this.lastErrorMessage,
  });

  // Helper method to create a copy with updated values
  EntryState copyWith({
    List<Entry>? entries,
    List<String>? categories,
    bool? isLoading,
    String? lastErrorMessage,
    bool clearLastError = false, // Flag to explicitly clear the error message
  }) {
    return EntryState(
      entries: entries ?? this.entries,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      // If clearLastError is true, set to null, otherwise use provided or existing
      lastErrorMessage:
          clearLastError ? null : (lastErrorMessage ?? this.lastErrorMessage),
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
  static const String _categoriesKey = 'custom_categories_v1';
  final String _apiKey =
      dotenv.env['OPENAI_API_KEY'] ?? 'YOUR_API_KEY_NOT_FOUND';
  final String _apiUrl = 'https://api.openai.com/v1/responses';

  // --- Category Management ---

  List<String> get _defaultCategories => ['Misc'];

  Future<void> _loadCategories() async {
    // Clear previous error on load attempt
    emit(state.copyWith(clearLastError: true));
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCategories = prefs.getStringList(_categoriesKey);
      if (savedCategories == null || savedCategories.isEmpty) {
        emit(state.copyWith(categories: _defaultCategories));
        await _saveCategories(_defaultCategories);
      } else {
        List<String> currentCategories = List<String>.from(savedCategories);
        if (!currentCategories.contains('Misc')) {
          currentCategories.add('Misc');
        }
        emit(state.copyWith(categories: currentCategories));
      }
      print("Cubit: Loaded Categories: ${state.categories}");
    } catch (e) {
      print("Cubit Error loading categories: $e");
      emit(state.copyWith(lastErrorMessage: "Failed to load categories."));
    }
  }

  Future<void> _saveCategories(List<String> categories) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_categoriesKey, categories);
      print("Cubit: Saved Categories: $categories");
    } catch (e) {
      print("Cubit Error saving categories: $e");
      emit(state.copyWith(lastErrorMessage: "Failed to save categories."));
    }
  }

  Future<void> addCustomCategory(String newCategory) async {
    final trimmedCategory = newCategory.trim();
    if (trimmedCategory.isNotEmpty &&
        trimmedCategory != 'Misc' &&
        !state.categories.contains(trimmedCategory)) {
      final updatedCategories = List<String>.from(state.categories)
        ..add(trimmedCategory);
      // Emit state first for immediate UI update
      emit(state.copyWith(categories: updatedCategories, clearLastError: true));
      await _saveCategories(updatedCategories); // Persist
    }
  }

  Future<void> deleteCategory(String categoryToDelete) async {
    if (categoryToDelete == 'Misc') return;

    if (state.categories.contains(categoryToDelete)) {
      emit(state.copyWith(clearLastError: true));
      final updatedCategories = List<String>.from(state.categories)
        ..remove(categoryToDelete);
      final updatedEntries =
          state.entries.map((entry) {
            return entry.category == categoryToDelete
                ? Entry(
                  text: entry.text,
                  timestamp: entry.timestamp,
                  category: 'Misc', // Reassign entries to 'Misc'
                )
                : entry;
          }).toList();

      emit(
        state.copyWith(categories: updatedCategories, entries: updatedEntries),
      );
      await _saveCategories(updatedCategories);
      await _saveEntries(updatedEntries);
    }
  }

  // --- Entry Loading/Saving ---

  Future<void> _loadEntries() async {
    emit(state.copyWith(clearLastError: true));
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEntriesJson = prefs.getStringList(_entriesKey) ?? [];
      List<Entry> loadedEntries = [];
      if (savedEntriesJson.isNotEmpty) {
        loadedEntries =
            savedEntriesJson.map((jsonString) {
              try {
                return Entry.fromJsonString(jsonString);
              } catch (e) {
                print("Error parsing entry JSON: $jsonString. Error: $e");
                // Return a default or placeholder entry, or re-throw/handle differently
                // For now, returning a dummy entry to avoid crashing the map.
                // Consider filtering out invalid entries instead.
                return Entry(
                  text: "Error parsing entry",
                  timestamp: DateTime.now(),
                  category: "Error",
                );
              }
            }).toList();
        // Optionally filter out error entries if needed
        loadedEntries.removeWhere((entry) => entry.category == "Error");
      }
      print(
        'Cubit: Successfully loaded ${loadedEntries.length} categorized entries.',
      );
      emit(state.copyWith(entries: loadedEntries));
    } catch (e) {
      print(
        'Cubit Error loading entries: $e. Clearing potentially incompatible data.',
      );
      final prefs =
          await SharedPreferences.getInstance(); // Re-get prefs instance
      await prefs.remove(_entriesKey);
      emit(
        state.copyWith(
          entries: [],
          lastErrorMessage: "Failed to load entries, data cleared.",
        ),
      );
    }
  }

  Future<void> _loadAllData() async {
    emit(state.copyWith(isLoading: true, clearLastError: true));
    await _loadCategories();
    // Only proceed if category load didn't set an error
    if (state.lastErrorMessage == null) {
      await _loadEntries();
    }
    emit(state.copyWith(isLoading: false));
  }

  Future<void> _saveEntries(List<Entry> entries) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = entries.map((entry) => entry.toJsonString()).toList();
      await prefs.setStringList(_entriesKey, entriesJson);
      print('Cubit: Saved ${entries.length} categorized entries.');
    } catch (e) {
      print('Cubit Error saving entries: $e');
      emit(state.copyWith(lastErrorMessage: "Failed to save entries."));
    }
  }

  // --- OpenAI Call (Using Structured Outputs) ---

  Future<String> _getCategoryFromOpenAI(String text) async {
    String errorCategory = 'Error'; // Default category if error occurs
    String? errorMessage; // Specific message for UI

    // 1. Pre-flight checks
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      errorMessage = 'OpenAI API Key not found.';
      errorCategory = 'Config Error';
    } else if (state.categories.isEmpty) {
      errorMessage = 'No categories available for classification.';
      errorCategory = 'Config Error';
    } else if (state.categories.length == 1 &&
        state.categories.contains('Misc')) {
      // If only 'Misc' exists, no need to call API
      print("Only 'Misc' category available. Skipping OpenAI call.");
      return 'Misc';
    }

    if (errorMessage != null) {
      print("Cubit Error: $errorMessage");
      // Emit state with error message BEFORE returning error category
      emit(state.copyWith(lastErrorMessage: errorMessage));
      return errorCategory;
    }

    // 2. Prepare API Call with Structured Output
    emit(state.copyWith(clearLastError: true)); // Clear previous error
    final String modelId = 'gpt-4.1-mini'; // *** USE NEW MODEL ID ***
    print(
      "Calling OpenAI API ($modelId) for text: '$text' using Structured Output",
    );
    final List<String> currentCategories = state.categories;

    // Define the JSON schema for the desired output
    final schema = {
      "type": "object",
      "properties": {
        "category": {
          "type": "string",
          "description": "The category name for the input text",
          "enum":
              currentCategories, // Ensure output is one of the available categories
        },
      },
      "required": ["category"],
      "additionalProperties": false,
    };

    // Construct the request body according to the /v1/responses documentation
    final requestBody = {
      'model': modelId,
      'input': [
        {
          "role": "system",
          "content":
              "Categorize the user's text using the provided JSON schema.",
        },
        {"role": "user", "content": text},
      ],
      'text': {
        'format': {
          'type': 'json_schema',
          'name': 'category_assignment',
          'schema': schema,
          'strict': true, // Enforce schema adherence
        },
      },
      'temperature': 0.1, // Keep temperature low for deterministic output
      // 'max_output_tokens': 50 // Consider adding a token limit for the JSON output
    };

    // 3. Execute API Call and Handle Response/Errors
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(requestBody), // Encode the structured request body
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        // Check for API-level errors or non-completed status
        if (responseBody['status'] != 'completed' ||
            responseBody['error'] != null) {
          errorMessage =
              'OpenAI request failed or returned an error. Status: ${responseBody['status']}. Error: ${responseBody['error']}';
          errorCategory = 'API Error';
          print(errorMessage);
          print('Full Response Body: ${response.body}');
        } else if (responseBody['output'] != null &&
            responseBody['output'] is List &&
            responseBody['output'].isNotEmpty &&
            responseBody['output'][0]['content'] != null &&
            responseBody['output'][0]['content'] is List &&
            responseBody['output'][0]['content'].isNotEmpty) {
          final contentItem = responseBody['output'][0]['content'][0];

          if (contentItem['type'] == 'output_text' &&
              contentItem['text'] != null) {
            final jsonOutputString = contentItem['text'];
            print("Received JSON string from OpenAI: $jsonOutputString");

            try {
              // Parse the JSON string contained within the 'text' field
              final Map<String, dynamic> parsedJson = jsonDecode(
                jsonOutputString,
              );

              if (parsedJson.containsKey('category') &&
                  parsedJson['category'] is String) {
                String category = parsedJson['category'];
                // Double-check if the returned category is valid (though schema should guarantee it)
                if (currentCategories.contains(category)) {
                  print("OpenAI returned valid category via JSON: $category");
                  return category; // Valid category found
                } else {
                  // This case should ideally not happen with strict schema adherence
                  print(
                    "Warning: OpenAI structured output ('$category') not in allowed list ${currentCategories}. Falling back to 'Misc'.",
                  );
                  return 'Misc';
                }
              } else {
                errorMessage =
                    'Parsed JSON from OpenAI does not contain a valid "category" key.';
                errorCategory = 'Parse Error';
                print('$errorMessage JSON: $parsedJson');
              }
            } catch (e) {
              errorMessage = 'Failed to parse JSON response from OpenAI.';
              errorCategory = 'Parse Error';
              print('$errorMessage Raw text: $jsonOutputString. Error: $e');
            }
          } else if (contentItem['type'] == 'refusal' &&
              contentItem['refusal'] != null) {
            errorMessage =
                'OpenAI refused the request: ${contentItem['refusal']}';
            errorCategory = 'API Refusal';
            print(errorMessage);
          } else {
            errorMessage =
                'Unexpected content type or format in OpenAI response.';
            errorCategory = 'Parse Error';
            print('$errorMessage Content Item: $contentItem');
          }
        } else {
          errorMessage = 'Failed to parse overall OpenAI response structure.';
          errorCategory = 'Parse Error';
          print('$errorMessage Body: ${response.body}');
        }
      } else {
        // Handle HTTP errors
        // *** Potential issue: Check if the selected model supports structured output. If not, API might return 400 Bad Request ***
        if (response.statusCode == 400) {
          errorMessage =
              'OpenAI API error (Code: 400). This might be because $modelId does not support structured outputs (json_schema). Consider using gpt-4o or removing the text.format parameter.';
          errorCategory = 'API Config Error';
        } else if (response.statusCode == 401) {
          errorMessage = 'Invalid OpenAI API Key.';
          errorCategory = 'API Auth Error';
        } else if (response.statusCode == 429) {
          errorMessage = 'OpenAI rate limit exceeded.';
          errorCategory = 'API Rate Limit';
        } else {
          errorMessage = 'OpenAI API HTTP error (Code: ${response.statusCode})';
          errorCategory = 'API Network Error';
        }
        print(
          '$errorMessage Response Body: ${response.body}',
        ); // Log the error response body
      }
    } catch (e, stacktrace) {
      // Catch network or other exceptions during the request
      print('Error calling OpenAI API: $e $stacktrace');
      errorMessage = 'Network error or exception during API call.';
      errorCategory = 'Network Exception';
    }

    // 4. Final Error Handling
    // If an error occurred at any point, emit state with the message
    if (errorMessage != null) {
      emit(state.copyWith(lastErrorMessage: errorMessage));
    }
    print(
      "Returning error category: $errorCategory due to error: $errorMessage",
    );
    return errorCategory; // Return the generic error category name
  }

  // --- Entry Manipulation ---

  Future<void> addEntry(String text) async {
    if (text.isNotEmpty) {
      emit(
        state.copyWith(clearLastError: true),
      ); // Clear previous errors on new entry
      String category = 'Processing...'; // Initial temporary category

      final tempEntry = Entry(
        text: text,
        timestamp: DateTime.now(),
        category: category,
      );
      // Add temporary entry to list for immediate UI update
      final tempList = List<Entry>.from(state.entries)
        ..insert(0, tempEntry); // Insert at top
      // Set isLoading true while processing this entry
      emit(state.copyWith(entries: tempList, isLoading: true));
      final entryIndex = 0; // Index will always be 0 as we inserted at the top

      // Get actual category (this function now handles emitting errors and uses structured output)
      category = await _getCategoryFromOpenAI(text);

      // Create the final entry object
      final finalEntry = Entry(
        text: text,
        timestamp: tempEntry.timestamp, // Use original timestamp
        category: category, // Use category from API (or error/fallback)
      );

      // Update the entry in the list (assuming state hasn't drastically changed)
      // Use a fresh copy of the state entries to avoid mutation issues
      final currentEntriesList = List<Entry>.from(state.entries);

      // Check if the entry at the expected index is still the placeholder
      if (currentEntriesList.isNotEmpty &&
          entryIndex < currentEntriesList.length && // Ensure index is valid
          currentEntriesList[entryIndex].timestamp ==
              tempEntry.timestamp && // Match timestamp
          currentEntriesList[entryIndex].category == 'Processing...') {
        currentEntriesList[entryIndex] =
            finalEntry; // Replace placeholder with final entry
        // Set isLoading false after processing finishes
        emit(state.copyWith(entries: currentEntriesList, isLoading: false));
        await _saveEntries(currentEntriesList); // Save the updated list
      } else {
        // This case might happen if entries were deleted/added rapidly during processing
        print(
          "Warning: State changed during processing or placeholder not found at index $entryIndex. Adding final entry anew.",
        );
        // Attempt to remove the placeholder if it still exists somewhere else (by timestamp)
        currentEntriesList.removeWhere(
          (e) =>
              e.timestamp == tempEntry.timestamp &&
              e.category == 'Processing...',
        );
        // Add the final entry at the top
        currentEntriesList.insert(0, finalEntry);
        // Ensure sorting if needed, though adding at top usually maintains reverse chrono
        // currentEntriesList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        emit(state.copyWith(entries: currentEntriesList, isLoading: false));
        await _saveEntries(currentEntriesList);
      }

      // Ensure isLoading is false even if something went wrong above or state changed unexpectedly
      if (state.isLoading) emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> addEntryObject(Entry entryToAdd) async {
    emit(state.copyWith(clearLastError: true));
    final updatedEntries = List<Entry>.from(state.entries)..add(entryToAdd);
    updatedEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    emit(state.copyWith(entries: updatedEntries));
    await _saveEntries(updatedEntries);
    print("Cubit: Undid delete for entry - ${entryToAdd.text}");
  }

  Future<void> deleteEntry(Entry entryToDelete) async {
    emit(state.copyWith(clearLastError: true));
    final updatedEntries =
        state.entries
            .where(
              (entry) =>
                  entry.timestamp != entryToDelete.timestamp ||
                  entry.text != entryToDelete.text, // Check both for safety
            )
            .toList();
    if (updatedEntries.length < state.entries.length) {
      // Check if deletion happened
      emit(state.copyWith(entries: updatedEntries));
      await _saveEntries(updatedEntries);
    }
  }

  Future<void> updateEntry(Entry originalEntry, Entry updatedEntry) async {
    emit(state.copyWith(clearLastError: true));
    final index = state.entries.indexWhere(
      (entry) =>
          entry.timestamp == originalEntry.timestamp &&
          entry.text == originalEntry.text, // Check both for safety
    );
    if (index != -1) {
      final updatedEntries = List<Entry>.from(state.entries);
      updatedEntries[index] = updatedEntry;
      // No sorting needed here as we are updating in place
      emit(state.copyWith(entries: updatedEntries));
      await _saveEntries(updatedEntries);
    }
  }

  // Method to clear the last error message (e.g., after SnackBar dismissal)
  void clearLastError() {
    if (state.lastErrorMessage != null) {
      emit(state.copyWith(clearLastError: true));
    }
  }
}
