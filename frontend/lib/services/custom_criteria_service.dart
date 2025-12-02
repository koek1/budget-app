import 'package:hive/hive.dart';
import 'package:budget_app/models/custom_criteria.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:budget_app/utils/constants.dart';
import 'package:budget_app/models/transaction.dart';

class CustomCriteriaService {
  static const String _boxName = 'customCriteriaBox';
  static const String _hiddenCategoriesKey = 'hiddenDefaultCategories';

  // Initialize the box (should be called in main.dart)
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<CustomCriteria>(_boxName);
    }
  }

  // Get all custom criteria for current user
  static Future<List<CustomCriteria>> getCustomCriteria() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        return [];
      }
      
      final box = Hive.box<CustomCriteria>(_boxName);
      final currentUser = await LocalStorageService.getCurrentUser();
      
      if (currentUser == null) {
        return [];
      }
      
      // Filter criteria by current user
      try {
        return box.values
            .where((c) => c.userId == currentUser.id)
            .toList();
      } catch (e) {
        print('Error filtering custom criteria: $e');
        return [];
      }
    } catch (e) {
      print('Error getting custom criteria: $e');
      return [];
    }
  }

  // Get custom criteria by type (income or expense)
  static Future<List<CustomCriteria>> getCustomCriteriaByType(
      String type) async {
    final allCriteria = await getCustomCriteria();
    return allCriteria.where((c) => c.type == type).toList();
  }

  // Get all custom category names by type
  static Future<List<String>> getCustomCategoryNames(String type) async {
    final criteria = await getCustomCriteriaByType(type);
    return criteria.map((c) => c.name).toList();
  }

  // Add custom criteria
  static Future<void> addCustomCriteria(
      String type, String name) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        throw Exception('Custom criteria database is not available');
      }
      
      final box = Hive.box<CustomCriteria>(_boxName);
      final currentUser = await LocalStorageService.getCurrentUser();
      
      if (currentUser == null) {
        throw Exception('User must be logged in to add custom criteria');
      }
      
      if (type.isEmpty || name.trim().isEmpty) {
        throw Exception('Type and name are required');
      }
      
      if (type != 'income' && type != 'expense') {
        throw Exception('Type must be either "income" or "expense"');
      }

      // Check for duplicates (same type and name for this user) - optimized
      try {
        final normalizedName = name.trim().toLowerCase();
        final existing = box.values.firstWhere(
          (c) =>
              c.userId == currentUser.id &&
              c.type == type &&
              c.name.toLowerCase() == normalizedName,
          orElse: () => CustomCriteria(
            id: '',
            userId: '',
            type: '',
            name: '',
            createdAt: DateTime.now(),
          ),
        );

        if (existing.id.isNotEmpty) {
          throw Exception('This category already exists');
        }
      } catch (e) {
        if (e.toString().contains('already exists')) {
          rethrow;
        }
        // If firstWhere throws StateError (not found), that's fine - continue
        print('Error checking duplicates: $e');
      }

      final criteria = CustomCriteria(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: currentUser.id,
        type: type,
        name: name.trim(),
        createdAt: DateTime.now(),
      );

      await box.add(criteria);
    } catch (e) {
      print('Error adding custom criteria: $e');
      rethrow;
    }
  }

  // Update custom criteria
  static Future<void> updateCustomCriteria(
      String id, String name) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        throw Exception('Custom criteria database is not available');
      }
      
      final box = Hive.box<CustomCriteria>(_boxName);
      final currentUser = await LocalStorageService.getCurrentUser();
      
      if (currentUser == null) {
        throw Exception('User must be logged in to update custom criteria');
      }
      
      if (id.isEmpty || name.trim().isEmpty) {
        throw Exception('ID and name are required');
      }

      // Find the criteria by ID and user ID
      for (var i = 0; i < box.length; i++) {
        try {
          final existing = box.getAt(i);
          if (existing?.id == id && existing?.userId == currentUser.id) {
            // Check for duplicates (excluding current item)
            try {
              final normalizedName = name.trim().toLowerCase();
              final duplicate = box.values.firstWhere(
                (c) =>
                    c.userId == currentUser.id &&
                    c.type == existing!.type &&
                    c.id != id &&
                    c.name.toLowerCase() == normalizedName,
                orElse: () => CustomCriteria(
                  id: '',
                  userId: '',
                  type: '',
                  name: '',
                  createdAt: DateTime.now(),
                ),
              );

              if (duplicate.id.isNotEmpty) {
                throw Exception('This category already exists');
              }
            } catch (e) {
              if (e.toString().contains('already exists')) {
                rethrow;
              }
              // If firstWhere throws StateError (not found), that's fine
            }

            final updated = CustomCriteria(
              id: existing!.id,
              userId: existing.userId,
              type: existing.type,
              name: name.trim(),
              createdAt: existing.createdAt,
            );

            await box.putAt(i, updated);
            return;
          }
        } catch (e) {
          // Skip corrupted entries
          print('Error reading criteria at index $i: $e');
          continue;
        }
      }

      throw Exception('Custom criteria not found');
    } catch (e) {
      print('Error updating custom criteria: $e');
      rethrow;
    }
  }

  // Delete custom criteria
  static Future<void> deleteCustomCriteria(String id) async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        throw Exception('Custom criteria database is not available');
      }
      
      final box = Hive.box<CustomCriteria>(_boxName);
      final currentUser = await LocalStorageService.getCurrentUser();
      
      if (currentUser == null) {
        throw Exception('User must be logged in to delete custom criteria');
      }
      
      if (id.isEmpty) {
        throw Exception('Criteria ID is required');
      }

      // Find the criteria by ID and user ID
      for (var i = 0; i < box.length; i++) {
        try {
          final criteria = box.getAt(i);
          if (criteria?.id == id && criteria?.userId == currentUser.id) {
            await box.deleteAt(i);
            return;
          }
        } catch (e) {
          // Skip corrupted entries
          print('Error reading criteria at index $i: $e');
          continue;
        }
      }

      throw Exception('Custom criteria not found');
    } catch (e) {
      print('Error deleting custom criteria: $e');
      rethrow;
    }
  }

  // Get hidden default categories for current user
  static Future<List<String>> getHiddenDefaultCategories() async {
    final settingsBox = Hive.box('settingsBox');
    final currentUser = await LocalStorageService.getCurrentUser();
    if (currentUser == null) return [];
    
    final key = '${_hiddenCategoriesKey}_${currentUser.id}';
    final hidden = settingsBox.get(key);
    if (hidden is List) {
      return List<String>.from(hidden);
    }
    return [];
  }

  // Hide a default category
  static Future<void> hideDefaultCategory(String type, String categoryName) async {
    final settingsBox = Hive.box('settingsBox');
    final currentUser = await LocalStorageService.getCurrentUser();
    
    if (currentUser == null) {
      throw Exception('User must be logged in to hide default categories');
    }

    final key = '${_hiddenCategoriesKey}_${currentUser.id}';
    final hidden = await getHiddenDefaultCategories();
    
    final categoryKey = '$type:$categoryName';
    if (!hidden.contains(categoryKey)) {
      hidden.add(categoryKey);
      await settingsBox.put(key, hidden);
    }
  }

  // Show a default category (unhide)
  static Future<void> showDefaultCategory(String type, String categoryName) async {
    final settingsBox = Hive.box('settingsBox');
    final currentUser = await LocalStorageService.getCurrentUser();
    
    if (currentUser == null) {
      throw Exception('User must be logged in to show default categories');
    }

    final key = '${_hiddenCategoriesKey}_${currentUser.id}';
    final hidden = await getHiddenDefaultCategories();
    
    final categoryKey = '$type:$categoryName';
    hidden.remove(categoryKey);
    await settingsBox.put(key, hidden);
  }

  // Check if a default category is hidden
  static Future<bool> isDefaultCategoryHidden(String type, String categoryName) async {
    final hidden = await getHiddenDefaultCategories();
    final categoryKey = '$type:$categoryName';
    return hidden.contains(categoryKey);
  }

  // Edit a default category (creates a custom version and optionally updates transactions)
  static Future<void> editDefaultCategory(
    String type,
    String oldName,
    String newName, {
    bool updateTransactions = true,
  }) async {
    final currentUser = await LocalStorageService.getCurrentUser();
    
    if (currentUser == null) {
      throw Exception('User must be logged in to edit default categories');
    }

    // Create a custom category with the new name
    await addCustomCriteria(type, newName);

    // Optionally update all transactions using the old category name
    if (updateTransactions) {
      await _updateTransactionsCategory(currentUser.id, type, oldName, newName);
    }
  }

  // Update all transactions with a specific category to a new category
  static Future<void> _updateTransactionsCategory(
    String userId,
    String type,
    String oldCategory,
    String newCategory,
  ) async {
    try {
      if (!Hive.isBoxOpen('transactionsBox')) {
        print('Transactions box not open, skipping category update');
        return;
      }
      
      final transactionsBox = Hive.box<Transaction>('transactionsBox');
      int updateCount = 0;
      
      for (var i = 0; i < transactionsBox.length; i++) {
        try {
          final transaction = transactionsBox.getAt(i);
          if (transaction != null &&
              transaction.userId == userId &&
              transaction.type == type &&
              transaction.category == oldCategory) {
            final updated = Transaction(
              id: transaction.id,
              userId: transaction.userId,
              amount: transaction.amount,
              type: transaction.type,
              category: newCategory,
              description: transaction.description,
              date: transaction.date,
              isSynced: transaction.isSynced,
            );
            await transactionsBox.putAt(i, updated);
            updateCount++;
          }
        } catch (e) {
          // Skip corrupted entries
          print('Error updating transaction at index $i: $e');
          continue;
        }
      }
      
      if (updateCount > 0) {
        print('Updated $updateCount transactions with new category');
      }
    } catch (e) {
      print('Error updating transactions category: $e');
      // Don't rethrow - this is a background operation
    }
  }

  // Get all categories (default + custom) for a type, excluding hidden ones
  static Future<List<CategoryItem>> getAllCategories(String type) async {
    final defaultCategories = type == 'income'
        ? AppConstants.incomeCategories
        : AppConstants.expenseCategories;
    final customCriteria = await getCustomCriteriaByType(type);
    final hidden = await getHiddenDefaultCategories();

    final items = <CategoryItem>[];

    // Add default categories (excluding hidden ones)
    for (final category in defaultCategories) {
      final categoryKey = '$type:$category';
      if (!hidden.contains(categoryKey)) {
        items.add(CategoryItem(
          name: category,
          isDefault: true,
          customCriteriaId: null,
        ));
      }
    }

    // Add custom categories
    for (final criteria in customCriteria) {
      items.add(CategoryItem(
        name: criteria.name,
        isDefault: false,
        customCriteriaId: criteria.id,
      ));
    }

    return items;
  }
}

// Helper class to represent a category item
class CategoryItem {
  final String name;
  final bool isDefault;
  final String? customCriteriaId;

  CategoryItem({
    required this.name,
    required this.isDefault,
    this.customCriteriaId,
  });
}

