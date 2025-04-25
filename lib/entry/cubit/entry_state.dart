part of 'entry_cubit.dart';

class EntryState {
  final List<Entry> entries;
  final List<String> categories;
  final bool isLoading;
  final String? lastErrorMessage;
  final String? filterCategory; // Add filter category
  final List<dynamic> displayListItems; // Add processed list for UI

  EntryState({
    this.entries = const [],
    this.categories = const [],
    this.isLoading = false,
    this.lastErrorMessage,
    this.filterCategory, // Initialize filter
    this.displayListItems = const [], // Initialize display list
  });

  // Helper method to create a copy with updated values
  EntryState copyWith({
    List<Entry>? entries,
    List<String>? categories,
    bool? isLoading,
    String? lastErrorMessage,
    String? filterCategory, // Add filter to copyWith
    List<dynamic>? displayListItems, // Add displayListItems to copyWith
    bool clearLastError = false,
    bool clearFilter = false, // Add flag to clear filter
  }) {
    return EntryState(
      entries: entries ?? this.entries,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      lastErrorMessage:
          clearLastError ? null : (lastErrorMessage ?? this.lastErrorMessage),
      filterCategory:
          clearFilter
              ? null
              : (filterCategory ??
                  this.filterCategory), // Handle filter update/clear
      displayListItems: displayListItems ?? this.displayListItems,
    );
  }
}
