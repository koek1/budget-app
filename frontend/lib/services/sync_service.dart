import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/services/api_service.dart';
import 'package:hive/hive.dart';

class SyncService {
  static Future<void> syncTransaction(Transaction transaction) async {
    try {
      // Convert to JSON for API
      final transactionJson = transaction.toJson();
      
      // Send to server
      await ApiService.addTransaction(transactionJson);
      
      // Mark as synced in local database
      final box = Hive.box<Transaction>('transactionsBox');
      final index = box.values.toList().indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        final updatedTransaction = Transaction(
          id: transaction.id,
          amount: transaction.amount,
          type: transaction.type,
          category: transaction.category,
          description: transaction.description,
          date: transaction.date,
          isSynced: true,
        );
        await box.putAt(index, updatedTransaction);
      }
    } catch (e) {
      print('Sync failed: $e');
      // Transaction remains unsynced and will be retried later
    }
  }

  static Future<void> syncAllTransactions() async {
    final box = Hive.box<Transaction>('transactionsBox');
    final unsyncedTransactions = box.values.where((t) => !t.isSynced).toList();
    
    for (final transaction in unsyncedTransactions) {
      await syncTransaction(transaction);
    }
  }

  static Future<void> pullFromServer() async {
    try {
      final serverTransactions = await ApiService.getTransactions();
      final box = Hive.box<Transaction>('transactionsBox');
      
      for (final serverTx in serverTransactions) {
        final transaction = Transaction.fromJson(serverTx);
        
        // Check if transaction already exists locally
        final exists = box.values.any((localTx) => localTx.id == transaction.id);
        
        if (!exists) {
          await box.add(transaction);
        }
      }
    } catch (e) {
      print('Pull from server failed: $e');
    }
  }
}