import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:myapp/entry/category.dart';

import '../entry.dart';
import '../../utils/logger.dart';
import '../repository/entry_repository.dart';
import '../../services/ai_service.dart'; // CP: Import AiServiceException

part 'entry_state.dart';

class EntryCubit extends Cubit<EntryState> {
  final EntryRepository _entryRepository;

  EntryCubit({required EntryRepository entryRepository}) : _entryRepository = entryRepository, super(EntryState()) {
    _initialize();
  }

  final Map<DateTime, Timer> _newEntryTimers = {};
  static const Duration _newEntryHighlightDuration = Duration(seconds: 5);

  @override
  Future<void> close() {
    _newEntryTimers.forEach((_, timer) => timer.cancel());
    _newEntryTimers.clear();
    return super.close();
  }

  Future<void> _initialize() async {
    emit(state.copyWith(isLoading: true, clearLastError: true));
    try {
      await _entryRepository.initialize();
      final initialEntries = _entryRepository.currentEntries;
      final initialCategories = _entryRepository.currentCategories;
      final initialDisplayList = _buildDisplayList(initialEntries, null);
      emit(
        state.copyWith(
          isLoading: false,
          categories: initialCategories,
          displayListItems: initialDisplayList,
        ),
      );
      initialEntries.where((e) => e.isNew).forEach(_markEntryAsNotNewAfterDelay);
    } catch (e) {
      AppLogger.error("Cubit: Error initializing repository", error: e);
      emit(
        state.copyWith(
          isLoading: false,
          lastErrorMessage: "Failed to load initial data.",
        ),
      );
    }
  }

