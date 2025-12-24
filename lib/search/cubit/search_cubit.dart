import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
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

    final results = allEntries.where((entry) {
      return entry.text.toLowerCase().contains(normalizedQuery);
    }).toList();

    emit(state.copyWith(
      results: results,
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
