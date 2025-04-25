import 'dart:convert';

// Represents a single entry with text, a timestamp, and a category.
class Entry {
  final String text;
  final DateTime timestamp;
  final String category; // Added category field
  final bool isNew; // Track whether this is a newly added entry

  Entry({
    required this.text,
    required this.timestamp,
    required this.category, // Make category required
    this.isNew = false, // Default to false
  });

  // Factory constructor to create an Entry from a JSON map
  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      // Handle potential missing category in older data during load?
      // For now, assume it exists or provide default if needed.
      category: json['category'] as String? ?? 'Unknown', // Default if missing
      isNew: json['isNew'] as bool? ?? false, // Default to false if missing
    );
  }

  // Method to convert an Entry instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'category': category, // Add category to JSON
      'isNew': isNew, // Add isNew to JSON
    };
  }

  // Helper method to encode an Entry object to a JSON string
  String toJsonString() => jsonEncode(toJson());

  // Static helper method to decode a JSON string into an Entry object
  static Entry fromJsonString(String jsonString) =>
      Entry.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

  // Create a copy of this entry with modified properties
  Entry copyWith({
    String? text,
    DateTime? timestamp,
    String? category,
    bool? isNew,
  }) {
    return Entry(
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      isNew: isNew ?? this.isNew,
    );
  }
}
