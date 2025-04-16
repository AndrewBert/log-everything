import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entry.dart';
import 'dart:convert';

class EntryCubit extends Cubit<List<Entry>> {
  // Initialize with an empty list
  EntryCubit() : super([]);

  static const String _entriesKey = 'saved_entries_v3_categorized';

  // Load entries from SharedPreferences
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
      emit(loadedEntries); // Emit the loaded list
    } catch (e) {
      print('Cubit Error loading entries: $e. Clearing potentially incompatible data for key $_entriesKey.');
      loadSuccess = false;
      await prefs.remove(_entriesKey);
      emit([]); // Emit empty list after clearing
    }
    // Consider emitting a specific state for load failure if more complex handling is needed
  }

  // Save the current state (list of entries) to SharedPreferences
  Future<void> _saveEntries(List<Entry> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entriesJson = entries.map((entry) => entry.toJsonString()).toList();
      await prefs.setStringList(_entriesKey, entriesJson);
      print('Cubit: Saved ${entries.length} categorized entries.');
    } catch (e) {
      print('Cubit Error saving entries: $e');
      // Optionally, emit an error state or handle differently
    }
  }

  // Add a new entry
  Future<void> addEntry(String text, String category) async {
    if (text.isNotEmpty) {
      final String categoryToSave = category.trim().isNotEmpty ? category.trim() : 'General';
      final newEntry = Entry(
        text: text,
        timestamp: DateTime.now(),
        category: categoryToSave,
      );

      // Create a new list with the added entry
      // Important: Create a NEW list instance for Bloc to detect the change
      final updatedList = List<Entry>.from(state)..add(newEntry);

      emit(updatedList); // Emit the new state
      await _saveEntries(updatedList); // Save the updated list
    }
  }

  // Optional: Add a method to delete an entry if needed later
  // Future<void> deleteEntry(Entry entryToRemove) async {
  //   final updatedList = state.where((entry) => entry != entryToRemove).toList();
  //   emit(updatedList);
  //   await _saveEntries(updatedList);
  // }
}
