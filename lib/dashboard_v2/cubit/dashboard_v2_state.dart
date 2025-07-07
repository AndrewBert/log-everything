part of 'dashboard_v2_cubit.dart';

class DashboardV2State extends Equatable {
  final List<Entry> entries;
  final bool isLoading;
  final bool hasMoreEntries;
  final int selectedCarouselIndex;
  final bool isGeneratingInsight;

  const DashboardV2State({
    this.entries = const [],
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
    bool? isLoading,
    bool? hasMoreEntries,
    int? selectedCarouselIndex,
    bool? isGeneratingInsight,
  }) {
    return DashboardV2State(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      hasMoreEntries: hasMoreEntries ?? this.hasMoreEntries,
      selectedCarouselIndex: selectedCarouselIndex ?? this.selectedCarouselIndex,
      isGeneratingInsight: isGeneratingInsight ?? this.isGeneratingInsight,
    );
  }

  // CC: Get entries organized by category
  Map<String, List<Entry>> get categorizedEntries {
    final Map<String, List<Entry>> result = {};
    
    for (final entry in entries) {
      final category = entry.category ?? 'Uncategorized';
      result.putIfAbsent(category, () => []).add(entry);
    }
    
    return result;
  }

  @override
  List<Object?> get props => [
        entries,
        isLoading,
        hasMoreEntries,
        selectedCarouselIndex,
        isGeneratingInsight,
      ];
}