import 'package:hive/hive.dart';
import 'package:budget_app/models/receipt_batch.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class ReceiptBatchService {
  static const String _boxName = 'receiptBatchesBox';

  /// Initialize the batch service
  static Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await Hive.openBox<ReceiptBatch>(_boxName);
      }
    } catch (e) {
      print('Error initializing receipt batch service: $e');
    }
  }

  /// Get all batches for the current user
  static Future<List<ReceiptBatch>> getBatches() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        return [];
      }

      final box = Hive.box<ReceiptBatch>(_boxName);
      final currentUser = await LocalStorageService.getCurrentUser();

      if (currentUser == null) {
        return [];
      }

      final batches = box.values
          .where((b) => b.userId == currentUser.id)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first

      return batches;
    } catch (e) {
      print('Error getting batches: $e');
      return [];
    }
  }

  /// Get a specific batch by ID
  static Future<ReceiptBatch?> getBatch(String batchId) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        return null;
      }

      final box = Hive.box<ReceiptBatch>(_boxName);
      final batch = box.get(batchId);
      
      if (batch == null) return null;

      final currentUser = await LocalStorageService.getCurrentUser();
      if (currentUser == null || batch.userId != currentUser.id) {
        return null;
      }

      return batch;
    } catch (e) {
      print('Error getting batch: $e');
      return null;
    }
  }

  /// Get all transactions in a batch
  static Future<List<Transaction>> getBatchTransactions(String batchId) async {
    try {
      final batch = await getBatch(batchId);
      if (batch == null) return [];

      final allTransactions = await LocalStorageService.getTransactions();
      final batchTransactions = allTransactions
          .where((t) => batch.transactionIds.contains(t.id))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date)); // Newest first

      return batchTransactions;
    } catch (e) {
      print('Error getting batch transactions: $e');
      return [];
    }
  }

  /// Create a new batch
  static Future<ReceiptBatch> createBatch(String name) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await init();
      }

      final box = Hive.box<ReceiptBatch>(_boxName);
      final currentUser = await LocalStorageService.getCurrentUser();

      if (currentUser == null) {
        throw Exception('User must be logged in to create batches');
      }

      final batch = ReceiptBatch(
        id: Uuid().v4(),
        userId: currentUser.id,
        name: name,
        createdAt: DateTime.now(),
        transactionIds: [],
        totalAmount: 0.0,
      );

      await box.put(batch.id, batch);
      return batch;
    } catch (e) {
      print('Error creating batch: $e');
      rethrow;
    }
  }

  /// Add a transaction to a batch
  static Future<void> addTransactionToBatch(
    String batchId,
    Transaction transaction,
  ) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await init();
      }

      final box = Hive.box<ReceiptBatch>(_boxName);
      final batch = await getBatch(batchId);

      if (batch == null) {
        throw Exception('Batch not found');
      }

      // Add transaction to storage first
      await LocalStorageService.addTransaction(transaction);

      // Update batch
      final updatedTransactionIds = [...batch.transactionIds, transaction.id];
      final updatedTotalAmount = batch.totalAmount + transaction.amount;

      final updatedBatch = ReceiptBatch(
        id: batch.id,
        userId: batch.userId,
        name: batch.name,
        createdAt: batch.createdAt,
        transactionIds: updatedTransactionIds,
        totalAmount: updatedTotalAmount,
      );

      await box.put(batch.id, updatedBatch);
    } catch (e) {
      print('Error adding transaction to batch: $e');
      rethrow;
    }
  }

  /// Update batch total when transaction is modified
  static Future<void> updateBatchTotal(String batchId) async {
    try {
      final batch = await getBatch(batchId);
      if (batch == null) return;

      final transactions = await getBatchTransactions(batchId);
      final totalAmount = transactions.fold<double>(
        0.0,
        (sum, transaction) => sum + transaction.amount,
      );

      final box = Hive.box<ReceiptBatch>(_boxName);
      final updatedBatch = ReceiptBatch(
        id: batch.id,
        userId: batch.userId,
        name: batch.name,
        createdAt: batch.createdAt,
        transactionIds: batch.transactionIds,
        totalAmount: totalAmount,
      );

      await box.put(batch.id, updatedBatch);
    } catch (e) {
      print('Error updating batch total: $e');
    }
  }

  /// Delete a batch (but keep the transactions)
  static Future<void> deleteBatch(String batchId) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        return;
      }

      final box = Hive.box<ReceiptBatch>(_boxName);
      await box.delete(batchId);
    } catch (e) {
      print('Error deleting batch: $e');
      rethrow;
    }
  }

  /// Remove a transaction from a batch
  static Future<void> removeTransactionFromBatch(
    String batchId,
    String transactionId,
  ) async {
    try {
      final batch = await getBatch(batchId);
      if (batch == null) return;

      final box = Hive.box<ReceiptBatch>(_boxName);
      final updatedTransactionIds =
          batch.transactionIds.where((id) => id != transactionId).toList();

      // Recalculate total
      final transactions = await getBatchTransactions(batchId);
      final remainingTransactions =
          transactions.where((t) => t.id != transactionId).toList();
      final totalAmount = remainingTransactions.fold<double>(
        0.0,
        (sum, transaction) => sum + transaction.amount,
      );

      final updatedBatch = ReceiptBatch(
        id: batch.id,
        userId: batch.userId,
        name: batch.name,
        createdAt: batch.createdAt,
        transactionIds: updatedTransactionIds,
        totalAmount: totalAmount,
      );

      await box.put(batch.id, updatedBatch);
    } catch (e) {
      print('Error removing transaction from batch: $e');
      rethrow;
    }
  }
}

