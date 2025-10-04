import 'package:equatable/equatable.dart';

class SimpleInsight extends Equatable {
  final String content;
  final DateTime generatedAt;

  const SimpleInsight({
    required this.content,
    required this.generatedAt,
  });

  @override
  List<Object?> get props => [content, generatedAt];

  // JSON serialization
  Map<String, dynamic> toJson() => {
        'content': content,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory SimpleInsight.fromJson(Map<String, dynamic> json) => SimpleInsight(
        content: json['content'] as String,
        generatedAt: DateTime.parse(json['generatedAt'] as String),
      );

  @override
  String toString() => 'SimpleInsight(content: $content)';
}
