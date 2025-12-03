import 'package:hive/hive.dart';
import 'package:budget_app/models/budget.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class BudgetService {
  static const String _boxName = 'budgetsBox';
  static const double _defaultWarningThreshold = 80.0; // 80%

  // Initialize the box (should be called in main.dart)
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<Budget>(_boxName);
    }
  }

  // Get all budgets for current user
  static Future<List<Budget>> getBudgets() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        return [];
      }

      final box = Hive.box<Budget>(_boxName);
      final currentUser = await LocalStorageService.getCurrentUser();

      if (currentUser == null) {
        return [];
      }

      return box.values
          .where((b) => b.userId == currentUser.id && b.isActive)
          .toList();
    } catch (e) {
      print('Error getting budgets: $e');
      return [];
    }
  }

  // Get overall budget (no category)
  static Future<Budget?> getOverallBudget({String period = 'monthly'}) async {
    final budgets = await getBudgets();
    return budgets.firstWhere(
      (b) => b.category == null && b.period == period,
      orElse: () => Budget(
        id: '',
        userId: '',
        amount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: false,
      ),
    );
  }

  // Get category budget
  static Future<Budget?> getCategoryBudget(String category, {String period = 'monthly'}) async {
    final budgets = await getBudgets();
    try {
      return budgets.firstWhere(
        (b) => b.category == category && b.period == period,
      );
    } catch (e) {
      return null;
    }
  }

  // Get all category budgets
  static Future<List<Budget>> getCategoryBudgets({String period = 'monthly'}) async {
    final budgets = await getBudgets();
    return budgets.where((b) => b.category != null && b.period == period).toList();
  }

  // Add or update budget
  static Future<void> saveBudget(Budget budget) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        await init();
      }

      final box = Hive.box<Budget>(_boxName);
      await box.put(budget.id, budget);
    } catch (e) {
      print('Error saving budget: $e');
      rethrow;
    }
  }

  // Create new budget
  static Future<Budget> createBudget({
    String? category,
    required double amount,
    String period = 'monthly',
    double? warningThreshold,
  }) async {
    final currentUser = await LocalStorageService.getCurrentUser();
    if (currentUser == null) {
      throw Exception('User not logged in');
    }

    final now = DateTime.now();
    final budget = Budget(
      id: const Uuid().v4(),
      userId: currentUser.id,
      category: category,
      amount: amount,
      period: period,
      createdAt: now,
      updatedAt: now,
      warningThreshold: warningThreshold ?? _defaultWarningThreshold,
      isActive: true,
    );

    await saveBudget(budget);
    return budget;
  }

  // Update budget
  static Future<Budget> updateBudget(Budget budget) async {
    final updatedBudget = budget.copyWith(
      updatedAt: DateTime.now(),
    );
    await saveBudget(updatedBudget);
    return updatedBudget;
  }

  // Delete budget (soft delete by setting isActive to false)
  static Future<void> deleteBudget(String budgetId) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        return;
      }

      final box = Hive.box<Budget>(_boxName);
      final budget = box.get(budgetId);
      if (budget != null) {
        final updatedBudget = budget.copyWith(isActive: false);
        await box.put(budgetId, updatedBudget);
      }
    } catch (e) {
      print('Error deleting budget: $e');
      rethrow;
    }
  }

  // Calculate current spending for a budget
  static Future<double> getCurrentSpending(Budget budget) async {
    final transactions = await LocalStorageService.getTransactions();
    final now = DateTime.now();
    
    DateTime startDate;
    DateTime endDate;

    switch (budget.period) {
      case 'weekly':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
        endDate = startDate.add(Duration(days: 7));
        break;
      case 'yearly':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year + 1, 1, 1);
        break;
      case 'monthly':
      default:
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 1);
        break;
    }

    final filteredTransactions = transactions.where((t) {
      if (t.type != 'expense') return false;
      if (t.date.isBefore(startDate) || t.date.isAfter(endDate)) return false;
      if (budget.category != null && t.category != budget.category) return false;
      return true;
    }).toList();

    return filteredTransactions.fold<double>(0.0, (sum, t) => sum + t.amount);
  }

  // Get budget status
  static Future<Map<String, dynamic>> getBudgetStatus(Budget budget) async {
    final spending = await getCurrentSpending(budget);
    final percentage = budget.amount > 0 ? (spending / budget.amount) * 100 : 0.0;
    final warningThreshold = budget.warningThreshold ?? _defaultWarningThreshold;
    final remaining = budget.amount - spending;

    String status;
    if (percentage >= 100) {
      status = 'exceeded';
    } else if (percentage >= warningThreshold) {
      status = 'warning';
    } else {
      status = 'ok';
    }

    return {
      'budget': budget,
      'spending': spending,
      'remaining': remaining,
      'percentage': percentage,
      'status': status,
      'isExceeded': percentage >= 100,
      'isWarning': percentage >= warningThreshold && percentage < 100,
    };
  }

  // Get all budget statuses
  static Future<List<Map<String, dynamic>>> getAllBudgetStatuses({String period = 'monthly'}) async {
    final budgets = await getBudgets();
    final periodBudgets = budgets.where((b) => b.period == period).toList();
    
    final List<Map<String, dynamic>> statuses = [];
    for (final budget in periodBudgets) {
      final status = await getBudgetStatus(budget);
      statuses.add(status);
    }
    
    return statuses;
  }
}

