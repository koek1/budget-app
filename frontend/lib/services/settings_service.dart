import 'package:hive/hive.dart';

class SettingsService {
  static const String _settingsBoxName = 'settingsBox';
  static const String _currencyKey = 'currency';
  static const String _themeModeKey = 'themeMode';
  
  // Default values
  static const String defaultCurrency = 'R';
  static const String defaultThemeMode = 'light';

  // Available currencies
  static const List<Map<String, String>> availableCurrencies = [
    {'code': 'R', 'symbol': 'R', 'name': 'Rand (ZAR)'},
    {'code': '\$', 'symbol': '\$', 'name': 'Dollar (USD)'},
    {'code': '€', 'symbol': '€', 'name': 'Euro (EUR)'},
    {'code': '£', 'symbol': '£', 'name': 'Pound (GBP)'},
    {'code': '¥', 'symbol': '¥', 'name': 'Yen (JPY)'},
    {'code': '₹', 'symbol': '₹', 'name': 'Rupee (INR)'},
  ];

  // Initialize settings box (called from main.dart after box is opened)
  static Future<void> init() async {
    // Box is already opened in main.dart, just ensure it exists
    if (!Hive.isBoxOpen(_settingsBoxName)) {
      await Hive.openBox(_settingsBoxName);
    }
  }

  // Get currency
  static String getCurrency() {
    if (!Hive.isBoxOpen(_settingsBoxName)) {
      return defaultCurrency;
    }
    final box = Hive.box(_settingsBoxName);
    return box.get(_currencyKey, defaultValue: defaultCurrency) as String;
  }

  // Set currency
  static Future<void> setCurrency(String currency) async {
    if (!Hive.isBoxOpen(_settingsBoxName)) {
      await Hive.openBox(_settingsBoxName);
    }
    final box = Hive.box(_settingsBoxName);
    await box.put(_currencyKey, currency);
  }

  // Get theme mode ('light' or 'dark')
  static String getThemeMode() {
    if (!Hive.isBoxOpen(_settingsBoxName)) {
      return defaultThemeMode;
    }
    final box = Hive.box(_settingsBoxName);
    return box.get(_themeModeKey, defaultValue: defaultThemeMode) as String;
  }

  // Set theme mode
  static Future<void> setThemeMode(String themeMode) async {
    if (!Hive.isBoxOpen(_settingsBoxName)) {
      await Hive.openBox(_settingsBoxName);
    }
    final box = Hive.box(_settingsBoxName);
    await box.put(_themeModeKey, themeMode);
  }

  // Check if dark mode is enabled
  static bool isDarkMode() {
    return getThemeMode() == 'dark';
  }
}

