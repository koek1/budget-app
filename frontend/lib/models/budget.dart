import 'package:hive/hive.dart';

part 'budget.g.dart';

@HiveType(typeId: 4)
class Budget {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String? category; // null for overall budget, category name for category budget

  @HiveField(3)
  final double amount;

  @HiveField(4)
  final String period; // 'monthly', 'weekly', 'yearly'

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final DateTime updatedAt;

  @HiveField(7)
  final double? warningThreshold; // Percentage (e.g., 80 for 80%) - null means default 80%

  @HiveField(8)
  final bool isActive;

  Budget({
    required this.id,
    required this.userId,
    this.category,
    required this.amount,
    this.period = 'monthly',
    required this.createdAt,
    required this.updatedAt,
    this.warningThreshold,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'category': category,
      'amount': amount,
      'period': period,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'warningThreshold': warningThreshold,
      'isActive': isActive,
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] ?? json['_id'] ?? '',
      userId: json['userId'] ?? '',
      category: json['category'],
      amount: (json['amount'] as num).toDouble(),
      period: json['period'] ?? 'monthly',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      warningThreshold: json['warningThreshold'] != null
          ? (json['warningThreshold'] as num).toDouble()
          : null,
      isActive: json['isActive'] ?? true,
    );
  }

  Budget copyWith({
    String? id,
    String? userId,
    String? category,
    double? amount,
    String? period,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? warningThreshold,
    bool? isActive,
  }) {
    return Budget(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      isActive: isActive ?? this.isActive,
    );
  }
}