  // Helper to build the display list from entries and filter
  List<dynamic> _buildDisplayList(List<Entry> entries, String? filterCategory) {
    // Ensure we have a mutable list to work with before filtering/sorting
    List<Entry> mutableEntries = List<Entry>.from(entries);

    final List<Entry> filteredEntries =
        filterCategory == null
            ? mutableEntries // Use the mutable copy
            : mutableEntries
                .where((entry) => entry.category == filterCategory)
                .toList(); // .where().toList() already creates a new mutable list

    // Sort the filtered list (which is now guaranteed to be mutable)
    filteredEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (filteredEntries.isEmpty) {
      return [];
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
    final sortedDates = groupedEntries.keys.toList()..sort((a, b) => b.compareTo(a));

    // Create the final list with headers and entries
    final List<dynamic> listItems = [];
    for (var date in sortedDates) {
      listItems.add(date);
      listItems.addAll(groupedEntries[date]!);
    }

    return listItems;
  }

  // --- UI State Update Helpers ---

  // CP: Update _updateStateFromRepository to use List<Category>
  void _updateStateFromRepository({
    required List<Entry> updatedEntries,
    List<Category>? updatedCategories,
    bool? clearFilter,
    String? newFilterCategory,
  }) {
    final filterToUse = (clearFilter ?? false) ? null : (newFilterCategory ?? state.filterCategory);
    final newDisplayList = _buildDisplayList(updatedEntries, filterToUse);

    emit(
      state.copyWith(
        categories: updatedCategories ?? state.categories,
        displayListItems: newDisplayList,
        filterCategory: filterToUse,
        clearFilter: clearFilter ?? false,
        clearLastError: true,
      ),
    );
  }

  // Re-add: Method to show a temporary entry immediately
  void showTemporaryEntry(Entry tempEntry) {
    final currentEntries = _entryRepository.currentEntries;
    // Create a temporary list for display purposes only
    final tempEntriesList = [tempEntry, ...currentEntries];
    final tempDisplayList = _buildDisplayList(
      tempEntriesList,
      state.filterCategory,
    );
    emit(
      state.copyWith(
        isLoading: true, // Indicate processing
        displayListItems: tempDisplayList,
        clearLastError: true,
      ),
    );
  }

  // CP: Update recent categories based on entry timestamps
  void _updateRecentCategories(List<Entry> entries) {
    if (entries.isEmpty) {
      AppLogger.info('[Recent Categories] No entries to process');
      return;
    }

    // Sort entries by timestamp, most recent first
    final sortedEntries = List<Entry>.from(entries)..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Get unique categories from most recent entries (including Misc)
    final recentCats = sortedEntries.map((e) => e.category).toSet().take(3).toList();

    AppLogger.info(
      '[Recent Categories] Updated recent categories to: $recentCats',
    );
    emit(state.copyWith(recentCategories: recentCats));
  }

  // Re-add: Method to finalize state after background processing
  void finalizeProcessing(List<Entry> finalEntries) {
    AppLogger.info(
      '[Recent Categories] Processing ${finalEntries.length} entries',
    );
    final finalCategories = _entryRepository.currentCategories;
    final finalDisplayList = _buildDisplayList(
      finalEntries,
      state.filterCategory,
    );

    // CP: Update recent categories when finalizing entries
    _updateRecentCategories(_entryRepository.currentEntries);

    emit(
      state.copyWith(
        isLoading: false,
        displayListItems: finalDisplayList,
        categories: finalCategories,
        clearLastError: true,
      ),
    );
    finalEntries.where((e) => e.isNew).forEach(_markEntryAsNotNewAfterDelay);
  }

  // --- Public Methods (delegating to repository) ---

  // Ensure addEntry uses the helper methods
  Future<void> addEntry(String text) async {
    if (text.isEmpty) return;

    final DateTime processingTimestamp = DateTime.now();
    final tempEntry = Entry(
      text: text,
      timestamp: processingTimestamp,
      category: 'Processing...',
      isNew: true,
    );

    // Use the helper to show temporary state
    showTemporaryEntry(tempEntry);

    List<Entry> finalEntries = [];
    try {
      finalEntries = await _entryRepository.addEntry(text);

      finalizeProcessing(finalEntries);

      final entriesToStartTimerFor = finalEntries.where((e) => e.isNew && e.timestamp == processingTimestamp).toList();

      entriesToStartTimerFor.forEach(_markEntryAsNotNewAfterDelay);
      HapticFeedback.mediumImpact();
    } on AiServiceException catch (e) {
      // CP: Catch AiServiceException specifically
      AppLogger.error(
        "Cubit: AiServiceException adding entry: ${e.message}",
        error: e.underlyingError,
      );
      // Revert UI state
      final currentEntries = _entryRepository.currentEntries;
      final revertedDisplayList = _buildDisplayList(
        currentEntries,
        state.filterCategory,
      );
      emit(
        state.copyWith(
          isLoading: false,
          lastErrorMessage: "AI processing failed: ${e.message}", // CP: More specific error
          displayListItems: revertedDisplayList,
        ),
      );
    } catch (e) {
      AppLogger.error("Cubit: Error adding entry via repository", error: e);
      // Revert UI state
      final currentEntries = _entryRepository.currentEntries;
      final revertedDisplayList = _buildDisplayList(
        currentEntries,
        state.filterCategory,
      );
      emit(
        state.copyWith(
          isLoading: false,
          lastErrorMessage: "Failed to add entry.",
          displayListItems: revertedDisplayList,
        ),
      );
    }
  }

  Future<void> addEntryObject(Entry entryToAdd) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final updatedEntries = await _entryRepository.addEntryObject(entryToAdd);
      _updateStateFromRepository(updatedEntries: updatedEntries);
    } catch (e) {
      AppLogger.error(
        "Cubit: Error adding entry object via repository",
        error: e,
      );
      emit(state.copyWith(lastErrorMessage: "Failed to add entry."));
    }
  }

  Future<void> deleteEntry(Entry entryToDelete) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final updatedEntries = await _entryRepository.deleteEntry(entryToDelete);
      _updateStateFromRepository(updatedEntries: updatedEntries);
    } catch (e) {
      AppLogger.error("Cubit: Error deleting entry via repository", error: e);
      emit(state.copyWith(lastErrorMessage: "Failed to delete entry."));
    }
  }

  Future<void> updateEntry(Entry originalEntry, Entry updatedEntry) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final updatedEntries = await _entryRepository.updateEntry(
        originalEntry,
        updatedEntry,
      );
      _updateStateFromRepository(updatedEntries: updatedEntries);
    } catch (e) {
      AppLogger.error("Cubit: Error updating entry via repository", error: e);
      emit(state.copyWith(lastErrorMessage: "Failed to update entry."));
    }
  }

  // Update _markEntryAsNotNewAfterDelay to remove logging
  void _markEntryAsNotNewAfterDelay(Entry entry) {
    _newEntryTimers[entry.timestamp]?.cancel();
    _newEntryTimers[entry.timestamp] = Timer(
      _newEntryHighlightDuration,
      () async {
        if (!isClosed) {
          bool updated = await _entryRepository.markEntryAsNotNew(
            entry.timestamp,
            entry.text,
          );
          if (updated) {
            final currentEntries = _entryRepository.currentEntries;
            _updateStateFromRepository(updatedEntries: currentEntries);
          }
          _newEntryTimers.remove(entry.timestamp);
        }
      },
    );
  }

  Future<void> addCustomCategory(String newCategory) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final updatedCategories = await _entryRepository.addCustomCategory(
        newCategory,
      );
      emit(state.copyWith(categories: updatedCategories));
    } catch (e) {
      AppLogger.error("Cubit: Error adding category via repository", error: e);
      emit(state.copyWith(lastErrorMessage: "Failed to add category."));
    }
  }

  Future<void> addCustomCategoryWithDescription(
    String name,
    String description,
  ) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final updatedCategories = await _entryRepository.addCustomCategoryWithDescription(name, description);
      emit(state.copyWith(categories: updatedCategories));
    } catch (e) {
      AppLogger.error(
        "Cubit: Error adding category with description via repository",
        error: e,
      );
      emit(state.copyWith(lastErrorMessage: "Failed to add category."));
    }
  }

  Future<void> deleteCategory(String categoryToDelete) async {
    if (categoryToDelete == 'Misc') return;
    emit(state.copyWith(clearLastError: true));
    try {
      final result = await _entryRepository.deleteCategory(categoryToDelete);

      // CP: Remove deleted category from recent categories list
      final updatedRecentCategories = state.recentCategories.where((category) => category != categoryToDelete).toList();

      _updateStateFromRepository(
        updatedEntries: result.entries,
        updatedCategories: result.categories,
        clearFilter: state.filterCategory == categoryToDelete,
      );

      // CP: Update recent categories after state update
      emit(state.copyWith(recentCategories: updatedRecentCategories));
    } catch (e) {
      AppLogger.error(
        "Cubit: Error deleting category via repository",
        error: e,
      );
      emit(state.copyWith(lastErrorMessage: "Failed to delete category."));
    }
  }

  Future<void> renameCategory(
    String oldName,
    String newName, {
    String? description,
  }) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final result = await _entryRepository.renameCategory(
        oldName,
        newName,
        description: description,
      );
      _updateStateFromRepository(
        updatedEntries: result.entries,
        updatedCategories: result.categories,
        newFilterCategory: state.filterCategory == oldName ? newName : state.filterCategory,
      );
    } catch (e) {
      AppLogger.error(
        "Cubit: Error renaming category via repository",
        error: e,
      );
      emit(state.copyWith(lastErrorMessage: "Failed to rename category."));
    }
  }

  // CP: Add method to update category description only (for inline editing)
  Future<void> updateCategoryDescription(
    String categoryName,
    String newDescription,
  ) async {
    emit(state.copyWith(clearLastError: true));
    try {
      // CP: Use the existing renameCategory method with same name but new description
      final result = await _entryRepository.renameCategory(
        categoryName,
        categoryName, // CP: Keep the same name
        description: newDescription,
      );
      _updateStateFromRepository(
        updatedEntries: result.entries,
        updatedCategories: result.categories,
      );
    } catch (e) {
      AppLogger.error(
        "Cubit: Error updating category description via repository",
        error: e,
      );
      emit(state.copyWith(lastErrorMessage: "Failed to update category description."));
    }
  }

  void setFilter(String? category) {
    AppLogger.info("Cubit: Setting filter to: ${category ?? 'null'}");
    final currentEntries = _entryRepository.currentEntries;
    final newDisplayList = _buildDisplayList(currentEntries, category);
    emit(
      state.copyWith(
        filterCategory: category,
        clearFilter: category == null,
        displayListItems: newDisplayList,
        clearLastError: true,
      ),
    );
  }

  // CP: Add editing methods for the new editing experience
  void startEditingEntry(Entry entry) {
    emit(state.copyWith(editingEntry: entry, isEditingMode: true));
  }

  void cancelEditingEntry() {
    emit(state.copyWith(clearEditingEntry: true, isEditingMode: false));
  }

  Future<void> finishEditingEntry(String newText, String newCategory) async {
    final editingEntry = state.editingEntry;
    if (editingEntry == null || newText.trim().isEmpty) {
      cancelEditingEntry();
      return;
    }

    emit(state.copyWith(clearLastError: true));
    try {
      final updatedEntry = editingEntry.copyWith(
        text: newText.trim(),
        category: newCategory,
      );

      final updatedEntries = await _entryRepository.updateEntry(
        editingEntry,
        updatedEntry,
      );

      _updateStateFromRepository(updatedEntries: updatedEntries);

      // Clear editing state
      emit(state.copyWith(clearEditingEntry: true, isEditingMode: false));
    } catch (e) {
      AppLogger.error("Cubit: Error updating entry via repository", error: e);
      emit(state.copyWith(lastErrorMessage: "Failed to update entry."));
    }
  }

  void clearLastError() {
    if (state.lastErrorMessage != null) {
      emit(state.copyWith(clearLastError: true));
    }
  }

  // CP: Set which entry has an open context menu
  void setContextMenuEntry(Entry entry) {
    emit(state.copyWith(contextMenuEntry: entry));
  }

  // CP: Clear the context menu entry when menu is closed
  void clearContextMenuEntry() {
    emit(state.copyWith(clearContextMenuEntry: true));
  }
}
