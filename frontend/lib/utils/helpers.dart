import 'package:intl/intl.dart';

class Helpers {
    static String formatCurrency(double amount) {
        return NumberFormat.currency(symbol: '\R', decimalDigits: 2).format(amount);
    }

    static String FormatDate(DateTime date) {
        return DateFormat('dd, MMM, yyyy').format(date);
    }

    static String formatDateForAPI(DateTime date) {
        return DateFormat('yyyy-MM-dd').format(date);
    }
}