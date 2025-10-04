import 'dart:convert';
import 'package:equatable/equatable.dart'; // Add equatable import
import 'package:uuid/uuid.dart';
import '../dashboard_v2/model/insight.dart'; // CC: Import for ComprehensiveInsight

// Represents a single entry with text, a timestamp, and a category.
class Entry extends Equatable {
  // Extend Equatable
  final String id; // CC: Unique identifier for the entry
  final String text;
  final DateTime timestamp;
  final String category; // Added category field
  final bool isNew; // Track whether this is a newly added entry
  final bool isCompleted; // Track completion status for checklist items
  final bool isTask; // Track whether this entry is AI-detected as a task/todo
  final DateTime? completedAt; // CC: Track when the task was completed
  final ComprehensiveInsight? insight; // CC: AI-generated insights for this entry
  final bool isGeneratingInsight; // CC: Track if insight is being generated (initial or regeneration)

  Entry({
    String? id,
    required this.text,
    required this.timestamp,
    required this.category, // Make category required
    this.isNew = false, // Default to false
    this.isCompleted = false, // Default to false
    this.isTask = false, // Default to false
    this.completedAt, // CC: When the task was completed
    this.insight, // CC: Optional insight
    this.isGeneratingInsight = false, // CC: Default to false
  }) : id = id ?? const Uuid().v4(); // CC: Generate UUID if not provided

  // Factory constructor to create an Entry from a JSON map
  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'] as String? ?? const Uuid().v4(), // CC: Use existing ID or generate new one
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      category: json['category'] as String? ?? 'Unknown', // Default if missing
      isNew: json['isNew'] as bool? ?? false, // Default to false if missing
      isCompleted: json['isCompleted'] as bool? ?? false, // Default to false if missing
      isTask: json['isTask'] as bool? ?? false, // Default to false if missing
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null, // CC: Parse completedAt if present
      insight: json['insight'] != null
          ? ComprehensiveInsight.fromJson(json['insight'] as Map<String, dynamic>)
          : null, // CC: Parse insight if present
      isGeneratingInsight: json['isGeneratingInsight'] as bool? ?? false, // CC: Default to false if missing
    );
  }

  // Method to convert an Entry instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id, // CC: Add id to JSON
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'category': category, // Add category to JSON
      'isNew': isNew, // Add isNew to JSON
      'isCompleted': isCompleted, // Add isCompleted to JSON
      'isTask': isTask, // Add isTask to JSON
      'completedAt': completedAt?.toIso8601String(), // CC: Add completedAt to JSON
      'insight': insight?.toJson(), // CC: Add insight to JSON
      'isGeneratingInsight': isGeneratingInsight, // CC: Add isGeneratingInsight to JSON
    };
  }

  // Helper method to encode an Entry object to a JSON string
  String toJsonString() => jsonEncode(toJson());

  // Static helper method to decode a JSON string into an Entry object
  static Entry fromJsonString(String jsonString) => Entry.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  // Create a copy of this entry with modified properties
  Entry copyWith({
    String? id,
    String? text,
    DateTime? timestamp,
    String? category,
    bool? isNew,
    bool? isCompleted,
    bool? isTask,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    ComprehensiveInsight? insight,
    bool clearInsight = false,
    bool? isGeneratingInsight,
  }) {
    return Entry(
      id: id ?? this.id,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      isNew: isNew ?? this.isNew,
      isCompleted: isCompleted ?? this.isCompleted,
      isTask: isTask ?? this.isTask,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt), // CC: Support clearing completedAt
      insight: clearInsight ? null : (insight ?? this.insight), // CC: Support clearing insight
      isGeneratingInsight: isGeneratingInsight ?? this.isGeneratingInsight,
    );
  }

  // Convenience method to toggle completion status
  Entry toggleCompletion() {
    // CC: If completing, set completedAt; if uncompleting, clear it
    if (!isCompleted) {
      return copyWith(isCompleted: true, completedAt: DateTime.now());
    } else {
      return copyWith(isCompleted: false, clearCompletedAt: true);
    }
  }

  @override
  List<Object?> get props => [id, text, timestamp, category, isNew, isCompleted, isTask, completedAt, insight, isGeneratingInsight]; // Add props for Equatable
}
