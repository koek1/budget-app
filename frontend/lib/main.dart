import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'models/user.dart';
import 'models/transaction.dart';
import 'models/custom_criteria.dart';
import 'models/budget.dart';
import 'services/settings_service.dart';
import 'services/custom_criteria_service.dart';
import 'services/budget_service.dart';
import 'services/budget_notification_service.dart';
import 'services/recurring_debit_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive:
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(TransactionAdapter());
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(CustomCriteriaAdapter());
  Hive.registerAdapter(BudgetAdapter());

  // Check if this is a fresh install by checking for app version marker
  final isFreshInstall = await _checkIfFreshInstall();

  // Open Boxes (in order of dependency):
  // 1. Settings box first (needed for defaults)
  await Hive.openBox('settingsBox');

  // 2. User boxes
  final userBox = await Hive.openBox('userBox');
  final usersBox = await Hive.openBox('usersBox'); // Store all users

  // If fresh install, clear ALL data including Hive boxes
  if (isFreshInstall) {
    print('Fresh install detected - clearing ALL app data');
    try {
      // Clear all Hive boxes
      await usersBox.clear();
      await userBox.clear();

      // Clear settings box and set defaults for fresh install
      final settingsBox = Hive.box('settingsBox');
      await settingsBox.clear();
      // Set default theme to light mode for fresh install
      await settingsBox.put('themeMode', 'light');
      await settingsBox.put('currency', 'R');
      print('Set default theme to light mode for fresh install');

      // Clear custom criteria box
      if (Hive.isBoxOpen('customCriteriaBox')) {
        await Hive.box<CustomCriteria>('customCriteriaBox').clear();
      }

      // Transactions box will be handled below
      print('Cleared all user data on fresh install');
    } catch (e) {
      print('Error clearing data on fresh install: $e');
      // Try to delete boxes from disk as fallback
      try {
        await Hive.deleteBoxFromDisk('usersBox');
        await Hive.deleteBoxFromDisk('userBox');
        await Hive.deleteBoxFromDisk('customCriteriaBox');
        print('Deleted boxes from disk as fallback');
        // Reopen boxes after deletion
        await Hive.openBox('usersBox');
        await Hive.openBox('userBox');
        // Set defaults
        final settingsBox = Hive.box('settingsBox');
        await settingsBox.put('themeMode', 'light');
        await settingsBox.put('currency', 'R');
      } catch (deleteError) {
        print('Error deleting boxes: $deleteError');
      }
    }
  }

  // Open transactions box with error handling for old format
  // If there's an error, it's likely due to old transaction format - clear and recreate
  try {
    await Hive.openBox<Transaction>('transactionsBox');
  } catch (e) {
    print('Error opening transactions box (possibly old format): $e');
    // Clear the box and recreate it to avoid deserialization errors
    try {
      // Try to delete the box file
      try {
        await Hive.deleteBoxFromDisk('transactionsBox');
      } catch (_) {
        // Ignore if deletion fails
      }
      // Recreate the box
      await Hive.openBox<Transaction>('transactionsBox');
      print('Recreated transactions box (cleared old format data)');
    } catch (recreateError) {
      print('Error recreating transactions box: $recreateError');
      // Last resort - try to open with a different approach
      try {
        final box = await Hive.openLazyBox<Transaction>('transactionsBox');
        await box.close();
        await Hive.openBox<Transaction>('transactionsBox');
      } catch (finalError) {
        print('Final error opening transactions box: $finalError');
        // Continue anyway - app should still work without transactions
      }
    }
  }

  // Settings box already opened above
  // Ensure custom criteria box is open
  if (!Hive.isBoxOpen('customCriteriaBox')) {
    await Hive.openBox<CustomCriteria>('customCriteriaBox');
  }

  // If fresh install, clear transactions box and mark complete
  if (isFreshInstall) {
    try {
      if (Hive.isBoxOpen('transactionsBox')) {
        final transactionsBox = Hive.box<Transaction>('transactionsBox');
        await transactionsBox.clear();
        print('Cleared transactions on fresh install');
      } else {
        // If box isn't open, try to delete from disk
        try {
          await Hive.deleteBoxFromDisk('transactionsBox');
          print('Deleted transactions box from disk');
        } catch (e) {
          print('Error deleting transactions box: $e');
        }
      }
    } catch (e) {
      print('Error clearing transactions on fresh install: $e');
      // Try to delete from disk as fallback
      try {
        await Hive.deleteBoxFromDisk('transactionsBox');
      } catch (deleteError) {
        print('Error deleting transactions box: $deleteError');
      }
    }
    // Mark that we've completed the fresh install cleanup
    await _markInstallComplete();
    print('Fresh install cleanup completed');
  }

  // Clean up corrupted user data on first launch or after reinstall
  // Run cleanup in background to not block app startup
  _cleanupCorruptedUserData(usersBox).catchError((e) {
    print('Cleanup error (non-blocking): $e');
  });

  // Initialize settings service
  await SettingsService.init();

  // Initialize custom criteria service
  await CustomCriteriaService.init();

  // Initialize budget service
  await BudgetService.init();

  // Initialize budget notification service
  await BudgetNotificationService.init();

  // Initialize recurring debit notification service
  await RecurringDebitNotificationService.init();
  // Schedule notifications for recurring debits
  RecurringDebitNotificationService.scheduleRecurringDebitNotifications();

  runApp(const MyApp());
}

