import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
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

  List<Transaction> _getTransactionsForMonth() {
    // Get all transactions and filter by month
    final allTransactions = transactionsBox.values.toList();
    
    if (allTransactions.isEmpty) {
      return [];
    }
    
    return allTransactions.where((transaction) {
      final transactionDate = transaction.date;
      // Normalize dates to compare only year and month (ignore time)
      final transactionYearMonth = DateTime(transactionDate.year, transactionDate.month);
      final selectedYearMonth = DateTime(_selectedMonth.year, _selectedMonth.month);
      return transactionYearMonth == selectedYearMonth;
    }).toList();
  }

  double getMonthlyIncome() {
    final transactions = _getTransactionsForMonth();
    return transactions
        .where((transaction) => transaction.type == 'income')
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double getMonthlyExpenses() {
    final transactions = _getTransactionsForMonth();
    return transactions
        .where((transaction) => transaction.type == 'expense')
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double getMonthlyBalance() {
    return getMonthlyIncome() - getMonthlyExpenses();
  }

  double getSavings() {
    // Calculate savings as total income minus expenses
    final totalIncome = transactionsBox.values
        .where((transaction) => transaction.type == 'income')
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
    final totalExpenses = transactionsBox.values
        .where((transaction) => transaction.type == 'expense')
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
    return totalIncome - totalExpenses;
  }

  List<FlSpot> _getGraphData() {
    final transactions = _getTransactionsForMonth();
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    
    // Get all transactions up to the selected month to calculate starting balance
    final allTransactions = transactionsBox.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    // Calculate starting balance (all transactions before this month)
    double startingBalance = 0;
    for (var transaction in allTransactions) {
      if (transaction.date.year < _selectedMonth.year ||
          (transaction.date.year == _selectedMonth.year && transaction.date.month < _selectedMonth.month)) {
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
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<Box<Transaction>>(
          valueListenable: transactionsBox.listenable(),
          builder: (context, box, _) {
            final monthlyIncome = getMonthlyIncome();
            final monthlyExpenses = getMonthlyExpenses();
            final monthlyBalance = getMonthlyBalance();
            final savings = getSavings();
            final graphData = _getGraphData();

            return CustomScrollView(
              slivers: [
                // Header with time, menu, title, and profile
                SliverAppBar(
                  backgroundColor: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
                  elevation: 0,
                  leading: Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: IconButton(
                      icon: Icon(Icons.menu, color: theme.iconTheme.color, size: 24),
                      onPressed: widget.onMenuTap,
                    ),
                  ),
                  centerTitle: true,
                  title: Text(
                    'Panel',
                    style: TextStyle(
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
                              backgroundColor: Color(0xFF2563EB).withOpacity(0.1),
                              child: Icon(Icons.person, color: Color(0xFF2563EB), size: 20),
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
                                  border: Border.all(color: Colors.white, width: 2),
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
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 24),

                        // Combined Saving Card with Graph
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Color(0xFF14B8A6), // Teal color
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF14B8A6).withOpacity(0.3),
                                blurRadius: 15,
                                offset: Offset(0, 5),
                              ),
                            ],
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
                                    style: TextStyle(
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
                                Helpers.formatCurrency(savings > 0 ? savings : 0),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
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
                                      _selectedMonth = DateTime(picked.year, picked.month);
                                    });
                                  }
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('MMMM yyyy').format(_selectedMonth),
                                      style: TextStyle(
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
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      topTitles: AxisTitles(
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          interval: 5,
                                          getTitlesWidget: (value, meta) {
                                            final day = value.toInt();
                                            if ([1, 5, 10, 15, 20, 25, 30].contains(day)) {
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
                                        sideTitles: SideTitles(showTitles: false),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    lineTouchData: LineTouchData(
                                      touchTooltipData: LineTouchTooltipData(
                                        tooltipRoundedRadius: 8,
                                        tooltipPadding: EdgeInsets.all(8),
                                        tooltipBgColor: Colors.white.withOpacity(0.9),
                                        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                                          return touchedBarSpots.map((barSpot) {
                                            final day = barSpot.x.toInt();
                                            final monthName = DateFormat('MMM').format(_selectedMonth);
                                            // Use the actual graph value (barSpot.y) which is the balance at that point
                                            final graphValue = barSpot.y;
                                            final amountStr = Helpers.formatCurrency(graphValue);
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
                                          getDotPainter: (spot, percent, barData, index) {
                                            if (index == graphData.length - 1 || 
                                                [1, 5, 10, 15, 20, 25, 30].contains(spot.x.toInt())) {
                                              return FlDotCirclePainter(
                                                radius: 4,
                                                color: Colors.white,
                                                strokeWidth: 2,
                                                strokeColor: Color(0xFF14B8A6),
                                              );
                                            }
                                            return FlDotCirclePainter(radius: 0);
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
                                        : (graphData.map((e) => e.y).reduce((a, b) => a < b ? a : b) * 0.95).clamp(0, double.infinity),
                                    maxY: graphData.isEmpty || graphData.every((e) => e.y == 0)
                                        ? 1000
                                        : (graphData.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.1).clamp(100, double.infinity),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),

                        // Monthly Stats Cards
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
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
                                      'Total balance',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      Helpers.formatCurrency(monthlyBalance),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                                      ),
                                    ),
                                  ],
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
                                padding: EdgeInsets.all(20),
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
                                    Row(
                                      children: [
                                        Icon(Icons.arrow_upward, color: Colors.green, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Income',
                                          style: TextStyle(
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
                                padding: EdgeInsets.all(20),
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
                                    Row(
                                      children: [
                                        Icon(Icons.arrow_downward, color: Colors.red, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Expenses',
                                          style: TextStyle(
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
                        
                        // Monthly Transactions Section
                        Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                          ),
                        ),
                        SizedBox(height: 16),
                        _buildMonthlyTransactionsList(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMonthlyTransactionsList() {
    final theme = Theme.of(context);
    final transactions = _getTransactionsForMonth();
    
    if (transactions.isEmpty) {
      return Container(
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 60, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'No transactions for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
              style: TextStyle(
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
              label: Text('Add Transaction'),
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
        ...displayTransactions.map((transaction) => _HomeTransactionCard(transaction: transaction)),
        if (transactions.length > 5)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () {
                // Navigate to transactions screen - this will be handled by parent
                // For now, just show a message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('View all transactions in the Transactions tab')),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color ?? Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  DateFormat('d MMMM').format(transaction.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${Helpers.formatCurrency(transaction.amount)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
