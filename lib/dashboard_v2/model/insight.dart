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

  const ComprehensiveInsight({
    required this.entryId,
    required this.entryText,
    required this.insights,
    required this.generatedAt,
  });

  Insight? getInsightByType(InsightType type) {
    try {
      return insights.firstWhere((insight) => insight.type == type);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [entryId, entryText, insights, generatedAt];
}