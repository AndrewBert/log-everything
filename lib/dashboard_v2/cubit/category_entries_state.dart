part of 'category_entries_cubit.dart';

class CategoryEntriesState extends Equatable {
  final String categoryName;
  final List<Entry> entries;
  final bool isLoading;

  const CategoryEntriesState({
    required this.categoryName,
    this.entries = const [],
    this.isLoading = true,
  });

  CategoryEntriesState copyWith({
    String? categoryName,
    List<Entry>? entries,
    bool? isLoading,
  }) {
    return CategoryEntriesState(
      categoryName: categoryName ?? this.categoryName,
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [categoryName, entries, isLoading];
}