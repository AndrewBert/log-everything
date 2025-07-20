// CP: Category model for name/description support
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class Category extends Equatable {
  final String name;
  final String description;
  final bool isChecklist;
  final Color? color; // CC: Integrate color directly into category model

  const Category({
    required this.name,
    this.description = '',
    this.isChecklist = false,
    this.color,
  });

  Category copyWith({
    String? name,
    String? description,
    bool? isChecklist,
    Color? color,
    bool clearColor = false,
  }) {
    return Category(
      name: name ?? this.name,
      description: description ?? this.description,
      isChecklist: isChecklist ?? this.isChecklist,
      color: clearColor ? null : (color ?? this.color),
    );
  }

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    isChecklist: json['isChecklist'] as bool? ?? false,
    color: json['colorHex'] != null ? _colorFromHex(json['colorHex'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'isChecklist': isChecklist,
    if (color != null) 'colorHex': _colorToHex(color!),
  };

  // CC: Color conversion helpers
  static Color _colorFromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceAll('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static String _colorToHex(Color color) {
    int argb = color.toARGB32();
    String hex = argb.toRadixString(16).padLeft(8, '0');
    return '#${hex.substring(2)}';
  }

  @override
  List<Object?> get props => [name, description, isChecklist, color];
}
