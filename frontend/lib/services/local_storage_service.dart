import 'package:hive/hive.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/models/user.dart';
import 'package:budget_app/services/budget_notification_service.dart';

class LocalStorageService {
  // Transaction operations
  static Future<List<Transaction>> getTransactions() async {
    try {
      if (!Hive.isBoxOpen('transactionsBox')) {
        return [];
      }
      
      final box = Hive.box<Transaction>('transactionsBox');
      final currentUser = await getCurrentUser();
      
      if (currentUser == null) {
        return [];
      }
      
      // Filter transactions by current user - optimized to avoid full scan when possible
      try {
        return box.values.where((t) => t.userId == currentUser.id).toList();
      } catch (e) {
        print('Error filtering transactions: $e');
        return [];
      }
    } catch (e) {
      print('Error getting transactions: $e');
      return [];
    }
  }

  static Future<void> addTransaction(Transaction transaction) async {
    try {
      if (!Hive.isBoxOpen('transactionsBox')) {
        throw Exception('Transactions database is not available');
      }
      
      final box = Hive.box<Transaction>('transactionsBox');
      final currentUser = await getCurrentUser();
      
      if (currentUser == null) {
        throw Exception('User must be logged in to add transactions');
      }
      
      // Validate transaction data
      if (transaction.amount <= 0) {
        throw Exception('Transaction amount must be greater than 0');
      }
      if (transaction.category.isEmpty) {
        throw Exception('Transaction category is required');
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
      
      // Check budgets and send notifications if this is an expense
      if (userTransaction.type == 'expense') {
        BudgetNotificationService.checkBudgetsAndNotify().catchError((e) {
          print('Error checking budgets after transaction: $e');
          // Don't throw - budget checking failure shouldn't prevent transaction from being saved
        });
      }
    } catch (e) {
      print('Error adding transaction: $e');
      rethrow;
    }
  }

  static Future<void> updateTransaction(Transaction transaction) async {
    try {
      if (!Hive.isBoxOpen('transactionsBox')) {
        throw Exception('Transactions database is not available');
      }
      
      final box = Hive.box<Transaction>('transactionsBox');
      final currentUser = await getCurrentUser();
      
      if (currentUser == null) {
        throw Exception('User must be logged in to update transactions');
      }
      
      // Validate transaction data
      if (transaction.amount <= 0) {
        throw Exception('Transaction amount must be greater than 0');
      }
      if (transaction.category.isEmpty) {
        throw Exception('Transaction category is required');
      }
      
      // Find the transaction by ID and user ID - optimized to stop early
      for (var i = 0; i < box.length; i++) {
        try {
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
        } catch (e) {
          // Skip corrupted entries
          print('Error reading transaction at index $i: $e');
          continue;
        }
      }
      throw Exception('Transaction not found or does not belong to current user');
    } catch (e) {
      print('Error updating transaction: $e');
      rethrow;
    }
  }

  static Future<void> deleteTransaction(String transactionId) async {
    try {
      if (!Hive.isBoxOpen('transactionsBox')) {
        throw Exception('Transactions database is not available');
      }
      
      final box = Hive.box<Transaction>('transactionsBox');
      final currentUser = await getCurrentUser();
      
      if (currentUser == null) {
        throw Exception('User must be logged in to delete transactions');
      }
      
      if (transactionId.isEmpty) {
        throw Exception('Transaction ID is required');
      }
      
      // Find the transaction by ID and user ID
      for (var i = 0; i < box.length; i++) {
        try {
          final transaction = box.getAt(i);
          if (transaction?.id == transactionId && 
              transaction?.userId == currentUser.id) {
            await box.deleteAt(i);
            return;
          }
        } catch (e) {
          // Skip corrupted entries
          print('Error reading transaction at index $i: $e');
          continue;
        }
      }
      throw Exception('Transaction not found or does not belong to current user');
    } catch (e) {
      print('Error deleting transaction: $e');
      rethrow;
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
    try {
      if (!Hive.isBoxOpen('userBox')) {
        return null;
      }
      
      final box = Hive.box('userBox');
      final userId = box.get('userId');
      if (userId == null) return null;
      
      final userData = box.get('user');
      if (userData == null) return null;
      
      try {
        return User.fromJson(Map<String, dynamic>.from(userData));
      } catch (e) {
        print('Error parsing user data: $e');
        // Clear corrupted user data
        await box.clear();
        return null;
      }
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  static Future<void> saveUser(User user) async {
    try {
      if (!Hive.isBoxOpen('userBox')) {
        throw Exception('User database is not available');
      }
      
      final box = Hive.box('userBox');
      await box.put('userId', user.id);
      await box.put('user', user.toJson());
    } catch (e) {
      print('Error saving user: $e');
      rethrow;
    }
  }

  static Future<void> clearUser() async {
    try {
      if (Hive.isBoxOpen('userBox')) {
        final box = Hive.box('userBox');
        await box.clear();
      }
      // Note: We don't clear transactions here because they're filtered by userId
      // Transactions will be automatically filtered when a new user logs in
    } catch (e) {
      print('Error clearing user: $e');
      // Continue anyway - this is not critical
    }
  }

  static Future<bool> isLoggedIn() async {
    final box = Hive.box('userBox');
    return box.get('userId') != null;
  }

  // Clear all app data (for troubleshooting/reset)
  static Future<void> clearAllData() async {
    try {
      // Clear user session
      if (Hive.isBoxOpen('userBox')) {
        await Hive.box('userBox').clear();
      }
      
      // Clear all users
      if (Hive.isBoxOpen('usersBox')) {
        await Hive.box('usersBox').clear();
      }
      
      // Clear all transactions
      if (Hive.isBoxOpen('transactionsBox')) {
        await Hive.box<Transaction>('transactionsBox').clear();
      }
      
      // Note: We don't clear settingsBox to preserve user preferences
    } catch (e) {
      print('Error clearing all data: $e');
      rethrow;
    }
  }
  
  // Clear transactions for a specific user (when user is deleted)
  static Future<void> clearUserTransactions(String userId) async {
    try {
      if (!Hive.isBoxOpen('transactionsBox')) {
        return;
      }
      
      if (userId.isEmpty) {
        throw Exception('User ID is required');
      }
      
      final box = Hive.box<Transaction>('transactionsBox');
      final transactionsToDelete = <int>[];
      
      // Find all transactions for this user
      for (var i = 0; i < box.length; i++) {
        try {
          final transaction = box.getAt(i);
          if (transaction?.userId == userId) {
            transactionsToDelete.add(i);
          }
        } catch (e) {
          // Skip corrupted entries
          print('Error reading transaction at index $i: $e');
          continue;
        }
      }
      
      // Delete in reverse order to maintain indices
      for (var i = transactionsToDelete.length - 1; i >= 0; i--) {
        try {
          await box.deleteAt(transactionsToDelete[i]);
        } catch (e) {
          print('Error deleting transaction at index ${transactionsToDelete[i]}: $e');
          // Continue with next deletion
        }
      }
    } catch (e) {
      print('Error clearing user transactions: $e');
      rethrow;
    }
  }
}

