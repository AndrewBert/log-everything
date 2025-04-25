import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';

import '../entry.dart';
import '../../utils/logger.dart';
import '../../services/ai_categorization_service.dart';
import '../../services/entry_persistence_service.dart';
import '../../locator.dart'; // <-- Import locator

part 'entry_state.dart';

class EntryCubit extends Cubit<EntryState> {
  final AiCategorizationService _aiService;
  final EntryPersistenceService _persistenceService;

  // Modify constructor to use locator
  EntryCubit()
    : _aiService = locator<AiCategorizationService>(), // <-- Get from locator
      _persistenceService =
          locator<EntryPersistenceService>(), // <-- Get from locator
      super(EntryState()) {
    _loadAllData();
  }

  final Map<DateTime, Timer> _newEntryTimers = {};
  static const Duration _newEntryHighlightDuration = Duration(seconds: 5);

  @override
  Future<void> close() async {
    _newEntryTimers.forEach((_, timer) => timer.cancel());
    _newEntryTimers.clear();
    super.close();
  }

  void _markEntryAsNotNewAfterDelay(Entry entry) {
    _newEntryTimers[entry.timestamp] = Timer(_newEntryHighlightDuration, () {
      if (!isClosed) {
        final index = state.entries.indexWhere(
          (e) => e.timestamp == entry.timestamp && e.text == entry.text,
        );
        if (index != -1) {
          final updatedEntries = List<Entry>.from(state.entries);
          updatedEntries[index] = entry.copyWith(isNew: false);

          // Recalculate display list when 'isNew' changes
          final newDisplayList = _buildDisplayList(
            updatedEntries,
            state.filterCategory,
          );
          emit(
            state.copyWith(
              entries: updatedEntries,
              displayListItems: newDisplayList,
            ),
          );
          _saveEntries(updatedEntries); // Call the cubit's save method
        }
        _newEntryTimers.remove(entry.timestamp);
      }
    });
  }

  // --- Category Management ---

  Future<void> _loadCategories() async {
    emit(state.copyWith(clearLastError: true));
    try {
      // Use persistence service
      final loadedCategories = await _persistenceService.loadCategories();
      emit(state.copyWith(categories: loadedCategories));
      AppLogger.info("Cubit: Loaded Categories: ${state.categories}");
    } catch (e) {
      AppLogger.error("Cubit: Error loading categories", error: e);
      emit(state.copyWith(lastErrorMessage: "Failed to load categories."));
      // Optionally emit default categories from service as fallback?
      // emit(state.copyWith(categories: _persistenceService.getDefaultCategories()));
    }
  }

  Future<void> _saveCategories(List<String> categories) async {
    emit(state.copyWith(clearLastError: true));
    try {
      // Use persistence service
      await _persistenceService.saveCategories(categories);
      AppLogger.info("Cubit: Saved Categories: $categories");
    } catch (e) {
      AppLogger.error("Cubit: Error saving categories", error: e);
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
      // Emit state first for responsiveness
      emit(state.copyWith(categories: updatedCategories, clearLastError: true));
      // Then save using the service
      await _saveCategories(updatedCategories);
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
                ? entry.copyWith(category: 'Misc')
                : entry;
          }).toList();

      // Recalculate display list after updating entries
      final newDisplayList = _buildDisplayList(
        updatedEntries,
        state.filterCategory,
      );

