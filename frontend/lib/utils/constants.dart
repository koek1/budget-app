import 'package:flutter/material.dart';
import 'package:budget_app/services/custom_criteria_service.dart';

class AppConstants {
  static const List<String> expenseCategories = [
    'Food & Dining',
    'Shopping',
    'Entertainment',
    'Bills & Utilities',
    'Healthcare',
    'Education',
    'Travel',
    'Subscriptions',
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
    'Subscriptions': Colors.indigo,
    'Salary': Colors.green,
    'Freelance': Colors.blue,
    'Investment': Colors.amber,
    'Gift': Colors.pink,
    'Bonus': Colors.orange,
    'Other': Colors.grey,
  };

  // Get merged categories (default + custom) for a given type, excluding hidden ones
  static Future<List<String>> getCategories(String type) async {
    final defaultCategories = type == 'income' ? incomeCategories : expenseCategories;
    final customCategories = await CustomCriteriaService.getCustomCategoryNames(type);
    final hidden = await CustomCriteriaService.getHiddenDefaultCategories();
    
    // Merge and remove duplicates (case-insensitive)
    final allCategories = <String>[];
    final seen = <String>{};
    
    // Add default categories first (excluding hidden ones)
    for (final category in defaultCategories) {
      final categoryKey = '$type:$category';
      final lower = category.toLowerCase();
      if (!hidden.contains(categoryKey) && !seen.contains(lower)) {
        allCategories.add(category);
        seen.add(lower);
      }
    }
    
    // Add custom categories
    for (final category in customCategories) {
      final lower = category.toLowerCase();
      if (!seen.contains(lower)) {
        allCategories.add(category);
        seen.add(lower);
      }
    }
    
    return allCategories;
  }
}