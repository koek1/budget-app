import 'dart:convert';
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

    @HiveField(8)
    bool isRecurring;

    @HiveField(9)
    DateTime? recurringEndDate;

    @HiveField(10)
    String? recurringFrequency; // 'monthly', 'weekly', 'biweekly', 'yearly'

    @HiveField(11)
    bool isSubscription; // For subscriptions like Gym, Spotify, Netflix, etc.

    @HiveField(12)
    int? subscriptionPaymentDay; // Day of month (1-31) when subscription is due

    @HiveField(13)
    String? subscriptionPriceHistory; // JSON string of price history: [{"date": "2024-01-01", "amount": 9.99}]

    Transaction({
        required this.id,
        required this.userId,
        required this.amount,
        required this.type,
        required this.category,
        required this.description,
        required this.date,
        this.isSynced = true,
        this.isRecurring = false,
        this.recurringEndDate,
        this.recurringFrequency,
        this.isSubscription = false,
        this.subscriptionPaymentDay,
        this.subscriptionPriceHistory,
    });

    Map<String, dynamic> toJson() {
        return {
            'userId': userId,
            'amount': amount,
            'type': type,
            'category': category,
            'description': description,
            'date': date.toIso8601String(),
            'isRecurring': isRecurring,
            'recurringEndDate': recurringEndDate?.toIso8601String(),
            'recurringFrequency': recurringFrequency,
            'isSubscription': isSubscription,
            'subscriptionPaymentDay': subscriptionPaymentDay,
            'subscriptionPriceHistory': subscriptionPriceHistory,
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
            isRecurring: json['isRecurring'] ?? false,
            recurringEndDate: json['recurringEndDate'] != null 
                ? DateTime.parse(json['recurringEndDate']) 
                : null,
            recurringFrequency: json['recurringFrequency'],
            isSubscription: json['isSubscription'] ?? false,
            subscriptionPaymentDay: json['subscriptionPaymentDay'] != null 
                ? (json['subscriptionPaymentDay'] as num).toInt() 
                : null,
            subscriptionPriceHistory: json['subscriptionPriceHistory'],
        );
    }

    // Helper methods for subscription price history
    List<Map<String, dynamic>> getPriceHistory() {
        if (subscriptionPriceHistory == null || subscriptionPriceHistory!.isEmpty) {
            return [];
        }
        try {
            final decoded = jsonDecode(subscriptionPriceHistory!);
            if (decoded is List) {
                return List<Map<String, dynamic>>.from(decoded);
            }
            return [];
        } catch (e) {
            return [];
        }
    }

    void addPriceChange(DateTime date, double amount) {
        final history = getPriceHistory();
        history.add({
            'date': date.toIso8601String(),
            'amount': amount,
        });
        // Sort by date
        history.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
        subscriptionPriceHistory = jsonEncode(history);
    }

    double getCurrentPrice() {
        final history = getPriceHistory();
        if (history.isEmpty) {
            return amount; // Use transaction amount as default
        }
        // Get the most recent price
        final latest = history.last;
        return (latest['amount'] as num).toDouble();
    }
}