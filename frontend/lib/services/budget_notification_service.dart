import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:budget_app/services/budget_service.dart';
import 'package:budget_app/models/budget.dart';
import 'package:budget_app/utils/helpers.dart';

class BudgetNotificationService {
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
    // Handle notification tap - can navigate to budget screen
    print('Notification tapped: ${response.payload}');
  }

  // Check budgets and send notifications if needed
  static Future<void> checkBudgetsAndNotify() async {
    try {
      await init();
      final budgetStatuses = await BudgetService.getAllBudgetStatuses();

      for (final status in budgetStatuses) {
        final budget = status['budget'] as Budget;
        final spending = status['spending'] as double;
        final percentage = status['percentage'] as double;
        final isExceeded = status['isExceeded'] as bool;
        final isWarning = status['isWarning'] as bool;

        if (isExceeded) {
          await _showBudgetExceededNotification(budget, spending);
        } else if (isWarning) {
          await _showBudgetWarningNotification(budget, spending, percentage);
        }
      }
    } catch (e) {
      print('Error checking budgets: $e');
    }
  }

  // Show notification when budget is exceeded
  static Future<void> _showBudgetExceededNotification(
      Budget budget, double spending) async {
    final budgetName = budget.category ?? 'Overall Budget';
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription:
          'Notifications for budget warnings and exceeded budgets',
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
      budget.id.hashCode, // Unique ID for this budget
      'Budget Exceeded: $budgetName',
      'You\'ve exceeded your budget of ${Helpers.formatCurrency(budget.amount)}. Current spending: ${Helpers.formatCurrency(spending)}',
      details,
      payload: 'budget_${budget.id}',
    );
  }

  // Show notification when budget is close to limit
  static Future<void> _showBudgetWarningNotification(
    Budget budget,
    double spending,
    double percentage,
  ) async {
    final budgetName = budget.category ?? 'Overall Budget';
    final remaining = budget.amount - spending;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'budget_alerts',
      'Budget Alerts',
      channelDescription:
          'Notifications for budget warnings and exceeded budgets',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
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
      budget.id.hashCode + 1000, // Different ID for warnings
      'Budget Warning: $budgetName',
      'You\'ve used ${percentage.toStringAsFixed(1)}% of your budget. ${Helpers.formatCurrency(remaining)} remaining.',
      details,
      payload: 'budget_${budget.id}',
    );
  }

  // Cancel notification for a budget
  static Future<void> cancelBudgetNotification(String budgetId) async {
    await _notifications.cancel(budgetId.hashCode);
    await _notifications.cancel(budgetId.hashCode + 1000);
  }

  // Cancel all budget notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
