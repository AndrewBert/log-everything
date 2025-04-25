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

  // Update _updateStateFromRepository to log category changes
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

    // Log category changes before emitting
    if (updatedCategories != null &&
        !const DeepCollectionEquality().equals(
          state.categories,
          updatedCategories,
        )) {
      AppLogger.debug(
        '[Cubit._updateStateFromRepository] Categories changed. Emitting: $updatedCategories',
      );
    } else if (updatedCategories != null) {
      AppLogger.debug(
        '[Cubit._updateStateFromRepository] Categories provided but unchanged.',
      );
    }

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

  // --- Public Methods (delegating to repository) ---

  Future<void> addEntry(String text) async {
    if (text.isEmpty) return;

    // 1. Create temporary entry
    final DateTime processingTimestamp = DateTime.now();
    final tempEntry = Entry(
      text: text, // Show original text while processing
      timestamp: processingTimestamp,
      category: 'Processing...',
      isNew: true,
    );

    // 2. Get current state from repository and create temporary list
    final currentEntries = _entryRepository.currentEntries;
    final tempEntriesList = [
      tempEntry,
      ...currentEntries,
    ]; // Prepend temp entry
    final tempDisplayList = _buildDisplayList(
      tempEntriesList,
      state.filterCategory,
    );

    // 3. Emit intermediate loading state with temporary entry visible
    emit(
      state.copyWith(
        isLoading: true,
        displayListItems: tempDisplayList,
        // Keep current categories, don't clear them here
        // categories: state.categories,
        clearLastError: true,
      ),
    );

    // 4. Call repository to process and save (this updates repo's internal list)
    List<Entry> finalEntries = [];
    try {
      // Repository now handles AI call and saving
      finalEntries = await _entryRepository.addEntry(text);
      // Get latest categories in case they changed (unlikely here, but good practice)
      final finalCategories = _entryRepository.currentCategories;
      // Build final display list from repository's current state
      final finalDisplayList = _buildDisplayList(
        finalEntries,
        state.filterCategory,
      );

      // 5. Emit final state
      emit(
        state.copyWith(
          isLoading: false,
          displayListItems: finalDisplayList,
          categories: finalCategories,
          // Error message is handled by the repository call result if needed
        ),
      );

      // 6. Start timers for the *actual* new entries added by the repository
      finalEntries
          .where(
            (e) => e.isNew && e.timestamp == processingTimestamp,
          ) // Find entries from this operation
          .forEach(_markEntryAsNotNewAfterDelay);
      HapticFeedback.mediumImpact(); // Feedback after successful processing
    } catch (e) {
      AppLogger.error("Cubit: Error adding entry via repository", error: e);
      // If repo call failed, revert UI to state before temp entry was added?
      // Or just show error and leave temp entry (which might be confusing)
      // Let's revert for now:
      final revertedDisplayList = _buildDisplayList(
        currentEntries,
        state.filterCategory,
      );
      emit(
        state.copyWith(
          isLoading: false,
          lastErrorMessage: "Failed to add entry.",
          displayListItems: revertedDisplayList, // Show list without temp entry
        ),
      );
    }
    // Note: isLoading: false is handled in both success and error paths now
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

  // Update _markEntryAsNotNewAfterDelay to add logging
  void _markEntryAsNotNewAfterDelay(Entry entry) {
    // Cancel any existing timer for this specific entry
    _newEntryTimers[entry.timestamp]?.cancel();
    AppLogger.debug(
      '[Cubit._markEntryAsNotNewAfterDelay] Starting timer for entry: ${entry.text} (${entry.timestamp})',
    );

    _newEntryTimers[entry.timestamp] = Timer(_newEntryHighlightDuration, () {
      AppLogger.debug(
        '[Cubit._markEntryAsNotNewAfterDelay] Timer fired for entry: ${entry.text} (${entry.timestamp})',
      );
      if (!isClosed) {
        // Ask repository to update the flag
        bool updated = _entryRepository.markEntryAsNotNew(
          entry.timestamp,
          entry.text,
        );
        AppLogger.debug(
          '[Cubit._markEntryAsNotNewAfterDelay] Repository update result: $updated',
        );
        if (updated) {
          // If updated, get the current list from repo and update UI state
          final currentEntries = _entryRepository.currentEntries;
          AppLogger.debug(
            '[Cubit._markEntryAsNotNewAfterDelay] Calling _updateStateFromRepository after flag update.',
          );
          _updateStateFromRepository(updatedEntries: currentEntries);
        }
        _newEntryTimers.remove(entry.timestamp);
      } else {
        AppLogger.debug(
          '[Cubit._markEntryAsNotNewAfterDelay] Timer fired but cubit closed.',
        );
      }
    });
  }

  Future<void> addCustomCategory(String newCategory) async {
    emit(state.copyWith(clearLastError: true));
    try {
      final updatedCategories = await _entryRepository.addCustomCategory(
        newCategory,
      );
      AppLogger.debug(
        '[Cubit.addCustomCategory] Received from repo: $updatedCategories',
      );
      // Only update categories in state
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
      AppLogger.debug(
        '[Cubit.deleteCategory] Received from repo: Categories=${result.categories}',
      );
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
      AppLogger.debug(
        '[Cubit.renameCategory] Received from repo: Categories=${result.categories}',
      );
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
