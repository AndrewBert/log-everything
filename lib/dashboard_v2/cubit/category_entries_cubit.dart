import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/repository/entry_repository.dart';

part 'category_entries_state.dart';

class CategoryEntriesCubit extends Cubit<CategoryEntriesState> {
  final EntryRepository _entryRepository;
  final String categoryName;
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
    final allEntries = _entryRepository.currentEntries;
    final categoryEntries = allEntries
        .where((entry) => entry.category == categoryName)
        .toList();
    
    emit(state.copyWith(
      entries: categoryEntries,
      isLoading: false,
    ));
  }

  void _onEntriesUpdated(List<Entry> allEntries) {
    // CC: Filter entries for this category
    final categoryEntries = allEntries
        .where((entry) => entry.category == categoryName)
        .toList();
    
    emit(state.copyWith(entries: categoryEntries));
  }

  @override
  Future<void> close() {
    _entriesSubscription?.cancel();
    return super.close();
  }
}