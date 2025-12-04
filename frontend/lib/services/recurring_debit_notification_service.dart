import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/utils/helpers.dart';
import 'package:intl/intl.dart';

class RecurringDebitNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Initialize notifications
  static Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for Android 13+
    if (await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        false) {
      _initialized = true;
    } else {
      _initialized = true; // Continue anyway
    }
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('Recurring debit notification tapped: ${response.payload}');
  }

  // Schedule notifications for upcoming recurring debit orders
  static Future<void> scheduleRecurringDebitNotifications() async {
    try {
      await init();
      
      if (!Hive.isBoxOpen('transactionsBox')) {
        return;
      }

      final transactionsBox = Hive.box<Transaction>('transactionsBox');
      final transactions = transactionsBox.values.toList();
      
      // Get upcoming recurring debit orders for next 7 days
      final upcoming = Helpers.getUpcomingRecurringDebitOrders(
        transactions,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(Duration(days: 7)),
      );

      // Cancel all existing recurring debit notifications
      for (int i = 2000; i < 3000; i++) {
        await _notifications.cancel(i);
      }

      // Schedule notifications for each upcoming debit order
      for (int i = 0; i < upcoming.length; i++) {
        final item = upcoming[i];
        final transaction = item['transaction'] as Transaction;
        final nextDate = item['nextDate'] as DateTime;
        final now = DateTime.now();
        final daysUntil = nextDate.difference(now).inDays;

        // Notify for payments due today or tomorrow
        if (daysUntil == 0) {
          // Due today - notify immediately
          await _showRecurringDebitNotification(transaction, nextDate, 0);
        } else if (daysUntil == 1) {
          // Due tomorrow - notify today
          await _showRecurringDebitNotification(transaction, nextDate, 1);
        }
      }
    } catch (e) {
      print('Error scheduling recurring debit notifications: $e');
    }
  }

  // Show notification for recurring debit order
  static Future<void> _showRecurringDebitNotification(
    Transaction transaction,
    DateTime dueDate,
    int daysUntil,
  ) async {
    final daysText = daysUntil == 0 ? 'Today' : 'Tomorrow';
    final transactionName = transaction.description.isNotEmpty
        ? transaction.description
        : transaction.category;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'recurring_debits',
      'Recurring Debit Orders',
      channelDescription: 'Notifications for upcoming recurring debit orders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      2000 + transaction.id.hashCode % 1000, // Unique ID
      'Recurring Payment: $daysText',
      '$transactionName - ${Helpers.formatCurrency(transaction.amount)} due ${DateFormat('MMM d').format(dueDate)}',
      details,
      payload: 'recurring_${transaction.id}',
    );
  }


  // Check and send notifications daily
  static Future<void> checkAndNotifyDaily() async {
    await scheduleRecurringDebitNotifications();
  }
}

