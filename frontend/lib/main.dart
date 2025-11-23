import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'models/user.dart';
import 'models/transaction.dart';

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

  runApp(const MyApp());
}
