import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/utils/constants.dart';
import 'package:budget_app/services/api_service.dart';
import 'package:budget_app/services/sync_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedType = 'expense';
  String _selectedCategory = 'Food & Dining';
  DateTime _selectedDate = DateTime.now();

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final transaction = Transaction(
      id: Uuid().v4(),
      amount: double.parse(_amountController.text),
      type: _selectedType,
      category: _selectedCategory,
      description: _descriptionController.text,
      date: _selectedDate,
      isSynced: false,
    );

    // Save to local database
    final box = Hive.box<Transaction>('transactionsBox');
    await box.add(transaction);

    // Sync with server in background
    SyncService.syncTransaction(transaction);

    Navigator.pop(context);
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
        title: Text('Add Transaction'),
        actions: [
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
          child: Column(
            children: [
              // Transaction Type
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: Text('Income'),
                      leading: Radio<String>(
                        value: 'income',
                        groupValue: _selectedType,
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                            _selectedCategory = AppConstants.incomeCategories.first;
                          });
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: Text('Expense'),
                      leading: Radio<String>(
                        value: 'expense',
                        groupValue: _selectedType,
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                            _selectedCategory = AppConstants.expenseCategories.first;
                          });
                        },
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
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
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
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: (_selectedType == 'income' 
                    ? AppConstants.incomeCategories 
                    : AppConstants.expenseCategories
                ).map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value!);
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
                subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
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