// Check if this is a fresh install using SharedPreferences (survives uninstall)
Future<bool> _checkIfFreshInstall() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    const String appVersionKey = 'app_version';
    const String currentVersion = '1.0.0'; // Match pubspec.yaml version

    // Check if app version exists and matches
    final storedVersion = prefs.getString(appVersionKey);

    if (storedVersion == null) {
      // First time install - mark as fresh
      print('First time install detected');
      return true;
    }

    if (storedVersion != currentVersion) {
      // Version changed - treat as fresh install
      print(
          'Version changed from $storedVersion to $currentVersion - treating as fresh install');
      return true;
    }

    // Version matches - not a fresh install
    print('App version matches stored version: $storedVersion');
    return false;
  } catch (e) {
    // If we can't check, assume it's a fresh install to be safe
    print('Error checking install status: $e');
    return true;
  }
}

// Mark that install cleanup is complete
Future<void> _markInstallComplete() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    const String appVersionKey = 'app_version';
    const String currentVersion = '1.0.0'; // Match pubspec.yaml version

    await prefs.setString(appVersionKey, currentVersion);
    print('Marked install complete for version: $currentVersion');
  } catch (e) {
    print('Error marking install complete: $e');
  }
}

// Clean up corrupted user data and orphaned transactions
Future<void> _cleanupCorruptedUserData(Box usersBox) async {
  try {
    print('Starting data cleanup...');
    final users = usersBox.values.toList();
    final validUsers = <Map<String, dynamic>>[];
    final validUserIds = <String>[];

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
            // Collect valid user IDs
            final userId =
                userMap['id']?.toString() ?? userMap['_id']?.toString();
            if (userId != null && userId.isNotEmpty) {
              validUserIds.add(userId);
            }
          }
        }
      } catch (e) {
        // Skip corrupted entries
        print('Skipping corrupted user data: $e');
      }
    }

    print(
        'Found ${validUsers.length} valid users out of ${users.length} total');

    // Clean up orphaned transactions (transactions without valid users)
    try {
      final transactionsBox = Hive.box<Transaction>('transactionsBox');

      // Check if box can be accessed
      try {
        final length = transactionsBox.length;
        print('Checking $length transactions...');
      } catch (e) {
        print('Cannot access transactions box length: $e');
        // Box might be corrupted - try to clear it
        try {
          await transactionsBox.clear();
          print('Cleared corrupted transactions box');
        } catch (clearError) {
          print('Error clearing transactions box: $clearError');
        }
        return;
      }

      final transactionsToDelete = <int>[];

      // If there are transactions but no valid users, clear all transactions
      if (transactionsBox.length > 0 && validUserIds.isEmpty) {
        print('No valid users found, clearing all transactions');
        await transactionsBox.clear();
        return;
      }

      // Only process if we have transactions
      if (transactionsBox.length == 0) {
        print('No transactions to clean up');
        return;
      }

      for (var i = 0; i < transactionsBox.length; i++) {
        try {
          final transaction = transactionsBox.getAt(i);
          if (transaction == null) {
            transactionsToDelete.add(i);
            continue;
          }

          // Safely check userId - handle old transactions that might not have this field
          String transactionUserId = '';
          try {
            transactionUserId = transaction.userId;
          } catch (e) {
            // Old transaction format without userId - mark for deletion
            print(
                'Transaction at index $i has old format (no userId), marking for deletion');
            transactionsToDelete.add(i);
            continue;
          }

          // If transaction has userId but user doesn't exist, mark for deletion
          // Also delete transactions without userId (old format)
          if (transactionUserId.isEmpty ||
              !validUserIds.contains(transactionUserId)) {
            transactionsToDelete.add(i);
          }
        } catch (e) {
          // If we can't read the transaction (deserialization error), mark it for deletion
          print(
              'Error reading transaction at index $i (likely old format): $e');
          transactionsToDelete.add(i);
        }
      }

      // Delete orphaned transactions in reverse order
      if (transactionsToDelete.isNotEmpty) {
        print(
            'Deleting ${transactionsToDelete.length} orphaned transactions...');
        for (var i = transactionsToDelete.length - 1; i >= 0; i--) {
          try {
            await transactionsBox.deleteAt(transactionsToDelete[i]);
          } catch (e) {
            print(
                'Error deleting transaction at index ${transactionsToDelete[i]}: $e');
          }
        }
        print(
            'Cleaned up ${transactionsToDelete.length} orphaned transactions');
      }
    } catch (e, stackTrace) {
      print('Error cleaning up transactions: $e');
      print('Stack trace: $stackTrace');
      // If transaction cleanup fails completely, try to clear the box
      try {
        final box = Hive.box<Transaction>('transactionsBox');
        await box.clear();
        print('Cleared all transactions due to cleanup error');
      } catch (clearError) {
        print('Error clearing transactions box: $clearError');
        // Don't throw - allow app to continue
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

    print('Data cleanup completed successfully');
  } catch (e, stackTrace) {
    print('Error cleaning up user data: $e');
    print('Stack trace: $stackTrace');
    // If cleanup fails completely, try to clear boxes but don't block app startup
    try {
      await usersBox.clear();
      await Hive.box<Transaction>('transactionsBox').clear();
      print('Cleared all data due to cleanup failure');
    } catch (clearError) {
      print('Error clearing boxes: $clearError');
      // Don't throw - allow app to continue even if cleanup fails
    }
  }
}
