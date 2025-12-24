part of 'search_cubit.dart';

class SearchState extends Equatable {
  final String query;
  final List<Entry> results;
  final bool isSearching;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isSearching = false,
  });

  bool get hasQuery => query.length >= 2;
  bool get hasResults => results.isNotEmpty;
  bool get showNoResults => hasQuery && !isSearching && results.isEmpty;

  SearchState copyWith({
    String? query,
    List<Entry>? results,
    bool? isSearching,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
    );
  }

  @override
  List<Object?> get props => [query, results, isSearching];
}
