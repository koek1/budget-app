import 'package:budget_app/services/local_storage_service.dart';

/// Service for analyzing spending/income trends and providing budget suggestions
/// This service is designed to be AI-ready - can be extended with AI integration in the future
class BudgetAnalysisService {
  // Get spending trends for the last N months
  static Future<Map<String, double>> getSpendingTrends({int months = 3}) async {
    final transactions = await LocalStorageService.getTransactions();
    final now = DateTime.now();
    final Map<String, double> trends = {};

    for (int i = 0; i < months; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      
      final monthTransactions = transactions.where((t) {
        if (t.type != 'expense') return false;
        final tMonth = DateTime(t.date.year, t.date.month);
        return tMonth.year == month.year && tMonth.month == month.month;
      }).toList();

      trends[monthKey] = monthTransactions.fold<double>(0.0, (sum, t) => sum + t.amount);
    }

    return trends;
  }

  // Get category spending trends
  static Future<Map<String, Map<String, double>>> getCategorySpendingTrends({int months = 3}) async {
    final transactions = await LocalStorageService.getTransactions();
    final now = DateTime.now();
    final Map<String, Map<String, double>> categoryTrends = {};

    for (int i = 0; i < months; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';

      final monthTransactions = transactions.where((t) {
        if (t.type != 'expense') return false;
        final tMonth = DateTime(t.date.year, t.date.month);
        return tMonth.year == month.year && tMonth.month == month.month;
      }).toList();

      for (final transaction in monthTransactions) {
        if (!categoryTrends.containsKey(transaction.category)) {
          categoryTrends[transaction.category] = {};
        }
        categoryTrends[transaction.category]![monthKey] = 
            (categoryTrends[transaction.category]![monthKey] ?? 0.0) + transaction.amount;
      }
    }

    return categoryTrends;
  }

  // Get income trends
  static Future<Map<String, double>> getIncomeTrends({int months = 3}) async {
    final transactions = await LocalStorageService.getTransactions();
    final now = DateTime.now();
    final Map<String, double> trends = {};

    for (int i = 0; i < months; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      
      final monthTransactions = transactions.where((t) {
        if (t.type != 'income') return false;
        final tMonth = DateTime(t.date.year, t.date.month);
        return tMonth.year == month.month && tMonth.month == month.month;
      }).toList();

      trends[monthKey] = monthTransactions.fold<double>(0.0, (sum, t) => sum + t.amount);
    }

    return trends;
  }

  // Calculate average monthly spending
  static Future<double> getAverageMonthlySpending({int months = 3}) async {
    final trends = await getSpendingTrends(months: months);
    if (trends.isEmpty) return 0.0;
    
    final total = trends.values.fold<double>(0.0, (sum, amount) => sum + amount);
    return total / trends.length;
  }

  // Calculate average monthly income
  static Future<double> getAverageMonthlyIncome({int months = 3}) async {
    final trends = await getIncomeTrends(months: months);
    if (trends.isEmpty) return 0.0;
    
    final total = trends.values.fold<double>(0.0, (sum, amount) => sum + amount);
    return total / trends.length;
  }

  // Get suggested overall budget based on trends
  /// AI-ready: This method can be enhanced with AI to provide more sophisticated suggestions
  static Future<BudgetSuggestion> getSuggestedOverallBudget({int months = 3}) async {
    final avgSpending = await getAverageMonthlySpending(months: months);
    final avgIncome = await getAverageMonthlyIncome(months: months);
    
    // Calculate suggested budget (aim for 80% of average spending to encourage savings)
    final suggestedAmount = avgSpending * 0.8;
    
    // Calculate potential savings
    final potentialSavings = avgIncome - suggestedAmount;
    final savingsPercentage = avgIncome > 0 ? (potentialSavings / avgIncome) * 100 : 0.0;

    String reasoning;
    if (avgSpending == 0) {
      reasoning = 'No spending history available. Start with a conservative budget based on your income.';
    } else if (suggestedAmount < avgSpending * 0.7) {
      reasoning = 'Your spending has been high. This budget will help you save ${potentialSavings.toStringAsFixed(0)} per month (${savingsPercentage.toStringAsFixed(1)}% of income).';
    } else {
      reasoning = 'Based on your ${months}-month average spending of ${avgSpending.toStringAsFixed(0)}, this budget allows for ${potentialSavings.toStringAsFixed(0)} in monthly savings.';
    }

    return BudgetSuggestion(
      amount: suggestedAmount,
      reasoning: reasoning,
      confidence: avgSpending > 0 ? 0.85 : 0.5,
      potentialSavings: potentialSavings,
      savingsPercentage: savingsPercentage,
    );
  }

