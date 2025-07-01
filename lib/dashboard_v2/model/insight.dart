import 'package:equatable/equatable.dart';

enum InsightType {
  summary,
  emotion,
  pattern,
  theme,
  recommendation,
}

class Insight extends Equatable {
  final String id;
  final InsightType type;
  final String title;
  final String content;
  final DateTime generatedAt;
  final Map<String, dynamic>? metadata;

  const Insight({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.generatedAt,
    this.metadata,
  });

  @override
  List<Object?> get props => [id, type, title, content, generatedAt, metadata];
}

class ComprehensiveInsight extends Equatable {
  final String entryId;
  final String entryText;
  final List<Insight> insights;
  final DateTime generatedAt;
  final String? priority;

  const ComprehensiveInsight({
    required this.entryId,
    required this.entryText,
    required this.insights,
    required this.generatedAt,
    this.priority,
  });

  Insight? getInsightByType(InsightType type) {
    try {
      return insights.firstWhere((insight) => insight.type == type);
    } catch (_) {
      return null;
    }
  }

  Insight? getPrimaryInsight() {
    // CP: First, check if AI provided a priority
    if (priority != null) {
      switch (priority) {
        case 'pattern':
          final pattern = getInsightByType(InsightType.pattern);
          if (pattern != null && pattern.content.isNotEmpty) return pattern;
          break;
        case 'recommendation':
          final recommendation = getInsightByType(InsightType.recommendation);
          if (recommendation != null && recommendation.content.isNotEmpty) return recommendation;
          break;
        case 'summary':
          final summary = getInsightByType(InsightType.summary);
          if (summary != null) return summary;
          break;
      }
    }
    
    // CP: Fallback logic if priority doesn't work
    final pattern = getInsightByType(InsightType.pattern);
    if (pattern != null && pattern.content.isNotEmpty) return pattern;
    
    final recommendation = getInsightByType(InsightType.recommendation);
    if (recommendation != null && recommendation.content.isNotEmpty) return recommendation;
    
    return getInsightByType(InsightType.summary);
  }

  @override
  List<Object?> get props => [entryId, entryText, insights, generatedAt, priority];
}