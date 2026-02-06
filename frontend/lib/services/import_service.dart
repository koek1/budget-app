import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

/// Result of a CSV import operation.
class ImportResult {
  final int successCount;
  final int skipCount;
  final List<String> errors;

  const ImportResult({
    required this.successCount,
    required this.skipCount,
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
  int get totalProcessed => successCount + skipCount + errors.length;
}

/// Service for importing transactions from CSV (e.g. exported from this app).
class ImportService {
  static const String _headerLine = 'Date,Type,Category,Description,Amount';
  static const List<String> _summaryKeywords = [
    'SUMMARY',
    'Total Income',
    'Total Expenses',
    'Net Total',
  ];

  /// Imports transactions from CSV content (format matching app export).
  /// Returns [ImportResult] with counts and any parse/save errors.
  static Future<ImportResult> importFromCsvContent(String content) async {
    final errors = <String>[];
    int successCount = 0;
    int skipCount = 0;

    final currentUser = await LocalStorageService.getCurrentUser();
    if (currentUser == null) {
      return ImportResult(
        successCount: 0,
        skipCount: 0,
        errors: ['You must be logged in to import transactions.'],
      );
    }

    final lines = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    if (lines.isEmpty) {
      return const ImportResult(
        successCount: 0,
        skipCount: 0,
        errors: ['File is empty.'],
      );
    }

    // Find header row (may have BOM or extra spaces)
    int dataStartIndex = 0;
    for (int i = 0; i < lines.length; i++) {
      final normalized = lines[i].trim().toLowerCase();
      if (normalized == _headerLine.toLowerCase() ||
          normalized.startsWith('date,type,category,description,amount')) {
        dataStartIndex = i + 1;
        break;
      }
    }

    for (int i = dataStartIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        skipCount++;
        continue;
      }

      final parts = _parseCsvLine(line);
      if (parts.length < 5) {
        skipCount++;
        continue;
      }

      final firstCell = parts[0].trim();
      if (firstCell.isEmpty ||
          _summaryKeywords.any((k) => firstCell.toLowerCase().startsWith(k.toLowerCase()))) {
        skipCount++;
        continue;
      }

      final date = _parseDate(firstCell);
      if (date == null) {
        errors.add('Row ${i + 1}: Invalid date "$firstCell"');
        continue;
      }

      final typeRaw = parts[1].trim().toLowerCase();
      if (typeRaw != 'income' && typeRaw != 'expense') {
        errors.add('Row ${i + 1}: Type must be Income or Expense, got "${parts[1]}"');
        continue;
      }

      final amount = double.tryParse(parts[4].trim());
      if (amount == null || amount <= 0) {
        errors.add('Row ${i + 1}: Invalid amount "${parts[4]}"');
        continue;
      }

      final category = parts[2].trim().replaceAll(';', ',').replaceAll('"', '');
      final description = parts[3].trim().replaceAll(';', ',').replaceAll('"', '');

      final transaction = Transaction(
        id: const Uuid().v4(),
        userId: currentUser.id,
        amount: amount,
        type: typeRaw,
        category: category.isEmpty ? 'Uncategorized' : category,
        description: description,
        date: date,
        isSynced: false,
      );

      try {
        await LocalStorageService.addTransaction(transaction);
        successCount++;
      } catch (e) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        errors.add('Row ${i + 1}: $msg');
      }
    }

    return ImportResult(
      successCount: successCount,
      skipCount: skipCount,
      errors: errors,
    );
  }

  /// Parse a single CSV line respecting quoted fields.
  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (inQuotes) {
        current.write(c);
      } else if (c == ',') {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(c);
      }
    }
    result.add(current.toString());
    return result;
  }

  /// Parse date in d/m/yyyy or d/m/yy format (matches export).
  static DateTime? _parseDate(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0].trim());
    final month = int.tryParse(parts[1].trim());
    var year = int.tryParse(parts[2].trim());
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000; // 25 -> 2025

    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }
}
