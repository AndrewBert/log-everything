part of 'entry_cubit.dart';

// Extend Equatable
class EntryState extends Equatable {
  // Use List<Category> for categories to support descriptions
  final List<Category> categories;
  final bool isLoading;
  final String? lastErrorMessage;
  final String? filterCategory;
  final List<dynamic> displayListItems;

  const EntryState({
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
    List<Category>? categories,
    bool? isLoading,
    String? lastErrorMessage,
    String? filterCategory,
    List<dynamic>? displayListItems,
    bool clearLastError = false,
    bool clearFilter = false,
  }) {
    return EntryState(
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