      // Emit state first
      emit(
        state.copyWith(
          categories: updatedCategories,
          entries: updatedEntries,
          displayListItems: newDisplayList,
          // Clear filter if the deleted category was the selected filter
          clearFilter: state.filterCategory == categoryToDelete,
        ),
      );
      // Then save using the service
      await _saveCategories(updatedCategories);
      await _saveEntries(updatedEntries);
    }
  }

  // Method to rename a category
  Future<void> renameCategory(String oldName, String newName) async {
    final trimmedNewName = newName.trim();
    if (oldName == 'Misc' ||
        trimmedNewName.isEmpty ||
        oldName == trimmedNewName) {
      return; // Cannot rename Misc, empty name, or same name
    }

    // Check if new name already exists (case-insensitive)
    if (state.categories.any(
      (c) => c.toLowerCase() == trimmedNewName.toLowerCase(),
    )) {
      AppLogger.warning(
        'Rename failed: Category "$trimmedNewName" already exists.',
      );
      return; // Avoid renaming if the new name conflicts
    }

    final updatedCategories =
        state.categories.map((c) => c == oldName ? trimmedNewName : c).toList();
    final updatedEntries =
        state.entries.map((entry) {
          return entry.category == oldName
              ? entry.copyWith(category: trimmedNewName)
              : entry;
        }).toList();

    // Recalculate display list after updating entries
    final newDisplayList = _buildDisplayList(
      updatedEntries,
      state.filterCategory == oldName
          ? trimmedNewName
          : state.filterCategory, // Update filter if it was the old name
    );

    // Emit state first
    emit(
      state.copyWith(
        entries: updatedEntries,
        categories: updatedCategories,
        displayListItems: newDisplayList, // Update the display list
        // Update filter category in state if it was the one being renamed
        filterCategory:
            state.filterCategory == oldName
                ? trimmedNewName
                : state.filterCategory,
      ),
    );
    // Then save using the service
    await _saveEntries(updatedEntries);
    await _saveCategories(updatedCategories);
  }

  // --- Entry Loading/Saving ---
  Future<void> _loadEntries() async {
    emit(state.copyWith(clearLastError: true));
    List<Entry> loadedEntries = [];
    try {
      // Use persistence service
      loadedEntries = await _persistenceService.loadEntries();
      AppLogger.info(
        'Cubit: Successfully loaded ${loadedEntries.length} entries.',
      );
      // Calculate display list after loading
      final newDisplayList = _buildDisplayList(
        loadedEntries,
        null,
      ); // No filter initially
      emit(
        state.copyWith(
          entries: loadedEntries,
          displayListItems: newDisplayList,
        ),
      );
    } catch (e) {
      AppLogger.error(
        'Cubit: Error loading entries. Clearing potentially incompatible data.',
        error: e,
      );
      emit(
        state.copyWith(
          entries: [],
          displayListItems: [], // Clear display list on error
          lastErrorMessage: "Failed to load entries.", // More generic message
        ),
      );
    }
  }

  Future<void> _loadAllData() async {
    emit(state.copyWith(isLoading: true, clearLastError: true));
    await _loadCategories();
    if (state.lastErrorMessage == null) {
      await _loadEntries(); // This now calculates and emits displayListItems
    }
    // Loading is finished, ensure isLoading is false, keep loaded data
    emit(state.copyWith(isLoading: false));
  }

  Future<void> _saveEntries(List<Entry> entries) async {
    try {
      // Use persistence service
      await _persistenceService.saveEntries(entries);
      AppLogger.info('Cubit: Saved ${entries.length} entries.');
    } catch (e) {
      AppLogger.error('Cubit: Error saving entries', error: e);
      emit(state.copyWith(lastErrorMessage: "Failed to save entries."));
    }
  }

  // --- Helper to build the display list ---
  List<dynamic> _buildDisplayList(List<Entry> entries, String? filterCategory) {
    // Apply filtering
    final List<Entry> filteredEntries =
        filterCategory == null
            ? entries
            : entries
                .where((entry) => entry.category == filterCategory)
                .toList();

    // Sort entries by timestamp (descending) - applied before grouping
    filteredEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (filteredEntries.isEmpty) {
      return []; // Return empty list if no entries match
    }

    // Group entries by date
    final groupedEntries = groupBy<Entry, DateTime>(
      filteredEntries,
      (entry) => DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      ),
    );

    // Sort dates descending
    final sortedDates =
        groupedEntries.keys.toList()..sort((a, b) => b.compareTo(a));

    // Create the final list with headers and entries
    final List<dynamic> listItems = [];
    for (var date in sortedDates) {
      listItems.add(date); // Add date header
      // Entries within the date are already sorted by timestamp descending
      listItems.addAll(groupedEntries[date]!); // Add entries for that date
    }

    return listItems;
  }

  // --- Method to set the filter ---
  void setFilter(String? category) {
    AppLogger.info(
      "Setting filter to: ${category ?? 'null'}",
    ); // Log the attempt
    final newDisplayList = _buildDisplayList(state.entries, category);
    emit(
      state.copyWith(
        // Pass the category value. It's used if non-null and clearFilter is false.
        filterCategory: category,
        // Explicitly set clearFilter to true when the desired category is null.
        clearFilter: category == null,
        displayListItems: newDisplayList,
        clearLastError: true, // Clear any previous errors when filter changes
      ),
    );
  }

  // --- Entry Manipulation ---
  Future<void> addEntry(String text) async {
    if (text.isEmpty) return;

    // 1. Create a temporary processing entry
    final DateTime processingTimestamp = DateTime.now();
    final tempEntry = Entry(
      text: text, // Use original text for temporary display
      timestamp: processingTimestamp,
      category: 'Processing...', // Temporary category
      isNew: true,
    );

    // 2. Add temporary entry and emit state immediately
    List<Entry> currentEntries = List<Entry>.from(state.entries);
    currentEntries.insert(0, tempEntry);
    final tempDisplayList = _buildDisplayList(
      currentEntries,
      state.filterCategory,
    );
    emit(
      state.copyWith(
        entries: currentEntries,
        displayListItems: tempDisplayList,
        isLoading: true, // Indicate background processing
        clearLastError: true,
      ),
    );
    // Don't save the temporary entry yet

    // 3. Perform AI categorization in the background
    List<EntryPrototype> extractedData = [];
    String? serviceError;
    try {
      extractedData = await _aiService.extractEntries(text, state.categories);
    } on AiCategorizationException catch (e) {
      AppLogger.error(
        "AI Service failed: ${e.message}",
        error: e.underlyingError,
      );
      serviceError = e.message;
    } catch (e, stacktrace) {
      AppLogger.error(
        "Unexpected error calling AI Service",
        error: e,
        stackTrace: stacktrace,
      );
      serviceError = "An unexpected error occurred during categorization.";
    }

    // 4. Process results and update/replace the temporary entry
    List<Entry> finalEntries = List<Entry>.from(state.entries);
    // Find the index of the temporary entry (match by timestamp and initial text)
    final tempIndex = finalEntries.indexWhere(
      (e) =>
          e.timestamp == processingTimestamp &&
          e.text == text &&
          e.category == 'Processing...',
    );

    if (tempIndex != -1) {
      // Remove the temporary entry
      finalEntries.removeAt(tempIndex);

      if (serviceError != null) {
        // AI failed, update the temp entry to Misc with error indication (optional)
        // Or just revert to a standard 'Misc' entry
        final fallbackEntry = Entry(
          text: text,
          timestamp: processingTimestamp, // Keep original timestamp
          category: 'Misc', // Fallback category
          isNew: true,
        );
        finalEntries.insert(tempIndex, fallbackEntry);
        _markEntryAsNotNewAfterDelay(fallbackEntry);
        emit(
          state.copyWith(isLoading: false, lastErrorMessage: serviceError),
        ); // Emit error
      } else if (extractedData.isEmpty) {
        // AI returned no specific entries, update temp entry to Misc
        final fallbackEntry = Entry(
          text: text,
          timestamp: processingTimestamp,
          category: 'Misc',
          isNew: true,
        );
        finalEntries.insert(tempIndex, fallbackEntry);
        _markEntryAsNotNewAfterDelay(fallbackEntry);
      } else {
        // AI succeeded, insert the new categorized entries
        final List<Entry> newEntries = [];
        for (var data in extractedData) {
          final newEntry = Entry(
            text: data.text_segment,
            timestamp:
                processingTimestamp, // Use consistent timestamp for related entries
            category: data.category,
            isNew: true,
          );
          newEntries.add(newEntry);
          _markEntryAsNotNewAfterDelay(newEntry);
        }
        // Insert new entries at the original temporary entry position
        finalEntries.insertAll(tempIndex, newEntries);
      }
    } else {
      // Should not happen if state management is correct, but log if it does
      AppLogger.warning("Temporary processing entry not found for update.");
      // If temp entry wasn't found, handle error/fallback appropriately
      if (serviceError != null) {
        emit(state.copyWith(isLoading: false, lastErrorMessage: serviceError));
      }
    }

    // 5. Recalculate display list and emit final state
    final finalDisplayList = _buildDisplayList(
      finalEntries,
      state.filterCategory,
    );
    // Add haptic feedback after processing is complete
    HapticFeedback.mediumImpact();
    emit(
      state.copyWith(
        entries: finalEntries,
        displayListItems: finalDisplayList,
        isLoading: false, // Processing finished
        // Keep error message if it occurred, otherwise clear it implicitly by not setting it
        lastErrorMessage: serviceError,
      ),
    );
    await _saveEntries(finalEntries);
  }

  Future<void> addEntryObject(Entry entryToAdd) async {
    emit(state.copyWith(clearLastError: true));
    final updatedEntries = List<Entry>.from(state.entries)..add(entryToAdd);
    // No need to sort here, _buildDisplayList handles sorting
    final newDisplayList = _buildDisplayList(
      updatedEntries,
      state.filterCategory,
    );
    emit(
      state.copyWith(entries: updatedEntries, displayListItems: newDisplayList),
    );
    // Save after adding
    await _saveEntries(updatedEntries);
    AppLogger.info("Undid delete for entry - ${entryToAdd.text}");
  }

  Future<void> deleteEntry(Entry entryToDelete) async {
    emit(state.copyWith(clearLastError: true));
    final originalEntries = List<Entry>.from(state.entries);
    final updatedEntries =
        originalEntries
            .where(
              (entry) =>
                  !(entry.timestamp == entryToDelete.timestamp &&
                      entry.text == entryToDelete.text),
            )
            .toList();

    if (updatedEntries.length < originalEntries.length) {
      final newDisplayList = _buildDisplayList(
        updatedEntries,
        state.filterCategory,
      );
      emit(
        state.copyWith(
          entries: updatedEntries,
          displayListItems: newDisplayList,
        ),
      );
      // Save after deleting
      await _saveEntries(updatedEntries);
    }
  }

  Future<void> updateEntry(Entry originalEntry, Entry updatedEntry) async {
    emit(state.copyWith(clearLastError: true));
    final index = state.entries.indexWhere(
      (entry) =>
          entry.timestamp == originalEntry.timestamp &&
          entry.text == originalEntry.text,
    );
    if (index != -1) {
      final updatedEntries = List<Entry>.from(state.entries);
      // Ensure isNew is preserved or reset correctly if needed
      updatedEntries[index] = updatedEntry.copyWith(
        isNew: state.entries[index].isNew,
      );

      final newDisplayList = _buildDisplayList(
        updatedEntries,
        state.filterCategory,
      );
      emit(
        state.copyWith(
          entries: updatedEntries,
          displayListItems: newDisplayList,
        ),
      );
      // Save after updating
      await _saveEntries(updatedEntries);
    }
  }

  void clearLastError() {
    if (state.lastErrorMessage != null) {
      emit(state.copyWith(clearLastError: true));
    }
  }
}
