import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:budget_app/models/custom_criteria.dart';
import 'package:budget_app/services/custom_criteria_service.dart';
import 'package:budget_app/utils/helpers.dart';

class ManageCriteriaScreen extends StatefulWidget {
  const ManageCriteriaScreen({super.key});

  @override
  _ManageCriteriaScreenState createState() => _ManageCriteriaScreenState();
}

class _ManageCriteriaScreenState extends State<ManageCriteriaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _addCriteria(String type) async {
    final theme = Theme.of(context);
    final controller = TextEditingController();
    _controllers[type] = controller;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Add ${type == 'income' ? 'Income' : 'Expense'} Category',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Category Name',
            hintText: 'Enter category name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: theme.brightness == Brightness.dark
                ? theme.scaffoldBackgroundColor
                : Colors.grey[50],
          ),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              _controllers.remove(type);
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(
              'Add',
              style: GoogleFonts.inter(
                color: Color(0xFF14B8A6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await CustomCriteriaService.addCustomCriteria(type, result);
        if (mounted) {
          Helpers.showSuccessSnackBar(
              context, 'Category added successfully');
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = e.toString();
          if (errorMessage.startsWith('Exception: ')) {
            errorMessage = errorMessage.substring(11);
          }
          Helpers.showErrorSnackBar(context, errorMessage);
        }
      }
    } else {
      controller.dispose();
      _controllers.remove(type);
    }
  }

  Future<void> _editCategory(String type, CategoryItem item) async {
    final theme = Theme.of(context);
    final controller = TextEditingController(text: item.name);
    final key = item.customCriteriaId ?? item.name;
    _controllers[key] = controller;

    final isDefault = item.isDefault;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Edit Category',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDefault)
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Editing a default category will create a custom version and update all existing transactions.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? theme.scaffoldBackgroundColor
                    : Colors.grey[50],
              ),
              style: GoogleFonts.inter(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              _controllers.remove(key);
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                color: Color(0xFF14B8A6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != item.name) {
      try {
        if (isDefault) {
          // Edit default category - creates custom version and updates transactions
          await CustomCriteriaService.editDefaultCategory(
            type,
            item.name,
            result,
            updateTransactions: true,
          );
        } else {
          // Edit custom category
          await CustomCriteriaService.updateCustomCriteria(
            item.customCriteriaId!,
            result,
          );
        }
        if (mounted) {
          Helpers.showSuccessSnackBar(
              context, 'Category updated successfully');
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = e.toString();
          if (errorMessage.startsWith('Exception: ')) {
            errorMessage = errorMessage.substring(11);
          }
          Helpers.showErrorSnackBar(context, errorMessage);
        }
      }
    } else {
      controller.dispose();
      _controllers.remove(key);
    }
  }

  Future<void> _deleteCategory(String type, CategoryItem item) async {
    final theme = Theme.of(context);
    final isDefault = item.isDefault;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          isDefault ? 'Hide Category' : 'Delete Category',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDefault
                  ? 'Are you sure you want to hide "${item.name}"? This will remove it from the category list, but existing transactions will keep this category.'
                  : 'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
              style: GoogleFonts.inter(),
            ),
            if (isDefault) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Existing transactions using this category will remain unchanged.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isDefault ? 'Hide' : 'Delete',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        if (isDefault) {
          // Hide default category
          await CustomCriteriaService.hideDefaultCategory(type, item.name);
          if (mounted) {
            Helpers.showSuccessSnackBar(
                context, 'Category hidden successfully');
          }
        } else {
          // Delete custom category
          await CustomCriteriaService.deleteCustomCriteria(
              item.customCriteriaId!);
          if (mounted) {
            Helpers.showSuccessSnackBar(
                context, 'Category deleted successfully');
          }
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = e.toString();
          if (errorMessage.startsWith('Exception: ')) {
            errorMessage = errorMessage.substring(11);
          }
          Helpers.showErrorSnackBar(context, errorMessage);
        }
      }
    }
  }

  Widget _buildCriteriaList(String type) {
    return ValueListenableBuilder(
      valueListenable: Hive.box('settingsBox').listenable(),
      builder: (context, settingsBox, _) {
        return ValueListenableBuilder(
          valueListenable:
              Hive.box<CustomCriteria>('customCriteriaBox').listenable(),
          builder: (context, box, _) {
            return FutureBuilder<List<CategoryItem>>(
              future: CustomCriteriaService.getAllCategories(type),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF14B8A6),
                    ),
                  );
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No categories available',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap the + button to add one',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final theme = Theme.of(context);

                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? Color(0xFF1E293B)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Color(0xFF14B8A6).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            type == 'income'
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            color: Color(0xFF14B8A6),
                            size: 24,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                            if (item.isDefault)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Default',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_rounded),
                              color: Color(0xFF14B8A6),
                              onPressed: () => _editCategory(type, item),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_rounded),
                              color: Colors.red,
                              onPressed: () => _deleteCategory(type, item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Categories',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Color(0xFF14B8A6),
          unselectedLabelColor: theme.textTheme.bodyMedium?.color,
          indicatorColor: Color(0xFF14B8A6),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_upward_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Income', style: GoogleFonts.inter()),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_downward_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Expense', style: GoogleFonts.inter()),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCriteriaList('income'),
          _buildCriteriaList('expense'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final type = _tabController.index == 0 ? 'income' : 'expense';
          _addCriteria(type);
        },
        backgroundColor: Color(0xFF14B8A6),
        child: Icon(Icons.add_rounded),
      ),
    );
  }
}

