import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';

import '../entry.dart';
import '../../utils/logger.dart';
import '../repository/entry_repository.dart';

part 'entry_state.dart';

class EntryCubit extends Cubit<EntryState> {
  final EntryRepository _entryRepository;

  EntryCubit({required EntryRepository entryRepository})
    : _entryRepository = entryRepository,
      super(EntryState()) {
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
      initialEntries
          .where((e) => e.isNew)
          .forEach(_markEntryAsNotNewAfterDelay);
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
    final sortedDates =
        groupedEntries.keys.toList()..sort((a, b) => b.compareTo(a));

    // Create the final list with headers and entries
    final List<dynamic> listItems = [];
    for (var date in sortedDates) {
      listItems.add(date);
      listItems.addAll(groupedEntries[date]!);
    }

    return listItems;
  }

  // --- UI State Update Helpers ---

  // Update _updateStateFromRepository to remove logging
  void _updateStateFromRepository({
    required List<Entry> updatedEntries,
    List<String>? updatedCategories,
    bool? clearFilter,
    String? newFilterCategory,
  }) {
    final filterToUse =
        (clearFilter ?? false)
            ? null
            : (newFilterCategory ?? state.filterCategory);
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
    AppLogger.debug(
      '[Cubit.showTemporaryEntry] Showing temp entry: ${tempEntry.text}',
    );
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

  // Re-add: Method to finalize state after background processing
  void finalizeProcessing(List<Entry> finalEntries) {
    AppLogger.debug(
      '[Cubit.finalizeProcessing] Finalizing with ${finalEntries.length} entries.',
    );
    final finalCategories =
        _entryRepository.currentCategories; // Get latest categories
    final finalDisplayList = _buildDisplayList(
      finalEntries,
      state.filterCategory,
    );
    emit(
      state.copyWith(
        isLoading: false, // Processing finished
        displayListItems: finalDisplayList,
        categories: finalCategories,
        clearLastError: true, // Assume success if this is called
      ),
    );
    // Start timers for any new entries added during processing
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

      final entriesToStartTimerFor =
          finalEntries
              .where((e) => e.isNew && e.timestamp == processingTimestamp)
              .toList();

      entriesToStartTimerFor.forEach(_markEntryAsNotNewAfterDelay);
      HapticFeedback.mediumImpact();
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

  Future<void> deleteCategory(String categoryToDelete) async {
    if (categoryToDelete == 'Misc') return;
    emit(state.copyWith(clearLastError: true));
    try {
      final result = await _entryRepository.deleteCategory(categoryToDelete);
      _updateStateFromRepository(
        updatedEntries: result.entries,
        updatedCategories: result.categories,
        clearFilter: state.filterCategory == categoryToDelete,
      );
    } catch (e) {
      AppLogger.error(
        "Cubit: Error deleting category via repository",
        error: e,
      );
      emit(state.copyWith(lastErrorMessage: "Failed to delete category."));
    }
  }

  Future<void> renameCategory(String oldName, String newName) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final result = await _entryRepository.renameCategory(oldName, newName);
      _updateStateFromRepository(
        updatedEntries: result.entries,
        updatedCategories: result.categories,
        newFilterCategory:
            state.filterCategory == oldName ? newName : state.filterCategory,
      );
    } catch (e) {
      AppLogger.error(
        "Cubit: Error renaming category via repository",
        error: e,
      );
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

  void clearLastError() {
    if (state.lastErrorMessage != null) {
      emit(state.copyWith(clearLastError: true));
    }
  }
}
