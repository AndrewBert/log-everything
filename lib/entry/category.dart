// CP: Category model for name/description support
import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String name;
  final String description;

  const Category({required this.name, this.description = ''});

  Category copyWith({String? name, String? description}) {
    return Category(name: name ?? this.name, description: description ?? this.description);
  }

  factory Category.fromJson(Map<String, dynamic> json) =>
      Category(name: json['name'] as String, description: json['description'] as String? ?? '');

  Map<String, dynamic> toJson() => {'name': name, 'description': description};

  @override
  List<Object?> get props => [name, description];
}
