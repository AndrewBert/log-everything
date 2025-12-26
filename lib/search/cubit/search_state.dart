part of 'search_cubit.dart';

class SearchState extends Equatable {
  final String query;
  final List<Entry> results;
  final List<Category> matchingCategories;
  final bool isSearching;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.matchingCategories = const [],
    this.isSearching = false,
  });

  bool get hasQuery => query.length >= 2;
  bool get hasResults => results.isNotEmpty;
  bool get hasMatchingCategories => matchingCategories.isNotEmpty;
  bool get showNoResults => hasQuery && !isSearching && results.isEmpty && matchingCategories.isEmpty;

  SearchState copyWith({
    String? query,
    List<Entry>? results,
    List<Category>? matchingCategories,
    bool? isSearching,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      matchingCategories: matchingCategories ?? this.matchingCategories,
      isSearching: isSearching ?? this.isSearching,
    );
  }

  @override
  List<Object?> get props => [query, results, matchingCategories, isSearching];
}
