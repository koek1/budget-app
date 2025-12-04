import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:budget_app/services/settings_service.dart';
import 'package:budget_app/models/transaction.dart';

class Helpers {
    static String formatCurrency(double amount) {
        // Get currency symbol from settings
        final currencySymbol = SettingsService.getCurrencySymbol();
        
        // Check if amount is negative to preserve the sign
        final isNegative = amount < 0;
        
        // Format like "$ 7 380,16" - currency symbol, spaces for thousands, comma for decimal
        final absAmount = amount.abs();
        final integerPart = absAmount.toInt();
        final decimalPart = ((absAmount - integerPart) * 100).round();
        
        // Format integer part with spaces every 3 digits from right
        String integerStr = integerPart.toString();
        String formattedInteger = '';
        int count = 0;
        for (int i = integerStr.length - 1; i >= 0; i--) {
          if (count > 0 && count % 3 == 0) {
            formattedInteger = ' ' + formattedInteger;
          }
          formattedInteger = integerStr[i] + formattedInteger;
          count++;
        }
        
        // Add negative sign prefix if amount is negative
        final signPrefix = isNegative ? '-' : '';
        
        return '$signPrefix$currencySymbol $formattedInteger,${decimalPart.toString().padLeft(2, '0')}';
    }

    static String FormatDate(DateTime date) {
        return DateFormat('dd, MMM, yyyy').format(date);
    }

    static String formatDateForAPI(DateTime date) {
        return DateFormat('yyyy-MM-dd').format(date);
    }

    // Format date with relative labels (Today, Yesterday, Tomorrow, or formatted date)
    static String formatDateRelative(DateTime date) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dateOnly = DateTime(date.year, date.month, date.day);
        final yesterday = today.subtract(Duration(days: 1));
        final tomorrow = today.add(Duration(days: 1));

