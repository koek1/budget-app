import 'package:hive/hive.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/models/user.dart';

class LocalStorageService {
  // Transaction operations
  static Future<List<Transaction>> getTransactions() async {
    final box = Hive.box<Transaction>('transactionsBox');
    return box.values.toList();
  }

  static Future<void> addTransaction(Transaction transaction) async {
    final box = Hive.box<Transaction>('transactionsBox');
    // Use add to ensure proper auto-incrementing and listener notifications
    // ValueListenableBuilder will automatically update when box.add() is called
    await box.add(transaction);
  }

  static Future<void> updateTransaction(Transaction transaction) async {
    final box = Hive.box<Transaction>('transactionsBox');
    // Find the transaction by ID and get its key
    for (var i = 0; i < box.length; i++) {
      final existingTransaction = box.getAt(i);
      if (existingTransaction?.id == transaction.id) {
        await box.putAt(i, transaction);
        return;
      }
    }
  }

  static Future<void> deleteTransaction(String transactionId) async {
    final box = Hive.box<Transaction>('transactionsBox');
    // Find the transaction by ID and get its key
    for (var i = 0; i < box.length; i++) {
      final transaction = box.getAt(i);
      if (transaction?.id == transactionId) {
        await box.deleteAt(i);
        return;
      }
    }
  }

  static Future<List<Transaction>> getTransactionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final transactions = await getTransactions();
    return transactions.where((t) {
      return t.date.isAfter(startDate.subtract(Duration(days: 1))) &&
          t.date.isBefore(endDate.add(Duration(days: 1)));
    }).toList();
  }

  // User operations
  static Future<User?> getCurrentUser() async {
    final box = Hive.box('userBox');
    final userId = box.get('userId');
    if (userId == null) return null;
    
    final userData = box.get('user');
    if (userData == null) return null;
    
    return User.fromJson(Map<String, dynamic>.from(userData));
  }

  static Future<void> saveUser(User user) async {
    final box = Hive.box('userBox');
    await box.put('userId', user.id);
    await box.put('user', user.toJson());
  }

  static Future<void> clearUser() async {
    final box = Hive.box('userBox');
    await box.clear();
  }

  static Future<bool> isLoggedIn() async {
    final box = Hive.box('userBox');
    return box.get('userId') != null;
  }
}

