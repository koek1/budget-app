import 'package:flutter/material.dart';

class AppConstants {
  static const List<String> expenseCategories = [
    'Food & Dining',
    'Shopping',
    'Entertainment',
    'Bills & Utilities',
    'Healthcare',
    'Education',
    'Travel',
    'Other'
  ];

  static const List<String> incomeCategories = [
    'Salary',
    'Freelance',
    'Investment',
    'Gift',
    'Bonus',
    'Other'
  ];

  static const Map<String, Color> categoryColors = {
    'Food & Dining': Colors.orange,
    'Transportation': Colors.blue,
    'Shopping': Colors.pink,
    'Entertainment': Colors.purple,
    'Bills & Utilities': Colors.red,
    'Healthcare': Colors.green,
    'Education': Colors.teal,
    'Travel': Colors.cyan,
    'Salary': Colors.green,
    'Freelance': Colors.blue,
    'Investment': Colors.amber,
    'Gift': Colors.pink,
    'Bonus': Colors.orange,
    'Other': Colors.grey,
  };
}