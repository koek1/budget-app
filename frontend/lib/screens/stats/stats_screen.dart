import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:budget_app/utils/helpers.dart';
import 'package:budget_app/utils/constants.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  _StatsScreenState createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Box<Transaction> transactionsBox;
  DateTime _selectedStartDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _selectedEndDate = DateTime.now();
  String _selectedTimeFrame = 'Last 30 Days';

  @override
  void initState() {
    super.initState();
    transactionsBox = Hive.box<Transaction>('transactionsBox');
  }

  // Get user-filtered transactions for date range
  Future<List<Transaction>> _getTransactionsForDateRange() async {
    final allTransactions = await LocalStorageService.getTransactions();
    final startOfDay = DateTime(
      _selectedStartDate.year,
      _selectedStartDate.month,
      _selectedStartDate.day,
    );
    final endOfDay = DateTime(
      _selectedEndDate.year,
      _selectedEndDate.month,
      _selectedEndDate.day,
      23,
      59,
      59,
    );

    return allTransactions.where((transaction) {
      final transactionDate = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      return !transactionDate.isBefore(startOfDay) &&
          !transactionDate.isAfter(endOfDay);
    }).toList();
  }

  // Calculate total income (verified accurate)
  Future<double> _getTotalIncome() async {
    final transactions = await _getTransactionsForDateRange();
    return transactions
        .where((t) => t.type == 'income')
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  // Calculate total expenses (verified accurate)
  Future<double> _getTotalExpenses() async {
    final transactions = await _getTransactionsForDateRange();
    return transactions
        .where((t) => t.type == 'expense')
        .fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  // Get dual line graph data (income and expenses over time)
  Future<Map<String, List<FlSpot>>> _getDualLineData() async {
    final transactions = await _getTransactionsForDateRange();
    
    // Separate income and expenses
    final incomeTransactions = transactions
        .where((t) => t.type == 'income')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final expenseTransactions = transactions
        .where((t) => t.type == 'expense')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // Group by day for income
    Map<String, double> dailyIncome = {};
    for (var transaction in incomeTransactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      dailyIncome[dateKey] = (dailyIncome[dateKey] ?? 0) + transaction.amount;
    }

    // Group by day for expenses
    Map<String, double> dailyExpenses = {};
    for (var transaction in expenseTransactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      dailyExpenses[dateKey] = (dailyExpenses[dateKey] ?? 0) + transaction.amount;
    }

    // Get all unique dates and sort
    final allDates = <String>{};
    allDates.addAll(dailyIncome.keys);
    allDates.addAll(dailyExpenses.keys);
    final sortedDates = allDates.toList()..sort();

    if (sortedDates.isEmpty) {
      return {
        'income': [FlSpot(0, 0), FlSpot(1, 0)],
        'expenses': [FlSpot(0, 0), FlSpot(1, 0)],
        'dates': [],
      };
    }

    // Create spots for income (cumulative)
    List<FlSpot> incomeSpots = [];
    double cumulativeIncome = 0;
    for (int i = 0; i < sortedDates.length; i++) {
      cumulativeIncome += dailyIncome[sortedDates[i]] ?? 0;
      incomeSpots.add(FlSpot(i.toDouble(), cumulativeIncome));
    }

    // Create spots for expenses (cumulative)
    List<FlSpot> expenseSpots = [];
    double cumulativeExpenses = 0;
    for (int i = 0; i < sortedDates.length; i++) {
      cumulativeExpenses += dailyExpenses[sortedDates[i]] ?? 0;
      expenseSpots.add(FlSpot(i.toDouble(), cumulativeExpenses));
    }

    // Ensure at least 2 points
    if (incomeSpots.length == 1) {
      incomeSpots.add(FlSpot(incomeSpots[0].x + 1, incomeSpots[0].y));
    }
    if (expenseSpots.length == 1) {
      expenseSpots.add(FlSpot(expenseSpots[0].x + 1, expenseSpots[0].y));
    }

    return {
      'income': incomeSpots,
      'expenses': expenseSpots,
    };
  }

  // Get pie chart data for income vs expenses
  Future<List<PieChartSectionData>> _getIncomeExpensePieData() async {
    final income = await _getTotalIncome();
    final expenses = await _getTotalExpenses();
    final total = income + expenses;

    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          title: 'No Data',
          color: Colors.grey,
          radius: 60,
          titleStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ];
    }

    final incomePercent = (income / total) * 100;
    final expensePercent = (expenses / total) * 100;

    return [
      PieChartSectionData(
        value: income,
        title: income > 0 ? '${incomePercent.toStringAsFixed(1)}%' : '',
        color: Colors.green,
        radius: 70,
        titleStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: expenses,
        title: expenses > 0 ? '${expensePercent.toStringAsFixed(1)}%' : '',
        color: Colors.red,
        radius: 70,
        titleStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  // Get category breakdown pie chart data
  Future<List<PieChartSectionData>> _getCategoryBreakdownPieData() async {
    final transactions = await _getTransactionsForDateRange();
    final expenseTransactions = transactions.where((t) => t.type == 'expense').toList();

    if (expenseTransactions.isEmpty) {
      return [
        PieChartSectionData(
          value: 1,
          title: 'No Data',
          color: Colors.grey,
          radius: 60,
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ];
    }

    // Group by category
    Map<String, double> categoryTotals = {};
    for (var transaction in expenseTransactions) {
      categoryTotals[transaction.category] =
          (categoryTotals[transaction.category] ?? 0) + transaction.amount;
    }

    // Calculate total expenses
    final totalExpenses = expenseTransactions.fold(0.0, (sum, t) => sum + t.amount);

    if (totalExpenses == 0) {
      return [
        PieChartSectionData(
          value: 1,
          title: 'No Data',
          color: Colors.grey,
          radius: 60,
        ),
      ];
    }

    // Sort by amount (descending) and take top categories
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Create pie chart sections
    List<PieChartSectionData> sections = [];
    final colors = [
      Colors.orange,
      Colors.pink,
      Colors.purple,
      Colors.red,
      Colors.green,
      Colors.teal,
      Colors.cyan,
      Colors.blue,
      Colors.amber,
      Colors.indigo,
    ];

    for (int i = 0; i < sortedCategories.length && i < 10; i++) {
      final entry = sortedCategories[i];
      final percentage = (entry.value / totalExpenses) * 100;
      final color = AppConstants.categoryColors[entry.key] ??
          colors[i % colors.length];

      sections.add(PieChartSectionData(
        value: entry.value,
        title: percentage >= 5
            ? '${percentage.toStringAsFixed(0)}%'
            : '', // Only show percentage if >= 5%
        color: color,
        radius: 65,
        titleStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    return sections;
  }

  // Get category breakdown map for legend
  Future<Map<String, double>> _getCategoryBreakdown() async {
    final transactions = await _getTransactionsForDateRange();
    final expenseTransactions = transactions.where((t) => t.type == 'expense').toList();

    Map<String, double> categoryTotals = {};
    for (var transaction in expenseTransactions) {
      categoryTotals[transaction.category] =
          (categoryTotals[transaction.category] ?? 0) + transaction.amount;
    }

    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sorted);
  }

  // Get this month's biggest expense categories for bar chart
  Future<List<BarChartGroupData>> _getMonthlyExpenseBarData() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final allTransactions = await LocalStorageService.getTransactions();
    final monthTransactions = allTransactions.where((t) {
      return t.type == 'expense' &&
          !t.date.isBefore(monthStart) &&
          !t.date.isAfter(monthEnd);
    }).toList();

    if (monthTransactions.isEmpty) {
      return [
        BarChartGroupData(
          x: 0,
          barRods: [
            BarChartRodData(
              toY: 0,
              color: Colors.grey,
            ),
          ],
        ),
      ];
    }

    // Group by category
    Map<String, double> categoryTotals = {};
    for (var transaction in monthTransactions) {
      categoryTotals[transaction.category] =
          (categoryTotals[transaction.category] ?? 0) + transaction.amount;
    }

    // Sort and take top 5
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();

    List<BarChartGroupData> barGroups = [];
    final colors = [
      Colors.orange,
      Colors.pink,
      Colors.purple,
      Colors.red,
      Colors.green,
    ];

    for (int i = 0; i < top5.length; i++) {
      final entry = top5[i];
      final color = AppConstants.categoryColors[entry.key] ??
          colors[i % colors.length];

      barGroups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: color,
            width: 20,
            borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ));
    }

    return barGroups;
  }

  // Get category names for bar chart
  Future<List<String>> _getMonthlyExpenseCategories() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final allTransactions = await LocalStorageService.getTransactions();
    final monthTransactions = allTransactions.where((t) {
      return t.type == 'expense' &&
          !t.date.isBefore(monthStart) &&
          !t.date.isAfter(monthEnd);
    }).toList();

    Map<String, double> categoryTotals = {};
    for (var transaction in monthTransactions) {
      categoryTotals[transaction.category] =
          (categoryTotals[transaction.category] ?? 0) + transaction.amount;
    }

    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(5).map((e) => e.key).toList();
  }

  // Get income trend data
  Future<List<FlSpot>> _getIncomeTrendData() async {
    final transactions = await _getTransactionsForDateRange();
    final incomeTransactions = transactions
        .where((t) => t.type == 'income')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (incomeTransactions.isEmpty) {
      return [FlSpot(0, 0), FlSpot(1, 0)];
    }

    Map<String, double> dailyIncome = {};
    for (var transaction in incomeTransactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      dailyIncome[dateKey] = (dailyIncome[dateKey] ?? 0) + transaction.amount;
    }

    final sortedDates = dailyIncome.keys.toList()..sort();
    List<FlSpot> spots = [];
    double cumulativeTotal = 0;

    for (int i = 0; i < sortedDates.length; i++) {
      cumulativeTotal += dailyIncome[sortedDates[i]]!;
      spots.add(FlSpot(i.toDouble(), cumulativeTotal));
    }

    if (spots.length == 1) {
      spots.add(FlSpot(spots[0].x + 1, spots[0].y));
    }

    return spots;
  }

  // Get expense trend data
  Future<List<FlSpot>> _getExpenseTrendData() async {
    final transactions = await _getTransactionsForDateRange();
    final expenseTransactions = transactions
        .where((t) => t.type == 'expense')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (expenseTransactions.isEmpty) {
      return [FlSpot(0, 0), FlSpot(1, 0)];
    }

    Map<String, double> dailyExpenses = {};
    for (var transaction in expenseTransactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      dailyExpenses[dateKey] = (dailyExpenses[dateKey] ?? 0) + transaction.amount;
    }

    final sortedDates = dailyExpenses.keys.toList()..sort();
    List<FlSpot> spots = [];
    double cumulativeTotal = 0;

    for (int i = 0; i < sortedDates.length; i++) {
      cumulativeTotal += dailyExpenses[sortedDates[i]]!;
      spots.add(FlSpot(i.toDouble(), cumulativeTotal));
    }

    if (spots.length == 1) {
      spots.add(FlSpot(spots[0].x + 1, spots[0].y));
    }

    return spots;
  }

  // Calculate cash flow analysis
  Future<Map<String, dynamic>> _getCashFlowAnalysis() async {
    final income = await _getTotalIncome();
    final expenses = await _getTotalExpenses();
    final netCashFlow = income - expenses;
    final savingsRate = income > 0 ? (netCashFlow / income) * 100 : 0.0;

    String analysis = '';
    String recommendation = '';

    if (netCashFlow > 0) {
      analysis = 'You have a positive cash flow of ${Helpers.formatCurrency(netCashFlow.abs())}.';
      if (savingsRate >= 20) {
        recommendation =
            'Excellent! You\'re saving ${savingsRate.toStringAsFixed(1)}% of your income. Keep up the great work!';
      } else if (savingsRate >= 10) {
        recommendation =
            'Good! You\'re saving ${savingsRate.toStringAsFixed(1)}% of your income. Consider increasing your savings rate.';
      } else {
        recommendation =
            'You\'re saving ${savingsRate.toStringAsFixed(1)}% of your income. Try to increase this to at least 20%.';
      }
    } else if (netCashFlow < 0) {
      analysis =
          'You have a negative cash flow of ${Helpers.formatCurrency(netCashFlow.abs())}.';
      recommendation =
          'Your expenses exceed your income. Consider reducing expenses or increasing income to achieve a positive cash flow.';
    } else {
      analysis = 'Your income and expenses are balanced.';
      recommendation =
          'You\'re breaking even. Consider saving a portion of your income for future goals.';
    }

    return {
      'netCashFlow': netCashFlow,
      'savingsRate': savingsRate,
      'analysis': analysis,
      'recommendation': recommendation,
    };
  }

  Future<void> _selectTimeFrame() async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<String>(
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
                'Select Time Frame',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ),
            SizedBox(height: 20),
            ...['Last 7 Days', 'Last 30 Days', 'Last 3 Months', 'Last 6 Months', 'Last Year', 'Custom']
                .map((frame) => ListTile(
                      title: Text(
                        frame,
                        style: GoogleFonts.inter(
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: _selectedTimeFrame == frame
                          ? Icon(Icons.check, color: Color(0xFF14B8A6))
                          : null,
                      onTap: () {
                        Navigator.pop(context, frame);
                      },
                    )),
            SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedTimeFrame = result;
        final now = DateTime.now();
        switch (result) {
          case 'Last 7 Days':
            _selectedStartDate = now.subtract(Duration(days: 7));
            _selectedEndDate = now;
            break;
          case 'Last 30 Days':
            _selectedStartDate = now.subtract(Duration(days: 30));
            _selectedEndDate = now;
            break;
          case 'Last 3 Months':
            _selectedStartDate = DateTime(now.year, now.month - 3, now.day);
            _selectedEndDate = now;
            break;
          case 'Last 6 Months':
            _selectedStartDate = DateTime(now.year, now.month - 6, now.day);
            _selectedEndDate = now;
            break;
          case 'Last Year':
            _selectedStartDate = DateTime(now.year - 1, now.month, now.day);
            _selectedEndDate = now;
            break;
          case 'Custom':
            _selectDateRange();
            break;
        }
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _selectedStartDate,
        end: _selectedEndDate,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedStartDate = picked.start;
        _selectedEndDate = picked.end;
        _selectedTimeFrame = 'Custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Statistics',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<Box<Transaction>>(
          valueListenable: transactionsBox.listenable(),
          builder: (context, box, _) {
            return FutureBuilder<List<Transaction>>(
              future: _getTransactionsForDateRange(),
              builder: (context, snapshot) {
                return SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time Frame Selector
                      _buildTimeFrameSelector(theme),
                      SizedBox(height: 20),

                      // Dual Line Graph (Income + Expenses)
                      FutureBuilder<Map<String, List<FlSpot>>>(
                        future: _getDualLineData(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return _buildLoadingCard(theme);
                          }
                          return _buildDualLineChart(
                            snapshot.data!,
                            theme,
                            isDark,
                          );
                        },
                      ),
                      SizedBox(height: 20),

                      // Income vs Expenses Pie Chart
                      FutureBuilder<List<PieChartSectionData>>(
                        future: _getIncomeExpensePieData(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return _buildLoadingCard(theme);
                          }
                          return _buildIncomeExpensePieChart(
                            snapshot.data!,
                            theme,
                          );
                        },
                      ),
                      SizedBox(height: 20),

                      // Category Breakdown Pie Chart
                      FutureBuilder<List<PieChartSectionData>>(
                        future: _getCategoryBreakdownPieData(),
                        builder: (context, pieSnapshot) {
                          return FutureBuilder<Map<String, double>>(
                            future: _getCategoryBreakdown(),
                            builder: (context, catSnapshot) {
                              if (!pieSnapshot.hasData || !catSnapshot.hasData) {
                                return _buildLoadingCard(theme);
                              }
                              return Column(
                                children: [
                                  _buildCategoryBreakdownPieChart(
                                    pieSnapshot.data!,
                                    theme,
                                  ),
                                  SizedBox(height: 20),
                                  _buildCategoryInsights(
                                    catSnapshot.data!,
                                    theme,
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      SizedBox(height: 20),

                      // Monthly Expense Bar Chart
                      FutureBuilder<List<BarChartGroupData>>(
                        future: _getMonthlyExpenseBarData(),
                        builder: (context, barSnapshot) {
                          return FutureBuilder<List<String>>(
                            future: _getMonthlyExpenseCategories(),
                            builder: (context, catSnapshot) {
                              if (!barSnapshot.hasData || !catSnapshot.hasData) {
                                return _buildLoadingCard(theme);
                              }
                              return _buildMonthlyExpenseBarChart(
                                barSnapshot.data!,
                                catSnapshot.data!,
                                theme,
                                isDark,
                              );
                            },
                          );
                        },
                      ),
                      SizedBox(height: 20),

                      // Income Trend
                      FutureBuilder<List<FlSpot>>(
                        future: _getIncomeTrendData(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return _buildLoadingCard(theme);
                          }
                          return _buildTrendChart(
                            'Income Trend',
                            snapshot.data!,
                            Colors.green,
                            theme,
                            isDark,
                          );
                        },
                      ),
                      SizedBox(height: 20),

                      // Expense Trend
                      FutureBuilder<List<FlSpot>>(
                        future: _getExpenseTrendData(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return _buildLoadingCard(theme);
                          }
                          return _buildTrendChart(
                            'Expense Trend',
                            snapshot.data!,
                            Colors.red,
                            theme,
                            isDark,
                          );
                        },
                      ),
                      SizedBox(height: 20),

                      // Cash Flow Analysis
                      FutureBuilder<Map<String, dynamic>>(
                        future: _getCashFlowAnalysis(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return _buildLoadingCard(theme);
                          }
                          return _buildCashFlowAnalysis(
                            snapshot.data!,
                            theme,
                          );
                        },
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimeFrameSelector(ThemeData theme) {
    return InkWell(
      onTap: _selectTimeFrame,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: Color(0xFF14B8A6),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time Frame',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _selectedTimeFrame,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDualLineChart(
    Map<String, List<FlSpot>> data,
    ThemeData theme,
    bool isDark,
  ) {
    final incomeSpots = data['income']!;
    final expenseSpots = data['expenses']!;
    final maxY = [
          ...incomeSpots.map((e) => e.y),
          ...expenseSpots.map((e) => e.y),
        ].reduce((a, b) => a > b ? a : b) *
        1.2;

    return _buildChartCard(
      theme,
      'Income vs Expenses',
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
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
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 70,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text(
                        Helpers.formatCurrency(value),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: incomeSpots,
                isCurved: true,
                color: Colors.green,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.green.withOpacity(0.1),
                ),
              ),
              LineChartBarData(
                spots: expenseSpots,
                isCurved: true,
                color: Colors.red,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.red.withOpacity(0.1),
                ),
              ),
            ],
            minY: 0,
            maxY: maxY > 0 ? maxY : 1000,
          ),
        ),
      ),
      legend: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('Income', Colors.green, theme),
          SizedBox(width: 24),
          _buildLegendItem('Expenses', Colors.red, theme),
        ],
      ),
    );
  }

  Widget _buildIncomeExpensePieChart(
    List<PieChartSectionData> data,
    ThemeData theme,
  ) {
    return FutureBuilder<double>(
      future: _getTotalIncome(),
      builder: (context, incomeSnapshot) {
        return FutureBuilder<double>(
          future: _getTotalExpenses(),
          builder: (context, expenseSnapshot) {
            if (!incomeSnapshot.hasData || !expenseSnapshot.hasData) {
              return _buildLoadingCard(theme);
            }

            return _buildChartCard(
              theme,
              'Income vs Expenses',
              child: Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: data,
                        centerSpaceRadius: 50,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            'Income',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            Helpers.formatCurrency(incomeSnapshot.data!),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'Expenses',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            Helpers.formatCurrency(expenseSnapshot.data!),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryBreakdownPieChart(
    List<PieChartSectionData> data,
    ThemeData theme,
  ) {
    return FutureBuilder<Map<String, double>>(
      future: _getCategoryBreakdown(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildLoadingCard(theme);
        }

        final categories = snapshot.data!;
        final sortedCategories = categories.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return _buildChartCard(
          theme,
          'Expense Breakdown by Category',
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: data,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),
              SizedBox(height: 20),
              ...sortedCategories.take(5).map((entry) {
                final percentage = categories.values.fold(0.0, (a, b) => a + b) > 0
                    ? (entry.value / categories.values.fold(0.0, (a, b) => a + b)) * 100
                    : 0.0;
                final color = AppConstants.categoryColors[entry.key] ?? Colors.grey;

                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthlyExpenseBarChart(
    List<BarChartGroupData> barGroups,
    List<String> categories,
    ThemeData theme,
    bool isDark,
  ) {
    if (barGroups.isEmpty || categories.isEmpty) {
      return _buildChartCard(
        theme,
        'This Month\'s Biggest Expenses',
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Text(
              'No expense data for this month',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
          ),
        ),
      );
    }

    final maxY = barGroups
            .map((g) => g.barRods.first.toY)
            .reduce((a, b) => a > b ? a : b) *
        1.2;

    return _buildChartCard(
      theme,
      'This Month\'s Biggest Expenses',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
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
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= categories.length) return Text('');
                        final category = categories[value.toInt()];
                        return Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            category.length > 10
                                ? category.substring(0, 10) + '...'
                                : category,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 70,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text(
                            Helpers.formatCurrency(value),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                            ),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
                maxY: maxY > 0 ? maxY : 1000,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(
    String title,
    List<FlSpot> spots,
    Color color,
    ThemeData theme,
    bool isDark,
  ) {
    final maxY = spots.isEmpty || spots.every((e) => e.y == 0)
        ? 1000
        : (spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2);

    return _buildChartCard(
      theme,
      title,
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
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
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 70,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text(
                        Helpers.formatCurrency(value),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withOpacity(0.1),
                ),
              ),
            ],
            minY: 0,
            maxY: maxY.toDouble(),
          ),
        ),
      ),
    );
  }

  Widget _buildCashFlowAnalysis(
    Map<String, dynamic> data,
    ThemeData theme,
  ) {
    final netCashFlow = data['netCashFlow'] as double;
    final savingsRate = data['savingsRate'] as double;
    final analysis = data['analysis'] as String;
    final recommendation = data['recommendation'] as String;

    return _buildChartCard(
      theme,
      'Cash Flow Analysis',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net Cash Flow',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      Helpers.formatCurrency(netCashFlow.abs()),
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: netCashFlow >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: netCashFlow >= 0
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${savingsRate >= 0 ? '+' : ''}${savingsRate.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: netCashFlow >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      color: Color(0xFF14B8A6),
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
              color: theme.brightness == Brightness.dark
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
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
        ],
      ),
    );
  }

  Widget _buildChartCard(
    ThemeData theme,
    String title, {
    required Widget child,
    Widget? legend,
  }) {
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
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 24),
          child,
          if (legend != null) ...[
            SizedBox(height: 20),
            legend,
          ],
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // Get category insights
  Map<String, dynamic> _getCategoryInsights(Map<String, double> categories) {
    if (categories.isEmpty) {
      return {
        'analysis': '',
        'recommendation': '',
      };
    }

    final sorted = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = categories.values.fold(0.0, (a, b) => a + b);

    String analysis = '';
    String recommendation = '';

    if (sorted.length >= 3) {
      final top3Total = sorted.take(3).fold(0.0, (sum, e) => sum + e.value);
      final top3Percent = (top3Total / total) * 100;

      if (top3Percent > 80) {
        analysis =
            'Your top 3 categories (${sorted[0].key}, ${sorted[1].key}, ${sorted[2].key}) account for ${top3Percent.toStringAsFixed(1)}% of your expenses.';
        recommendation =
            'Your spending is highly concentrated. Consider diversifying your expenses or reviewing if these categories align with your financial priorities.';
      } else if (top3Percent > 60) {
        analysis =
            'Your top 3 expense categories account for ${top3Percent.toStringAsFixed(1)}% of total spending.';
        recommendation =
            'You have a balanced spending distribution. Continue monitoring these categories to maintain financial health.';
      }
    }

    // Check for dominant category
    if (sorted.isNotEmpty) {
      final topCategory = sorted.first;
      final topPercent = (topCategory.value / total) * 100;

      if (topPercent > 50 && analysis.isEmpty) {
        analysis =
            '${topCategory.key} dominates your spending at ${topPercent.toStringAsFixed(1)}% of total expenses.';
        recommendation =
            'This category takes up more than half of your expenses. Review if this is sustainable and aligns with your financial goals.';
      }
    }

    // Check for many small categories
    if (sorted.length > 8) {
      final smallCategories = sorted.where((e) => (e.value / total) * 100 < 5).length;
      if (smallCategories > 5 && analysis.isEmpty) {
        analysis =
            'You have ${sorted.length} different expense categories, with ${smallCategories} categories each accounting for less than 5% of spending.';
        recommendation =
            'Consider consolidating similar small categories to get a clearer picture of your spending patterns.';
      }
    }

    return {
      'analysis': analysis,
      'recommendation': recommendation,
    };
  }

  Widget _buildCategoryInsights(
    Map<String, double> categories,
    ThemeData theme,
  ) {
    final insights = _getCategoryInsights(categories);

    if (insights['analysis']!.isEmpty) {
      return SizedBox.shrink();
    }

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
                color: Color(0xFF14B8A6),
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Category Insights',
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
                  insights['analysis'] as String,
                  style: GoogleFonts.inter(
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
                    insights['recommendation'] as String,
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
  }

  Widget _buildLoadingCard(ThemeData theme) {
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
}
