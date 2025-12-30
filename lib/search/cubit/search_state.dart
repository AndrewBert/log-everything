part of 'search_cubit.dart';

enum SearchMode {
  all,
  categoriesOnly,
  entriesOnly,
}

class SearchState extends Equatable {
  final String query;
  final List<Entry> results;
  final List<Category> matchingCategories;
  final bool isSearching;
  final SearchMode mode;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.matchingCategories = const [],
    this.isSearching = false,
    this.mode = SearchMode.all,
  });

  bool get hasQuery => query.length >= 2;
  bool get hasResults => results.isNotEmpty;
  bool get hasMatchingCategories => matchingCategories.isNotEmpty;

  // CP: Separate todos from regular entries for distinct rendering
  List<Entry> get todoResults => results.where((e) => e.isTask).toList();
  List<Entry> get regularResults => results.where((e) => !e.isTask).toList();
  bool get hasTodoResults => todoResults.isNotEmpty;
  bool get hasRegularResults => regularResults.isNotEmpty;

  bool get showNoResults {
    if (!hasQuery || isSearching) return false;
    return switch (mode) {
      SearchMode.categoriesOnly => matchingCategories.isEmpty,
      SearchMode.entriesOnly => results.isEmpty,
      SearchMode.all => results.isEmpty && matchingCategories.isEmpty,
    };
  }

  SearchState copyWith({
    String? query,
    List<Entry>? results,
    List<Category>? matchingCategories,
    bool? isSearching,
    SearchMode? mode,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      matchingCategories: matchingCategories ?? this.matchingCategories,
      isSearching: isSearching ?? this.isSearching,
      mode: mode ?? this.mode,
    );
  }

  @override
  List<Object?> get props => [query, results, matchingCategories, isSearching, mode];
}
