import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/models/weekly_reflection.dart';
import 'package:budget_app/services/settings_service.dart';
import 'package:budget_app/utils/helpers.dart';

/// Handles behavioural nudge notifications:
/// - Weekly reflection reminder (Sunday evening if not yet completed)
/// - Monthly savings goal check (end of month — congrats or nudge)
/// - Impulse spending weekly summary
class BehaviouralNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // Notification ID ranges
  static const int _weeklyReflectionId = 4000;
  static const int _savingsGoalId = 4001;
  static const int _impulseSummaryId = 4002;

  /// Stores the payload of the last tapped notification so the app can
  /// navigate to the right screen after the user logs back in.
  /// Consumed (set to null) once the navigation is performed.
  static String? pendingNotificationPayload;

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
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Check if app was launched by tapping a notification (cold start)
    final launchDetails =
        await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails != null &&
        launchDetails.didNotificationLaunchApp &&
        launchDetails.notificationResponse?.payload != null) {
      pendingNotificationPayload =
          launchDetails.notificationResponse!.payload;
      print(
          'App launched from notification: $pendingNotificationPayload');
    }

    _initialized = true;
  }

  static void _onNotificationTapped(NotificationResponse response) {
    print('Behavioural notification tapped: ${response.payload}');
    if (response.payload != null && response.payload!.isNotEmpty) {
      pendingNotificationPayload = response.payload;
    }
  }

  /// Consumes and returns the pending payload (if any).
  /// Returns null if there is nothing pending.
  static String? consumePendingPayload() {
    final payload = pendingNotificationPayload;
    pendingNotificationPayload = null;
    return payload;
  }

  /// Call this on each app launch (after login) to check and fire relevant notifications.
  static Future<void> checkAndNotify() async {
    try {
      await init();
      await _checkWeeklyReflectionReminder();
      await _checkMonthlySavingsGoal();
      await _checkWeeklyImpulseSummary();
    } catch (e) {
      print('Error in behavioural notifications: $e');
    }
  }

  // ──────────────────────────────────────────────
  // 1. Weekly reflection reminder
  // ──────────────────────────────────────────────

  static Future<void> _checkWeeklyReflectionReminder() async {
    try {
      final now = DateTime.now();
      // Only remind on Friday (5), Saturday (6), or Sunday (7)
      if (now.weekday < 5) return;

      // Check if user already completed this week's reflection
      if (!Hive.isBoxOpen('weeklyReflectionsBox')) return;

      final box = Hive.box<WeeklyReflection>('weeklyReflectionsBox');
      final weekStart = DateTime(now.year, now.month, now.day - (now.weekday - 1));

      // Check if current user has a reflection for this week
      String? currentUserId;
      if (Hive.isBoxOpen('userBox')) {
        final userBox = Hive.box('userBox');
        currentUserId = userBox.get('userId')?.toString();
      }
      if (currentUserId == null) return;

      final hasReflection = box.values.any((r) =>
          r.userId == currentUserId &&
          r.weekStarting.year == weekStart.year &&
          r.weekStarting.month == weekStart.month &&
          r.weekStarting.day == weekStart.day);

      if (hasReflection) return; // Already done

      // Check if we already sent a reminder today
      final settingsBox = Hive.box('settingsBox');
      final lastReminderDate =
          settingsBox.get('lastReflectionReminderDate') as String?;
      final todayStr = '${now.year}-${now.month}-${now.day}';
      if (lastReminderDate == todayStr) return; // Already reminded today

      // Send reminder
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'behavioural_nudges',
        'Behaviour Insights',
        channelDescription:
            'Weekly reflections and savings goal notifications',
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
        _weeklyReflectionId,
        'Time to reflect on your week',
        'Take 2 minutes to review your spending. What went well? What would you change?',
        details,
        payload: 'weekly_reflection',
      );

      await settingsBox.put('lastReflectionReminderDate', todayStr);
    } catch (e) {
      print('Error checking weekly reflection: $e');
    }
  }

  // ──────────────────────────────────────────────
  // 2. Monthly savings goal check
  // ──────────────────────────────────────────────

  static Future<void> _checkMonthlySavingsGoal() async {
    try {
      final now = DateTime.now();
      // Only check in the last 3 days of the month or first 2 days of new month
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final isEndOfMonth = now.day >= daysInMonth - 2;
      final isStartOfMonth = now.day <= 2;
      if (!isEndOfMonth && !isStartOfMonth) return;

      // Check if we already sent this month's notification
      final settingsBox = Hive.box('settingsBox');
      final lastSavingsCheckMonth =
          settingsBox.get('lastSavingsCheckMonth') as String?;
      // Use the month we're checking (current for end-of-month, previous for start-of-month)
      final checkMonth = isStartOfMonth
          ? DateTime(now.year, now.month - 1)
          : DateTime(now.year, now.month);
      final checkMonthStr = '${checkMonth.year}-${checkMonth.month}';
      if (lastSavingsCheckMonth == checkMonthStr) return;

      // Get current user's transactions for the check month
      if (!Hive.isBoxOpen('transactionsBox')) return;
      String? currentUserId;
      if (Hive.isBoxOpen('userBox')) {
        final userBox = Hive.box('userBox');
        currentUserId = userBox.get('userId')?.toString();
      }
      if (currentUserId == null) return;

      final transactionsBox = Hive.box<Transaction>('transactionsBox');
      final monthTransactions = transactionsBox.values.where((t) =>
          t.userId == currentUserId &&
          t.date.year == checkMonth.year &&
          t.date.month == checkMonth.month);

      final totalIncome = monthTransactions
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.amount);
      final totalExpenses = monthTransactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);
      final netSavings = totalIncome - totalExpenses;

      // Calculate impulse spending for the month
      final impulseAmount = monthTransactions
          .where((t) => t.type == 'expense' && t.isPlanned == false)
          .fold(0.0, (sum, t) => sum + t.amount);

      // Only notify if there's actual data
      if (totalIncome == 0 && totalExpenses == 0) return;

      // Get user's monthly savings goal
      final savingsGoal = SettingsService.getMonthlySavingsGoal();

      String title;
      String body;

      if (savingsGoal > 0) {
        // ── User has a savings goal set ──
        if (netSavings >= savingsGoal) {
          // Met or exceeded the goal
          final overAmount = netSavings - savingsGoal;
          title = 'You crushed your savings goal!';
          body =
              'Goal: ${Helpers.formatCurrency(savingsGoal)} — You saved: ${Helpers.formatCurrency(netSavings)}.';
          if (overAmount > 0) {
            body +=
                ' That\'s ${Helpers.formatCurrency(overAmount)} extra! Amazing discipline.';
          }
        } else if (netSavings > 0) {
          // Saved something but didn't hit the goal
          final shortfall = savingsGoal - netSavings;
          final percentReached = (netSavings / savingsGoal * 100);
          title =
              'Almost there — ${percentReached.toStringAsFixed(0)}% of your goal';
          body =
              'You saved ${Helpers.formatCurrency(netSavings)} of your ${Helpers.formatCurrency(savingsGoal)} goal. Just ${Helpers.formatCurrency(shortfall)} short.';
          if (impulseAmount > shortfall) {
            body +=
                ' Tip: your impulse spending (${Helpers.formatCurrency(impulseAmount)}) alone would have covered the gap!';
          } else {
            body += ' Small adjustments next month can get you there!';
          }
        } else if (netSavings == 0) {
          title = 'You broke even — your goal was ${Helpers.formatCurrency(savingsGoal)}';
          body =
              'No savings this month, but no debt either. Try cutting a few expenses next month to hit your goal.';
          if (impulseAmount > 0) {
            body +=
                ' Reducing ${Helpers.formatCurrency(impulseAmount)} in impulse spending would be a great start.';
          }
        } else {
          // Overspent
          title =
              'Overspent by ${Helpers.formatCurrency(netSavings.abs())} — goal was ${Helpers.formatCurrency(savingsGoal)}';
          if (impulseAmount > totalExpenses * 0.3 && impulseAmount > 0) {
            body =
                '${Helpers.formatCurrency(impulseAmount)} was unplanned spending (${(impulseAmount / totalExpenses * 100).toStringAsFixed(0)}% of expenses). Reducing impulse buys is the fastest way to hit your ${Helpers.formatCurrency(savingsGoal)} target.';
          } else {
            body =
                'Review your biggest expense categories and look for areas to cut. Your goal of ${Helpers.formatCurrency(savingsGoal)} is reachable!';
          }
        }
      } else {
        // ── No goal set — generic feedback ──
        if (netSavings > 0) {
          final savingsRate =
              totalIncome > 0 ? (netSavings / totalIncome * 100) : 0;
          title =
              'Great month! You saved ${Helpers.formatCurrency(netSavings)}';
          body = savingsRate >= 20
              ? 'You saved ${savingsRate.toStringAsFixed(0)}% of your income. That\'s excellent discipline!'
              : 'You\'re on the right track. Set a monthly savings goal in Settings to stay focused!';
          if (impulseAmount > 0) {
            body +=
                ' (${Helpers.formatCurrency(impulseAmount)} was impulse spending)';
          }
        } else if (netSavings == 0) {
          title = 'You broke even this month';
          body =
              'No savings, but no debt either. Set a savings goal in Settings to give yourself a target!';
          if (impulseAmount > 0) {
            body +=
                ' Cutting ${Helpers.formatCurrency(impulseAmount)} in impulse spending would put you ahead.';
          }
        } else {
          title =
              'You overspent by ${Helpers.formatCurrency(netSavings.abs())}';
          if (impulseAmount > totalExpenses * 0.3 && impulseAmount > 0) {
            body =
                '${Helpers.formatCurrency(impulseAmount)} was unplanned spending — that\'s ${(impulseAmount / totalExpenses * 100).toStringAsFixed(0)}% of your expenses. Set a savings goal in Settings to stay on track!';
          } else {
            body =
                'Review your biggest expense categories to find where you can cut back. Consider setting a savings goal!';
          }
        }
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'behavioural_nudges',
        'Behaviour Insights',
        channelDescription:
            'Weekly reflections and savings goal notifications',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        styleInformation: BigTextStyleInformation(''),
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
        _savingsGoalId,
        title,
        body,
        details,
        payload: 'savings_goal',
      );

      await settingsBox.put('lastSavingsCheckMonth', checkMonthStr);
    } catch (e) {
      print('Error checking savings goal: $e');
    }
  }

  // ──────────────────────────────────────────────
  // 3. Weekly impulse spending summary (Monday morning)
  // ──────────────────────────────────────────────

  static Future<void> _checkWeeklyImpulseSummary() async {
    try {
      final now = DateTime.now();
      // Only fire on Monday or Tuesday
      if (now.weekday > 2) return;

      // Check if already sent this week
      final settingsBox = Hive.box('settingsBox');
      final lastImpulseSummaryWeek =
          settingsBox.get('lastImpulseSummaryWeek') as String?;
      final weekStart =
          DateTime(now.year, now.month, now.day - (now.weekday - 1));
      final weekStr = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
      if (lastImpulseSummaryWeek == weekStr) return;

      // Get last week's transactions
      String? currentUserId;
      if (Hive.isBoxOpen('userBox')) {
        final userBox = Hive.box('userBox');
        currentUserId = userBox.get('userId')?.toString();
      }
      if (currentUserId == null) return;

      if (!Hive.isBoxOpen('transactionsBox')) return;
      final transactionsBox = Hive.box<Transaction>('transactionsBox');
      final lastWeekStart = weekStart.subtract(Duration(days: 7));
      final lastWeekEnd = weekStart;

      final lastWeekExpenses = transactionsBox.values.where((t) =>
          t.userId == currentUserId &&
          t.type == 'expense' &&
          !t.date.isBefore(lastWeekStart) &&
          t.date.isBefore(lastWeekEnd));

      final impulseTransactions =
          lastWeekExpenses.where((t) => t.isPlanned == false).toList();

      // Only notify if there were impulse purchases
      if (impulseTransactions.isEmpty) return;

      final impulseTotal =
          impulseTransactions.fold(0.0, (sum, t) => sum + t.amount);
      final totalExpenses =
          lastWeekExpenses.fold(0.0, (sum, t) => sum + t.amount);
      final impulsePercent =
          totalExpenses > 0 ? (impulseTotal / totalExpenses * 100) : 0;

      String title =
          'Last week: ${impulseTransactions.length} impulse purchases';
      String body =
          '${Helpers.formatCurrency(impulseTotal)} unplanned (${impulsePercent.toStringAsFixed(0)}% of spending).';

      if (impulsePercent > 50) {
        body += ' That\'s a lot — can you plan better this week?';
      } else if (impulsePercent > 25) {
        body += ' Room for improvement. Try the "sleep on it" rule.';
      } else {
        body += ' Not bad! Keep the intentional spending up.';
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'behavioural_nudges',
        'Behaviour Insights',
        channelDescription:
            'Weekly reflections and savings goal notifications',
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
        _impulseSummaryId,
        title,
        body,
        details,
        payload: 'impulse_summary',
      );

      await settingsBox.put('lastImpulseSummaryWeek', weekStr);
    } catch (e) {
      print('Error checking impulse summary: $e');
    }
  }
}
