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
        // Silently return empty list on error - user will see empty state
        return [];
      }
    } catch (e) {
      // Silently return empty list on error - user will see empty state
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
      // Preserve all transaction properties including recurring fields
      final userTransaction = Transaction(
        id: transaction.id,
        userId: currentUser.id,
        amount: transaction.amount,
        type: transaction.type,
        category: transaction.category,
        description: transaction.description,
        date: transaction.date,
        isSynced: transaction.isSynced,
        isRecurring: transaction.isRecurring,
        recurringEndDate: transaction.recurringEndDate,
        recurringFrequency: transaction.recurringFrequency,
        isSubscription: transaction.isSubscription,
      );
      
      // Use add to ensure proper auto-incrementing and listener notifications
      // ValueListenableBuilder will automatically update when box.add() is called
      await box.add(userTransaction);
      
      // Check budgets and send notifications if this is an expense
      if (userTransaction.type == 'expense') {
        BudgetNotificationService.checkBudgetsAndNotify().catchError((e) {
          // Silently fail - budget checking failure shouldn't prevent transaction from being saved
        });
      }
    } catch (e) {
      // Re-throw with user-friendly message
      if (e.toString().contains('Exception: ')) {
        rethrow;
      }
      throw Exception('Failed to save transaction. Please try again.');
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
            // Preserve all transaction properties including recurring fields
            final userTransaction = Transaction(
              id: transaction.id,
              userId: currentUser.id,
              amount: transaction.amount,
              type: transaction.type,
              category: transaction.category,
              description: transaction.description,
              date: transaction.date,
              isSynced: transaction.isSynced,
              isRecurring: transaction.isRecurring,
              recurringEndDate: transaction.recurringEndDate,
              recurringFrequency: transaction.recurringFrequency,
              isSubscription: transaction.isSubscription,
            );
            await box.putAt(i, userTransaction);
            return;
          }
        } catch (e) {
          // Skip corrupted entries silently
          continue;
        }
      }
      throw Exception('Transaction not found or does not belong to current user');
    } catch (e) {
      // Re-throw with user-friendly message if needed
      if (e.toString().contains('Exception: ')) {
        rethrow;
      }
      throw Exception('Failed to update transaction. Please try again.');
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
          // Skip corrupted entries silently
          continue;
        }
      }
      throw Exception('Transaction not found or does not belong to current user');
    } catch (e) {
      // Re-throw with user-friendly message if needed
      if (e.toString().contains('Exception: ')) {
        rethrow;
      }
      throw Exception('Failed to delete transaction. Please try again.');
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
        // Clear corrupted user data silently
        await box.clear();
        return null;
      }
    } catch (e) {
      // Return null on error - user will be prompted to login
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
      // Re-throw with user-friendly message
      if (e.toString().contains('Exception: ')) {
        rethrow;
      }
      throw Exception('Failed to save user session. Please try again.');
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
      // Silently continue - this is not critical
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
      // Re-throw with user-friendly message
      if (e.toString().contains('Exception: ')) {
        rethrow;
      }
      throw Exception('Failed to clear data. Please try again.');
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
          // Skip corrupted entries silently
          continue;
        }
      }
      
      // Delete in reverse order to maintain indices
      for (var i = transactionsToDelete.length - 1; i >= 0; i--) {
        try {
          await box.deleteAt(transactionsToDelete[i]);
        } catch (e) {
          // Continue with next deletion silently
        }
      }
    } catch (e) {
      // Re-throw with user-friendly message
      if (e.toString().contains('Exception: ')) {
        rethrow;
      }
      throw Exception('Failed to clear user transactions. Please try again.');
    }
  }
}

