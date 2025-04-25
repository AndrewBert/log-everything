part of 'entry_cubit.dart';

// Extend Equatable
class EntryState extends Equatable {
  // Remove entries list from state, repository is source of truth
  // final List<Entry> entries;
  final List<String> categories;
  final bool isLoading;
  final String? lastErrorMessage;
  final String? filterCategory;
  final List<dynamic> displayListItems;

  const EntryState({
    // this.entries = const [], // Removed
    this.categories = const [],
    this.isLoading = false,
    this.lastErrorMessage,
    this.filterCategory,
    this.displayListItems = const [],
  });

  // Implement props getter
  @override
  List<Object?> get props => [
    categories,
    isLoading,
    lastErrorMessage,
    filterCategory,
    displayListItems,
  ];

  // copyWith remains the same, but without entries
  EntryState copyWith({
    // List<Entry>? entries, // Removed
    List<String>? categories,
    bool? isLoading,
    String? lastErrorMessage,
    String? filterCategory,
    List<dynamic>? displayListItems,
    bool clearLastError = false,
    bool clearFilter = false,
  }) {
    return EntryState(
      // entries: entries ?? this.entries, // Removed
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      lastErrorMessage:
          clearLastError ? null : (lastErrorMessage ?? this.lastErrorMessage),
      filterCategory:
          clearFilter ? null : (filterCategory ?? this.filterCategory),
      displayListItems: displayListItems ?? this.displayListItems,
    );
  }
}
