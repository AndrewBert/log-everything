import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:myapp/entry/category.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/repository/entry_repository.dart';

part 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  final EntryRepository _entryRepository;
  Timer? _debounceTimer;

  static const _debounceDuration = Duration(milliseconds: 300);
  static const _minQueryLength = 2;

  SearchCubit({
    required EntryRepository entryRepository,
  })  : _entryRepository = entryRepository,
        super(const SearchState());

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
    final allEntries = _entryRepository.currentEntries;
    final allCategories = _entryRepository.currentCategories;

    final results = allEntries.where((entry) {
      if (entry.text.toLowerCase().contains(normalizedQuery)) return true;
      if (entry.imageTitle?.toLowerCase().contains(normalizedQuery) ?? false) return true;
      if (entry.imageDescription?.toLowerCase().contains(normalizedQuery) ?? false) return true;
      return false;
    }).toList();

    final matchingCategories = allCategories.where((category) {
      if (category.name.toLowerCase().contains(normalizedQuery)) return true;
      if (category.description.toLowerCase().contains(normalizedQuery)) return true;
      return false;
    }).toList();

    emit(state.copyWith(
      results: results,
      matchingCategories: matchingCategories,
      isSearching: false,
    ));
  }

  void clearSearch() {
    _debounceTimer?.cancel();
    emit(const SearchState());
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