        if (dateOnly == today) {
            return 'Today';
        } else if (dateOnly == yesterday) {
            return 'Yesterday';
        } else if (dateOnly == tomorrow) {
            return 'Tomorrow';
        } else {
            // For dates within the same year, show "MMM d", otherwise show full date
            if (date.year == now.year) {
                return DateFormat('MMM d').format(date);
            } else {
                return DateFormat('MMM d, yyyy').format(date);
            }
        }
    }

    // Show modern error SnackBar
    static void showErrorSnackBar(BuildContext context, String message) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Container(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                        children: [
                            Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.white,
                                    size: 20,
                                ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    message,
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
                backgroundColor: Colors.red[600],
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                duration: Duration(seconds: 4),
            ),
        );
    }

    // Show modern success SnackBar
    static void showSuccessSnackBar(BuildContext context, String message) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Container(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                        children: [
                            Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: Colors.white,
                                    size: 20,
                                ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    message,
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
                backgroundColor: Color(0xFF14B8A6),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                duration: Duration(seconds: 3),
            ),
        );
    }

    // Show modern info SnackBar
    static void showInfoSnackBar(BuildContext context, String message) {
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Container(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                        children: [
                            Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.white,
                                    size: 20,
                                ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    message,
                                    style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
                backgroundColor: theme.brightness == Brightness.dark
                    ? Color(0xFF1E293B)
                    : Color(0xFF3B82F6),
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                duration: Duration(seconds: 3),
            ),
        );
    }

    // Calculate next occurrence date for a recurring transaction
    static DateTime? getNextRecurringDate(Transaction transaction) {
        if (!transaction.isRecurring || transaction.recurringFrequency == null) {
            return null;
        }

        final now = DateTime.now();
        final lastDate = transaction.date;
        DateTime? nextDate;

        switch (transaction.recurringFrequency) {
            case 'weekly':
                nextDate = lastDate.add(Duration(days: 7));
                while (nextDate != null && (nextDate.isBefore(now) || nextDate.isAtSameMomentAs(now))) {
                    nextDate = nextDate.add(Duration(days: 7));
                }
                break;
            case 'biweekly':
                nextDate = lastDate.add(Duration(days: 14));
                while (nextDate != null && (nextDate.isBefore(now) || nextDate.isAtSameMomentAs(now))) {
                    nextDate = nextDate.add(Duration(days: 14));
                }
                break;
            case 'monthly':
                nextDate = DateTime(lastDate.year, lastDate.month + 1, lastDate.day);
                while (nextDate != null && (nextDate.isBefore(now) || nextDate.isAtSameMomentAs(now))) {
                    nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
                }
                break;
            case 'yearly':
                nextDate = DateTime(lastDate.year + 1, lastDate.month, lastDate.day);
                while (nextDate != null && (nextDate.isBefore(now) || nextDate.isAtSameMomentAs(now))) {
                    nextDate = DateTime(nextDate.year, nextDate.month, nextDate.day);
                }
                break;
        }

        // Check if next date is before or equal to end date
        if (transaction.recurringEndDate != null && nextDate != null) {
            if (nextDate.isAfter(transaction.recurringEndDate!)) {
                return null; // Recurring payment has ended
            }
        }

        return nextDate;
    }

    // Get upcoming recurring debit orders (expenses) within a date range
    static List<Map<String, dynamic>> getUpcomingRecurringDebitOrders(
        List<Transaction> transactions,
        {DateTime? startDate, DateTime? endDate}) {
        final now = DateTime.now();
        final start = startDate ?? now;
        final end = endDate ?? now.add(Duration(days: 30)); // Default: next 30 days

        List<Map<String, dynamic>> upcoming = [];

        for (var transaction in transactions) {
            // Only process recurring expenses (debit orders)
            if (transaction.type != 'expense' || !transaction.isRecurring) {
                continue;
            }

            final nextDate = getNextRecurringDate(transaction);
            if (nextDate == null) {
                continue;
            }

            // Check if next occurrence is within the date range
            if (nextDate.isAfter(start.subtract(Duration(days: 1))) &&
                nextDate.isBefore(end.add(Duration(days: 1)))) {
                upcoming.add({
                    'transaction': transaction,
                    'nextDate': nextDate,
                    'amount': transaction.amount,
                });
            }
        }

        // Sort by next date
        upcoming.sort((a, b) => (a['nextDate'] as DateTime)
            .compareTo(b['nextDate'] as DateTime));

        return upcoming;
    }

    // Generate pending transactions for recurring bills that haven't occurred yet
    static List<Map<String, dynamic>> getPendingRecurringTransactions(
        List<Transaction> transactions) {
        final now = DateTime.now();
        List<Map<String, dynamic>> pending = [];

        for (var transaction in transactions) {
            // Only process recurring expenses
            if (transaction.type != 'expense' || !transaction.isRecurring) {
                continue;
            }

            // Get all future occurrences up to 90 days ahead
            DateTime? nextDate = getNextRecurringDate(transaction);
            int count = 0;
            while (nextDate != null && count < 12) { // Limit to 12 future occurrences
                // Only include future dates (not today or past)
                if (nextDate.isAfter(now)) {
                    pending.add({
                        'transaction': transaction,
                        'dueDate': nextDate,
                        'amount': transaction.amount,
                        'isPending': true,
                    });
                }

                // Calculate next occurrence
                nextDate = _getNextOccurrenceFromDate(transaction, nextDate);
                count++;
            }
        }

        // Sort by due date
        pending.sort((a, b) => (a['dueDate'] as DateTime)
            .compareTo(b['dueDate'] as DateTime));

        return pending;
    }

    // Helper to get next occurrence from a given date
    static DateTime? _getNextOccurrenceFromDate(
        Transaction transaction, DateTime fromDate) {
        if (!transaction.isRecurring || transaction.recurringFrequency == null) {
            return null;
        }

        DateTime? nextDate;

        switch (transaction.recurringFrequency) {
            case 'weekly':
                nextDate = fromDate.add(Duration(days: 7));
                break;
            case 'biweekly':
                nextDate = fromDate.add(Duration(days: 14));
                break;
            case 'monthly':
                nextDate = DateTime(fromDate.year, fromDate.month + 1, fromDate.day);
                break;
            case 'yearly':
                nextDate = DateTime(fromDate.year + 1, fromDate.month, fromDate.day);
                break;
        }

        // Check if next date is before or equal to end date (if exists)
        if (transaction.recurringEndDate != null && nextDate != null) {
            if (nextDate.isAfter(transaction.recurringEndDate!)) {
                return null; // Recurring payment has ended
            }
        }

        return nextDate;
    }

    // Calculate debt information for recurring bills with end dates (excluding subscriptions)
    static Map<String, double> calculateDebtInfo(List<Transaction> transactions) {
        double totalDebtDue = 0.0;
        double debtPaidOff = 0.0;
        final now = DateTime.now();
        final nowDate = DateTime(now.year, now.month, now.day);

        for (var transaction in transactions) {
            // Only process recurring expenses with end dates (not subscriptions)
            if (transaction.type != 'expense' ||
                !transaction.isRecurring ||
                transaction.isSubscription ||
                transaction.recurringEndDate == null) {
                continue;
            }

            final startDate = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
            final endDate = transaction.recurringEndDate!;
            
            // Calculate all payment dates from start to end
            List<DateTime> allPaymentDates = [];
            DateTime? currentDate = startDate;
            
            while (currentDate != null && !currentDate.isAfter(endDate)) {
                allPaymentDates.add(currentDate);
                currentDate = _getNextOccurrenceFromDate(transaction, currentDate);
            }

            // Separate into paid (past/current) and due (future)
            int paidPayments = 0;
            int remainingPayments = 0;
            
            for (var paymentDate in allPaymentDates) {
                if (paymentDate.isBefore(nowDate) || paymentDate.isAtSameMomentAs(nowDate)) {
                    paidPayments++;
                } else {
                    remainingPayments++;
                }
            }

            debtPaidOff += transaction.amount * paidPayments;
            totalDebtDue += transaction.amount * remainingPayments;
        }

        return {
            'totalDebtDue': totalDebtDue,
            'debtPaidOff': debtPaidOff,
        };
    }

    // Legacy method for backward compatibility
    static double calculateDebt(List<Transaction> transactions) {
        final debtInfo = calculateDebtInfo(transactions);
        return debtInfo['totalDebtDue'] ?? 0.0;
    }

    // Get debt management suggestions
    static List<String> getDebtManagementSuggestions(double debtAmount) {
        List<String> suggestions = [];

        if (debtAmount == 0) {
            suggestions.add('Great! You have no recurring debt.');
            suggestions.add('Keep up the good financial management!');
            return suggestions;
        }

        if (debtAmount < 1000) {
            suggestions.add('Your recurring debt is manageable.');
            suggestions.add('Consider paying off debts early to save on interest.');
        } else if (debtAmount < 5000) {
            suggestions.add('You have moderate recurring debt.');
            suggestions.add('Focus on paying off high-interest debts first.');
            suggestions.add('Consider consolidating debts if possible.');
        } else {
            suggestions.add('You have significant recurring debt.');
            suggestions.add('Prioritize paying off debts with highest interest rates.');
            suggestions.add('Consider creating a debt repayment plan.');
            suggestions.add('Look for ways to reduce recurring expenses.');
        }

        suggestions.add('Review your recurring bills regularly.');
        suggestions.add('Cancel any subscriptions you don\'t use.');
        suggestions.add('Negotiate better rates with service providers.');

        return suggestions;
    }
}