import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
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

class _TransactionsScreenState extends State<TransactionsScreen> with SingleTickerProviderStateMixin {
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

  List<Transaction> _getTransactionsForMonth() {
    final box = Hive.box<Transaction>('transactionsBox');
    
    // Get all transactions and filter by month
    final allTransactions = box.values.toList();
    
    // If no transactions, return empty list
    if (allTransactions.isEmpty) {
      return [];
    }
    
    // Filter transactions by selected month
    final filtered = allTransactions.where((transaction) {
      final transactionDate = transaction.date;
      // Normalize dates to compare only year and month (ignore time)
      final transactionYearMonth = DateTime(transactionDate.year, transactionDate.month);
      final selectedYearMonth = DateTime(_selectedMonth.year, _selectedMonth.month);
      return transactionYearMonth == selectedYearMonth;
    }).toList();
    
    return filtered;
  }

  List<FlSpot> _getGraphData() {
    final transactions = _getTransactionsForMonth();
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    
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
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(transaction: transaction),
      ),
    );
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Transaction'),
        content: Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await LocalStorageService.deleteTransaction(transaction.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction deleted')),
        );
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
          valueListenable: Hive.box<Transaction>('transactionsBox').listenable(),
          builder: (context, box, _) {
            final transactions = _getTransactionsForMonth();
            final spendings = transactions.where((t) => t.type == 'expense').toList()
              ..sort((a, b) => b.date.compareTo(a.date));
            final income = transactions.where((t) => t.type == 'income').toList()
              ..sort((a, b) => b.date.compareTo(a.date));
            final graphData = _getGraphData();
            
            // Calculate total for current tab
            final currentTabTotal = _selectedTab == 'Income' 
                ? income.fold(0.0, (sum, t) => sum + t.amount)
                : spendings.fold(0.0, (sum, t) => sum + t.amount);

            return CustomScrollView(
              slivers: [
                // Header
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
                    'Transactions',
                    style: TextStyle(
                      color: theme.textTheme.titleLarge?.color ?? Colors.black,
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
                                Icon(Icons.arrow_drop_down, color: Colors.white),
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
                                              // Show key days: 1, 5, 10, 15, 20, 25, 30
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
                                              // Use the actual graph value (barSpot.y) which is the balance at that point on the graph
                                              final graphValue = barSpot.y;
                                              final amountStr = Helpers.formatCurrency(graphValue);
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
                                            getDotPainter: (spot, percent, barData, index) {
                                              // Show dot on the last point or on specific days
                                              if (index == graphData.length - 1 || 
                                                  [1, 5, 10, 15, 20, 25, 30].contains(spot.x.toInt())) {
                                                return FlDotCirclePainter(
                                                  radius: 4,
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                  strokeColor: Color(0xFF2563EB),
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
                                          : (graphData.map((e) => e.y).reduce((a, b) => a < b ? a : b) * 0.9).clamp(0, double.infinity),
                                      maxY: graphData.isEmpty || graphData.every((e) => e.y == 0)
                                          ? 1000
                                          : (graphData.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2).clamp(100, double.infinity),
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

                // Transaction List
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTransactionList(spendings),
                      _buildTransactionList(income),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTransactionList(List<Transaction> transactions) {
    // Get all transactions to check if any exist
    final box = Hive.box<Transaction>('transactionsBox');
    final allTransactions = box.values.toList();
    
    if (transactions.isEmpty) {
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
              if (allTransactions.isNotEmpty) ...[
                Text(
                  'Total transactions in database: ${allTransactions.length}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Selected month: ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
                SizedBox(height: 8),
              ],
              Text(
                'Try selecting a different month or add a transaction',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(20),
      itemCount: transactions.length,
      physics: AlwaysScrollableScrollPhysics(),
      shrinkWrap: false,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _ModernTransactionCard(
          transaction: transaction,
          onEdit: () => _editTransaction(transaction),
          onDelete: () => _deleteTransaction(transaction),
        );
      },
    );
  }
}

class _ModernTransactionCard extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ModernTransactionCard({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
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
          
          // Amount and Actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}${Helpers.formatCurrency(transaction.amount)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isIncome ? Colors.green : Colors.red,
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
