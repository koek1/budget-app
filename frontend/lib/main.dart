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

  // Open Boxes:
  await Hive.openBox('userBox');
  final usersBox = await Hive.openBox('usersBox'); // Store all users
  await Hive.openBox<Transaction>('transactionsBox');
  await Hive.openBox('settingsBox'); // Settings (currency, theme)

  // Clean up corrupted user data on first launch or after reinstall
  await _cleanupCorruptedUserData(usersBox);

  // Initialize settings service
  await SettingsService.init();

  runApp(const MyApp());
}

// Clean up corrupted or invalid user data
Future<void> _cleanupCorruptedUserData(Box usersBox) async {
  try {
    final users = usersBox.values.toList();
    final validUsers = <Map<String, dynamic>>[];
    
    for (var userData in users) {
      try {
        // Validate user data structure
        if (userData is Map) {
          final userMap = Map<String, dynamic>.from(userData);
          // Check if user has required fields
          if (userMap['name'] != null && 
              userMap['name'].toString().isNotEmpty &&
              userMap['password'] != null &&
              userMap['password'].toString().isNotEmpty) {
            validUsers.add(userMap);
          }
        }
      } catch (e) {
        // Skip corrupted entries
        print('Skipping corrupted user data: $e');
      }
    }
    
    // If we found corrupted data, clear and restore valid users
    if (validUsers.length != users.length) {
      print('Found corrupted user data. Cleaning up...');
      await usersBox.clear();
      for (var user in validUsers) {
        await usersBox.add(user);
      }
      print('Cleaned up user data. Valid users: ${validUsers.length}');
    }
  } catch (e) {
    print('Error cleaning up user data: $e');
    // If cleanup fails, clear all data to prevent login issues
    try {
      await usersBox.clear();
    } catch (clearError) {
      print('Error clearing users box: $clearError');
    }
  }
}
