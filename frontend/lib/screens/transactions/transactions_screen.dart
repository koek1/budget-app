import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/screens/home/add_transaction_screen.dart';
import 'package:budget_app/utils/helpers.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:budget_app/screens/settings/settings_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class TransactionsScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const TransactionsScreen({super.key, this.onMenuTap});

  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();
  String _selectedTab = 'Spendings';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index == 0 ? 'Spendings' : 'Income';
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Transaction>> _getTransactionsForMonth() async {
    // Get user-filtered transactions
    final allTransactions = await LocalStorageService.getTransactions();

    // If no transactions, return empty list
    if (allTransactions.isEmpty) {
      return [];
    }

    // Filter transactions by selected month
    final filtered = allTransactions.where((transaction) {
      final transactionDate = transaction.date;
      // Normalize dates to compare only year and month (ignore time)
      final transactionYearMonth =
          DateTime(transactionDate.year, transactionDate.month);
      final selectedYearMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month);
      return transactionYearMonth == selectedYearMonth;
    }).toList();

    return filtered;
  }

  Future<List<Map<String, dynamic>>> _getPendingTransactions() async {
    final allTransactions = await LocalStorageService.getTransactions();
    return Helpers.getPendingRecurringTransactions(allTransactions);
  }

  Future<List<FlSpot>> _getGraphData() async {
    final transactions = await _getTransactionsForMonth();
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;

    // Filter transactions based on selected tab
    final filteredTransactions = transactions.where((t) {
      if (_selectedTab == 'Income') {
        return t.type == 'income';
      } else {
        return t.type == 'expense';
      }
    }).toList();

    Map<int, double> dailyTotals = {};
    double runningTotal = 0;

    // Initialize all days with 0
    for (int day = 1; day <= daysInMonth; day++) {
      dailyTotals[day] = 0;
    }

    // Sort transactions by date
    final sortedTransactions = List<Transaction>.from(filteredTransactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Calculate running total for each day
    for (var transaction in sortedTransactions) {
      final day = transaction.date.day;
      runningTotal += transaction.amount;
      // Update total for this day and all subsequent days until next transaction
      for (int d = day; d <= daysInMonth; d++) {
        dailyTotals[d] = runningTotal;
      }
    }

    // Create spots for the graph - ensure we have data points for all days
    List<FlSpot> spots = [];
    for (int day = 1; day <= daysInMonth; day++) {
      double total = dailyTotals[day] ?? 0;
      spots.add(FlSpot(day.toDouble(), total));
    }

    // Always return at least one spot to ensure graph renders
    if (spots.isEmpty) {
      spots.add(FlSpot(1.0, 0.0));
    }

    return spots;
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  Future<void> _editTransaction(Transaction transaction) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddTransactionScreen(transaction: transaction),
        ),
      );
      if (result == true && mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction updated'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error editing transaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to edit transaction'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: isDark ? Color(0xFF1E293B) : Colors.white,
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Delete Transaction',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  'Are you sure you want to delete this transaction? This action cannot be undone.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: theme.textTheme.bodyMedium?.color,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 24),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      if (confirmed == true) {
        await LocalStorageService.deleteTransaction(transaction.id)
            .timeout(Duration(seconds: 10));
        if (mounted) {
          Helpers.showSuccessSnackBar(
              context, 'Transaction deleted successfully');
        }
      }
    } catch (e) {
      print('Error deleting transaction: $e');
      if (mounted) {
        String errorMessage = 'Failed to delete transaction';
        if (e.toString().contains('timeout')) {
          errorMessage = 'Delete operation timed out. Please try again.';
        } else if (e.toString().contains('Exception:')) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        }
        Helpers.showErrorSnackBar(context, errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<Box<Transaction>>(
          valueListenable:
              Hive.box<Transaction>('transactionsBox').listenable(),
          builder: (context, box, _) {
            return FutureBuilder<Map<String, dynamic>>(
              future: Future.wait([
                _getTransactionsForMonth(),
                _getGraphData(),
                _getPendingTransactions(),
              ]).timeout(Duration(seconds: 10), onTimeout: () {
                throw Exception('Loading transactions timed out');
              }).then((results) {
                final transactions = results[0] as List<Transaction>;
                final pendingTransactions =
                    results[2] as List<Map<String, dynamic>>;

                // Filter pending transactions for the selected month
                final monthStart =
                    DateTime(_selectedMonth.year, _selectedMonth.month, 1);
                final monthEnd =
                    DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

                final pendingForMonth = pendingTransactions.where((p) {
                  final dueDate = p['dueDate'] as DateTime;
                  return dueDate
                          .isAfter(monthStart.subtract(Duration(days: 1))) &&
                      dueDate.isBefore(monthEnd.add(Duration(days: 1)));
                }).toList();

                final spendings = transactions
                    .where((t) => t.type == 'expense')
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));
                final income = transactions
                    .where((t) => t.type == 'income')
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));
                final graphData = results[1] as List<FlSpot>;

                // Calculate totals - only include actual transactions (not pending)
                final currentTabTotal = _selectedTab == 'Income'
                    ? income.fold<double>(0.0, (sum, t) => sum + t.amount)
                    : spendings.fold<double>(0.0, (sum, t) => sum + t.amount);

                return {
                  'spendings': spendings,
                  'income': income,
                  'graphData': graphData,
                  'currentTabTotal': currentTabTotal,
                  'pendingTransactions': pendingForMonth,
                };
              }).catchError((e) {
                print('Error loading transactions: $e');
                return {
                  'spendings': <Transaction>[],
                  'income': <Transaction>[],
                  'graphData': <FlSpot>[],
                  'currentTabTotal': 0.0,
                  'pendingTransactions': <Map<String, dynamic>>[],
                  'error': e.toString(),
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
                          'Loading transactions...',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError ||
                    (snapshot.hasData && snapshot.data!.containsKey('error'))) {
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
                            'Failed to load transactions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            snapshot.error?.toString() ??
                                snapshot.data?['error'] ??
                                'Unknown error',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: Text('Retry'),
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

                final spendings =
                    snapshot.data!['spendings'] as List<Transaction>;
                final income = snapshot.data!['income'] as List<Transaction>;
                final graphData = snapshot.data!['graphData'] as List<FlSpot>;
                final currentTabTotal =
                    snapshot.data!['currentTabTotal'] as double;
                final allPendingTransactions = snapshot
                    .data!['pendingTransactions'] as List<Map<String, dynamic>>;

                // Filter pending transactions for expenses only
                final pendingExpenses = allPendingTransactions
                    .where((p) =>
                        (p['transaction'] as Transaction).type == 'expense')
                    .toList();

                return CustomScrollView(
                  slivers: [
                    // Header
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
                        'Transactions',
                        style: TextStyle(
                          color:
                              theme.textTheme.titleLarge?.color ?? Colors.black,
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
                                      Color(0xFF2563EB).withOpacity(0.1),
                                  child: Icon(Icons.person,
                                      color: Color(0xFF2563EB), size: 20),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF2563EB),
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

                    // Balance Card with Graph
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Color(0xFF2563EB), // Blue color
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF2563EB).withOpacity(0.3),
                                blurRadius: 15,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Month Selector
                              InkWell(
                                onTap: _selectMonth,
                                child: Row(
                                  children: [
                                    Text(
                                      DateFormat('MMMM').format(_selectedMonth),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_drop_down,
                                        color: Colors.white),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),

                              // Balance
                              Text(
                                Helpers.formatCurrency(currentTabTotal),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Total ${_selectedTab.toLowerCase()}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 24),

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
                                            // Show key days: 1, 5, 10, 15, 20, 25, 30
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
                                            // Use the actual graph value (barSpot.y) which is the balance at that point on the graph
                                            final graphValue = barSpot.y;
                                            final amountStr =
                                                Helpers.formatCurrency(
                                                    graphValue);
                                            return LineTooltipItem(
                                              '$amountStr\n$day $monthName',
                                              TextStyle(
                                                color: Color(0xFF2563EB),
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
                                            // Show dot on the last point or on specific days
                                            if (index == graphData.length - 1 ||
                                                [1, 5, 10, 15, 20, 25, 30]
                                                    .contains(spot.x.toInt())) {
                                              return FlDotCirclePainter(
                                                radius: 4,
                                                color: Colors.white,
                                                strokeWidth: 2,
                                                strokeColor: Color(0xFF2563EB),
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
                                                0.9)
                                            .clamp(0, double.infinity),
                                    maxY: graphData.isEmpty ||
                                            graphData.every((e) => e.y == 0)
                                        ? 1000
                                        : (graphData.map((e) => e.y).reduce(
                                                    (a, b) => a > b ? a : b) *
                                                1.2)
                                            .clamp(100, double.infinity),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Tabs
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: Color(0xFF2563EB),
                          labelColor: Color(0xFF2563EB),
                          unselectedLabelColor: Colors.grey,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          tabs: [
                            Tab(text: 'Spendings'),
                            Tab(text: 'Income'),
                          ],
                        ),
                      ),
                    ),

                    // Spending Pattern Insights (only for expenses)
                    if (_selectedTab == 'Spendings' && spendings.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child:
                              _buildSpendingPatternInsights(spendings, theme),
                        ),
                      ),

                    // Transaction List
                    SliverFillRemaining(
                      hasScrollBody: true,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTransactionList(spendings, pendingExpenses),
                          _buildTransactionList(income, []),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // Calculate spending pattern insights
  Map<String, dynamic> _getSpendingPatternInsights(List<Transaction> expenses) {
    if (expenses.isEmpty) {
      return {
        'analysis': '',
        'recommendation': '',
        'categoryInsight': '',
      };
    }

    // Group by category
    Map<String, double> categoryTotals = {};
    Map<String, int> categoryCounts = {};
    for (var transaction in expenses) {
      categoryTotals[transaction.category] =
          (categoryTotals[transaction.category] ?? 0) + transaction.amount;
      categoryCounts[transaction.category] =
          (categoryCounts[transaction.category] ?? 0) + 1;
    }

    final totalExpenses = expenses.fold(0.0, (sum, t) => sum + t.amount);
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String analysis = '';
    String recommendation = '';
    String categoryInsight = '';

    // Frequency analysis
    final avgTransactionAmount = totalExpenses / expenses.length;
    final highValueTransactions =
        expenses.where((t) => t.amount > avgTransactionAmount * 2).length;
    final highValuePercent = (highValueTransactions / expenses.length) * 100;

    if (highValuePercent > 30) {
      analysis =
          'You have ${highValueTransactions} high-value transactions (above ${Helpers.formatCurrency(avgTransactionAmount * 2)}) this month, accounting for ${highValuePercent.toStringAsFixed(0)}% of your transactions.';
      recommendation =
          'Review these high-value transactions to ensure they\'re necessary. Consider breaking large purchases into smaller, more manageable payments.';
    } else if (expenses.length > 20) {
      analysis =
          'You have ${expenses.length} expense transactions this month with an average of ${Helpers.formatCurrency(avgTransactionAmount)} per transaction.';
      recommendation =
          'You\'re making many small transactions. Consider consolidating purchases or reviewing subscription services to reduce transaction frequency.';
    } else {
      analysis =
          'You have ${expenses.length} expense transactions this month totaling ${Helpers.formatCurrency(totalExpenses)}.';
      recommendation =
          'Your spending pattern looks manageable. Continue tracking to identify any trends or areas for improvement.';
    }

    // Category insights
    if (sortedCategories.isNotEmpty) {
      final topCategory = sortedCategories.first;
      final topCategoryPercent = (topCategory.value / totalExpenses) * 100;
      final topCategoryCount = categoryCounts[topCategory.key] ?? 0;

      if (topCategoryPercent > 50) {
        categoryInsight =
            '${topCategory.key} dominates your spending at ${topCategoryPercent.toStringAsFixed(1)}% (${topCategoryCount} transactions). This is a significant portion - consider if this aligns with your financial goals.';
      } else if (topCategoryPercent > 30) {
        categoryInsight =
            '${topCategory.key} is your largest spending category at ${topCategoryPercent.toStringAsFixed(1)}% of total expenses. Review if there are opportunities to optimize spending in this area.';
      } else if (sortedCategories.length <= 3) {
        categoryInsight =
            'Your spending is concentrated in ${sortedCategories.length} main categories. This shows focused spending, which can be easier to manage and optimize.';
      }
    }

    // Spending velocity (transactions per day)
    if (expenses.length > 1) {
      final firstDate =
          expenses.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);
      final lastDate =
          expenses.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);
      final daysDiff = lastDate.difference(firstDate).inDays + 1;
      final transactionsPerDay = expenses.length / daysDiff;

      if (transactionsPerDay > 1.5) {
        final velocityInsight =
            'You\'re making ${transactionsPerDay.toStringAsFixed(1)} transactions per day on average.';
        if (analysis.isNotEmpty) {
          analysis += ' $velocityInsight';
        } else {
          analysis = velocityInsight;
        }
      }
    }

    return {
      'analysis': analysis,
      'recommendation': recommendation,
      'categoryInsight': categoryInsight,
    };
  }

  Widget _buildSpendingPatternInsights(
    List<Transaction> expenses,
    ThemeData theme,
  ) {
    final insights = _getSpendingPatternInsights(expenses);

    if (insights['analysis']!.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(bottom: 20),
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
                color: Color(0xFF14B8A6),
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Spending Pattern Analysis',
                style: TextStyle(
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
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
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
                      color: Colors.blue,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Analysis',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  insights['analysis'] as String,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (insights['recommendation']!.isNotEmpty) ...[
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    insights['recommendation'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium?.color,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (insights['categoryInsight']!.isNotEmpty) ...[
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    insights['categoryInsight'] as String,
                    style: TextStyle(
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
  }

  Widget _buildTransactionList(List<Transaction> transactions,
      List<Map<String, dynamic>> pendingTransactions) {
    // Combine actual transactions with pending ones
    final allItems = <Map<String, dynamic>>[];

    // Add actual transactions
    for (var transaction in transactions) {
      allItems.add({
        'transaction': transaction,
        'isPending': false,
        'dueDate': transaction.date,
      });
    }

    // Add pending transactions
    for (var pending in pendingTransactions) {
      allItems.add({
        'transaction': pending['transaction'] as Transaction,
        'isPending': true,
        'dueDate': pending['dueDate'] as DateTime,
      });
    }

    // Sort by date (most recent first, but pending ones by due date)
    allItems.sort((a, b) {
      final dateA = a['dueDate'] as DateTime;
      final dateB = b['dueDate'] as DateTime;
      return dateB.compareTo(dateA);
    });

    if (allItems.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 40),
              Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
              SizedBox(height: 16),
              Text(
                'No ${_selectedTab.toLowerCase()} for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Try selecting a different month or add a transaction',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddTransactionScreen(),
                    ),
                  );
                },
                icon: Icon(Icons.add),
                label: Text('Add Transaction'),
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

    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: allItems.length,
      physics: AlwaysScrollableScrollPhysics(),
      shrinkWrap: false,
      itemBuilder: (context, index) {
        final item = allItems[index];
        final transaction = item['transaction'] as Transaction;
        final isPending = item['isPending'] as bool;
        final dueDate = item['dueDate'] as DateTime;

        return _ModernTransactionCard(
          transaction: transaction,
          isPending: isPending,
          dueDate: isPending ? dueDate : null,
          onEdit: isPending ? null : () => _editTransaction(transaction),
          onDelete: isPending ? null : () => _deleteTransaction(transaction),
        );
      },
    );
  }
}

class _ModernTransactionCard extends StatelessWidget {
  final Transaction transaction;
  final bool isPending;
  final DateTime? dueDate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ModernTransactionCard({
    required this.transaction,
    this.isPending = false,
    this.dueDate,
    this.onEdit,
    this.onDelete,
  });

  IconData _getCategoryIcon(String category) {
    // Map categories to Material icons
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon with category color
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

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description.isNotEmpty
                      ? transaction.description
                      : transaction.category,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      isPending && dueDate != null
                          ? 'Due ${Helpers.formatDateRelative(dueDate!)}'
                          : Helpers.formatDateRelative(transaction.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.7) ??
                            Colors.grey[600],
                      ),
                    ),
                    if (isPending) ...[
                      SizedBox(width: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: Colors.orange,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Pending',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (transaction.isRecurring ||
                        transaction.isSubscription) ...[
                      SizedBox(width: 8),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                              transaction.isSubscription
                                  ? 'Subscription'
                                  : 'Recurring',
                              style: TextStyle(
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
              ],
            ),
          ),

          // Amount and Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}${Helpers.formatCurrency(transaction.amount)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isPending
                      ? Colors.orange
                      : (isIncome ? Colors.green : Colors.red),
                  decoration: isPending ? TextDecoration.none : null,
                  decorationStyle: isPending ? null : null,
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: onEdit,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.edit, size: 16, color: Colors.blue),
                    ),
                  ),
                  SizedBox(width: 8),
                  InkWell(
                    onTap: onDelete,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.delete, size: 16, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
