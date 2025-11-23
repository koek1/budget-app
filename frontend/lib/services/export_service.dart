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
      // Get transactions from local storage
      final allTransactions = await LocalStorageService.getTransactions();
      
      // Filter by date range
      var transactions = allTransactions.where((t) {
        return t.date.isAfter(startDate.subtract(Duration(days: 1))) &&
            t.date.isBefore(endDate.add(Duration(days: 1)));
      }).toList();
      
      // Filter by type if specified
      if (reportType != 'all') {
        transactions = transactions.where((t) => t.type == reportType).toList();
      }
      
      // Sort by date
      transactions.sort((a, b) => a.date.compareTo(b.date));

      // Calculate totals
      final incomeTotal = transactions
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.amount);
      final expenseTotal = transactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);
      final netTotal = incomeTotal - expenseTotal;

      // Create CSV content
      final csvBuffer = StringBuffer();
      
      // Add headers
      csvBuffer.writeln('Date,Type,Category,Description,Amount');
      
      // Add data rows
      for (final transaction in transactions) {
        final dateStr = '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}';
        final typeStr = transaction.type[0].toUpperCase() + transaction.type.substring(1);
        final description = transaction.description.replaceAll(',', ';'); // Replace commas to avoid CSV issues
        csvBuffer.writeln('$dateStr,$typeStr,${transaction.category},$description,${transaction.amount}');
      }
      
      // Add summary
      csvBuffer.writeln('');
      csvBuffer.writeln('SUMMARY,,,,');
      csvBuffer.writeln('Total Income,,,$incomeTotal');
      csvBuffer.writeln('Total Expenses,,,$expenseTotal');
      csvBuffer.writeln('Net Total,,,$netTotal');

      // Get downloads directory
      final directory = await getDownloadsDirectory();
      if (directory == null) {
        onError('Could not access downloads directory');
        return;
      }

      // Create file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${directory.path}/budget-report-$timestamp.csv');
      
      // Write CSV data to file
      await file.writeAsString(csvBuffer.toString());
      
      // Open the file
      await OpenFile.open(file.path);
      
      onSuccess('Report exported successfully!');
    } catch (e) {
      onError('Export failed: $e');
    }
  }

  static Future<Map<String, dynamic>> getReportSummary({
    required DateTime startDate,
    required DateTime endDate,
    required String reportType,
  }) async {
    try {
      // Get transactions from local storage
      final allTransactions = await LocalStorageService.getTransactions();
      
      // Filter by date range
      var transactions = allTransactions.where((t) {
        return t.date.isAfter(startDate.subtract(Duration(days: 1))) &&
            t.date.isBefore(endDate.add(Duration(days: 1)));
      }).toList();
      
      // Filter by type if specified
      if (reportType != 'all') {
        transactions = transactions.where((t) => t.type == reportType).toList();
      }
      
      // Sort by date
      transactions.sort((a, b) => a.date.compareTo(b.date));

      // Calculate daily income
      final dailyIncome = <String, double>{};
      transactions
          .where((t) => t.type == 'income')
          .forEach((t) {
        final dateStr = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
        dailyIncome[dateStr] = (dailyIncome[dateStr] ?? 0) + t.amount;
      });

      final totalIncome = transactions
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.amount);
      final totalExpenses = transactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);

      return {
        'totalTransactions': transactions.length,
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
        'netTotal': totalIncome - totalExpenses,
        'dailyIncome': dailyIncome.entries.map((e) => {'date': e.key, 'amount': e.value}).toList(),
        'transactions': transactions.take(10).map((t) => {
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
      throw Exception('Summary failed: $e');
    }
  }
}