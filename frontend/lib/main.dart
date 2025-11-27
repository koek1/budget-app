import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'models/user.dart';
import 'models/transaction.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive:
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(TransactionAdapter());
  Hive.registerAdapter(UserAdapter());

  //Open Boxes:
  await Hive.openBox('userBox');
  await Hive.openBox('usersBox'); // Store all users
  await Hive.openBox<Transaction>('transactionsBox');
  await Hive.openBox('settingsBox'); // Settings (currency, theme)

  // Initialize settings service
  await SettingsService.init();

  runApp(const MyApp());
}
