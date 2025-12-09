import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/models/user.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:budget_app/services/settings_service.dart';
import 'package:budget_app/utils/helpers.dart';
import 'package:budget_app/screens/settings/settings_screen.dart';
import 'package:budget_app/screens/home/add_transaction_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const DashboardScreen({super.key, this.onMenuTap});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Box<Transaction> transactionsBox;
  User? currentUser;
  DateTime _selectedMonth = DateTime.now();
  bool _showStartingBalanceNotification = false;

  @override
  void initState() {
    super.initState();
    transactionsBox = Hive.box<Transaction>('transactionsBox');
    _loadUser();
    _checkStartingBalanceNotification();
  }

  Future<void> _checkStartingBalanceNotification() async {
    // Check if starting balance is still at default (0.0) and notification hasn't been dismissed
    final startingBalance = SettingsService.getStartingBalance();
    final settingsBox = Hive.box('settingsBox');
    final notificationDismissed = settingsBox.get('startingBalanceNotificationDismissed', defaultValue: false) as bool;
    
    setState(() {
      _showStartingBalanceNotification = startingBalance == 0.0 && !notificationDismissed;
    });
  }

  Future<void> _dismissStartingBalanceNotification() async {
    final settingsBox = Hive.box('settingsBox');
    await settingsBox.put('startingBalanceNotificationDismissed', true);
    setState(() {
      _showStartingBalanceNotification = false;
    });
  }

  Future<void> _navigateToStartingBalance() async {
    // Navigate to settings screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    ).then((_) {
      // Check again after returning from settings
      _checkStartingBalanceNotification();
    });
  }

  Future<void> _loadUser() async {
    final user = await LocalStorageService.getCurrentUser();
    setState(() {
      currentUser = user;
    });
  }

  Future<void> _selectMonth() async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Select Month',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
            SizedBox(height: 20),
            ...[
              'This Month',
              'Last Month',
              '2 Months Ago',
              '3 Months Ago',
              '6 Months Ago',
              '1 Year Ago',
              'Custom'
            ].map((option) {
              DateTime? month;
              final now = DateTime.now();
              switch (option) {
                case 'This Month':
                  month = DateTime(now.year, now.month);
                  break;
                case 'Last Month':
                  month = DateTime(now.year, now.month - 1);
                  break;
                case '2 Months Ago':
                  month = DateTime(now.year, now.month - 2);
                  break;
                case '3 Months Ago':
                  month = DateTime(now.year, now.month - 3);
                  break;
                case '6 Months Ago':
                  month = DateTime(now.year, now.month - 6);
                  break;
                case '1 Year Ago':
                  month = DateTime(now.year - 1, now.month);
                  break;
              }
              final isSelected = month != null &&
                  month.year == _selectedMonth.year &&
                  month.month == _selectedMonth.month;
              return ListTile(
                title: Text(
                  option,
                  style: GoogleFonts.inter(
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: Color(0xFF14B8A6))
                    : null,
                onTap: () {
                  if (option == 'Custom') {
                    Navigator.pop(context);
                    _selectCustomMonth();
                  } else if (month != null) {
                    Navigator.pop(context, month);
                  }
                },
              );
            }),
            SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedMonth = result;
      });
    }
  }

  Future<void> _selectCustomMonth() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF14B8A6),
              onPrimary: Colors.white,
              surface: isDark ? Color(0xFF1E293B) : Colors.white,
              onSurface: theme.textTheme.bodyLarge?.color ?? Colors.black,
            ),
            dialogTheme: DialogThemeData(
                backgroundColor: isDark ? Color(0xFF1E293B) : Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  Widget _buildMonthSelector(ThemeData theme) {
    final now = DateTime.now();

    // Compact, elegant selector for turquoise gradient background
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_rounded,
            color: Colors.white,
            size: 18,
          ),
          SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: _selectMonth,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          // Compact navigation buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous month button
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedMonth =
                        DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              SizedBox(width: 4),
              // Next month button (disabled if future month)
              InkWell(
                onTap: () {
                  final nextMonth =
                      DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                  final currentMonth = DateTime(now.year, now.month);
                  if (nextMonth.year < currentMonth.year ||
                      (nextMonth.year == currentMonth.year &&
                          nextMonth.month <= currentMonth.month)) {
                    setState(() {
                      _selectedMonth = nextMonth;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:
                        (DateTime(_selectedMonth.year, _selectedMonth.month + 1)
                                        .year >
                                    now.year ||
                                (DateTime(_selectedMonth.year,
                                                _selectedMonth.month + 1)
                                            .year ==
                                        now.year &&
                                    DateTime(_selectedMonth.year,
                                                _selectedMonth.month + 1)
                                            .month >
                                        now.month))
                            ? Colors.white.withOpacity(0.1)
                            : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color:
                        (DateTime(_selectedMonth.year, _selectedMonth.month + 1)
                                        .year >
                                    now.year ||
                                (DateTime(_selectedMonth.year,
                                                _selectedMonth.month + 1)
                                            .year ==
                                        now.year &&
                                    DateTime(_selectedMonth.year,
                                                _selectedMonth.month + 1)
                                            .month >
                                        now.month))
                            ? Colors.white.withOpacity(0.4)
                            : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 4),
          InkWell(
            onTap: _selectMonth,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.all(6),
              child: Icon(
                Icons.more_vert_rounded,
                color: Colors.white.withOpacity(0.9),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<List<Transaction>> _getTransactionsForMonth() async {
    // Get user-filtered transactions
    final allTransactions = await LocalStorageService.getTransactions();

    if (allTransactions.isEmpty) {
      return [];
    }

    return allTransactions.where((transaction) {
      final transactionDate = transaction.date;
      // Normalize dates to compare only year and month (ignore time)
      final transactionYearMonth =
          DateTime(transactionDate.year, transactionDate.month);
      final selectedYearMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month);
      return transactionYearMonth == selectedYearMonth;
    }).toList();
  }

  Future<double> getMonthlyIncome() async {
    final transactions = await _getTransactionsForMonth();
    return transactions
        .where((transaction) => transaction.type == 'income')
        .fold<double>(0.0, (sum, transaction) => sum + transaction.amount);
  }

  Future<double> getMonthlyExpenses() async {
    final transactions = await _getTransactionsForMonth();
    return transactions
        .where((transaction) => transaction.type == 'expense')
        .fold<double>(0.0, (sum, transaction) => sum + transaction.amount);
  }

  Future<double> getMonthlyBalance() async {
    final income = await getMonthlyIncome();
    final expenses = await getMonthlyExpenses();
    return income - expenses;
  }

  Future<double> getSavings() async {
    // Calculate savings as starting balance + total income minus expenses (all time, user-filtered)
    // Optimized: single pass through transactions
    final allTransactions = await LocalStorageService.getTransactions();
    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    
    for (var transaction in allTransactions) {
      if (transaction.type == 'income') {
        totalIncome += transaction.amount;
      } else {
        totalExpenses += transaction.amount;
      }
    }
    
    // Include starting balance as baseline
    final startingBalance = SettingsService.getStartingBalance();
    return startingBalance + totalIncome - totalExpenses;
  }

  // Optimized method to load all dashboard data efficiently
  Future<Map<String, dynamic>> _loadDashboardData() async {
    try {
      // Load all data in parallel
      final results = await Future.wait([
        getMonthlyIncome(),
        getMonthlyExpenses(),
        getMonthlyBalance(),
        getSavings(),
        _getGraphData(),
        _getUpcomingRecurringDebitOrders(),
      ]).timeout(Duration(seconds: 10), onTimeout: () {
        throw Exception('Loading dashboard data timed out');
      });
      
      return {
        'income': results[0] as double,
        'expenses': results[1] as double,
        'balance': results[2] as double,
        'savings': results[3] as double,
        'graphData': results[4] as List<FlSpot>,
        'upcomingRecurringDebitOrders': results[5] as List<Map<String, dynamic>>,
      };
    } catch (e) {
      // Return empty data on error - user will see error state
      return {
        'income': 0.0,
        'expenses': 0.0,
        'balance': 0.0,
        'savings': 0.0,
        'graphData': <FlSpot>[],
        'upcomingRecurringDebitOrders': <Map<String, dynamic>>[],
        'error': Helpers.getUserFriendlyErrorMessage(e.toString()),
      };
    }
  }

  Future<List<FlSpot>> _getGraphData() async {
    final transactions = await _getTransactionsForMonth();
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

    // Get all user-filtered transactions up to the selected month to calculate starting balance
    final allTransactions = await LocalStorageService.getTransactions()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Calculate starting balance (starting balance + all transactions before this month)
    double startingBalance = SettingsService.getStartingBalance();
    for (var transaction in allTransactions) {
      if (transaction.date.year < _selectedMonth.year ||
          (transaction.date.year == _selectedMonth.year &&
              transaction.date.month < _selectedMonth.month)) {
        if (transaction.type == 'income') {
          startingBalance += transaction.amount;
        } else {
          startingBalance -= transaction.amount;
        }
      }
    }

    // Sort transactions by date (chronological order)
    final sortedTransactions = List<Transaction>.from(transactions)
      ..sort((a, b) {
        // Sort by day first
        final dayCompare = a.date.day.compareTo(b.date.day);
        if (dayCompare != 0) return dayCompare;
        // If same day, income comes before expense (so we see increases first, then decreases)
        if (a.type == 'income' && b.type == 'expense') return -1;
        if (a.type == 'expense' && b.type == 'income') return 1;
        return 0;
      });

    // Create a map to track balance for each day
    Map<int, double> dailyBalances = {};
    double runningBalance = startingBalance;

    // Initialize all days with starting balance
    for (int day = 1; day <= daysInMonth; day++) {
      dailyBalances[day] = startingBalance;
    }

    // First, collect all recurring expense payment dates that have occurred in this month
    // Optimized to only calculate dates within the selected month
    Map<int, double> recurringPaymentsByDay = {};
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final selectedMonthStart = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final selectedMonthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    
    for (var transaction in sortedTransactions) {
      if (transaction.isRecurring && transaction.type == 'expense') {
        // Generate all payment dates that have occurred up to now
        final startDate = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);
        
        // Skip if transaction starts after the selected month
        if (startDate.isAfter(selectedMonthEnd)) {
          continue;
        }
        
        // Start from the first occurrence that could be in the selected month
        DateTime? paymentDate = startDate;
        int maxIterations = 500; // Safety limit
        int iterations = 0;
        
        // Fast-forward to the selected month if needed
        while (paymentDate != null && 
               paymentDate.isBefore(selectedMonthStart) && 
               iterations < maxIterations) {
          paymentDate = Helpers.getNextOccurrenceFromDate(transaction, paymentDate);
          iterations++;
        }
        
        // Now collect all payment dates in the selected month
        while (paymentDate != null && 
               !paymentDate.isAfter(selectedMonthEnd) && 
               iterations < maxIterations) {
          // Only include dates that have occurred (past or today)
          if (paymentDate.isBefore(nowDate) || paymentDate.isAtSameMomentAs(nowDate)) {
            final day = paymentDate.day;
            recurringPaymentsByDay[day] = (recurringPaymentsByDay[day] ?? 0.0) + transaction.amount;
          }
          
          // Stop if we've reached future dates
          if (paymentDate.isAfter(nowDate)) {
            break;
          }
          
          // Get next payment date
          paymentDate = Helpers.getNextOccurrenceFromDate(transaction, paymentDate);
          iterations++;
        }
      }
    }

    // Group transactions by day to process all transactions on the same day together
    Map<int, List<Transaction>> transactionsByDay = {};
    for (var transaction in sortedTransactions) {
      // Skip recurring expenses - we'll handle them separately using their payment dates
      if (transaction.isRecurring && transaction.type == 'expense') {
        continue; // Skip the setup transaction, we use the payment dates instead
      }
      
      final day = transaction.date.day;
      if (!transactionsByDay.containsKey(day)) {
        transactionsByDay[day] = [];
      }
      transactionsByDay[day]!.add(transaction);
    }
    
    // Merge recurring payments into the transactions by day map
    // This ensures all transactions on the same day are processed together
    for (var day in recurringPaymentsByDay.keys) {
      if (!transactionsByDay.containsKey(day)) {
        transactionsByDay[day] = [];
      }
      // Add a virtual expense transaction for recurring payments
      // We'll handle it as a negative amount in the net change calculation
    }
    
    // Process all transactions day by day (including recurring payments) to avoid intermediate balance updates
    final sortedDays = transactionsByDay.keys.toList()..sort();
    for (var day in sortedDays) {
      final dayTransactions = transactionsByDay[day]!;
      
      // Process all transactions for this day and calculate net change
      double dayNetChange = 0;
      for (var transaction in dayTransactions) {
        if (transaction.type == 'income') {
          dayNetChange += transaction.amount;
        } else {
          dayNetChange -= transaction.amount;
        }
      }
      
      // Add recurring payments for this day (if any)
      if (recurringPaymentsByDay.containsKey(day)) {
        dayNetChange -= recurringPaymentsByDay[day]!;
      }
      
      // Update running balance once for the entire day
      runningBalance += dayNetChange;
      
      // Update balance for this day and all subsequent days
      for (int d = day; d <= daysInMonth; d++) {
        dailyBalances[d] = runningBalance;
      }
    }

    // Create spots for the graph
    List<FlSpot> spots = [];
    for (int day = 1; day <= daysInMonth; day++) {
      spots.add(FlSpot(day.toDouble(), dailyBalances[day] ?? startingBalance));
    }

    // Always return at least one spot to ensure graph renders
    if (spots.isEmpty) {
      spots.add(FlSpot(1.0, startingBalance));
    }

    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTurquoise = const Color(0xFF14B8A6);
    final primaryBlue = const Color(0xFF0EA5E9);
    final accentBlue = const Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ]
                : [
                    primaryTurquoise.withOpacity(0.15),
                    primaryBlue.withOpacity(0.1),
                    accentBlue.withOpacity(0.08),
                  ],
          ),
        ),
        child: SafeArea(
          child: ValueListenableBuilder<Box<Transaction>>(
            valueListenable: transactionsBox.listenable(),
            builder: (context, box, _) {
              return FutureBuilder<Map<String, dynamic>>(
                future: _loadDashboardData()
                    .catchError((e) {
                      // Return empty data on error - user will see error state
                      return {
                        'income': 0.0,
                        'expenses': 0.0,
                        'balance': 0.0,
                        'savings': 0.0,
                        'graphData': <FlSpot>[],
                        'upcomingRecurringDebitOrders':
                            <Map<String, dynamic>>[],
                        'error': Helpers.getUserFriendlyErrorMessage(e.toString()),
                      };
                    }),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF14B8A6),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading dashboard...',
                            style: GoogleFonts.inter(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError ||
                      (snapshot.hasData &&
                          snapshot.data!.containsKey('error'))) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            SizedBox(height: 16),
                            Text(
                              'Failed to load dashboard',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              Helpers.getUserFriendlyErrorMessage(
                                snapshot.error?.toString() ??
                                    snapshot.data?['error'] ??
                                    'Unknown error',
                              ),
                              style: GoogleFonts.inter(
                                color: theme.textTheme.bodyMedium?.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (mounted) {
                                  setState(() {});
                                }
                              },
                              icon: Icon(Icons.refresh),
                              label: Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF14B8A6),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF14B8A6),
                      ),
                    );
                  }

                  final monthlyIncome = snapshot.data!['income'] as double;
                  final monthlyExpenses = snapshot.data!['expenses'] as double;
                  final monthlyBalance = snapshot.data!['balance'] as double;
                  final savings = snapshot.data!['savings'] as double;
                  final graphData = snapshot.data!['graphData'] as List<FlSpot>;
                  final upcomingRecurringDebitOrders =
                      snapshot.data!['upcomingRecurringDebitOrders']
                          as List<Map<String, dynamic>>;

                  return CustomScrollView(
                    slivers: [
                      // Header with time, menu, title, and profile
                      SliverAppBar(
                        backgroundColor: theme.appBarTheme.backgroundColor ??
                            theme.scaffoldBackgroundColor,
                        elevation: 0,
                        leading: Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: IconButton(
                            icon: Icon(Icons.menu,
                                color: theme.iconTheme.color, size: 24),
                            onPressed: widget.onMenuTap,
                          ),
                        ),
                        centerTitle: true,
                        title: Text(
                          'Home',
                          style: GoogleFonts.inter(
                            color: theme.textTheme.bodyLarge?.color ??
                                Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        actions: [
                          Padding(
                            padding: EdgeInsets.only(right: 16),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SettingsScreen(),
                                  ),
                                );
                              },
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        primaryTurquoise.withOpacity(0.1),
                                    child: Icon(Icons.person,
                                        color: primaryTurquoise, size: 20),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: primaryTurquoise,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Content
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Greeting
                              Text(
                                'Hello ${currentUser?.name.split(' ').first ?? 'User'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  color: theme.textTheme.bodyLarge?.color ??
                                      Colors.black87,
                                ),
                              ),
                              SizedBox(height: 24),

                              // Starting Balance Notification
                              if (_showStartingBalanceNotification)
                                _buildStartingBalanceNotification(theme, isDark, primaryTurquoise),

                              // Combined Saving Card with Graph
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF14B8A6),
                                      Color(0xFF0D9488),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Color(0xFF14B8A6).withOpacity(0.25),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: BackdropFilter(
                                    filter:
                                        ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                    child: Container(
                                      padding: EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Header row with Saving Label and Expand button
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Saving Label
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.savings,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Saving',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 14,
                                                      color: Colors.white
                                                          .withOpacity(0.9),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              // Expand button
                                              GestureDetector(
                                                onTap: () {
                                                  _showFullScreenChart(
                                                    context,
                                                    graphData,
                                                    _selectedMonth,
                                                    upcomingRecurringDebitOrders,
                                                  );
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.25),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: Colors.white.withOpacity(0.3),
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.fullscreen,
                                                        size: 16,
                                                        color: Colors.white,
                                                      ),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        'Expand',
                                                        style: GoogleFonts.inter(
                                                          fontSize: 12,
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 12),

                                          // Amount Saved
                                          Text(
                                            Helpers.formatCurrency(
                                                savings > 0 ? savings : 0),
                                            style: GoogleFonts.poppins(
                                              fontSize: 36,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.5,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 16),

                                          // Month Selector
                                          _buildMonthSelector(theme),
                                          SizedBox(height: 20),

                                          // Graph - Make it clickable
                                          GestureDetector(
                                            onTap: () {
                                              _showFullScreenChart(
                                                context,
                                                graphData,
                                                _selectedMonth,
                                                upcomingRecurringDebitOrders,
                                              );
                                            },
                                            child: Container(
                                              height: 150,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Stack(
                                                children: [
                                                  LineChart(
                                              LineChartData(
                                                gridData: FlGridData(
                                                  show: true,
                                                  drawVerticalLine: false,
                                                  getDrawingHorizontalLine:
                                                      (value) {
                                                    return FlLine(
                                                      color: Colors.white
                                                          .withOpacity(0.1),
                                                      strokeWidth: 1,
                                                    );
                                                  },
                                                ),
                                                titlesData: FlTitlesData(
                                                  show: true,
                                                  rightTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                        showTitles: false),
                                                  ),
                                                  topTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                        showTitles: false),
                                                  ),
                                                  bottomTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                      showTitles: true,
                                                      reservedSize: 30,
                                                      interval: 5,
                                                      getTitlesWidget:
                                                          (value, meta) {
                                                        final day =
                                                            value.toInt();
                                                        if ([
                                                          1,
                                                          5,
                                                          10,
                                                          15,
                                                          20,
                                                          25,
                                                          30
                                                        ].contains(day)) {
                                                          return Text(
                                                            day.toString(),
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .white70,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          );
                                                        }
                                                        return SizedBox
                                                            .shrink();
                                                      },
                                                    ),
                                                  ),
                                                  leftTitles: AxisTitles(
                                                    sideTitles: SideTitles(
                                                        showTitles: false),
                                                  ),
                                                ),
                                                borderData:
                                                    FlBorderData(show: false),
                                                lineTouchData: LineTouchData(
                                                  touchTooltipData:
                                                      LineTouchTooltipData(
                                                    tooltipRoundedRadius: 8,
                                                    tooltipPadding:
                                                        EdgeInsets.all(8),
                                                    tooltipBgColor: Colors.white
                                                        .withOpacity(0.9),
                                                    getTooltipItems:
                                                        (List<LineBarSpot>
                                                            touchedBarSpots) {
                                                      return touchedBarSpots
                                                          .map((barSpot) {
                                                        final day =
                                                            barSpot.x.toInt();
                                                        final monthName =
                                                            DateFormat('MMM')
                                                                .format(
                                                                    _selectedMonth);
                                                        // Use the actual graph value (barSpot.y) which is the balance at that point
                                                        final graphValue =
                                                            barSpot.y;
                                                        final amountStr =
                                                            Helpers
                                                                .formatCurrency(
                                                                    graphValue);
                                                        return LineTooltipItem(
                                                          '$amountStr\n$day $monthName',
                                                          TextStyle(
                                                            color: Color(
                                                                0xFF14B8A6),
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 12,
                                                          ),
                                                        );
                                                      }).toList();
                                                    },
                                                  ),
                                                  handleBuiltInTouches: true,
                                                ),
                                                lineBarsData: [
                                                  LineChartBarData(
                                                    spots: graphData,
                                                    isCurved: true,
                                                    color: Colors.white,
                                                    barWidth: 3,
                                                    isStrokeCapRound: true,
                                                    dotData: FlDotData(
                                                      show: true,
                                                      getDotPainter: (spot,
                                                          percent,
                                                          barData,
                                                          index) {
                                                        if (index ==
                                                                graphData
                                                                        .length -
                                                                    1 ||
                                                            [
                                                              1,
                                                              5,
                                                              10,
                                                              15,
                                                              20,
                                                              25,
                                                              30
                                                            ].contains(spot.x
                                                                .toInt())) {
                                                          return FlDotCirclePainter(
                                                            radius: 4,
                                                            color: Colors.white,
                                                            strokeWidth: 2,
                                                            strokeColor: Color(
                                                                0xFF14B8A6),
                                                          );
                                                        }
                                                        return FlDotCirclePainter(
                                                            radius: 0);
                                                      },
                                                    ),
                                                    belowBarData: BarAreaData(
                                                      show: true,
                                                      color: Colors.white
                                                          .withOpacity(0.2),
                                                    ),
                                                  ),
                                                ],
                                                minY: graphData.isEmpty
                                                    ? 0
                                                    : () {
                                                        final minValue = graphData
                                                            .map((e) => e.y)
                                                            .reduce((a, b) => a < b ? a : b);
                                                        // If minimum is negative, add padding below; otherwise use 0 or slightly below
                                                        if (minValue < 0) {
                                                          return minValue * 1.1; // Add 10% padding below
                                                        } else {
                                                          return minValue * 0.95; // Add 5% padding below for positive values
                                                        }
                                                      }(),
                                                maxY: graphData.isEmpty ||
                                                        graphData.every(
                                                            (e) => e.y == 0)
                                                    ? 1000
                                                    : () {
                                                        final maxValue = graphData
                                                            .map((e) => e.y)
                                                            .reduce((a, b) => a > b ? a : b);
                                                        // Add 10% padding above
                                                        return maxValue * 1.1;
                                                      }(),
                                                extraLinesData: ExtraLinesData(
                                                  verticalLines:
                                                      _buildRecurringDebitOrderVerticalLines(
                                                    upcomingRecurringDebitOrders,
                                                    graphData,
                                                  ),
                                                  // Add horizontal line at y=0 if there are negative values
                                                  horizontalLines: graphData.any((e) => e.y < 0)
                                                      ? [
                                                          HorizontalLine(
                                                            y: 0,
                                                            color: Colors.white.withOpacity(0.5),
                                                            strokeWidth: 2,
                                                            dashArray: [5, 5],
                                                          ),
                                                        ]
                                                      : [],
                                                ),
                                                ),
                                              ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 24),

                              // Upcoming Recurring Debit Orders Notification
                              _buildUpcomingRecurringDebitOrdersNotification(
                                upcomingRecurringDebitOrders,
                                theme,
                              ),
                              if (upcomingRecurringDebitOrders.isNotEmpty)
                                SizedBox(height: 24),

                              // Monthly Stats Cards
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? theme.cardColor
                                                : Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.06),
                                            blurRadius: 12,
                                            offset: Offset(0, 4),
                                            spreadRadius: 0,
                                          ),
                                        ],
                                        border: Border.all(
                                          color: theme.dividerColor
                                              .withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 6, sigmaY: 6),
                                          child: Container(
                                            padding: EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: theme.brightness ==
                                                      Brightness.dark
                                                  ? theme.cardColor
                                                      .withOpacity(0.7)
                                                  : Colors.white
                                                      .withOpacity(0.7),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Total balance',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 14,
                                                    color: theme.textTheme
                                                            .bodyMedium?.color
                                                            ?.withOpacity(
                                                                0.7) ??
                                                        Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  Helpers.formatCurrency(
                                                      monthlyBalance),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 26,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -0.5,
                                                    color: theme.textTheme
                                                            .bodyLarge?.color ??
                                                        Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),

                              // Income and Expenses Row
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        color: Colors.green.withOpacity(0.1),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.green.withOpacity(0.15),
                                            blurRadius: 20,
                                            offset: Offset(0, 10),
                                            spreadRadius: 0,
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 6, sigmaY: 6),
                                          child: Container(
                                            padding: EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: Colors.green
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.arrow_upward,
                                                        color: Colors.green,
                                                        size: 20),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Income',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        color: Colors.grey[600],
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  Helpers.formatCurrency(
                                                      monthlyIncome),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -0.5,
                                                    color: Colors.green[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        color: Colors.red.withOpacity(0.1),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withOpacity(0.15),
                                            blurRadius: 20,
                                            offset: Offset(0, 10),
                                            spreadRadius: 0,
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.red.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(
                                              sigmaX: 6, sigmaY: 6),
                                          child: Container(
                                            padding: EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.red.withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.arrow_downward,
                                                        color: Colors.red,
                                                        size: 20),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Expenses',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        color: Colors.grey[600],
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  Helpers.formatCurrency(
                                                      monthlyExpenses),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: -0.5,
                                                    color: Colors.red[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24),

                              // Monthly Financial Insights
                              _buildMonthlyFinancialInsights(
                                monthlyIncome,
                                monthlyExpenses,
                                monthlyBalance,
                                theme,
                              ),
                              SizedBox(height: 24),

                              // Monthly Transactions Section
                              Text(
                                'Recent Transactions',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                  color: theme.textTheme.bodyLarge?.color ??
                                      Colors.black87,
                                ),
                              ),
                              SizedBox(height: 16),
                              FutureBuilder<List<Transaction>>(
                                future: _getTransactionsForMonth(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF14B8A6),
                                      ),
                                    );
                                  }
                                  return _buildMonthlyTransactionsList(
                                      snapshot.data!);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Calculate monthly financial insights
  Future<Map<String, dynamic>> _getMonthlyInsights(
    double income,
    double expenses,
    double balance,
  ) async {
    final expenseRatio = income > 0 ? (expenses / income) * 100 : 0.0;
    final savingsRate = income > 0 ? ((income - expenses) / income) * 100 : 0.0;

    String analysis = '';
    String recommendation = '';
    Color insightColor = Colors.blue;

    if (income == 0 && expenses == 0) {
      analysis = 'No financial activity recorded for this month.';
      recommendation =
          'Start tracking your income and expenses to gain better financial insights.';
      insightColor = Colors.grey;
    } else if (balance > 0) {
      if (savingsRate >= 20) {
        analysis =
            'Excellent financial management! You\'re saving ${savingsRate.toStringAsFixed(1)}% of your income this month.';
        recommendation =
            'Consider investing your savings or building an emergency fund with 3-6 months of expenses.';
        insightColor = Colors.green;
      } else if (savingsRate >= 10) {
        analysis =
            'Good progress! You\'re saving ${savingsRate.toStringAsFixed(1)}% of your income this month.';
        recommendation =
            'Try to increase your savings rate to at least 20% by reducing non-essential expenses.';
        insightColor = Colors.blue;
      } else {
        analysis =
            'You have a positive balance of ${Helpers.formatCurrency(balance.abs())} this month.';
        recommendation =
            'While you\'re saving, aim to save at least 10-20% of your income for better financial security.';
        insightColor = Colors.orange;
      }
    } else if (balance < 0) {
      analysis =
          'Your expenses exceed income by ${Helpers.formatCurrency(balance.abs())} this month.';
      if (expenseRatio > 120) {
        recommendation =
            'Your expenses are ${expenseRatio.toStringAsFixed(0)}% of your income. Review your spending categories and cut back on non-essential expenses immediately.';
        insightColor = Colors.red;
      } else {
        recommendation =
            'Review your spending patterns and identify areas where you can reduce expenses. Consider creating a budget to stay on track.';
        insightColor = Colors.orange;
      }
    } else {
      analysis = 'Your income and expenses are balanced this month.';
      recommendation =
          'You\'re breaking even. Consider setting aside a portion of your income for savings or investments.';
      insightColor = Colors.blue;
    }

    // Category insights
    final transactions = await _getTransactionsForMonth();
    final expenseTransactions =
        transactions.where((t) => t.type == 'expense').toList();
    Map<String, double> categoryTotals = {};
    for (var transaction in expenseTransactions) {
      categoryTotals[transaction.category] =
          (categoryTotals[transaction.category] ?? 0) + transaction.amount;
    }

    String categoryInsight = '';
    if (categoryTotals.isNotEmpty) {
      final sortedCategories = categoryTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topCategory = sortedCategories.first;
      final topCategoryPercent =
          expenses > 0 ? (topCategory.value / expenses) * 100 : 0.0;

      if (topCategoryPercent > 40) {
        categoryInsight =
            '${topCategory.key} accounts for ${topCategoryPercent.toStringAsFixed(1)}% of your expenses. Consider reviewing this category for potential savings.';
      } else if (topCategoryPercent > 25) {
        categoryInsight =
            'Your largest expense category is ${topCategory.key} (${topCategoryPercent.toStringAsFixed(1)}% of total expenses).';
      }
    }

    return {
      'analysis': analysis,
      'recommendation': recommendation,
      'categoryInsight': categoryInsight,
      'color': insightColor,
      'savingsRate': savingsRate,
      'expenseRatio': expenseRatio,
    };
  }

  Widget _buildMonthlyFinancialInsights(
    double income,
    double expenses,
    double balance,
    ThemeData theme,
  ) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getMonthlyInsights(income, expenses, balance),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF14B8A6),
              ),
            ),
          );
        }

        final insights = snapshot.data!;
        final analysis = insights['analysis'] as String;
        final recommendation = insights['recommendation'] as String;
        final categoryInsight = insights['categoryInsight'] as String;
        final insightColor = insights['color'] as Color;

        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    color: insightColor,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Monthly Financial Insights',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: insightColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: insightColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          color: insightColor,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Analysis',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      analysis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Colors.orange,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Recommendation',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      recommendation,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (categoryInsight.isNotEmpty) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF14B8A6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFF14B8A6).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.category_outlined,
                            color: Color(0xFF14B8A6),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Category Insight',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        categoryInsight,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthlyTransactionsList(List<Transaction> transactions) {
    final theme = Theme.of(context);

    if (transactions.isEmpty) {
      return Container(
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? theme.cardColor
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'No transactions for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddTransactionScreen(),
                  ),
                );
              },
              icon: Icon(Icons.add),
              label: Text(
                'Add Transaction',
                style: GoogleFonts.inter(),
              ),
            ),
          ],
        ),
      );
    }

    // Sort by date (newest first) and take first 5
    final recentTransactions = List<Transaction>.from(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    final displayTransactions = recentTransactions.take(5).toList();

    return Column(
      children: [
        ...displayTransactions.map(
            (transaction) => _HomeTransactionCard(transaction: transaction)),
        if (transactions.length > 5)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () {
                // Navigate to transactions screen - this will be handled by parent
                // For now, just show a message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          'View all transactions in the Transactions tab')),
                );
              },
              child: Text('View all ${transactions.length} transactions'),
            ),
          ),
      ],
    );
  }

  // Get upcoming recurring debit orders
  Future<List<Map<String, dynamic>>> _getUpcomingRecurringDebitOrders() async {
    final allTransactions = await LocalStorageService.getTransactions();
    final now = DateTime.now();
    final endDate = now.add(Duration(days: 30)); // Show next 30 days
    return Helpers.getUpcomingRecurringDebitOrders(
      allTransactions,
      startDate: now,
      endDate: endDate,
    );
  }

  // Build vertical lines for upcoming recurring debit orders on dashboard graph
  List<VerticalLine> _buildRecurringDebitOrderVerticalLines(
    List<Map<String, dynamic>> upcomingDebitOrders,
    List<FlSpot> graphData,
  ) {
    if (upcomingDebitOrders.isEmpty || graphData.isEmpty) return [];

    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    List<VerticalLine> verticalLines = [];

    for (var debitOrder in upcomingDebitOrders) {
      final nextDate = debitOrder['nextDate'] as DateTime;

      // Check if the date is in the selected month
      if (nextDate.year != _selectedMonth.year ||
          nextDate.month != _selectedMonth.month) {
        continue;
      }

      final day = nextDate.day;
      if (day >= 1 && day <= daysInMonth) {
        verticalLines.add(
          VerticalLine(
            x: day.toDouble(),
            color: Colors.orange.withOpacity(0.7),
            strokeWidth: 2,
            dashArray: [5, 5],
            label: VerticalLineLabel(
              show: true,
              alignment: Alignment.topCenter,
              padding: EdgeInsets.only(bottom: 4),
              style: TextStyle(
                color: Colors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    }

    return verticalLines;
  }

  // Build notification banner for starting balance
  Widget _buildStartingBalanceNotification(
    ThemeData theme,
    bool isDark,
    Color primaryTurquoise,
  ) {
    return GestureDetector(
      onTap: _navigateToStartingBalance,
      child: Container(
        margin: EdgeInsets.only(bottom: 20),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryTurquoise.withOpacity(0.15),
              primaryTurquoise.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primaryTurquoise.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryTurquoise.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryTurquoise.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: primaryTurquoise,
              size: 24,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Your Starting Balance',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Add your initial balance to track if you\'re saving or losing money over time.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
            onPressed: _dismissStartingBalanceNotification,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        ],
        ),
      ),
    );
  }

  // Build notification banner for upcoming recurring debit orders
  Widget _buildUpcomingRecurringDebitOrdersNotification(
    List<Map<String, dynamic>> upcomingDebitOrders,
    ThemeData theme,
  ) {
    if (upcomingDebitOrders.isEmpty) {
      return SizedBox.shrink();
    }

    // Filter for this month and next 30 days (extended from 7 to show more)
    final now = DateTime.now();
    final nextMonth = now.add(Duration(days: 30));
    final relevantDebitOrders = upcomingDebitOrders.where((order) {
      final date = order['nextDate'] as DateTime;
      return date.isAfter(now.subtract(Duration(days: 1))) &&
          date.isBefore(nextMonth.add(Duration(days: 1)));
    }).toList();

    if (relevantDebitOrders.isEmpty) {
      return SizedBox.shrink();
    }

    // Group by date
    final groupedByDate = <DateTime, List<Map<String, dynamic>>>{};
    for (var debitOrder in relevantDebitOrders) {
      final date = debitOrder['nextDate'] as DateTime;
      final dateOnly = DateTime(date.year, date.month, date.day);
      if (!groupedByDate.containsKey(dateOnly)) {
        groupedByDate[dateOnly] = [];
      }
      groupedByDate[dateOnly]!.add(debitOrder);
    }

    // Sort dates
    final sortedDates = groupedByDate.keys.toList()..sort();
    
    // Separate into urgent (next 7 days) and upcoming (8-30 days)
    final nowDate = DateTime(now.year, now.month, now.day);
    final urgentDates = sortedDates.where((date) {
      final daysUntil = date.difference(nowDate).inDays;
      return daysUntil >= 0 && daysUntil <= 7;
    }).toList();
    
    final upcomingDates = sortedDates.where((date) {
      final daysUntil = date.difference(nowDate).inDays;
      return daysUntil > 7 && daysUntil <= 30;
    }).toList();

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.withOpacity(0.15),
            Colors.red.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.notifications_active,
                  color: Colors.orange[700],
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upcoming Recurring Bills',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Balance will deduct on due date',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          // Show urgent bills (next 7 days)
          if (urgentDates.isNotEmpty) ...[
            Text(
              'Due Soon (Next 7 Days)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red[700],
              ),
            ),
            SizedBox(height: 8),
            ...urgentDates.take(5).map((date) {
              final debitOrders = groupedByDate[date]!;
              final dayAmount = debitOrders.fold<double>(
                0.0,
                (sum, order) => sum + (order['amount'] as double),
              );
              final daysUntil = date.difference(nowDate).inDays;
              final isUrgent = daysUntil <= 3;

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUrgent 
                      ? Colors.red.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isUrgent
                        ? Colors.red.withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUrgent
                            ? Colors.red.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUrgent ? Icons.warning : Icons.calendar_today,
                            size: 14,
                            color: isUrgent ? Colors.red[700] : Colors.orange[700],
                          ),
                          SizedBox(width: 4),
                          Text(
                            daysUntil == 0
                                ? 'Today'
                                : daysUntil == 1
                                    ? 'Tomorrow'
                                    : '$daysUntil days',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isUrgent ? Colors.red[700] : Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('MMM d, yyyy').format(date),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          if (debitOrders.length > 1) ...[
                            SizedBox(height: 4),
                            Text(
                              '${debitOrders.length} bills',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      Helpers.formatCurrency(dayAmount),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isUrgent ? Colors.red[700] : Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (urgentDates.length > 5)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'and ${urgentDates.length - 5} more in the next 7 days',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (upcomingDates.isNotEmpty) SizedBox(height: 16),
          ],
          // Show upcoming bills (8-30 days)
          if (upcomingDates.isNotEmpty) ...[
            Text(
              'Upcoming (Next 30 Days)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.blue[700],
              ),
            ),
            SizedBox(height: 8),
            ...upcomingDates.take(3).map((date) {
              final debitOrders = groupedByDate[date]!;
              final dayAmount = debitOrders.fold<double>(
                0.0,
                (sum, order) => sum + (order['amount'] as double),
              );
              final daysUntil = date.difference(nowDate).inDays;

              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$daysUntil days',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat('MMM d, yyyy').format(date),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    Text(
                      Helpers.formatCurrency(dayAmount),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (upcomingDates.length > 3)
              Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'and ${upcomingDates.length - 3} more upcoming bills',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // Show full-screen chart with time range selector
  void _showFullScreenChart(
    BuildContext context,
    List<FlSpot> currentGraphData,
    DateTime currentMonth,
    List<Map<String, dynamic>> upcomingRecurringDebitOrders,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => _FullScreenChartDialog(
        initialGraphData: currentGraphData,
        initialMonth: currentMonth,
        upcomingRecurringDebitOrders: upcomingRecurringDebitOrders,
      ),
    );
  }
}

// Full-screen chart dialog with time range selector
class _FullScreenChartDialog extends StatefulWidget {
  final List<FlSpot> initialGraphData;
  final DateTime initialMonth;
  final List<Map<String, dynamic>> upcomingRecurringDebitOrders;

  const _FullScreenChartDialog({
    required this.initialGraphData,
    required this.initialMonth,
    required this.upcomingRecurringDebitOrders,
  });

  @override
  State<_FullScreenChartDialog> createState() => _FullScreenChartDialogState();
}

class _FullScreenChartDialogState extends State<_FullScreenChartDialog> {
  String _selectedTimeRange = 'this_month'; // Default: this month
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  List<FlSpot> _graphData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _graphData = widget.initialGraphData;
    _loadGraphData();
  }

  Future<void> _loadGraphData() async {
    setState(() => _isLoading = true);
    
    try {
      final allTransactions = await LocalStorageService.getTransactions();
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate;
      
      switch (_selectedTimeRange) {
        case 'this_month':
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case '3_months':
          startDate = DateTime(now.year, now.month - 2, 1);
          endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'year':
          startDate = DateTime(now.year, 1, 1);
          endDate = DateTime(now.year, 12, 31);
          break;
        case 'custom':
          if (_customStartDate != null && _customEndDate != null) {
            startDate = _customStartDate!;
            endDate = _customEndDate!;
          } else {
            // Default to this month if custom dates not set
            startDate = DateTime(now.year, now.month, 1);
            endDate = DateTime(now.year, now.month + 1, 0);
          }
          break;
        default:
          startDate = DateTime(now.year, now.month, 1);
          endDate = DateTime(now.year, now.month + 1, 0);
      }
      
      final graphData = await _calculateGraphDataForRange(
        allTransactions,
        startDate,
        endDate,
      );
      
      setState(() {
        _graphData = graphData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading graph data: $e');
    }
  }

  Future<List<FlSpot>> _calculateGraphDataForRange(
    List<Transaction> allTransactions,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Calculate days in range
    final daysInRange = endDate.difference(startDate).inDays + 1;
    
    // Calculate starting balance (starting balance + all transactions before start date)
    double startingBalance = SettingsService.getStartingBalance();
    for (var transaction in allTransactions) {
      final transactionDate = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      
      if (transactionDate.isBefore(startDate)) {
        if (transaction.type == 'income') {
          startingBalance += transaction.amount;
        } else if (!transaction.isRecurring || transaction.type != 'expense') {
          startingBalance -= transaction.amount;
        }
      }
    }
    
    // Process transactions in the range
    final sortedTransactions = allTransactions
        .where((t) {
          final tDate = DateTime(t.date.year, t.date.month, t.date.day);
          return !tDate.isBefore(startDate) && !tDate.isAfter(endDate);
        })
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    // Create daily balances map
    Map<int, double> dailyBalances = {};
    double runningBalance = startingBalance;
    
    // Initialize all days with starting balance
    for (int day = 0; day < daysInRange; day++) {
      dailyBalances[day] = startingBalance;
    }
    
    // First, collect all recurring payment dates grouped by day
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    Map<int, double> recurringPaymentsByDay = {};
    
    for (var transaction in sortedTransactions) {
      if (transaction.isRecurring && transaction.type == 'expense') {
        final startDateOnly = DateTime(
          transaction.date.year,
          transaction.date.month,
          transaction.date.day,
        );
        
        DateTime? paymentDate = startDateOnly;
        int maxIterations = 1000;
        int iterations = 0;
        
        // Fast-forward to start date if needed
        while (paymentDate != null &&
               paymentDate.isBefore(startDate) &&
               iterations < maxIterations) {
          paymentDate = Helpers.getNextOccurrenceFromDate(transaction, paymentDate);
          iterations++;
        }
        
        // Collect all payment dates in range
        while (paymentDate != null &&
               !paymentDate.isAfter(endDate) &&
               iterations < maxIterations) {
          if (paymentDate.isBefore(nowDate) || paymentDate.isAtSameMomentAs(nowDate)) {
            final dayIndex = paymentDate.difference(startDate).inDays;
            if (dayIndex >= 0 && dayIndex < daysInRange) {
              // Group payments by day
              recurringPaymentsByDay[dayIndex] = 
                  (recurringPaymentsByDay[dayIndex] ?? 0.0) + transaction.amount;
            }
          }
          
          if (paymentDate.isAfter(nowDate)) break;
          paymentDate = Helpers.getNextOccurrenceFromDate(transaction, paymentDate);
          iterations++;
        }
      }
    }
    
    // Group non-recurring transactions by day to process all transactions on the same day together
    Map<int, List<Transaction>> transactionsByDay = {};
    for (var transaction in sortedTransactions) {
      if (transaction.isRecurring && transaction.type == 'expense') continue;
      
      final transactionDate = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      final dayIndex = transactionDate.difference(startDate).inDays;
      
      if (dayIndex >= 0 && dayIndex < daysInRange) {
        if (!transactionsByDay.containsKey(dayIndex)) {
          transactionsByDay[dayIndex] = [];
        }
        transactionsByDay[dayIndex]!.add(transaction);
      }
    }
    
    // Merge recurring payments into the transactions by day map
    // This ensures all transactions on the same day are processed together
    for (var dayIndex in recurringPaymentsByDay.keys) {
      if (!transactionsByDay.containsKey(dayIndex)) {
        transactionsByDay[dayIndex] = [];
      }
    }
    
    // Process all transactions day by day (including recurring payments) to avoid intermediate balance updates
    final sortedDayIndices = transactionsByDay.keys.toList()..sort();
    for (var dayIndex in sortedDayIndices) {
      final dayTransactions = transactionsByDay[dayIndex]!;
      
      // Process all transactions for this day and calculate net change
      double dayNetChange = 0;
      for (var transaction in dayTransactions) {
        if (transaction.type == 'income') {
          dayNetChange += transaction.amount;
        } else {
          dayNetChange -= transaction.amount;
        }
      }
      
      // Add recurring payments for this day (if any)
      if (recurringPaymentsByDay.containsKey(dayIndex)) {
        dayNetChange -= recurringPaymentsByDay[dayIndex]!;
      }
      
      // Update running balance once for the entire day
      runningBalance += dayNetChange;
      
      // Update balance for this day and all subsequent days
      for (int d = dayIndex; d < daysInRange; d++) {
        dailyBalances[d] = runningBalance;
      }
    }
    
    // Create spots for the graph
    List<FlSpot> spots = [];
    for (int day = 0; day < daysInRange; day++) {
      spots.add(FlSpot(day.toDouble(), dailyBalances[day] ?? startingBalance));
    }
    
    return spots.isEmpty ? [FlSpot(0.0, startingBalance)] : spots;
  }

  Future<void> _selectCustomDateRange() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTurquoise = const Color(0xFF14B8A6);
    
    // Store temporary dates for the dialog
    DateTime? tempStartDate = _customStartDate;
    DateTime? tempEndDate = _customEndDate;
    
    // Show a dialog with both date pickers
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryTurquoise.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.date_range,
                        color: primaryTurquoise,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select Date Range',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, false),
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ],
                ),
                SizedBox(height: 24),
                
                // From Date
                Text(
                  'From Date',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final startDate = await showDatePicker(
                      context: context,
                      initialDate: tempStartDate ?? DateTime.now().subtract(Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: tempEndDate ?? DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: primaryTurquoise,
                              onPrimary: Colors.white,
                              surface: isDark ? Color(0xFF1E293B) : Colors.white,
                              onSurface: theme.textTheme.bodyLarge?.color ?? Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (startDate != null) {
                      setDialogState(() {
                        tempStartDate = startDate;
                        // Ensure end date is not before start date
                        if (tempEndDate != null && tempEndDate!.isBefore(startDate)) {
                          tempEndDate = startDate;
                        }
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryTurquoise.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: primaryTurquoise,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          tempStartDate != null
                              ? DateFormat('MMM d, yyyy').format(tempStartDate!)
                              : 'Select start date',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: tempStartDate != null
                                ? theme.textTheme.bodyLarge?.color
                                : Colors.grey[600],
                          ),
                        ),
                        Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                // To Date
                Text(
                  'To Date',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    final endDate = await showDatePicker(
                      context: context,
                      initialDate: tempEndDate ?? (tempStartDate ?? DateTime.now()),
                      firstDate: tempStartDate ?? DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: primaryTurquoise,
                              onPrimary: Colors.white,
                              surface: isDark ? Color(0xFF1E293B) : Colors.white,
                              onSurface: theme.textTheme.bodyLarge?.color ?? Colors.black,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (endDate != null) {
                      setDialogState(() {
                        tempEndDate = endDate;
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryTurquoise.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: primaryTurquoise,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          tempEndDate != null
                              ? DateFormat('MMM d, yyyy').format(tempEndDate!)
                              : 'Select end date',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: tempEndDate != null
                                ? theme.textTheme.bodyLarge?.color
                                : Colors.grey[600],
                          ),
                        ),
                        Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Apply Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (tempStartDate != null && tempEndDate != null)
                        ? () {
                            setState(() {
                              _customStartDate = tempStartDate;
                              _customEndDate = tempEndDate;
                              _selectedTimeRange = 'custom';
                            });
                            Navigator.pop(context, true);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTurquoise,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Text(
                      'Apply',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    if (result == true) {
      await _loadGraphData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTurquoise = const Color(0xFF14B8A6);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ]
                : [
                    primaryTurquoise.withOpacity(0.15),
                    Color(0xFF0EA5E9).withOpacity(0.1),
                    Color(0xFF3B82F6).withOpacity(0.08),
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryTurquoise.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: primaryTurquoise,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Balance Chart',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Track your financial progress',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark 
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.black87.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 20),
              
              // Time range selector
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.1)
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.2)
                          : Colors.black.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            _buildTimeRangeChip('this_month', 'This Month'),
                            _buildTimeRangeChip('3_months', '3 Months'),
                            _buildTimeRangeChip('year', 'Year'),
                            _buildTimeRangeChip('custom', 'Custom'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 20),
              
              // Chart
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.15)
                          : Colors.black.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.08),
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  interval: _graphData.length > 30 ? 10 : 5,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index >= 0 && index < _graphData.length) {
                                      final now = DateTime.now();
                                      DateTime date;
                                      switch (_selectedTimeRange) {
                                        case 'this_month':
                                          date = DateTime(now.year, now.month, index + 1);
                                          break;
                                        case '3_months':
                                        case 'year':
                                        case 'custom':
                                          // Calculate date based on start date
                                          final startDate = _getStartDateForRange();
                                          date = startDate.add(Duration(days: index));
                                          break;
                                        default:
                                          date = DateTime(now.year, now.month, index + 1);
                                      }
                                      return Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          DateFormat('MMM d').format(date),
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }
                                    return SizedBox.shrink();
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 60,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      Helpers.formatCurrency(value),
                                      style: TextStyle(
                                        color: isDark 
                                            ? Colors.white.withOpacity(0.8)
                                            : Colors.black87.withOpacity(0.7),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            extraLinesData: ExtraLinesData(
                              // Add horizontal line at y=0 if there are negative values
                              horizontalLines: _graphData.any((e) => e.y < 0)
                                  ? [
                                      HorizontalLine(
                                        y: 0,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.4)
                                            : Colors.black.withOpacity(0.3),
                                        strokeWidth: 2,
                                        dashArray: [5, 5],
                                        label: HorizontalLineLabel(
                                          show: true,
                                          alignment: Alignment.centerRight,
                                          padding: EdgeInsets.only(right: 8),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white.withOpacity(0.7)
                                                : Colors.black.withOpacity(0.6),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ]
                                  : [],
                            ),
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                tooltipRoundedRadius: 8,
                                tooltipPadding: EdgeInsets.all(8),
                                tooltipBgColor: Colors.white.withOpacity(0.9),
                                getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                                  return touchedBarSpots.map((barSpot) {
                                    final index = barSpot.x.toInt();
                                    final now = DateTime.now();
                                    DateTime date;
                                    switch (_selectedTimeRange) {
                                      case 'this_month':
                                        date = DateTime(now.year, now.month, index + 1);
                                        break;
                                      case '3_months':
                                      case 'year':
                                      case 'custom':
                                        final startDate = _getStartDateForRange();
                                        date = startDate.add(Duration(days: index));
                                        break;
                                      default:
                                        date = DateTime(now.year, now.month, index + 1);
                                    }
                                    return LineTooltipItem(
                                      '${Helpers.formatCurrency(barSpot.y)}\n${DateFormat('MMM d, yyyy').format(date)}',
                                      TextStyle(
                                        color: Color(0xFF14B8A6),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                              handleBuiltInTouches: true,
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _graphData,
                                isCurved: true,
                                color: primaryTurquoise,
                                barWidth: 3.5,
                                isStrokeCapRound: true,
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) {
                                    // Show dots on key points
                                    if (index == 0 || 
                                        index == _graphData.length - 1 ||
                                        index % (_graphData.length ~/ 5) == 0) {
                                      return FlDotCirclePainter(
                                        radius: 4,
                                        color: primaryTurquoise,
                                        strokeWidth: 2,
                                        strokeColor: Colors.white,
                                      );
                                    }
                                    return FlDotCirclePainter(radius: 0);
                                  },
                                ),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      primaryTurquoise.withOpacity(0.3),
                                      primaryTurquoise.withOpacity(0.05),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            minY: _graphData.isEmpty
                                ? 0
                                : () {
                                    final minValue = _graphData
                                        .map((e) => e.y)
                                        .reduce((a, b) => a < b ? a : b);
                                    // If minimum is negative, add padding below; otherwise use 0 or slightly below
                                    if (minValue < 0) {
                                      return minValue * 1.1; // Add 10% padding below
                                    } else {
                                      return minValue * 0.95; // Add 5% padding below for positive values
                                    }
                                  }(),
                            maxY: _graphData.isEmpty || _graphData.every((e) => e.y == 0)
                                ? 1000
                                : () {
                                    final maxValue = _graphData
                                        .map((e) => e.y)
                                        .reduce((a, b) => a > b ? a : b);
                                    // Add 10% padding above
                                    return maxValue * 1.1;
                                  }(),
                          ),
                        ),
                ),
              ),
              
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _getStartDateForRange() {
    final now = DateTime.now();
    switch (_selectedTimeRange) {
      case '3_months':
        return DateTime(now.year, now.month - 2, 1);
      case 'year':
        return DateTime(now.year, 1, 1);
      case 'custom':
        return _customStartDate ?? DateTime(now.year, now.month, 1);
      default:
        return DateTime(now.year, now.month, 1);
    }
  }

  Widget _buildTimeRangeChip(String value, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTurquoise = const Color(0xFF14B8A6);
    final isSelected = _selectedTimeRange == value;
    
    // For custom, show the date range if selected
    String displayLabel = label;
    if (value == 'custom' && _selectedTimeRange == 'custom' && 
        _customStartDate != null && _customEndDate != null) {
      displayLabel = '${DateFormat('MMM d').format(_customStartDate!)} - ${DateFormat('MMM d').format(_customEndDate!)}';
    }
    
    return InkWell(
      onTap: () async {
        if (value == 'custom') {
          await _selectCustomDateRange();
        } else {
          setState(() {
            _selectedTimeRange = value;
          });
          await _loadGraphData();
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryTurquoise
              : (isDark 
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryTurquoise
                : (isDark
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.1)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryTurquoise.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayLabel,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark
                        ? Colors.white.withOpacity(0.9)
                        : Colors.black87),
              ),
            ),
            if (value == 'custom' && isSelected) ...[
              SizedBox(width: 6),
              Icon(
                Icons.edit,
                size: 14,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeTransactionCard extends StatelessWidget {
  final Transaction transaction;

  const _HomeTransactionCard({required this.transaction});

  IconData _getCategoryIcon(String category) {
    final iconMap = {
      'Coffee': Icons.local_cafe,
      'Taxi': Icons.local_taxi,
      'TV': Icons.tv,
      'Music': Icons.music_note,
      'Food & Dining': Icons.restaurant,
      'Shopping': Icons.shopping_bag,
      'Entertainment': Icons.movie,
      'Bills & Utilities': Icons.receipt,
      'Healthcare': Icons.local_hospital,
      'Education': Icons.school,
      'Travel': Icons.flight,
      'Salary': Icons.account_balance_wallet,
      'Freelance': Icons.work,
      'Investment': Icons.trending_up,
      'Gift': Icons.card_giftcard,
      'Bonus': Icons.stars,
    };
    return iconMap[category] ?? Icons.category;
  }

  Color _getCategoryColor(String category) {
    final colorMap = {
      'Coffee': Colors.brown,
      'Taxi': Colors.black,
      'TV': Colors.red,
      'Music': Colors.green,
      'Food & Dining': Colors.orange,
      'Shopping': Colors.pink,
      'Entertainment': Colors.purple,
      'Bills & Utilities': Colors.blue,
      'Healthcare': Colors.teal,
      'Education': Colors.indigo,
      'Travel': Colors.cyan,
      'Salary': Colors.green,
      'Freelance': Colors.blue,
      'Investment': Colors.amber,
      'Gift': Colors.pink,
      'Bonus': Colors.orange,
    };
    return colorMap[category] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == 'income';
    final categoryIcon = _getCategoryIcon(transaction.category);
    final categoryColor = _getCategoryColor(transaction.category);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.cardColor
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? theme.cardColor.withOpacity(0.6)
                  : Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      categoryIcon,
                      color: categoryColor,
                      size: 24,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description.isNotEmpty
                            ? transaction.description
                            : transaction.category,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color ??
                              Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                Helpers.formatDateRelative(transaction.date),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.7) ??
                                      Colors.grey[600],
                                ),
                              ),
                              if (transaction.isRecurring || transaction.isSubscription) ...[
                                SizedBox(width: 8),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: transaction.isSubscription 
                                        ? Colors.purple.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        transaction.isSubscription 
                                            ? Icons.subscriptions 
                                            : Icons.repeat,
                                        size: 12,
                                        color: transaction.isSubscription 
                                            ? Colors.purple 
                                            : Colors.orange,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        transaction.isSubscription ? 'Subscription' : 'Recurring',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: transaction.isSubscription 
                                              ? Colors.purple 
                                              : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // Show next due date for recurring expenses
                          if (transaction.isRecurring && transaction.type == 'expense') ...[
                            SizedBox(height: 6),
                            Builder(
                              builder: (context) {
                                final nextDate = Helpers.getNextRecurringDate(transaction);
                                if (nextDate == null) return SizedBox.shrink();
                                
                                final now = DateTime.now();
                                final today = DateTime(now.year, now.month, now.day);
                                final nextDateOnly = DateTime(nextDate.year, nextDate.month, nextDate.day);
                                final daysUntil = nextDateOnly.difference(today).inDays;
                                
                                String dueText;
                                Color dueColor;
                                if (daysUntil < 0) {
                                  dueText = 'Overdue: ${Helpers.formatDateRelative(nextDate)}';
                                  dueColor = Colors.red;
                                } else if (daysUntil == 0) {
                                  dueText = 'Due today';
                                  dueColor = Colors.red;
                                } else if (daysUntil == 1) {
                                  dueText = 'Due tomorrow';
                                  dueColor = Colors.orange;
                                } else if (daysUntil <= 7) {
                                  dueText = 'Due in $daysUntil days (${Helpers.formatDateRelative(nextDate)})';
                                  dueColor = Colors.orange;
                                } else {
                                  dueText = 'Next due: ${Helpers.formatDateRelative(nextDate)}';
                                  dueColor = Colors.blue;
                                }
                                
                                return Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: dueColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: dueColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 12,
                                        color: dueColor,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        dueText,
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: dueColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '${isIncome ? '+' : '-'}${Helpers.formatCurrency(transaction.amount)}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isIncome ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
