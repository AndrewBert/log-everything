part of 'category_entries_cubit.dart';

class CategoryEntriesState extends Equatable {
  final String categoryName;
  final Category? category;
  final List<Entry> entries;
  final bool isLoading;
  final bool isLoadingMore; // CP: Loading state for pagination
  final bool hasMoreEntries; // CP: Whether more entries are available
  final Color? categoryColor; // CC: Store color in state so Equatable can detect changes

  const CategoryEntriesState({
    required this.categoryName,
    this.category,
    this.entries = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMoreEntries = true,
    this.categoryColor,
  });

  CategoryEntriesState copyWith({
    String? categoryName,
    Category? category,
    List<Entry>? entries,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreEntries,
    Color? categoryColor,
    bool clearCategory = false,
  }) {
    return CategoryEntriesState(
      categoryName: categoryName ?? this.categoryName,
      category: clearCategory ? null : (category ?? this.category),
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreEntries: hasMoreEntries ?? this.hasMoreEntries,
      categoryColor: categoryColor ?? this.categoryColor,
    );
  }

  // CP: Active todos for this category (uncompleted tasks only)
  List<Entry> get activeTodos => entries.where((e) => e.isTask && !e.isCompleted).toList();

  // CP: Regular entries (non-task items only)
  List<Entry> get regularEntries => entries.where((e) => !e.isTask).toList();

  @override
  List<Object?> get props => [categoryName, category, entries, isLoading, isLoadingMore, hasMoreEntries, categoryColor];
}
