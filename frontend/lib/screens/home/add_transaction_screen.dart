import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/utils/constants.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:budget_app/services/settings_service.dart';
import 'package:budget_app/utils/helpers.dart';
import 'package:budget_app/screens/receipt/receipt_scanner_screen.dart';
import 'package:budget_app/services/receipt_scanner_service.dart';

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

  // Recurring bill fields
  bool _isRecurring = false;
  DateTime? _recurringEndDate;
  String? _recurringFrequency;
  bool _isSubscription = false; // For subscriptions like Gym, Spotify, Netflix
  int? _subscriptionPaymentDay; // Day of month (1-31) when subscription is due

  @override
  void initState() {
    super.initState();
    _isEditing = widget.transaction != null;

    if (_isEditing && widget.transaction != null) {
      final transaction = widget.transaction!;
      // Format amount nicely for editing (remove unnecessary decimals)
      final amountStr = transaction.amount % 1 == 0
          ? transaction.amount.toInt().toString()
          : transaction.amount.toStringAsFixed(2);
      _amountController.text = amountStr;
      _descriptionController.text = transaction.description;
      _selectedType = transaction.type;
      _selectedCategory = transaction.category;
      _selectedDate = transaction.date;
      _isRecurring = transaction.isRecurring;
      _recurringEndDate = transaction.recurringEndDate;
      _recurringFrequency = transaction.recurringFrequency ?? 'monthly';
      _isSubscription = transaction.isSubscription;
      _subscriptionPaymentDay = transaction.subscriptionPaymentDay;
    } else {
      _selectedType = 'expense';
      _selectedDate = DateTime.now();
      _recurringFrequency = 'monthly';
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
          if (_selectedCategory == null ||
              !_availableCategories.contains(_selectedCategory)) {
            _selectedCategory = _availableCategories.isNotEmpty
                ? _availableCategories.first
                : null;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = Helpers.getUserFriendlyErrorMessage(e.toString());
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

    // Validate recurring bill fields
    if (_selectedType == 'expense' && _isRecurring) {
      // Subscriptions don't require end dates (they're ongoing)
      // Regular recurring bills need an end date
      if (!_isSubscription && _recurringEndDate == null) {
        Helpers.showErrorSnackBar(
            context, 'Please select an end date for this recurring bill. Subscriptions don\'t require end dates.');
        return;
      }
      // If end date is provided, ensure it's strictly after the transaction date
      if (_recurringEndDate != null && !_recurringEndDate!.isAfter(_selectedDate)) {
        Helpers.showErrorSnackBar(
            context, 'End date must be after the transaction date');
        return;
      }
      if (_recurringFrequency == null || _recurringFrequency!.isEmpty) {
        Helpers.showErrorSnackBar(
            context, 'Please select a frequency for the recurring bill');
        return;
      }
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

      // Parse and validate amount - handle formatted numbers
      final amountText = _amountController.text.trim()
          .replaceAll(' ', '')
          .replaceAll(',', '')
          .replaceAll('_', '');
      if (amountText.isEmpty) {
        throw Exception('Please enter an amount');
      }

      final amount = double.tryParse(amountText);
      if (amount == null) {
        throw Exception('Please enter a valid number');
      }
      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }
      if (amount < 0.01) {
        throw Exception('Amount is too small. Minimum is 0.01');
      }
      // Additional validation for reasonable amounts
      if (amount > 999999999) {
        throw Exception('Amount is too large. Maximum allowed is 999,999,999');
      }

      // Initialize price history for subscriptions
      String? priceHistory;
      if (_isSubscription && _selectedType == 'expense') {
        // Create initial price history entry
        final initialPrice = [{
          'date': _selectedDate.toIso8601String(),
          'amount': amount,
        }];
        priceHistory = jsonEncode(initialPrice);
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
        isRecurring: _selectedType == 'expense' ? _isRecurring : false,
        recurringEndDate: _selectedType == 'expense' && _isRecurring
            ? _recurringEndDate
            : null,
        recurringFrequency: _selectedType == 'expense' && _isRecurring
            ? _recurringFrequency
            : null,
        isSubscription: _selectedType == 'expense' ? _isSubscription : false,
        subscriptionPaymentDay: _selectedType == 'expense' && _isSubscription
            ? _subscriptionPaymentDay
            : null,
        subscriptionPriceHistory: _selectedType == 'expense' && _isSubscription
            ? priceHistory
            : null,
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
          _isEditing
              ? 'Transaction updated successfully'
              : 'Transaction added successfully',
        );
        
        // Show reminder for recurring bills about next due date
        if (transaction.isRecurring && transaction.type == 'expense' && transaction.recurringFrequency != null) {
          final nextDate = Helpers.getNextRecurringDate(transaction);
          if (nextDate != null) {
            // Small delay to show success message first
            await Future.delayed(Duration(milliseconds: 1500));
            
            if (mounted) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final nextDateOnly = DateTime(nextDate.year, nextDate.month, nextDate.day);
              final daysUntil = nextDateOnly.difference(today).inDays;
              
              String reminderText;
              if (daysUntil == 0) {
                reminderText = 'Next payment is due today (${Helpers.formatDateRelative(nextDate)})';
              } else if (daysUntil == 1) {
                reminderText = 'Next payment is due tomorrow (${Helpers.formatDateRelative(nextDate)})';
              } else {
                reminderText = 'Next payment due in $daysUntil days (${Helpers.formatDateRelative(nextDate)})';
              }
              
              Helpers.showInfoSnackBar(
                context,
                'Reminder: $reminderText. Balance will deduct on the due date.',
              );
            }
          }
        }
        
        // Small delay to show success message before navigating
        await Future.delayed(Duration(milliseconds: 300));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = Helpers.getUserFriendlyErrorMessage(e.toString());
        setState(() {
          _isSaving = false;
          _errorMessage = errorMessage;
        });
        // Don't show error if user cancelled or if it's a validation error (already shown)
        if (!errorMessage.toLowerCase().contains('cancelled') &&
            !errorMessage.toLowerCase().contains('validation')) {
          Helpers.showErrorSnackBar(context, errorMessage);
        }
      }
    }
  }

  Future<void> _selectDate() async {
    // Allow future dates for income (e.g., expected salary), but limit expenses to past/present
    final maxDate = _selectedType == 'income' 
        ? DateTime.now().add(Duration(days: 365)) // Allow up to 1 year in future for income
        : DateTime.now(); // Expenses can only be in the past or today
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: maxDate,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // If recurring end date exists and is now invalid (before or equal to new transaction date),
        // clear it so user must select a new valid end date
        if (_isRecurring &&
            _recurringEndDate != null &&
            !_recurringEndDate!.isAfter(_selectedDate)) {
          _recurringEndDate = null;
        }
      });
    }
  }

  Future<void> _scanReceipt() async {
    try {
      final receiptData = await Navigator.push<ReceiptData>(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiptScannerScreen(),
        ),
      );

      if (receiptData != null && mounted) {
        setState(() {
          // Fill in the form with scanned data
          if (receiptData.amount != null) {
            _amountController.text = receiptData.amount!.toStringAsFixed(2);
          }
          if (receiptData.date != null) {
            _selectedDate = receiptData.date!;
          }
          if (receiptData.merchantName != null &&
              receiptData.merchantName!.isNotEmpty) {
            _descriptionController.text = receiptData.merchantName!;
          } else if (receiptData.description != null &&
              receiptData.description!.isNotEmpty) {
            _descriptionController.text = receiptData.description!;
          }
          if (receiptData.suggestedCategory != null) {
            // Load categories first, then set the suggested category
            _loadCategories().then((_) {
              if (_availableCategories
                  .contains(receiptData.suggestedCategory)) {
                setState(() {
                  _selectedCategory = receiptData.suggestedCategory;
                });
              }
            });
          }
        });

        // Show success message
        Helpers.showSuccessSnackBar(
          context,
          'Receipt scanned successfully! Please review and save.',
        );
      }
    } catch (e) {
      print('Error scanning receipt: $e');
      if (mounted) {
        Helpers.showErrorSnackBar(
          context,
          'Failed to scan receipt: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _selectRecurringEndDate() async {
    // Ensure the first selectable date is at least one day after the transaction date
    final minEndDate = _selectedDate.add(Duration(days: 1));
    final maxEndDate =
        DateTime.now().add(Duration(days: 3650)); // 10 years from now

    // Clamp initialDate to valid range [minEndDate, maxEndDate]
    // This prevents assertion errors when _recurringEndDate is invalid after _selectedDate changes
    DateTime initialDate;
    if (_recurringEndDate != null) {
      if (_recurringEndDate!.isBefore(minEndDate)) {
        // If existing end date is before minimum, use minimum
        initialDate = minEndDate;
      } else if (_recurringEndDate!.isAfter(maxEndDate)) {
        // If existing end date is after maximum, use maximum
        initialDate = maxEndDate;
      } else {
        // Existing end date is valid
        initialDate = _recurringEndDate!;
      }
    } else {
      // No existing end date, use minimum
      initialDate = minEndDate;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minEndDate, // Prevent selecting the same date as transaction
      lastDate: maxEndDate,
    );
    if (picked != null) {
      setState(() => _recurringEndDate = picked);
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
              onPressed: _isSaving ? null : _saveTransaction,
              tooltip: _isEditing ? 'Update Transaction' : 'Save Transaction',
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

              // Scan Receipt Button
              if (!_isEditing)
                Container(
                  margin: EdgeInsets.only(bottom: 20),
                  child: ElevatedButton.icon(
                    onPressed: _scanReceipt,
                    icon: Icon(Icons.camera_alt),
                    label: Text('Scan Receipt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF14B8A6),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

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
                inputFormatters: [
                  // Allow only numbers and one decimal point, max 2 decimal places
                  // More permissive to allow user-friendly input
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  // Remove any spaces, commas, or other formatting
                  final cleanedValue = value.trim()
                      .replaceAll(' ', '')
                      .replaceAll(',', '')
                      .replaceAll('_', '');
                  if (cleanedValue.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(cleanedValue);
                  if (amount == null) {
                    return 'Please enter a valid number';
                  }
                  if (amount <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  if (amount < 0.01) {
                    return 'Amount is too small (min: 0.01)';
                  }
                  if (amount > 999999999) {
                    return 'Amount is too large (max: 999,999,999)';
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
                            border:
                                Border.all(color: Colors.red.withOpacity(0.3)),
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
                          initialValue: _selectedCategory,
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
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
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
                            setState(() {
                              _selectedCategory = value;
                              // Auto-enable subscription mode if Subscriptions category is selected
                              if (value == 'Subscriptions' && _selectedType == 'expense') {
                                _isSubscription = true;
                                _isRecurring = true;
                                _recurringFrequency = 'monthly';
                                // Set payment day to the day of the selected date if not set
                                if (_subscriptionPaymentDay == null) {
                                  _subscriptionPaymentDay = _selectedDate.day;
                                }
                              } else if (value != 'Subscriptions') {
                                // If switching away from Subscriptions, keep subscription settings but allow user to change
                              }
                            });
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
                  hintText: 'Add a note about this transaction',
                  prefixIcon: Icon(Icons.note_outlined),
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
                maxLines: 2,
              ),
              SizedBox(height: 20),

              // Date
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).scaffoldBackgroundColor
                        : Colors.grey[50],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: const Color(0xFF14B8A6),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              Helpers.formatDateRelative(_selectedDate),
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Recurring Bill Section (only for expenses)
              if (_selectedType == 'expense') ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Color(0xFF1E293B)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.repeat,
                            color: const Color(0xFF14B8A6),
                            size: 24,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Recurring Bill',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                          ),
                          Switch(
                            value: _isRecurring,
                            onChanged: (value) {
                              setState(() {
                                _isRecurring = value;
                                if (!value) {
                                  _recurringEndDate = null;
                                  _recurringFrequency = 'monthly';
                                  _isSubscription = false; // Reset subscription when recurring is disabled
                                }
                              });
                            },
                            activeThumbColor: const Color(0xFF14B8A6),
                          ),
                        ],
                      ),
                      if (_isRecurring) ...[
                        SizedBox(height: 20),
                        // Frequency dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _recurringFrequency,
                          decoration: InputDecoration(
                            labelText: 'Frequency',
                            prefixIcon: Icon(Icons.schedule),
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
                                color: const Color(0xFF14B8A6),
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Theme.of(context).scaffoldBackgroundColor
                                    : Colors.white,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'weekly',
                              child: Text('Weekly'),
                            ),
                            DropdownMenuItem(
                              value: 'biweekly',
                              child: Text('Bi-weekly'),
                            ),
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text('Monthly'),
                            ),
                            DropdownMenuItem(
                              value: 'yearly',
                              child: Text('Yearly'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _recurringFrequency = value);
                          },
                          validator: (value) {
                            if (_isRecurring &&
                                (value == null || value.isEmpty)) {
                              return 'Please select a frequency';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        // End date picker (only shown for non-subscriptions)
                        if (!_isSubscription) ...[
                          InkWell(
                            onTap: _selectRecurringEndDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).dividerColor,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Theme.of(context).scaffoldBackgroundColor
                                    : Colors.white,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: const Color(0xFF14B8A6),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'End Date',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _recurringEndDate != null
                                              ? Helpers.formatDateRelative(_recurringEndDate!)
                                              : 'Select end date',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: _recurringEndDate != null
                                                ? Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.color
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_recurringEndDate == null)
                            Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 14, color: Colors.orange),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Required: Select when this recurring bill will end',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ] else ...[
                          // Show info for subscriptions (no end date needed)
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Subscriptions continue indefinitely until you cancel them. No end date required.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      // Subscription option (only for recurring expenses)
                      if (_isRecurring && _selectedType == 'expense') ...[
                        SizedBox(height: 20),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).brightness ==
                                    Brightness.dark
                                ? Theme.of(context).scaffoldBackgroundColor
                                : Colors.white,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.subscriptions,
                                color: const Color(0xFF14B8A6),
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Subscription',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Ongoing service (Gym, Spotify, Netflix, etc.) - No end date needed',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isSubscription,
                                onChanged: (value) {
                                  setState(() {
                                    _isSubscription = value;
                                    // Clear end date when switching to subscription
                                    if (value) {
                                      _recurringEndDate = null;
                                      // Set default payment day if not set
                                      if (_subscriptionPaymentDay == null) {
                                        _subscriptionPaymentDay = _selectedDate.day;
                                      }
                                    }
                                  });
                                },
                                activeThumbColor: const Color(0xFF14B8A6),
                              ),
                            ],
                          ),
                        ),
                        // Payment day selector for subscriptions
                        if (_isSubscription) ...[
                          SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            value: _subscriptionPaymentDay,
                            decoration: InputDecoration(
                              labelText: 'Payment Day (Day of Month)',
                              prefixIcon: Icon(Icons.calendar_today),
                              helperText: 'Select which day of the month this subscription is charged',
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
                                  color: const Color(0xFF14B8A6),
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Theme.of(context).brightness == Brightness.dark
                                  ? Theme.of(context).scaffoldBackgroundColor
                                  : Colors.white,
                            ),
                            items: List.generate(31, (index) {
                              final day = index + 1;
                              return DropdownMenuItem(
                                value: day,
                                child: Text('Day $day'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _subscriptionPaymentDay = value);
                            },
                            validator: (value) {
                              if (_isSubscription && (value == null)) {
                                return 'Please select a payment day';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
