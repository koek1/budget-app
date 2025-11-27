import 'package:intl/intl.dart';
import 'package:budget_app/services/settings_service.dart';

class Helpers {
    static String formatCurrency(double amount) {
        // Get currency from settings
        final currency = SettingsService.getCurrency();
        
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
        
        return '$currency $formattedInteger,${decimalPart.toString().padLeft(2, '0')}';
    }

    static String FormatDate(DateTime date) {
        return DateFormat('dd, MMM, yyyy').format(date);
    }

    static String formatDateForAPI(DateTime date) {
        return DateFormat('yyyy-MM-dd').format(date);
    }
}