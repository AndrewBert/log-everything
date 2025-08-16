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
      emit(state.copyWith(isLoading: false, categories: initialCategories, displayListItems: initialDisplayList));
      initialEntries.where((e) => e.isNew).forEach(_markEntryAsNotNewAfterDelay);
    } catch (e) {
      AppLogger.error("Cubit: Error initializing repository", error: e);
      emit(state.copyWith(isLoading: false, lastErrorMessage: "Failed to load initial data."));
    }
  }

  // Helper to build the display list from entries and filter
  List<dynamic> _buildDisplayList(List<Entry> entries, String? filterCategory) {
    // Ensure we have a mutable list to work with before filtering/sorting
    List<Entry> mutableEntries = List<Entry>.from(entries);

    final List<Entry> filteredEntries = filterCategory == null
        ? mutableEntries // Use the mutable copy
        : mutableEntries
              .where((entry) => entry.category == filterCategory)
              .toList(); // .where().toList() already creates a new mutable list

    if (filteredEntries.isEmpty) {
      return [];
    }

    // Group entries by date
    final groupedEntries = groupBy<Entry, DateTime>(
      filteredEntries,
      (entry) => DateTime(entry.timestamp.year, entry.timestamp.month, entry.timestamp.day),
    );

    // Sort dates descending
    final sortedDates = groupedEntries.keys.toList()..sort((a, b) => b.compareTo(a));

    // Create the final list with headers and entries
    final List<dynamic> listItems = [];
    for (var date in sortedDates) {
      listItems.add(date);

      // Sort all entries by timestamp (newest first) - maintain chronological order
      final dayEntries = groupedEntries[date]!;
      dayEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      listItems.addAll(dayEntries);
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
    final tempDisplayList = _buildDisplayList(tempEntriesList, state.filterCategory);
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

    AppLogger.info('[Recent Categories] Updated recent categories to: $recentCats');
    emit(state.copyWith(recentCategories: recentCats));
  }

  // Re-add: Method to finalize state after background processing
  void finalizeProcessing(List<Entry> finalEntries) {
    AppLogger.info('[Recent Categories] Processing ${finalEntries.length} entries');
    final finalCategories = _entryRepository.currentCategories;
    final finalDisplayList = _buildDisplayList(finalEntries, state.filterCategory);

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
    final tempEntry = Entry(text: text, timestamp: processingTimestamp, category: 'Processing...', isNew: true);

    // Use the helper to show temporary state
    showTemporaryEntry(tempEntry);

    try {
      final result = await _entryRepository.addEntry(text);
      final finalEntries = result.entries;
      final splitCount = result.splitCount;
      final originalText = result.originalText;
      final batchId = result.batchId;

      // CP: Handle split notification and store undo info
      if (splitCount > 1 && batchId != null) {
        AppLogger.info('[Split Detection] Repository detected $splitCount split entries with batch ID: $batchId');
        emit(
          state.copyWith(
            splitNotification: 'Entry split into $splitCount items',
            undoBatchId: batchId,
            undoOriginalText: originalText,
          ),
        );
      }

      finalizeProcessing(finalEntries);

      final entriesToStartTimerFor = finalEntries.where((e) => e.isNew && e.timestamp == processingTimestamp).toList();

      entriesToStartTimerFor.forEach(_markEntryAsNotNewAfterDelay);
      HapticFeedback.mediumImpact();
    } on AiServiceException catch (e) {
      // CP: Catch AiServiceException specifically
      AppLogger.error("Cubit: AiServiceException adding entry: ${e.message}", error: e.underlyingError);
      // Revert UI state
      final currentEntries = _entryRepository.currentEntries;
      final revertedDisplayList = _buildDisplayList(currentEntries, state.filterCategory);
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
      final revertedDisplayList = _buildDisplayList(currentEntries, state.filterCategory);
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
      AppLogger.error("Cubit: Error adding entry object via repository", error: e);
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
      final updatedEntries = await _entryRepository.updateEntry(originalEntry, updatedEntry);
      _updateStateFromRepository(updatedEntries: updatedEntries);
    } catch (e) {
      AppLogger.error("Cubit: Error updating entry via repository", error: e);
      emit(state.copyWith(lastErrorMessage: "Failed to update entry."));
    }
  }

  // Update _markEntryAsNotNewAfterDelay to remove logging
  void _markEntryAsNotNewAfterDelay(Entry entry) {
    _newEntryTimers[entry.timestamp]?.cancel();
    _newEntryTimers[entry.timestamp] = Timer(_newEntryHighlightDuration, () async {
      if (!isClosed) {
        bool updated = await _entryRepository.markEntryAsNotNew(entry.timestamp, entry.text);
        if (updated) {
          final currentEntries = _entryRepository.currentEntries;
          _updateStateFromRepository(updatedEntries: currentEntries);
        }
        _newEntryTimers.remove(entry.timestamp);
      }
    });
  }

  Future<void> addCustomCategory(String newCategory) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final updatedCategories = await _entryRepository.addCustomCategory(newCategory);
      emit(state.copyWith(categories: updatedCategories));
    } catch (e) {
      AppLogger.error("Cubit: Error adding category via repository", error: e);
      emit(state.copyWith(lastErrorMessage: "Failed to add category."));
    }
  }

  Future<void> addCustomCategoryWithDescription(
    String name,
    String description, {
    bool isChecklist = false,
    Color? color,
  }) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final updatedCategories = await _entryRepository.addCustomCategoryWithDescription(
        name,
        description,
        isChecklist: isChecklist,
        color: color,
      );
      emit(state.copyWith(categories: updatedCategories));
    } catch (e) {
      AppLogger.error("Cubit: Error adding category with description via repository", error: e);
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
      AppLogger.error("Cubit: Error deleting category via repository", error: e);
      emit(state.copyWith(lastErrorMessage: "Failed to delete category."));
    }
  }

  Future<void> renameCategory(String oldName, String newName, {String? description, bool? isChecklist}) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final result = await _entryRepository.renameCategory(
        oldName,
        newName,
        description: description,
        isChecklist: isChecklist,
      );
      _updateStateFromRepository(
        updatedEntries: result.entries,
        updatedCategories: result.categories,
        newFilterCategory: state.filterCategory == oldName ? newName : state.filterCategory,
      );
    } catch (e) {
      AppLogger.error("Cubit: Error renaming category via repository", error: e);
      emit(state.copyWith(lastErrorMessage: "Failed to rename category."));
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
    emit(state.copyWith(editingEntry: entry, isEditingMode: true, editingIsTask: entry.isTask));
  }

  void cancelEditingEntry() {
    emit(state.copyWith(clearEditingEntry: true, isEditingMode: false, clearEditingIsTask: true));
  }

  // CP: Toggle task status during editing
  void toggleEditingTaskStatus() {
    final currentStatus = state.editingIsTask ?? false;
    emit(state.copyWith(editingIsTask: !currentStatus));
  }

  Future<void> finishEditingEntry(String newText, String newCategory, {bool? isTask}) async {
    final editingEntry = state.editingEntry;
    if (editingEntry == null || newText.trim().isEmpty) {
      cancelEditingEntry();
      return;
    }

    emit(state.copyWith(clearLastError: true));
    try {
      final taskStatus = isTask ?? state.editingIsTask ?? editingEntry.isTask;
      final updatedEntry = editingEntry.copyWith(text: newText.trim(), category: newCategory, isTask: taskStatus);

      final updatedEntries = await _entryRepository.updateEntry(editingEntry, updatedEntry);

      _updateStateFromRepository(updatedEntries: updatedEntries);

      // Clear editing state
      emit(state.copyWith(clearEditingEntry: true, isEditingMode: false, clearEditingIsTask: true));
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

  // CP: Clear split notification after toast is shown
  void clearSplitNotification() {
    emit(state.copyWith(clearSplitNotification: true));
  }

  // CC: Undo split - merge entries back to original text
  Future<void> undoSplit() async {
    if (state.undoBatchId == null || state.undoOriginalText == null) {
      AppLogger.warn("Cubit: Cannot undo split - missing batch ID or original text");
      return;
    }

    emit(state.copyWith(isLoading: true, clearLastError: true));
    try {
      final updatedEntries = await _entryRepository.undoSplit(state.undoBatchId!, state.undoOriginalText!);
      _updateStateFromRepository(updatedEntries: updatedEntries);

      // CC: Clear undo info and show success message
      emit(
        state.copyWith(
          clearUndoInfo: true,
          clearSplitNotification: true,
        ),
      );

      HapticFeedback.mediumImpact();
      AppLogger.info("Cubit: Successfully undid split for batch ${state.undoBatchId}");
    } catch (e) {
      AppLogger.error("Cubit: Error undoing split", error: e);
      emit(
        state.copyWith(
          isLoading: false,
          lastErrorMessage: "Failed to undo split.",
        ),
      );
    }
  }

  // CP: Toggle completion status for checklist items
  Future<void> toggleEntryCompletion(Entry entry) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final updatedEntry = entry.toggleCompletion();
      final updatedEntries = await _entryRepository.updateEntry(entry, updatedEntry);
      _updateStateFromRepository(updatedEntries: updatedEntries);
    } catch (e) {
      AppLogger.error("Cubit: Error toggling entry completion via repository", error: e);
      emit(state.copyWith(lastErrorMessage: "Failed to update entry."));
    }
  }
}
