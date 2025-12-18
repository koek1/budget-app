import 'package:hive/hive.dart';

part 'receipt_batch.g.dart';

@HiveType(typeId: 3)
class ReceiptBatch {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final List<String> transactionIds; // Store transaction IDs

  @HiveField(5)
  final double totalAmount;

  ReceiptBatch({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    required this.transactionIds,
    required this.totalAmount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'transactionIds': transactionIds,
      'totalAmount': totalAmount,
    };
  }

  factory ReceiptBatch.fromJson(Map<String, dynamic> json) {
    return ReceiptBatch(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      transactionIds: json['transactionIds'] != null
          ? List<String>.from(json['transactionIds'])
          : [],
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

