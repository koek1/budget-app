import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive:
  await Hive.initFlutter();

  //Open Boxes:
  await Hive.openBox('userBox');
  await Hive.openBox('transactionsBox');

  runApp(const MyApp());
}
