import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/widgets/budget_card.dart';
import 'package:budget_app/utils/helpers.dart';
import 'package:budget_app/utils/constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Box<Transaction> transactionsBox;

  @override
  void initState() {
    super.initState();
    transactionsBox = Hive.box<Transaction>('transactionsBox');
  }

  double getTotalIncome() {
    return transactionsBox.values
        .where((transaction) => transaction.type == 'income')
        .fold(0, (sum, transaction) => sum + transaction.amount);
  }

  double getTotalExpenses() {
    return transactionsBox.values
        .where((transaction) => transaction.type == 'expense')
        .fold(0, (sum, transaction) => sum + transaction.amount);
  }

  double getBalance() {
    return getTotalIncome() - getTotalExpenses();
  }

  Map<String, double> getExpensesByCategory() {
    Map<String, double> categoryTotals = {};
    
    transactionsBox.values
        .where((transaction) => transaction.type == 'expense')
        .forEach((transaction) {
      categoryTotals.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    });
    
    return categoryTotals;
  }

  @override
  Widget build(BuildContext context) {
    final totalIncome = getTotalIncome();
    final totalExpenses = getTotalExpenses();
    final balance = getBalance();
    final categoryExpenses = getExpensesByCategory();

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Balance Card
          BudgetCard(
            title: 'Current Balance',
            amount: balance,
            color: balance >= 0 ? Colors.green : Colors.red,
            icon: Icons.account_balance_wallet,
          ),
          SizedBox(height: 16),
          
          // Income & Expense Cards
          Row(
            children: [
              Expanded(
                child: BudgetCard(
                  title: 'Income',
                  amount: totalIncome,
                  color: Colors.green,
                  icon: Icons.arrow_upward,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: BudgetCard(
                  title: 'Expenses',
                  amount: totalExpenses,
                  color: Colors.red,
                  icon: Icons.arrow_downward,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          
          // Expenses by Category
          Text(
            'Expenses by Category',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          
          if (categoryExpenses.isEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No expenses yet',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            )
          else
            ...categoryExpenses.entries.map((entry) {
              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppConstants.categoryColors[entry.key] ?? Colors.grey,
                    child: Icon(Icons.category, color: Colors.white),
                  ),
                  title: Text(entry.key),
                  trailing: Text(
                    Helpers.formatCurrency(entry.value),
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}