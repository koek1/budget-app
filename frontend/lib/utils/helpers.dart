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
    // This finds the next future payment date from the transaction's start date
    static DateTime? getNextRecurringDate(Transaction transaction) {
        if (!transaction.isRecurring || transaction.recurringFrequency == null) {
            return null;
        }

        final now = DateTime.now();
        final nowDate = DateTime(now.year, now.month, now.day);
        
        // For subscriptions with payment day, calculate based on payment day
        if (transaction.isSubscription && 
            transaction.subscriptionPaymentDay != null && 
            transaction.recurringFrequency == 'monthly') {
            return getNextSubscriptionPaymentDate(transaction, nowDate);
        }
        
        final startDate = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
        
        // Start from the transaction date and find the next occurrence
        DateTime? nextDate = startDate;
        
        // Keep advancing until we find a future date
        while (nextDate != null && 
               (nextDate.isBefore(nowDate) || nextDate.isAtSameMomentAs(nowDate))) {
            nextDate = getNextOccurrenceFromDate(transaction, nextDate);
            
            // Safety check to prevent infinite loops
            // If we've gone too far in the future (more than 10 years), something is wrong
            if (nextDate != null && nextDate.isAfter(nowDate.add(Duration(days: 3650)))) {
                return null;
            }
        }

        return nextDate;
    }

    // Get next subscription payment date based on payment day
    static DateTime? getNextSubscriptionPaymentDate(Transaction transaction, DateTime fromDate) {
        if (!transaction.isSubscription || transaction.subscriptionPaymentDay == null) {
            return null;
        }

        final paymentDay = transaction.subscriptionPaymentDay!;
        
        // Try this month first
        try {
            final thisMonthDate = DateTime(fromDate.year, fromDate.month, paymentDay);
            if (thisMonthDate.isAfter(fromDate) || thisMonthDate.isAtSameMomentAs(fromDate)) {
                return thisMonthDate;
            }
        } catch (e) {
            // Day doesn't exist in this month, will try next month
        }

        // Try next month
        try {
            final nextMonth = DateTime(fromDate.year, fromDate.month + 1, paymentDay);
            return nextMonth;
        } catch (e) {
            // If day doesn't exist in next month (e.g., day 31 in Feb),
            // use the last day of the target month
            final nextMonthLastDay = DateTime(fromDate.year, fromDate.month + 2, 0);
            return DateTime(fromDate.year, fromDate.month + 1, nextMonthLastDay.day);
        }
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
                nextDate = getNextOccurrenceFromDate(transaction, nextDate);
                count++;
            }
        }

        // Sort by due date
        pending.sort((a, b) => (a['dueDate'] as DateTime)
            .compareTo(b['dueDate'] as DateTime));

        return pending;
    }

    // Helper to get next occurrence from a given date
    // Made public so it can be used by dashboard and other screens
    static DateTime? getNextOccurrenceFromDate(
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
                // For subscriptions, use the payment day if specified
                int dayToUse = fromDate.day;
                if (transaction.isSubscription && transaction.subscriptionPaymentDay != null) {
                    dayToUse = transaction.subscriptionPaymentDay!;
                }
                // Handle month edge cases (e.g., Jan 31 -> Feb should use Feb 28/29)
                try {
                    nextDate = DateTime(fromDate.year, fromDate.month + 1, dayToUse);
                } catch (e) {
                    // If day doesn't exist in next month (e.g., Jan 31 -> Feb 31),
                    // use the last day of the target month
                    final nextMonth = DateTime(fromDate.year, fromDate.month + 2, 0);
                    nextDate = DateTime(fromDate.year, fromDate.month + 1, nextMonth.day);
                }
                break;
            case 'yearly':
                // Handle leap year edge cases (e.g., Feb 29 -> next year)
                try {
                    nextDate = DateTime(fromDate.year + 1, fromDate.month, fromDate.day);
                } catch (e) {
                    // If day doesn't exist in next year (e.g., Feb 29 in non-leap year),
                    // use the last day of the target month
                    final nextYearMonth = DateTime(fromDate.year + 1, fromDate.month + 1, 0);
                    nextDate = DateTime(fromDate.year + 1, fromDate.month, nextYearMonth.day);
                }
                break;
        }

        // Check if next date is before or equal to end date (if exists)
        // Subscriptions don't have end dates, so skip this check for them
        if (!transaction.isSubscription && 
            transaction.recurringEndDate != null && 
            nextDate != null) {
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
            int maxIterations = 1000; // Safety limit to prevent infinite loops
            int iterations = 0;
            
            while (currentDate != null && 
                   !currentDate.isAfter(endDate) && 
                   iterations < maxIterations) {
                allPaymentDates.add(currentDate);
                currentDate = getNextOccurrenceFromDate(transaction, currentDate);
                iterations++;
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

    // Convert technical errors to user-friendly messages
    static String getUserFriendlyErrorMessage(String error) {
        // Remove common prefixes
        String message = error;
        if (message.startsWith('Exception: ')) {
            message = message.substring(11);
        }
        
        // Map technical errors to user-friendly messages
        if (message.contains('timeout') || message.contains('timed out')) {
            return 'Request timed out. Please check your connection and try again.';
        }
        if (message.contains('database') || message.contains('not available')) {
            return 'Data storage is not available. Please restart the app.';
        }
        if (message.contains('not found')) {
            return 'Item not found. It may have been deleted.';
        }
        if (message.contains('must be logged in') || message.contains('logged in')) {
            return 'Please log in to continue.';
        }
        if (message.contains('validation') || message.contains('invalid')) {
            return 'Please check your input and try again.';
        }
        if (message.contains('network') || message.contains('connection')) {
            return 'Network error. Please check your internet connection.';
        }
        if (message == 'Unknown error' || message.isEmpty) {
            return 'Something went wrong. Please try again.';
        }
        
        // Return the message as-is if it's already user-friendly
        return message;
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