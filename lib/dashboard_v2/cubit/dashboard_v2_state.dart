part of 'dashboard_v2_cubit.dart';

class DashboardV2State extends Equatable {
  final List<Entry> entries;
  final bool isLoading;
  final bool hasMoreEntries;
  final int selectedCarouselIndex;
  final Map<String, ComprehensiveInsight> insightsCache;
  final ComprehensiveInsight? currentInsight;
  final bool isGeneratingInsight;

  const DashboardV2State({
    this.entries = const [],
    this.isLoading = false,
    this.hasMoreEntries = true,
    this.selectedCarouselIndex = 0,
    this.insightsCache = const {},
    this.currentInsight,
    this.isGeneratingInsight = false,
  });

  DashboardV2State copyWith({
    List<Entry>? entries,
    bool? isLoading,
    bool? hasMoreEntries,
    int? selectedCarouselIndex,
    Map<String, ComprehensiveInsight>? insightsCache,
    ComprehensiveInsight? currentInsight,
    bool clearCurrentInsight = false,
    bool? isGeneratingInsight,
  }) {
    return DashboardV2State(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      hasMoreEntries: hasMoreEntries ?? this.hasMoreEntries,
      selectedCarouselIndex: selectedCarouselIndex ?? this.selectedCarouselIndex,
      insightsCache: insightsCache ?? this.insightsCache,
      currentInsight: clearCurrentInsight ? null : (currentInsight ?? this.currentInsight),
      isGeneratingInsight: isGeneratingInsight ?? this.isGeneratingInsight,
    );
  }

  @override
  List<Object?> get props => [
        entries,
        isLoading,
        hasMoreEntries,
        selectedCarouselIndex,
        insightsCache,
        currentInsight,
        isGeneratingInsight,
      ];
}