  // Get suggested category budgets
  /// AI-ready: This method can be enhanced with AI to provide category-specific insights
  static Future<Map<String, BudgetSuggestion>> getSuggestedCategoryBudgets({int months = 3}) async {
    final categoryTrends = await getCategorySpendingTrends(months: months);
    final Map<String, BudgetSuggestion> suggestions = {};

    for (final entry in categoryTrends.entries) {
      final category = entry.key;
      final monthlyAmounts = entry.value.values.toList();
      
      if (monthlyAmounts.isEmpty) continue;

      final avgSpending = monthlyAmounts.fold<double>(0.0, (sum, amount) => sum + amount) / monthlyAmounts.length;
      final maxSpending = monthlyAmounts.reduce((a, b) => a > b ? a : b);
      final minSpending = monthlyAmounts.reduce((a, b) => a < b ? a : b);
      
      // Suggest 85% of average to encourage savings, but ensure it's realistic
      final suggestedAmount = (avgSpending * 0.85).clamp(minSpending * 0.7, maxSpending * 0.95);
      final potentialSavings = avgSpending - suggestedAmount;

      String reasoning;
      if (monthlyAmounts.length < 2) {
        reasoning = 'Limited data for this category. Budget set at ${suggestedAmount.toStringAsFixed(0)} based on recent spending.';
      } else if (maxSpending / minSpending > 2) {
        reasoning = 'Your spending in this category varies significantly. This budget helps stabilize your expenses.';
      } else {
        reasoning = 'Based on your average spending of ${avgSpending.toStringAsFixed(0)}, this budget can help you save ${potentialSavings.toStringAsFixed(0)} per month.';
      }

      suggestions[category] = BudgetSuggestion(
        amount: suggestedAmount,
        reasoning: reasoning,
        confidence: monthlyAmounts.length >= 2 ? 0.8 : 0.6,
        potentialSavings: potentialSavings,
        savingsPercentage: avgSpending > 0 ? (potentialSavings / avgSpending) * 100 : 0.0,
      );
    }

    return suggestions;
  }

  // Get spending pattern insights
  /// AI-ready: This method can be enhanced with AI for deeper pattern analysis
  static Future<List<String>> getSpendingInsights({int months = 3}) async {
    final avgSpending = await getAverageMonthlySpending(months: months);
    final avgIncome = await getAverageMonthlyIncome(months: months);
    final categoryTrends = await getCategorySpendingTrends(months: months);
    
    final List<String> insights = [];

    // Income vs Spending analysis
    if (avgIncome > 0) {
      final spendingRatio = (avgSpending / avgIncome) * 100;
      if (spendingRatio > 90) {
        insights.add('⚠️ You\'re spending ${spendingRatio.toStringAsFixed(1)}% of your income. Consider reducing expenses to build savings.');
      } else if (spendingRatio < 70) {
        insights.add('✅ Great job! You\'re spending only ${spendingRatio.toStringAsFixed(1)}% of your income, leaving room for savings.');
      }
    }

    // Category analysis
    if (categoryTrends.isNotEmpty) {
      final categoryAverages = categoryTrends.map((category, months) {
        final amounts = months.values.toList();
        final avg = amounts.fold<double>(0.0, (sum, a) => sum + a) / amounts.length;
        return MapEntry(category, avg);
      });

      final sortedCategories = categoryAverages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (sortedCategories.isNotEmpty) {
        final topCategory = sortedCategories.first;
        final topCategoryPercentage = avgSpending > 0 
            ? (topCategory.value / avgSpending) * 100 
            : 0.0;
        
        if (topCategoryPercentage > 30) {
          insights.add('📊 ${topCategory.key} accounts for ${topCategoryPercentage.toStringAsFixed(1)}% of your spending. Consider setting a specific budget for this category.');
        }
      }
    }

    // Trend analysis
    final trends = await getSpendingTrends(months: months);
    if (trends.length >= 2) {
      final trendValues = trends.values.toList().reversed.toList();
      final recent = trendValues.last;
      final previous = trendValues[trendValues.length - 2];
      
      if (recent > previous * 1.15) {
        insights.add('📈 Your spending increased by ${((recent - previous) / previous * 100).toStringAsFixed(1)}% this month. Review your expenses.');
      } else if (recent < previous * 0.85) {
        insights.add('📉 Your spending decreased by ${((previous - recent) / previous * 100).toStringAsFixed(1)}%. Great progress!');
      }
    }

    return insights;
  }
}

/// Data class for budget suggestions
class BudgetSuggestion {
  final double amount;
  final String reasoning;
  final double confidence; // 0.0 to 1.0
  final double potentialSavings;
  final double savingsPercentage;

  BudgetSuggestion({
    required this.amount,
    required this.reasoning,
    required this.confidence,
    required this.potentialSavings,
    required this.savingsPercentage,
  });
}

