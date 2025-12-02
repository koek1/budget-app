import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/models/user.dart';
import 'package:budget_app/services/local_storage_service.dart';
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

  @override
  void initState() {
    super.initState();
    transactionsBox = Hive.box<Transaction>('transactionsBox');
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await LocalStorageService.getCurrentUser();
    setState(() {
      currentUser = user;
    });
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
    // Calculate savings as total income minus expenses (all time, user-filtered)
    final allTransactions = await LocalStorageService.getTransactions();
    final totalIncome = allTransactions
        .where((transaction) => transaction.type == 'income')
        .fold<double>(0.0, (sum, transaction) => sum + transaction.amount);
    final totalExpenses = allTransactions
        .where((transaction) => transaction.type == 'expense')
        .fold<double>(0.0, (sum, transaction) => sum + transaction.amount);
    return totalIncome - totalExpenses;
  }

  Future<List<FlSpot>> _getGraphData() async {
    final transactions = await _getTransactionsForMonth();
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

    // Get all user-filtered transactions up to the selected month to calculate starting balance
    final allTransactions = await LocalStorageService.getTransactions()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Calculate starting balance (all transactions before this month)
    double startingBalance = 0;
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

    // Process transactions in order and update balances
    for (var transaction in sortedTransactions) {
      final day = transaction.date.day;

      // Update running balance
      if (transaction.type == 'income') {
        runningBalance += transaction.amount;
      } else {
        runningBalance -= transaction.amount;
      }

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
              future: Future.wait([
                getMonthlyIncome(),
                getMonthlyExpenses(),
                getMonthlyBalance(),
                getSavings(),
                _getGraphData(),
              ]).then((results) => {
                'income': results[0] as double,
                'expenses': results[1] as double,
                'balance': results[2] as double,
                'savings': results[3] as double,
                'graphData': results[4] as List<FlSpot>,
              }),
              builder: (context, snapshot) {
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
                      color: theme.textTheme.bodyLarge?.color ?? Colors.black,
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
                              builder: (context) => const SettingsScreen(),
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
                                  border:
                                      Border.all(color: Colors.white, width: 2),
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
                            color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                          ),
                        ),
                        SizedBox(height: 24),

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
                                color: Color(0xFF14B8A6).withOpacity(0.25),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Container(
                                padding: EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
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

                              // Date Selector
                              InkWell(
                                onTap: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedMonth,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                    initialDatePickerMode: DatePickerMode.year,
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _selectedMonth =
                                          DateTime(picked.year, picked.month);
                                    });
                                  }
                                },
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('MMMM yyyy')
                                          .format(_selectedMonth),
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Icon(
                                      Icons.calendar_today,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 20),

                              // Graph
                              Container(
                                height: 150,
                                child: LineChart(
                                  LineChartData(
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      getDrawingHorizontalLine: (value) {
                                        return FlLine(
                                          color: Colors.white.withOpacity(0.1),
                                          strokeWidth: 1,
                                        );
                                      },
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      rightTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      topTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          interval: 5,
                                          getTitlesWidget: (value, meta) {
                                            final day = value.toInt();
                                            if ([1, 5, 10, 15, 20, 25, 30]
                                                .contains(day)) {
                                              return Text(
                                                day.toString(),
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              );
                                            }
                                            return SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    lineTouchData: LineTouchData(
                                      touchTooltipData: LineTouchTooltipData(
                                        tooltipRoundedRadius: 8,
                                        tooltipPadding: EdgeInsets.all(8),
                                        tooltipBgColor:
                                            Colors.white.withOpacity(0.9),
                                        getTooltipItems: (List<LineBarSpot>
                                            touchedBarSpots) {
                                          return touchedBarSpots.map((barSpot) {
                                            final day = barSpot.x.toInt();
                                            final monthName = DateFormat('MMM')
                                                .format(_selectedMonth);
                                            // Use the actual graph value (barSpot.y) which is the balance at that point
                                            final graphValue = barSpot.y;
                                            final amountStr =
                                                Helpers.formatCurrency(
                                                    graphValue);
                                            return LineTooltipItem(
                                              '$amountStr\n$day $monthName',
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
                                        spots: graphData,
                                        isCurved: true,
                                        color: Colors.white,
                                        barWidth: 3,
                                        isStrokeCapRound: true,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter:
                                              (spot, percent, barData, index) {
                                            if (index == graphData.length - 1 ||
                                                [1, 5, 10, 15, 20, 25, 30]
                                                    .contains(spot.x.toInt())) {
                                              return FlDotCirclePainter(
                                                radius: 4,
                                                color: Colors.white,
                                                strokeWidth: 2,
                                                strokeColor: Color(0xFF14B8A6),
                                              );
                                            }
                                            return FlDotCirclePainter(
                                                radius: 0);
                                          },
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: Colors.white.withOpacity(0.2),
                                        ),
                                      ),
                                    ],
                                    minY: graphData.isEmpty
                                        ? 0
                                        : (graphData.map((e) => e.y).reduce(
                                                    (a, b) => a < b ? a : b) *
                                                0.95)
                                            .clamp(0, double.infinity),
                                    maxY: graphData.isEmpty ||
                                            graphData.every((e) => e.y == 0)
                                        ? 1000
                                        : (graphData.map((e) => e.y).reduce(
                                                    (a, b) => a > b ? a : b) *
                                                1.1)
                                            .clamp(100, double.infinity),
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

                        // Monthly Stats Cards
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: theme.brightness == Brightness.dark
                                      ? theme.cardColor
                                      : Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: theme.dividerColor.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                    child: Container(
                                      padding: EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: theme.brightness == Brightness.dark
                                            ? theme.cardColor.withOpacity(0.7)
                                            : Colors.white.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Total balance',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: theme.textTheme.bodyMedium?.color
                                                      ?.withOpacity(0.7) ??
                                                  Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            Helpers.formatCurrency(monthlyBalance),
                                            style: GoogleFonts.poppins(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.5,
                                              color:
                                                  theme.textTheme.bodyLarge?.color ??
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
                                      color: Colors.green.withOpacity(0.15),
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
                                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                    child: Container(
                                      padding: EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.arrow_upward,
                                                  color: Colors.green, size: 20),
                                              SizedBox(width: 8),
                                              Text(
                                                'Income',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            Helpers.formatCurrency(monthlyIncome),
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
                                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                    child: Container(
                                      padding: EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.arrow_downward,
                                                  color: Colors.red, size: 20),
                                              SizedBox(width: 8),
                                              Text(
                                                'Expenses',
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            Helpers.formatCurrency(monthlyExpenses),
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
                            return _buildMonthlyTransactionsList(snapshot.data!);
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
                    color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  DateFormat('d MMMM').format(transaction.date),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color:
                        theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ??
                            Colors.grey[600],
                  ),
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
