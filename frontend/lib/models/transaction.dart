import 'pachakge:hive/hive.dart';

part 'transaction.g.dart';

@HiveType(typeId: 0)
class Transaction {
    @HiveField(0)
    final String id;

    @HiveField(1)
    final double amount;

    @HiveField(2)
    final String type;    // 'income' or 'expense'

    @HiveField(3)
    final String category;

    @HiveField(4)
    final String description;

    @HiveField(5)
    final DateTime date;

    @HiveField(6)
    bool isSynced;

    Transaction({
        rerquired this.id,
        required this.amount,
        required this.type,
        required this.category,
        required this.description,
        required this.date,
        this.isSynced = true,
    });

    Map <String, dynamic> toJson() {
        return{
            'amount': amount,
            'type': type,
            'category': category,
            'description': description,
            'date': date.toIso8601String(),
        };
    }

    factory Transaction.fromJson(Map <String, dynamic> json) {
        return Transaction (
            id: json['_id'] ?? '',
            amount: (json['amount'] as num).toDouble(),
            type: json['type'],
            category: json['category'],
            description: json['description'] ?? '',
            date: DateTime.parse(json['date']),
            isSynced: json['isSynced'] ?? true,
        );
    }
}