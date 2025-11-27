import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/utils/helpers.dart';
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

  @override
  void initState() {
    super.initState();
    transactionsBox = Hive.box<Transaction>('transactionsBox');
  }

  List<Transaction> _getTransactionsForDateRange() {
    return transactionsBox.values.where((transaction) {
      return transaction.date.isAfter(_selectedStartDate.subtract(Duration(days: 1))) &&
          transaction.date.isBefore(_selectedEndDate.add(Duration(days: 1)));
    }).toList();
  }

  double _getTotalIncome() {
    final transactions = _getTransactionsForDateRange();
    return transactions
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double _getTotalExpenses() {
    final transactions = _getTransactionsForDateRange();
    return transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  List<PieChartSectionData> _getPieChartData() {
    final income = _getTotalIncome();
    final expenses = _getTotalExpenses();
    final total = income + expenses;

    if (total == 0) {
      return [
        PieChartSectionData(
          value: 1,
          title: 'No Data',
          color: Colors.grey,
          radius: 50,
        ),
      ];
    }

    return [
      PieChartSectionData(
        value: income,
        title: '${((income / total) * 100).toStringAsFixed(1)}%',
        color: Colors.green,
        radius: 80,
        titleStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      PieChartSectionData(
        value: expenses,
        title: '${((expenses / total) * 100).toStringAsFixed(1)}%',
        color: Colors.red,
        radius: 80,
        titleStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ];
  }

  List<FlSpot> _getIncomeLineData() {
    final transactions = _getTransactionsForDateRange();
    final incomeTransactions = transactions
        .where((t) => t.type == 'income')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    Map<String, double> dailyIncome = {};
    for (var transaction in incomeTransactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      dailyIncome[dateKey] = (dailyIncome[dateKey] ?? 0) + transaction.amount;
    }

    final sortedDates = dailyIncome.keys.toList()..sort();
    List<FlSpot> spots = [];
    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailyIncome[sortedDates[i]]!));
    }

    if (spots.isEmpty) {
      spots.add(FlSpot(0, 0));
    }

    return spots;
  }

  List<FlSpot> _getExpensesLineData() {
    final transactions = _getTransactionsForDateRange();
    final expenseTransactions = transactions
        .where((t) => t.type == 'expense')
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    Map<String, double> dailyExpenses = {};
    for (var transaction in expenseTransactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(transaction.date);
      dailyExpenses[dateKey] = (dailyExpenses[dateKey] ?? 0) + transaction.amount;
    }

    final sortedDates = dailyExpenses.keys.toList()..sort();
    List<FlSpot> spots = [];
    for (int i = 0; i < sortedDates.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailyExpenses[sortedDates[i]]!));
    }

    if (spots.isEmpty) {
      spots.add(FlSpot(0, 0));
    }

    return spots;
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Statistics',
          style: TextStyle(
            color: theme.textTheme.titleLarge?.color ?? Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<Box<Transaction>>(
          valueListenable: transactionsBox.listenable(),
          builder: (context, box, _) {
            final income = _getTotalIncome();
            final expenses = _getTotalExpenses();
            final incomeData = _getIncomeLineData();
            final expensesData = _getExpensesLineData();
            final pieData = _getPieChartData();

            return SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Selector
                  InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date Range',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '${DateFormat('MMM d').format(_selectedStartDate)} - ${DateFormat('MMM d, yyyy').format(_selectedEndDate)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Icon(Icons.calendar_today, color: theme.iconTheme.color?.withOpacity(0.7) ?? Colors.grey[600]),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
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
                                'Total Income',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                Helpers.formatCurrency(income),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
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
                                'Total Expenses',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                Helpers.formatCurrency(expenses),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),

                  // Pie Chart
                  Container(
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
                          'Income vs Expenses',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                          ),
                        ),
                        SizedBox(height: 20),
                        SizedBox(
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: pieData,
                              centerSpaceRadius: 40,
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem('Income', Colors.green),
                            SizedBox(width: 24),
                            _buildLegendItem('Expenses', Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Income Line Graph
                  Container(
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
                          'Income Trend',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                          ),
                        ),
                        SizedBox(height: 20),
                        SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: theme.brightness == Brightness.dark 
                                        ? Colors.grey[700]! 
                                        : Colors.grey[300]!,
                                    strokeWidth: 1,
                                  );
                                },
                              ),
                              titlesData: FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: incomeData,
                                  isCurved: true,
                                  color: Colors.green,
                                  barWidth: 3,
                                  dotData: FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.green.withOpacity(0.1),
                                  ),
                                ),
                              ],
                              minY: 0,
                              maxY: incomeData.isEmpty
                                  ? 1000
                                  : incomeData.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Expenses Line Graph
                  Container(
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
                          'Expenses Trend',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                          ),
                        ),
                        SizedBox(height: 20),
                        SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: theme.brightness == Brightness.dark 
                                        ? Colors.grey[700]! 
                                        : Colors.grey[300]!,
                                    strokeWidth: 1,
                                  );
                                },
                              ),
                              titlesData: FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: expensesData,
                                  isCurved: true,
                                  color: Colors.red,
                                  barWidth: 3,
                                  dotData: FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: Colors.red.withOpacity(0.1),
                                  ),
                                ),
                              ],
                              minY: 0,
                              maxY: expensesData.isEmpty
                                  ? 1000
                                  : expensesData.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
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
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

