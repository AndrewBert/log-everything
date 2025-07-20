import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/category.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/utils/category_colors.dart';

part 'category_entries_state.dart';

class CategoryEntriesCubit extends Cubit<CategoryEntriesState> {
  final EntryRepository _entryRepository;
  String categoryName;
  StreamSubscription<List<Entry>>? _entriesSubscription;

  CategoryEntriesCubit({
    required EntryRepository entryRepository,
    required this.categoryName,
  }) : _entryRepository = entryRepository,
       super(CategoryEntriesState(categoryName: categoryName)) {
    // CC: Subscribe to entries stream and filter by category
    _entriesSubscription = _entryRepository.entriesStream.listen(_onEntriesUpdated);
    // CC: Load initial entries
    _loadCategoryEntries();
  }

  void _loadCategoryEntries() {
    print('[CategoryEntriesCubit] _loadCategoryEntries() called');
    final allEntries = _entryRepository.currentEntries;
    final categoryEntries = allEntries.where((entry) => entry.category == categoryName).toList();

    // CC: Find the category object
    final category = _entryRepository.currentCategories.firstWhere(
      (cat) => cat.name == categoryName,
      orElse: () => Category(name: categoryName),
    );

    // CC: Fetch current color for this category
    final categoryColor = CategoryColors.getColorForCategory(categoryName);
    print('[CategoryEntriesCubit] Fetched color for $categoryName: $categoryColor');

    print('[CategoryEntriesCubit] About to emit new state');
    emit(
      state.copyWith(
        category: category,
        entries: categoryEntries,
        isLoading: false,
        categoryColor: categoryColor,
      ),
    );
    print('[CategoryEntriesCubit] New state emitted');
  }

  void _onEntriesUpdated(List<Entry> allEntries) {
    // CC: Filter entries for this category
    final categoryEntries = allEntries.where((entry) => entry.category == categoryName).toList();

    // CC: Also fetch current color to ensure state is up to date
    final categoryColor = CategoryColors.getColorForCategory(categoryName);

    emit(state.copyWith(entries: categoryEntries, categoryColor: categoryColor));
  }

  Future<void> updateCategory(String newName, String newDescription) async {
    await _entryRepository.renameCategory(
      categoryName,
      newName,
      description: newDescription,
    );

    // CC: Update the category name if it changed
    if (newName != categoryName) {
      categoryName = newName;
    }

    // CC: Reload category details
    _loadCategoryEntries();
  }

  // CC: Refresh the cubit state to pick up external changes (like color updates)
  void refreshState() {
    print('[CategoryEntriesCubit] refreshState() called - will reload category entries');
    _loadCategoryEntries();
    print('[CategoryEntriesCubit] refreshState() completed');
  }

  @override
  Future<void> close() {
    _entriesSubscription?.cancel();
    return super.close();
  }
}
