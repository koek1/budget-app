import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:budget_app/services/settings_service.dart';

class Helpers {
    static String formatCurrency(double amount) {
        // Get currency symbol from settings
        final currencySymbol = SettingsService.getCurrencySymbol();
        
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
        
        return '$currencySymbol $formattedInteger,${decimalPart.toString().padLeft(2, '0')}';
    }

    static String FormatDate(DateTime date) {
        return DateFormat('dd, MMM, yyyy').format(date);
    }

    static String formatDateForAPI(DateTime date) {
        return DateFormat('yyyy-MM-dd').format(date);
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
}