import 'package:equatable/equatable.dart';
import 'simple_insight.dart';

enum InsightType {
  summary,
  emotion,
  pattern,
  theme,
  recommendation,
}

// CC: Helper to convert InsightType to/from string
extension InsightTypeExtension on InsightType {
  String get name {
    switch (this) {
      case InsightType.summary:
        return 'summary';
      case InsightType.emotion:
        return 'emotion';
      case InsightType.pattern:
        return 'pattern';
      case InsightType.theme:
        return 'theme';
      case InsightType.recommendation:
        return 'recommendation';
    }
  }

  static InsightType fromString(String name) {
    switch (name) {
      case 'summary':
        return InsightType.summary;
      case 'emotion':
        return InsightType.emotion;
      case 'pattern':
        return InsightType.pattern;
      case 'theme':
        return InsightType.theme;
      case 'recommendation':
        return InsightType.recommendation;
      default:
        throw ArgumentError('Unknown InsightType: $name');
    }
  }
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

  // CC: JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'content': content,
      'generatedAt': generatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory Insight.fromJson(Map<String, dynamic> json) {
    return Insight(
      id: json['id'] as String,
      type: InsightTypeExtension.fromString(json['type'] as String),
      title: json['title'] as String,
      content: json['content'] as String,
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
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
    final recommendation = getInsightByType(InsightType.recommendation);
    if (recommendation != null && recommendation.content.isNotEmpty) return recommendation;

    return getInsightByType(InsightType.summary);
  }

  SimpleInsight toSimpleInsight() {
    final primaryInsight = getPrimaryInsight();

    final content = primaryInsight?.content ?? 'No insight available';

    return SimpleInsight(
      content: content,
      generatedAt: generatedAt,
    );
  }

  @override
  List<Object?> get props => [entryId, entryText, insights, generatedAt, priority];

  // CC: JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'entryId': entryId,
      'entryText': entryText,
      'insights': insights.map((insight) => insight.toJson()).toList(),
      'generatedAt': generatedAt.toIso8601String(),
      'priority': priority,
    };
  }

  factory ComprehensiveInsight.fromJson(Map<String, dynamic> json) {
    return ComprehensiveInsight(
      entryId: json['entryId'] as String,
      entryText: json['entryText'] as String,
      insights: (json['insights'] as List)
          .map((insightJson) => Insight.fromJson(insightJson as Map<String, dynamic>))
          .toList(),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      priority: json['priority'] as String?,
    );
  }
}
