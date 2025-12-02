import 'package:hive/hive.dart';

part 'custom_criteria.g.dart';

@HiveType(typeId: 2)
class CustomCriteria {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId; // Associate criteria with user

  @HiveField(2)
  final String type; // 'income' or 'expense'

  @HiveField(3)
  final String name; // Category name

  @HiveField(4)
  final DateTime createdAt;

  CustomCriteria({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CustomCriteria.fromJson(Map<String, dynamic> json) {
    return CustomCriteria(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

