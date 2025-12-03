import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:budget_app/services/local_storage_service.dart';

class ExportService {
  static Future<void> exportToExcel({
    required DateTime startDate,
    required DateTime endDate,
    required String reportType,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      // Validate date range
      if (startDate.isAfter(endDate)) {
        onError('Start date must be before end date');
        return;
      }
      
      // Get transactions from local storage with timeout
      final allTransactions = await LocalStorageService.getTransactions()
          .timeout(Duration(seconds: 10), onTimeout: () {
        throw Exception('Loading transactions timed out');
      });
      
      // Filter by date range - optimized
      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      
      var transactions = allTransactions.where((t) {
        final transactionDate = DateTime(t.date.year, t.date.month, t.date.day);
        return !transactionDate.isBefore(startOfDay) && !transactionDate.isAfter(endOfDay);
      }).toList();
      
      // Filter by type if specified
      if (reportType != 'all' && reportType != 'income' && reportType != 'expense') {
        onError('Invalid report type');
        return;
      }
      
      if (reportType != 'all') {
        transactions = transactions.where((t) => t.type == reportType).toList();
      }
      
      // Sort by date
      transactions.sort((a, b) => a.date.compareTo(b.date));

      // Calculate totals - optimized single pass
      double incomeTotal = 0.0;
      double expenseTotal = 0.0;
      for (final transaction in transactions) {
        if (transaction.type == 'income') {
          incomeTotal += transaction.amount;
        } else if (transaction.type == 'expense') {
          expenseTotal += transaction.amount;
        }
      }
      final netTotal = incomeTotal - expenseTotal;

      // Create CSV content
      final csvBuffer = StringBuffer();
      
      // Add headers
      csvBuffer.writeln('Date,Type,Category,Description,Amount');
      
      // Add data rows
      for (final transaction in transactions) {
        try {
        final dateStr = '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}';
          final typeStr = transaction.type.isNotEmpty
              ? transaction.type[0].toUpperCase() + transaction.type.substring(1)
              : transaction.type;
        final description = transaction.description.replaceAll(',', ';'); // Replace commas to avoid CSV issues
          final category = transaction.category.replaceAll(',', ';'); // Also sanitize category
          csvBuffer.writeln('$dateStr,$typeStr,$category,$description,${transaction.amount}');
        } catch (e) {
          print('Error writing transaction to CSV: $e');
          // Skip corrupted transactions
          continue;
        }
      }
      
      // Add summary
      csvBuffer.writeln('');
      csvBuffer.writeln('SUMMARY,,,,');
      csvBuffer.writeln('Total Income,,,$incomeTotal');
      csvBuffer.writeln('Total Expenses,,,$expenseTotal');
      csvBuffer.writeln('Net Total,,,$netTotal');

      // Get downloads directory with timeout
      final directory = await getDownloadsDirectory()
          .timeout(Duration(seconds: 5), onTimeout: () => null);
      if (directory == null) {
        onError('Could not access downloads directory. Please check app permissions.');
        return;
      }

      // Create file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/budget-report-$timestamp.csv');
      
      // Write CSV data to file with error handling
      try {
        await file.writeAsString(csvBuffer.toString())
            .timeout(Duration(seconds: 10));
      } catch (e) {
        onError('Failed to write file: ${e.toString()}');
        return;
      }
      
      // Open the file
      try {
        await OpenFile.open(file.path)
            .timeout(Duration(seconds: 5));
      } catch (e) {
        // File was created successfully, even if opening fails
        onSuccess('Report exported to: ${file.path}');
        return;
      }
      
      onSuccess('Report exported successfully!');
    } catch (e) {
      print('Export error: $e');
      String errorMessage = 'Export failed';
      if (e.toString().contains('timeout')) {
        errorMessage = 'Export timed out. Please try again.';
      } else if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      onError(errorMessage);
    }
  }

  static Future<Map<String, dynamic>> getReportSummary({
    required DateTime startDate,
    required DateTime endDate,
    required String reportType,
  }) async {
    try {
      // Validate date range
      if (startDate.isAfter(endDate)) {
        throw Exception('Start date must be before end date');
      }
      
      // Get transactions from local storage with timeout
      final allTransactions = await LocalStorageService.getTransactions()
          .timeout(Duration(seconds: 10), onTimeout: () {
        throw Exception('Loading transactions timed out');
      });
      
      // Filter by date range - optimized
      final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
      final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      
      var transactions = allTransactions.where((t) {
        final transactionDate = DateTime(t.date.year, t.date.month, t.date.day);
        return !transactionDate.isBefore(startOfDay) && !transactionDate.isAfter(endOfDay);
      }).toList();
      
      // Filter by type if specified
      if (reportType != 'all' && reportType != 'income' && reportType != 'expense') {
        throw Exception('Invalid report type');
      }
      
      if (reportType != 'all') {
        transactions = transactions.where((t) => t.type == reportType).toList();
      }
      
      // Sort by date
      transactions.sort((a, b) => a.date.compareTo(b.date));

      // Calculate daily income and totals in single pass - optimized
      final dailyIncome = <String, double>{};
      double totalIncome = 0.0;
      double totalExpenses = 0.0;
      
      for (final t in transactions) {
        if (t.type == 'income') {
          totalIncome += t.amount;
        final dateStr = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
        dailyIncome[dateStr] = (dailyIncome[dateStr] ?? 0) + t.amount;
        } else if (t.type == 'expense') {
          totalExpenses += t.amount;
        }
      }

      return {
        'totalTransactions': transactions.length,
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
        'netTotal': totalIncome - totalExpenses,
        'dailyIncome': dailyIncome.entries.map((e) => {'date': e.key, 'amount': e.value}).toList(),
        'transactions': transactions.take(10).map((t) {
          return {
            'date': t.date.toIso8601String(),
            'type': t.type,
            'category': t.category,
            'description': t.description,
            'amount': t.amount,
          };
        }).toList(),
      };
    } catch (e) {
      print('Error getting report summary: $e');
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Summary failed: ${e.toString()}');
    }
  }
}