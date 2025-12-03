import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/utils/constants.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:budget_app/services/settings_service.dart';
import 'package:budget_app/utils/helpers.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late String _selectedType;
  String? _selectedCategory;
  late DateTime _selectedDate;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isSaving = false;
  List<String> _availableCategories = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.transaction != null;

    if (_isEditing && widget.transaction != null) {
      final transaction = widget.transaction!;
      _amountController.text = transaction.amount.toString();
      _descriptionController.text = transaction.description;
      _selectedType = transaction.type;
      _selectedCategory = transaction.category;
      _selectedDate = transaction.date;
    } else {
      _selectedType = 'expense';
      _selectedDate = DateTime.now();
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final categories = await AppConstants.getCategories(_selectedType)
          .timeout(Duration(seconds: 5), onTimeout: () {
        throw Exception('Category loading timed out');
      });
      
      if (mounted) {
        setState(() {
          _availableCategories = categories;
          if (_selectedCategory == null || !_availableCategories.contains(_selectedCategory)) {
            _selectedCategory = _availableCategories.isNotEmpty ? _availableCategories.first : null;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load categories. Please try again.';
        });
        Helpers.showErrorSnackBar(context, _errorMessage!);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      Helpers.showErrorSnackBar(context, 'Please select a category');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Get current user to associate transaction
      final currentUser = await LocalStorageService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('You must be logged in to add transactions');
      }

      // Parse and validate amount
      final amountText = _amountController.text.trim();
      if (amountText.isEmpty) {
        throw Exception('Please enter an amount');
      }
      
      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        throw Exception('Please enter a valid amount greater than 0');
      }

      final transaction = Transaction(
        id: _isEditing ? widget.transaction!.id : Uuid().v4(),
        userId: _isEditing
            ? (widget.transaction!.userId.isNotEmpty
                ? widget.transaction!.userId
                : currentUser.id) // Use existing userId or current user's id
            : currentUser.id, // Associate new transaction with current user
        amount: amount,
        type: _selectedType,
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        date: _selectedDate,
        isSynced: true,
      );

      if (_isEditing) {
        await LocalStorageService.updateTransaction(transaction)
            .timeout(Duration(seconds: 10));
      } else {
        await LocalStorageService.addTransaction(transaction)
            .timeout(Duration(seconds: 10));
      }

      if (mounted) {
        // Show success message
        Helpers.showSuccessSnackBar(
          context,
          _isEditing ? 'Transaction updated successfully' : 'Transaction added successfully',
        );
        // Small delay to show success message before navigating
        await Future.delayed(Duration(milliseconds: 300));
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error saving transaction: $e');
      String errorMessage = 'Failed to save transaction';
      if (e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = errorMessage;
        });
        Helpers.showErrorSnackBar(context, errorMessage);
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.save),
              onPressed: _saveTransaction,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Transaction Type
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        setState(() {
                          _selectedType = 'income';
                        });
                        await _loadCategories();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedType == 'income'
                              ? Colors.green.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedType == 'income'
                                ? Colors.green
                                : Colors.grey.withOpacity(0.3),
                            width: _selectedType == 'income' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_upward_rounded,
                              color: _selectedType == 'income'
                                  ? Colors.green[700]
                                  : Colors.grey[600],
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Income',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _selectedType == 'income'
                                    ? Colors.green[700]
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        setState(() {
                          _selectedType = 'expense';
                        });
                        await _loadCategories();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedType == 'expense'
                              ? Colors.red.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedType == 'expense'
                                ? Colors.red
                                : Colors.grey.withOpacity(0.3),
                            width: _selectedType == 'expense' ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              color: _selectedType == 'expense'
                                  ? Colors.red[700]
                                  : Colors.grey[600],
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Expense',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _selectedType == 'expense'
                                    ? Colors.red[700]
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      SettingsService.getCurrencySymbol(),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).scaffoldBackgroundColor
                      : Colors.grey[50],
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              // Category
              _isLoading
                  ? Container(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    )
                  : _availableCategories.isEmpty
                      ? Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red),
                              SizedBox(height: 8),
                              Text(
                                _errorMessage ?? 'No categories available',
                                style: TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              TextButton(
                                onPressed: _loadCategories,
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).scaffoldBackgroundColor
                            : Colors.grey[50],
                      ),
                      items: _availableCategories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
              SizedBox(height: 20),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 20),

              // Date
              ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text('Date'),
                subtitle: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                trailing: Icon(Icons.arrow_drop_down),
                onTap: _selectDate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
