part of 'dashboard_v2_cubit.dart';

// CC: Import needed for Color type

class DashboardV2State extends Equatable {
  final List<Entry> entries;
  final List<Category> categories; // CC: Add categories to state for color lookup
  final bool isLoading;
  final bool hasMoreEntries;
  final int selectedCarouselIndex;
  final bool isGeneratingInsight;

  const DashboardV2State({
    this.entries = const [],
    this.categories = const [],
    this.isLoading = false,
    this.hasMoreEntries = true,
    this.selectedCarouselIndex = 0,
    this.isGeneratingInsight = false,
  });

  // CC: Derive current insight from selected entry
  ComprehensiveInsight? get currentInsight {
    if (selectedCarouselIndex < entries.length) {
      return entries[selectedCarouselIndex].insight;
    }
    return null;
  }

  DashboardV2State copyWith({
    List<Entry>? entries,
    List<Category>? categories,
    bool? isLoading,
    bool? hasMoreEntries,
    int? selectedCarouselIndex,
    bool? isGeneratingInsight,
  }) {
    return DashboardV2State(
      entries: entries ?? this.entries,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      hasMoreEntries: hasMoreEntries ?? this.hasMoreEntries,
      selectedCarouselIndex: selectedCarouselIndex ?? this.selectedCarouselIndex,
      isGeneratingInsight: isGeneratingInsight ?? this.isGeneratingInsight,
    );
  }

  // CC: Get entries organized by category, including empty categories
  Map<String, List<Entry>> get categorizedEntries {
    final Map<String, List<Entry>> result = {};

    // CC: First, add all categories (including empty ones)
    for (final category in categories) {
      result[category.name] = [];
    }

    // CC: Then populate with entries
    for (final entry in entries) {
      final category = entry.category;
      result.putIfAbsent(category, () => []).add(entry);
    }

    return result;
  }

  // CC: Get color for a category from state
  Color getCategoryColor(String categoryName) {
    final category = categories.firstWhere(
      (cat) => cat.name == categoryName,
      orElse: () => Category(name: categoryName),
    );
    return category.color ?? CategoryColors.getColorForCategory(categoryName);
  }

  @override
  List<Object?> get props => [
    entries,
    categories,
    isLoading,
    hasMoreEntries,
    selectedCarouselIndex,
    isGeneratingInsight,
  ];
}
