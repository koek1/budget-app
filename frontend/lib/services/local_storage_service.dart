import 'package:hive/hive.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/models/user.dart';

class LocalStorageService {
  // Transaction operations
  static Future<List<Transaction>> getTransactions() async {
    final box = Hive.box<Transaction>('transactionsBox');
    final currentUser = await getCurrentUser();
    
    if (currentUser == null) {
      return [];
    }
    
    // Filter transactions by current user
    return box.values.where((t) => t.userId == currentUser.id).toList();
  }

  static Future<void> addTransaction(Transaction transaction) async {
    final box = Hive.box<Transaction>('transactionsBox');
    final currentUser = await getCurrentUser();
    
    if (currentUser == null) {
      throw Exception('User must be logged in to add transactions');
    }
    
    // Ensure transaction is associated with current user
    final userTransaction = Transaction(
      id: transaction.id,
      userId: currentUser.id,
      amount: transaction.amount,
      type: transaction.type,
      category: transaction.category,
      description: transaction.description,
      date: transaction.date,
      isSynced: transaction.isSynced,
    );
    
    // Use add to ensure proper auto-incrementing and listener notifications
    // ValueListenableBuilder will automatically update when box.add() is called
    await box.add(userTransaction);
  }

  static Future<void> updateTransaction(Transaction transaction) async {
    final box = Hive.box<Transaction>('transactionsBox');
    final currentUser = await getCurrentUser();
    
    if (currentUser == null) {
      throw Exception('User must be logged in to update transactions');
    }
    
    // Find the transaction by ID and user ID
    for (var i = 0; i < box.length; i++) {
      final existingTransaction = box.getAt(i);
      if (existingTransaction?.id == transaction.id && 
          existingTransaction?.userId == currentUser.id) {
        // Ensure transaction remains associated with current user
        final userTransaction = Transaction(
          id: transaction.id,
          userId: currentUser.id,
          amount: transaction.amount,
          type: transaction.type,
          category: transaction.category,
          description: transaction.description,
          date: transaction.date,
          isSynced: transaction.isSynced,
        );
        await box.putAt(i, userTransaction);
        return;
      }
    }
    throw Exception('Transaction not found or does not belong to current user');
  }

  static Future<void> deleteTransaction(String transactionId) async {
    final box = Hive.box<Transaction>('transactionsBox');
    final currentUser = await getCurrentUser();
    
    if (currentUser == null) {
      throw Exception('User must be logged in to delete transactions');
    }
    
    // Find the transaction by ID and user ID
    for (var i = 0; i < box.length; i++) {
      final transaction = box.getAt(i);
      if (transaction?.id == transactionId && 
          transaction?.userId == currentUser.id) {
        await box.deleteAt(i);
        return;
      }
    }
    throw Exception('Transaction not found or does not belong to current user');
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
    // Note: We don't clear transactions here because they're filtered by userId
    // Transactions will be automatically filtered when a new user logs in
  }

  static Future<bool> isLoggedIn() async {
    final box = Hive.box('userBox');
    return box.get('userId') != null;
  }

  // Clear all app data (for troubleshooting/reset)
  static Future<void> clearAllData() async {
    // Clear user session
    await Hive.box('userBox').clear();
    
    // Clear all users
    await Hive.box('usersBox').clear();
    
    // Clear all transactions
    await Hive.box<Transaction>('transactionsBox').clear();
    
    // Note: We don't clear settingsBox to preserve user preferences
  }
  
  // Clear transactions for a specific user (when user is deleted)
  static Future<void> clearUserTransactions(String userId) async {
    final box = Hive.box<Transaction>('transactionsBox');
    final transactionsToDelete = <int>[];
    
    // Find all transactions for this user
    for (var i = 0; i < box.length; i++) {
      final transaction = box.getAt(i);
      if (transaction?.userId == userId) {
        transactionsToDelete.add(i);
      }
    }
    
    // Delete in reverse order to maintain indices
    for (var i = transactionsToDelete.length - 1; i >= 0; i--) {
      await box.deleteAt(transactionsToDelete[i]);
    }
  }
}

