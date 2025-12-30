import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:myapp/entry/category.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/repository/entry_repository.dart';

part 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  final EntryRepository _entryRepository;
  final SearchMode _mode;
  final String? _categoryFilter;
  final bool _archivedOnly;
  Timer? _debounceTimer;

  static const _debounceDuration = Duration(milliseconds: 300);
  static const _minQueryLength = 2;

  SearchCubit({
    required EntryRepository entryRepository,
    SearchMode mode = SearchMode.all,
    String? categoryFilter,
    bool archivedOnly = false,
  })  : _entryRepository = entryRepository,
        _mode = mode,
        _categoryFilter = categoryFilter,
        _archivedOnly = archivedOnly,
        super(SearchState(mode: mode));

  void updateQuery(String query) {
    _debounceTimer?.cancel();

    if (query.length < _minQueryLength) {
      emit(state.copyWith(
        query: query,
        results: [],
        matchingCategories: [],
        isSearching: false,
      ));
      return;
    }

    emit(state.copyWith(
      query: query,
      isSearching: true,
    ));

    _debounceTimer = Timer(_debounceDuration, () {
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    final normalizedQuery = query.toLowerCase();

    List<Entry> results = [];
    List<Category> matchingCategories = [];

    if (_mode != SearchMode.categoriesOnly) {
      results = _entryRepository.currentEntries.where((entry) {
        if (_categoryFilter != null && entry.category != _categoryFilter) {
          return false;
        }
        if (entry.text.toLowerCase().contains(normalizedQuery)) return true;
        if (entry.imageTitle?.toLowerCase().contains(normalizedQuery) ?? false) return true;
        if (entry.imageDescription?.toLowerCase().contains(normalizedQuery) ?? false) return true;
        return false;
      }).toList();
    }

    if (_mode != SearchMode.entriesOnly) {
      matchingCategories = _entryRepository.currentCategories.where((category) {
        if (_archivedOnly && !category.isArchived) return false;
        if (category.name.toLowerCase().contains(normalizedQuery)) return true;
        if (category.description.toLowerCase().contains(normalizedQuery)) return true;
        return false;
      }).toList();
    }

    emit(state.copyWith(
      results: results,
      matchingCategories: matchingCategories,
      isSearching: false,
    ));
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    emit(SearchState(mode: _mode));
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
