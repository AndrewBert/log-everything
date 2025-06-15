import 'dart:convert';
import 'package:equatable/equatable.dart'; // Add equatable import

// Represents a single entry with text, a timestamp, and a category.
class Entry extends Equatable {
  // Extend Equatable
  final String text;
  final DateTime timestamp;
  final String category; // Added category field
  final bool isNew; // Track whether this is a newly added entry
  final bool isCompleted; // Track completion status for checklist items
  final bool isTask; // Track whether this entry is AI-detected as a task/todo

  const Entry({
    required this.text,
    required this.timestamp,
    required this.category, // Make category required
    this.isNew = false, // Default to false
    this.isCompleted = false, // Default to false
    this.isTask = false, // Default to false
  });

  // Factory constructor to create an Entry from a JSON map
  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      category: json['category'] as String? ?? 'Unknown', // Default if missing
      isNew: json['isNew'] as bool? ?? false, // Default to false if missing
      isCompleted: json['isCompleted'] as bool? ?? false, // Default to false if missing
      isTask: json['isTask'] as bool? ?? false, // Default to false if missing
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
    };
  }

  // Helper method to encode an Entry object to a JSON string
  String toJsonString() => jsonEncode(toJson());

  // Static helper method to decode a JSON string into an Entry object
  static Entry fromJsonString(String jsonString) => Entry.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  // Create a copy of this entry with modified properties
  Entry copyWith({String? text, DateTime? timestamp, String? category, bool? isNew, bool? isCompleted, bool? isTask}) {
    return Entry(
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      isNew: isNew ?? this.isNew,
      isCompleted: isCompleted ?? this.isCompleted,
      isTask: isTask ?? this.isTask,
    );
  }

  // Convenience method to toggle completion status
  Entry toggleCompletion() => copyWith(isCompleted: !isCompleted);

  @override
  List<Object?> get props => [text, timestamp, category, isNew, isCompleted, isTask]; // Add props for Equatable
}
