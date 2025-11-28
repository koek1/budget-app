import 'package:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 0)
class Transaction {
    @HiveField(0)
    final String id;

    @HiveField(1)
    final String userId;  // Associate transaction with user

    @HiveField(2)
    final double amount;

    @HiveField(3)
    final String type;    // 'income' or 'expense'

    @HiveField(4)
    final String category;

    @HiveField(5)
    final String description;

    @HiveField(6)
    final DateTime date;

    @HiveField(7)
    bool isSynced;

    Transaction({
        required this.id,
        required this.userId,
        required this.amount,
        required this.type,
        required this.category,
        required this.description,
        required this.date,
        this.isSynced = true,
    });

    Map<String, dynamic> toJson() {
        return {
            'userId': userId,
            'amount': amount,
            'type': type,
            'category': category,
            'description': description,
            'date': date.toIso8601String(),
        };
    }

    factory Transaction.fromJson(Map<String, dynamic> json) {
        return Transaction(
            id: json['_id'] ?? json['id'] ?? '',
            userId: json['userId'] ?? '',
            amount: (json['amount'] as num).toDouble(),
            type: json['type'],
            category: json['category'],
            description: json['description'] ?? '',
            date: DateTime.parse(json['date']),
            isSynced: json['isSynced'] ?? true,
        );
    }
}