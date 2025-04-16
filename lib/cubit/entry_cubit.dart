import 'package:bloc/bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entry.dart';
import 'dart:convert';
import 'dart:math'; // For random fallback

class EntryCubit extends Cubit<List<Entry>> {
  EntryCubit() : super([]);

  static const String _entriesKey = 'saved_entries_v3_categorized'; // Keep key for now

  // --- LLM Simulation --- 
  // !! IMPORTANT: Replace this with actual API calls to an LLM service !!
  Future<String> _getCategoryFromLLM(String text) async {
    print("Simulating LLM call for text: '$text'");
    await Future.delayed(const Duration(milliseconds: 300)); // Simulate network latency

    // Simple keyword-based simulation
    final lowerText = text.toLowerCase();
    if (lowerText.contains('buy') || lowerText.contains('shop') || lowerText.contains('grocery') || lowerText.contains('costco') || lowerText.contains('amazon')) {
      return 'Shopping';
    } else if (lowerText.contains('eat') || lowerText.contains('ate') || lowerText.contains('food') || lowerText.contains('restaurant') || lowerText.contains('breakfast') || lowerText.contains('lunch') || lowerText.contains('dinner')) {
      return 'Food';
    } else if (lowerText.contains('work') || lowerText.contains('meeting') || lowerText.contains('project') || lowerText.contains('code')) {
      return 'Work';
    } else if (lowerText.contains('workout') || lowerText.contains('gym') || lowerText.contains('run') || lowerText.contains('exercise') || lowerText.contains('lift')) {
      return 'Exercise';
    } else if (lowerText.contains('sleep') || lowerText.contains('slept') || lowerText.contains('nap')) {
        return 'Sleep';
    } else if (lowerText.contains('idea') || lowerText.contains('think') || lowerText.contains('remember')) {
        return 'Idea';
    }

    // Fallback if no keywords match
    // In a real scenario, the LLM would likely provide a category anyway
    // or you might have better error handling / default category logic.
    print("LLM Simulation: No keywords matched, falling back.");
    final random = Random();
    final fallbacks = ['Personal', 'Observation', 'Misc', 'General'];
    return fallbacks[random.nextInt(fallbacks.length)];
  }

  // --- End LLM Simulation ---

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

  // Add a new entry using simulated LLM for category
  Future<void> addEntry(String text) async { // Only text is needed now
    if (text.isNotEmpty) {
      String category = 'Uncategorized'; // Default category
      try {
        // Get category from simulated LLM
        category = await _getCategoryFromLLM(text);
      } catch (e) {
        print("Error getting category from LLM simulation: $e");
        // Keep default category 'Uncategorized' on error
      }

      final newEntry = Entry(
        text: text,
        timestamp: DateTime.now(),
        category: category, // Use the determined category
      );

      final updatedList = List<Entry>.from(state)..add(newEntry);
      emit(updatedList);
      await _saveEntries(updatedList);
    }
  }
}
