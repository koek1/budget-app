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
    await box.add(transaction);
  }

  static Future<void> updateTransaction(Transaction transaction) async {
    final box = Hive.box<Transaction>('transactionsBox');
    final index = box.values.toList().indexWhere((t) => t.id == transaction.id);
    if (index != -1) {
      await box.putAt(index, transaction);
    }
  }

  static Future<void> deleteTransaction(String transactionId) async {
    final box = Hive.box<Transaction>('transactionsBox');
    final index = box.values.toList().indexWhere((t) => t.id == transactionId);
    if (index != -1) {
      await box.deleteAt(index);
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

