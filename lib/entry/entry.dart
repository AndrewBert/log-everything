import 'dart:convert';
import 'package:equatable/equatable.dart'; // Add equatable import
import '../dashboard_v2/model/insight.dart'; // CC: Import for ComprehensiveInsight
import '../dashboard_v2/model/simple_insight.dart';
import '../utils/logger.dart';

// Represents a single entry with text, a timestamp, and a category.
class Entry extends Equatable {
  // Extend Equatable
  final String text;
  final DateTime timestamp;
  final String category; // Added category field
  final bool isNew; // Track whether this is a newly added entry
  final bool isCompleted; // Track completion status for checklist items
  final bool isTask; // Track whether this entry is AI-detected as a task/todo
  final ComprehensiveInsight? insight; // CC: AI-generated insights for this entry (OLD - kept for backwards compatibility)
  final SimpleInsight? simpleInsight; // NEW - preferred format

  const Entry({
    required this.text,
    required this.timestamp,
    required this.category, // Make category required
    this.isNew = false, // Default to false
    this.isCompleted = false, // Default to false
    this.isTask = false, // Default to false
    this.insight, // CC: Optional insight
    this.simpleInsight,
  });

  // Factory constructor to create an Entry from a JSON map
  factory Entry.fromJson(Map<String, dynamic> json) {
    // Parse old format (for backwards compatibility)
    ComprehensiveInsight? oldInsight;
    if (json['insight'] != null) {
      oldInsight = ComprehensiveInsight.fromJson(json['insight'] as Map<String, dynamic>);
    }

    // Parse new format
    SimpleInsight? newInsight;
    if (json['simpleInsight'] != null) {
      newInsight = SimpleInsight.fromJson(json['simpleInsight'] as Map<String, dynamic>);
    }

    return Entry(
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      category: json['category'] as String? ?? 'Unknown', // Default if missing
      isNew: json['isNew'] as bool? ?? false, // Default to false if missing
      isCompleted: json['isCompleted'] as bool? ?? false, // Default to false if missing
      isTask: json['isTask'] as bool? ?? false, // Default to false if missing
      insight: oldInsight,
      simpleInsight: newInsight,
    );
  }

  // Method to convert an Entry instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'category': category, // Add category to JSON
      'isNew': isNew, // Add isNew to JSON
      'isCompleted': isCompleted, // Add isCompleted to JSON
      'isTask': isTask, // Add isTask to JSON
      'insight': insight?.toJson(), // CC: Add insight to JSON (keep old format for now)
      'simpleInsight': simpleInsight?.toJson(), // Add new format
    };
  }

  // Helper method to encode an Entry object to a JSON string
  String toJsonString() => jsonEncode(toJson());

  // Static helper method to decode a JSON string into an Entry object
  static Entry fromJsonString(String jsonString) => Entry.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  // Create a copy of this entry with modified properties
  Entry copyWith({
    String? text,
    DateTime? timestamp,
    String? category,
    bool? isNew,
    bool? isCompleted,
    bool? isTask,
    ComprehensiveInsight? insight,
    bool clearInsight = false,
    SimpleInsight? simpleInsight,
    bool clearSimpleInsight = false,
  }) {
    return Entry(
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      isNew: isNew ?? this.isNew,
      isCompleted: isCompleted ?? this.isCompleted,
      isTask: isTask ?? this.isTask,
      insight: clearInsight ? null : (insight ?? this.insight), // CC: Support clearing insight
      simpleInsight: clearSimpleInsight ? null : (simpleInsight ?? this.simpleInsight),
    );
  }

  // Convenience method to toggle completion status
  Entry toggleCompletion() => copyWith(isCompleted: !isCompleted);

  /// Returns the current insight, preferring new format over old.
  /// Converts old ComprehensiveInsight to SimpleInsight on-the-fly if needed.
  SimpleInsight? getCurrentInsight() {
    final entryId = timestamp.millisecondsSinceEpoch.toString();

    // Prefer new format
    if (simpleInsight != null) {
      AppLogger.info('[INSIGHT-READ] Entry $entryId: Using NEW simpleInsight format - "${simpleInsight!.content.substring(0, simpleInsight!.content.length > 30 ? 30 : simpleInsight!.content.length)}..."');
      return simpleInsight;
    }

    // Fallback: convert old format on-the-fly
    if (insight != null) {
      final converted = insight!.toSimpleInsight();
      AppLogger.info('[INSIGHT-READ] Entry $entryId: Converting OLD insight to SimpleInsight - "${converted.content.substring(0, converted.content.length > 30 ? 30 : converted.content.length)}..."');
      return converted;
    }

    AppLogger.info('[INSIGHT-READ] Entry $entryId: NO insight available (both simpleInsight and insight are null)');
    return null;
  }

  @override
  List<Object?> get props => [text, timestamp, category, isNew, isCompleted, isTask, insight, simpleInsight]; // Add props for Equatable
}
