part of 'category_entries_cubit.dart';

class CategoryEntriesState extends Equatable {
  final String categoryName;
  final Category? category;
  final List<Entry> entries;
  final bool isLoading;

  const CategoryEntriesState({
    required this.categoryName,
    this.category,
    this.entries = const [],
    this.isLoading = true,
  });

  CategoryEntriesState copyWith({
    String? categoryName,
    Category? category,
    List<Entry>? entries,
    bool? isLoading,
    bool clearCategory = false,
  }) {
    return CategoryEntriesState(
      categoryName: categoryName ?? this.categoryName,
      category: clearCategory ? null : (category ?? this.category),
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [categoryName, category, entries, isLoading];
}