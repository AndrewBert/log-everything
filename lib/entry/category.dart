// CP: Category model for name/description support
import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String name;
  final String description;
  final bool isChecklist;

  const Category({required this.name, this.description = '', this.isChecklist = false});

  Category copyWith({String? name, String? description, bool? isChecklist}) {
    return Category(
      name: name ?? this.name, 
      description: description ?? this.description,
      isChecklist: isChecklist ?? this.isChecklist,
    );
  }

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        isChecklist: json['isChecklist'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'name': name, 'description': description, 'isChecklist': isChecklist};

  @override
  List<Object?> get props => [name, description, isChecklist];
}
