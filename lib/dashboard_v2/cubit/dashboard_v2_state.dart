part of 'dashboard_v2_cubit.dart';

// CC: Import needed for Color type

class DashboardV2State extends Equatable {
  final List<Entry> entries;
  final List<Category> categories; // CC: Add categories to state for color lookup
  final bool isLoading;
  final bool hasMoreEntries;
  final int selectedCarouselIndex;
  final bool isGeneratingInsight;
  final bool isClassifyingIntent;
  final IntentClassification? lastIntentClassification;
  final String? intentClassificationError;
  final Entry? pendingEntry; // CC: Temp entry shown during AI categorization
  final Uint8List? selectedImageBytes; // CP: Image selected for attachment

  const DashboardV2State({
    this.entries = const [],
    this.categories = const [],
    this.isLoading = false,
    this.hasMoreEntries = true,
    this.selectedCarouselIndex = 0,
    this.isGeneratingInsight = false,
    this.isClassifyingIntent = false,
    this.lastIntentClassification,
    this.intentClassificationError,
    this.pendingEntry,
    this.selectedImageBytes,
  });

  // CC: Combine pending entry with entries for display
  List<Entry> get displayEntries =>
      pendingEntry != null ? [pendingEntry!, ...entries] : entries;

  // CC: Derive current insight from selected entry (converts from SimpleInsight if needed)
  ComprehensiveInsight? get currentInsight {
    // CC: Use displayEntries to account for pending entry
    if (selectedCarouselIndex < displayEntries.length) {
      final entry = displayEntries[selectedCarouselIndex];

      // Prefer old format if it exists (for backwards compatibility)
      if (entry.insight != null) {
        return entry.insight;
      }

      // Convert new SimpleInsight to ComprehensiveInsight for display
      final simpleInsight = entry.simpleInsight;
      if (simpleInsight != null) {
        return ComprehensiveInsight(
          entryId: entry.timestamp.millisecondsSinceEpoch.toString(),
          entryText: entry.text,
          insights: [
            Insight(
              id: entry.timestamp.millisecondsSinceEpoch.toString(),
              type: InsightType.summary,
              title: 'Insight',
              content: simpleInsight.content,
              generatedAt: simpleInsight.generatedAt,
            ),
          ],
          generatedAt: simpleInsight.generatedAt,
        );
      }
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
    bool? isClassifyingIntent,
    IntentClassification? lastIntentClassification,
    String? intentClassificationError,
    Entry? pendingEntry,
    Uint8List? selectedImageBytes,
    bool clearLastIntentClassification = false,
    bool clearIntentClassificationError = false,
    bool clearPendingEntry = false,
    bool clearSelectedImage = false,
  }) {
    return DashboardV2State(
      entries: entries ?? this.entries,
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      hasMoreEntries: hasMoreEntries ?? this.hasMoreEntries,
      selectedCarouselIndex: selectedCarouselIndex ?? this.selectedCarouselIndex,
      isGeneratingInsight: isGeneratingInsight ?? this.isGeneratingInsight,
      isClassifyingIntent: isClassifyingIntent ?? this.isClassifyingIntent,
      lastIntentClassification: clearLastIntentClassification
          ? null
          : (lastIntentClassification ?? this.lastIntentClassification),
      intentClassificationError: clearIntentClassificationError
          ? null
          : (intentClassificationError ?? this.intentClassificationError),
      pendingEntry: clearPendingEntry ? null : (pendingEntry ?? this.pendingEntry),
      selectedImageBytes: clearSelectedImage ? null : (selectedImageBytes ?? this.selectedImageBytes),
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
    isClassifyingIntent,
    lastIntentClassification,
    intentClassificationError,
    pendingEntry,
    selectedImageBytes,
  ];
}
