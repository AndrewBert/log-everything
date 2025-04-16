import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../entry.dart';
import 'dart:convert';

// Helper type for extracted entry data
typedef EntryPrototype = ({String text_segment, String category});

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
      final updatedEntries = state.entries.map((entry) {
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
        loadedEntries = savedEntriesJson.map((jsonString) {
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

  // --- OpenAI Call (Extracts Multiple Entries using Structured Outputs) ---
  Future<List<EntryPrototype>> _extractEntriesFromOpenAI(String text) async {
    List<EntryPrototype> extractedEntries = []; // Default to empty list
    String? errorMessage;

    // 1. Pre-flight checks
    if (_apiKey == 'YOUR_API_KEY_NOT_FOUND') {
      errorMessage = 'OpenAI API Key not found.';
    } else if (state.categories.isEmpty) {
      errorMessage = 'No categories available for classification.';
    }

    if (errorMessage != null) {
      print("Cubit Error: $errorMessage");
      emit(state.copyWith(lastErrorMessage: errorMessage));
      return extractedEntries; // Return empty list
    }

    // 2. Prepare API Call with Structured Output for multiple entries
    emit(state.copyWith(clearLastError: true)); // Clear previous error
    final String modelId = 'gpt-4.1-mini'; // Or 'gpt-4o' if compatibility issues arise
    print(
        "Calling OpenAI API ($modelId) to extract multiple entries for text: '$text' using Structured Output");
    final List<String> currentCategories = state.categories;

    // Define the JSON schema for the desired output (array of entries)
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
                    "The specific portion of the input text relevant to this entry."
              },
              "category": {
                "type": "string",
                "description": "The category assigned to this text segment.",
                "enum": currentCategories
              }
            },
            "required": ["text_segment", "category"],
            "additionalProperties": false
          }
        }
      },
      "required": ["entries"],
      "additionalProperties": false
    };

    // Construct the request body
    final requestBody = {
      'model': modelId,
      'input': [
        {
          "role": "system",
          "content":
              "Analyze the user's text. Identify distinct pieces of information or tasks. For each piece, extract the relevant text segment and assign the most appropriate category from the provided list using the JSON schema. If a segment doesn't fit any specific category, use 'Misc'. Respond with a JSON object containing an array named 'entries' holding these structured segments."
        },
        {"role": "user", "content": text}
      ],
      'text': {
        'format': {
          'type': 'json_schema',
          'name': 'multiple_entry_extraction',
          'schema': schema,
          'strict': true // Enforce schema adherence
        }
      },
      'temperature': 0.2, // Slightly higher temp might help segmentation
      // 'max_output_tokens': 500 // Consider increasing token limit for multiple entries
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

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        // Check for API-level errors or non-completed status
        if (responseBody['status'] != 'completed' ||
            responseBody['error'] != null) {
          errorMessage =
              'OpenAI request failed or returned an error. Status: ${responseBody['status']}. Error: ${responseBody['error']}';
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
              // Parse the JSON string containing the 'entries' array
              final Map<String, dynamic> parsedJson = jsonDecode(jsonOutputString);

              if (parsedJson.containsKey('entries') &&
                  parsedJson['entries'] is List) {
                final List<dynamic> entriesListJson = parsedJson['entries'];

                for (var item in entriesListJson) {
                  if (item is Map<String, dynamic> &&
                      item.containsKey('text_segment') &&
                      item['text_segment'] is String &&
                      item.containsKey('category') &&
                      item['category'] is String) {
                    String segment = item['text_segment'];
                    String category = item['category'];

                    // Validate category against available ones (redundant with strict schema but safe)
                    if (currentCategories.contains(category)) {
                      extractedEntries.add((text_segment: segment, category: category));
                    } else {
                      print(
                          "Warning: OpenAI structured output category ('$category') not in allowed list. Using 'Misc' for segment: '$segment'");
                      extractedEntries.add((text_segment: segment, category: 'Misc'));
                    }
                  } else {
                     print("Warning: Invalid item format in 'entries' array: $item");
                     errorMessage = "Invalid item format received from OpenAI."; // Set error message for UI
                  }
                }
                 print("Successfully extracted ${extractedEntries.length} entries.");
                 // If successful, return the list
                 if (errorMessage == null) return extractedEntries;

              } else {
                errorMessage =
                    '''Parsed JSON from OpenAI does not contain a valid "entries" key or it's not a list.''';
                print('$errorMessage JSON: $parsedJson');
              }
            } catch (e) {
              errorMessage = 'Failed to parse JSON response from OpenAI.';
              print('$errorMessage Raw text: $jsonOutputString. Error: $e');
            }
          } else if (contentItem['type'] == 'refusal' &&
              contentItem['refusal'] != null) {
            errorMessage =
                'OpenAI refused the request: ${contentItem['refusal']}';
            print(errorMessage);
          } else {
            errorMessage =
                'Unexpected content type or format in OpenAI response.';
            print('$errorMessage Content Item: $contentItem');
          }
        } else {
          errorMessage = 'Failed to parse overall OpenAI response structure.';
          print('$errorMessage Body: ${response.body}');
        }
      } else {
        // Handle HTTP errors
        if (response.statusCode == 400) {
          errorMessage =
              'OpenAI API error (Code: 400). This might be because $modelId does not support the requested structured output schema (json_schema). Consider using gpt-4o or simplifying the schema.';
        } else if (response.statusCode == 401) {
          errorMessage = 'Invalid OpenAI API Key.';
        } else if (response.statusCode == 429) {
          errorMessage = 'OpenAI rate limit exceeded.';
        } else {
          errorMessage = 'OpenAI API HTTP error (Code: ${response.statusCode})';
        }
        print('$errorMessage Response Body: ${response.body}');
      }
    } catch (e, stacktrace) {
      // Catch network or other exceptions during the request
      print('''Error calling OpenAI API: $e
$stacktrace''');
      errorMessage = 'Network error or exception during API call.';
    }

    // 4. Final Error Handling
    if (errorMessage != null) {
      emit(state.copyWith(lastErrorMessage: errorMessage));
    }
    print(
      "Returning ${extractedEntries.length} entries. Error (if any): $errorMessage",
    );
    return extractedEntries; // Return list (empty if errors occurred)
  }

  // --- Entry Manipulation (Modified for Multiple Entries) ---

  Future<void> addEntry(String text) async {
    if (text.isNotEmpty) {
      emit(state.copyWith(
          isLoading: true,
          clearLastError: true)); // Set loading true, clear previous errors

      List<EntryPrototype> extractedData = await _extractEntriesFromOpenAI(text);

      if (extractedData.isEmpty) {
         // If nothing was extracted (or an error occurred in extraction),
         // potentially add the original text as 'Misc' or show error from emit()
          if (state.lastErrorMessage == null) { // Only add Misc if no specific error was emitted
             print("No entries extracted by AI, adding original text as Misc.");
             final fallbackEntry = Entry(
                 text: text, timestamp: DateTime.now(), category: 'Misc');
             final updatedEntries = List<Entry>.from(state.entries)..insert(0, fallbackEntry);
             emit(state.copyWith(entries: updatedEntries, isLoading: false));
             await _saveEntries(updatedEntries);
          } else {
             print("Error occurred during extraction, not adding fallback entry.");
             emit(state.copyWith(isLoading: false)); // Ensure loading is turned off
          }
          return; // Exit early
      }

      // Create final Entry objects from extracted data
      final List<Entry> newEntries = [];
      final DateTime now = DateTime.now(); // Use the same timestamp for all entries from this input
      for (var data in extractedData) {
        newEntries.add(Entry(
          text: data.text_segment,
          timestamp: now,
          category: data.category,
        ));
      }

      // Update the state with the new entries added to the top
      final updatedEntries = List<Entry>.from(state.entries);
      updatedEntries.insertAll(0, newEntries);

      // Update state and save
      emit(state.copyWith(entries: updatedEntries, isLoading: false));
      await _saveEntries(updatedEntries);
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
    final updatedEntries = state.entries
        .where((entry) =>
            !(entry.timestamp == entryToDelete.timestamp &&
              entry.text == entryToDelete.text)) // More precise check
        .toList();
    if (updatedEntries.length < state.entries.length) {
      // Check if deletion happened
      emit(state.copyWith(entries: updatedEntries));
      await _saveEntries(updatedEntries);
    }
  }

  Future<void> updateEntry(Entry originalEntry, Entry updatedEntry) async {
    emit(state.copyWith(clearLastError: true));
    final index = state.entries.indexWhere((entry) =>
        entry.timestamp == originalEntry.timestamp &&
        entry.text == originalEntry.text); // More precise check
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
