import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:budget_app/models/budget.dart';
import 'package:budget_app/services/budget_service.dart';
import 'package:budget_app/services/budget_analysis_service.dart';
import 'package:budget_app/services/budget_notification_service.dart';
import 'package:budget_app/utils/helpers.dart';
import 'package:budget_app/utils/constants.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  _BudgetScreenState createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'monthly';
  bool _isLoading = true;
  Map<String, dynamic>? _overallBudgetStatus;
  List<Map<String, dynamic>> _categoryBudgetStatuses = [];
  BudgetSuggestion? _overallSuggestion;
  Map<String, BudgetSuggestion> _categorySuggestions = {};
  List<String> _insights = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBudgetData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBudgetData() async {
    setState(() => _isLoading = true);
    try {
      // Load overall budget
      final overallBudget =
          await BudgetService.getOverallBudget(period: _selectedPeriod);
      if (overallBudget != null && overallBudget.amount > 0) {
        _overallBudgetStatus =
            await BudgetService.getBudgetStatus(overallBudget);
      }

      // Load category budgets
      _categoryBudgetStatuses =
          await BudgetService.getAllBudgetStatuses(period: _selectedPeriod);
      _categoryBudgetStatuses = _categoryBudgetStatuses
          .where((s) => s['budget'].category != null)
          .toList();

      // Load suggestions
      _overallSuggestion =
          await BudgetAnalysisService.getSuggestedOverallBudget();
      _categorySuggestions =
          await BudgetAnalysisService.getSuggestedCategoryBudgets();
      _insights = await BudgetAnalysisService.getSpendingInsights();

      // Check budgets and notify
      await BudgetNotificationService.checkBudgetsAndNotify();
    } catch (e) {
      print('Error loading budget data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Budgets',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Period selector
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: DropdownButton<String>(
              value: _selectedPeriod,
              underline: SizedBox(),
              items: ['monthly', 'weekly', 'yearly'].map((period) {
                return DropdownMenuItem(
                  value: period,
                  child: Text(
                    period[0].toUpperCase() + period.substring(1),
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedPeriod = value);
                  _loadBudgetData();
                }
              },
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Color(0xFF14B8A6),
          unselectedLabelColor:
              theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
          indicatorColor: Color(0xFF14B8A6),
          tabs: [
            Tab(text: 'Overall', icon: Icon(Icons.account_balance_wallet)),
            Tab(text: 'Categories', icon: Icon(Icons.category)),
            Tab(text: 'Suggestions', icon: Icon(Icons.lightbulb)),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverallBudgetTab(theme, isDark),
                _buildCategoryBudgetsTab(theme, isDark),
                _buildSuggestionsTab(theme, isDark),
              ],
            ),
      floatingActionButton: _tabController.index == 2
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddBudgetDialog(context),
              backgroundColor: Color(0xFF14B8A6),
              child: Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildOverallBudgetTab(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Insights card
          if (_insights.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Color(0xFF1E293B) : Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.insights, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Spending Insights',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  ..._insights.map((insight) => Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          insight,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      )),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],

          // Overall budget card
          _overallBudgetStatus != null
              ? _buildBudgetStatusCard(_overallBudgetStatus!, theme, isDark,
                  isOverall: true)
              : _buildEmptyBudgetCard(
                  'Overall Budget',
                  'Set a monthly budget to track your total spending',
                  Icons.account_balance_wallet,
                  theme,
                  isDark,
                  onTap: () => _showAddBudgetDialog(context, isOverall: true),
                ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetsTab(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_categoryBudgetStatuses.isEmpty)
            _buildEmptyBudgetCard(
              'Category Budgets',
              'Create budgets for specific categories to better control your spending',
              Icons.category,
              theme,
              isDark,
              onTap: () => _showAddBudgetDialog(context, isOverall: false),
            )
          else
            ..._categoryBudgetStatuses.map((status) => Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: _buildBudgetStatusCard(status, theme, isDark,
                      isOverall: false),
                )),
        ],
      ),
    );
  }

  Widget _buildSuggestionsTab(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall suggestion
          if (_overallSuggestion != null) ...[
            Text(
              'Overall Budget Suggestion',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            SizedBox(height: 12),
            _buildSuggestionCard(_overallSuggestion!, null, theme, isDark),
            SizedBox(height: 24),
          ],

          // Category suggestions
          if (_categorySuggestions.isNotEmpty) ...[
            Text(
              'Category Budget Suggestions',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            SizedBox(height: 12),
            ..._categorySuggestions.entries.map((entry) => Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _buildSuggestionCard(
                      entry.value, entry.key, theme, isDark),
                )),
          ],

          if (_overallSuggestion == null && _categorySuggestions.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.analytics_outlined,
                        size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No suggestions available',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add some transactions to get personalized budget suggestions',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBudgetStatusCard(
    Map<String, dynamic> status,
    ThemeData theme,
    bool isDark, {
    required bool isOverall,
  }) {
    final budget = status['budget'] as Budget;
    final spending = status['spending'] as double;
    final remaining = status['remaining'] as double;
    final percentage = status['percentage'] as double;
    final statusType = status['status'] as String;

    final statusColor = statusType == 'exceeded'
        ? Colors.red
        : statusType == 'warning'
            ? Colors.orange
            : Colors.green;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOverall
                          ? 'Overall Budget'
                          : budget.category ?? 'Category',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Budget: ${Helpers.formatCurrency(budget.amount)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditBudgetDialog(context, budget),
                    color: Color(0xFF14B8A6),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, size: 20),
                    onPressed: () => _showDeleteBudgetDialog(context, budget),
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spent',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    Helpers.formatCurrency(spending),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Remaining',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    Helpers.formatCurrency(remaining),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: remaining >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${percentage.toStringAsFixed(1)}% Used',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(
    BudgetSuggestion suggestion,
    String? category,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFF14B8A6).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  category ?? 'Overall Budget',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF14B8A6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(suggestion.confidence * 100).toStringAsFixed(0)}% confidence',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF14B8A6),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suggested Budget',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    Helpers.formatCurrency(suggestion.amount),
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF14B8A6),
                    ),
                  ),
                ],
              ),
              if (suggestion.potentialSavings > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Potential Savings',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      Helpers.formatCurrency(suggestion.potentialSavings),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Color(0xFF14B8A6)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestion.reasoning,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _applySuggestion(suggestion, category),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF14B8A6),
                padding: EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Apply Suggestion',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBudgetCard(
    String title,
    String description,
    IconData icon,
    ThemeData theme,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Color(0xFF14B8A6).withOpacity(0.3),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 64, color: Color(0xFF14B8A6).withOpacity(0.5)),
            SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              description,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (onTap != null) ...[
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onTap,
                icon: Icon(Icons.add),
                label: Text('Create Budget'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAddBudgetDialog(BuildContext context,
      {bool isOverall = false}) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final TextEditingController amountController = TextEditingController();
    final TextEditingController thresholdController =
        TextEditingController(text: '80');
    String? selectedCategory;
    final categories = await AppConstants.getCategories('expense');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: isDark ? Color(0xFF1E293B) : Colors.white,
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFF14B8A6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isOverall
                            ? Icons.account_balance_wallet
                            : Icons.category,
                        color: Color(0xFF14B8A6),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isOverall
                            ? 'Create Overall Budget'
                            : 'Create Category Budget',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // Category dropdown (if not overall)
                if (!isOverall) ...[
                  Text(
                    'Category',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? theme.scaffoldBackgroundColor
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedCategory != null
                            ? Color(0xFF14B8A6)
                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        width: 1.5,
                      ),
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      dropdownColor: isDark ? Color(0xFF1E293B) : Colors.white,
                      style: GoogleFonts.inter(
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                      items: categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setDialogState(() => selectedCategory = value),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
                // Budget Amount
                Text(
                  'Budget Amount',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  autofocus: isOverall,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixText: 'R ',
                    prefixStyle: GoogleFonts.inter(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 16,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? theme.scaffoldBackgroundColor
                        : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color(0xFF14B8A6),
                        width: 2,
                      ),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                SizedBox(height: 20),
                // Warning Threshold
                Text(
                  'Warning Threshold',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: thresholdController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  decoration: InputDecoration(
                    hintText: '80',
                    suffixText: '%',
                    suffixStyle: GoogleFonts.inter(
                      color: theme.textTheme.bodyMedium?.color,
                      fontSize: 16,
                    ),
                    helperText: 'Get notified when you reach this percentage',
                    helperStyle: GoogleFonts.inter(
                      fontSize: 12,
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? theme.scaffoldBackgroundColor
                        : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Color(0xFF14B8A6),
                        width: 2,
                      ),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                SizedBox(height: 24),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        if (amountController.text.isNotEmpty &&
                            (isOverall || selectedCategory != null)) {
                          Navigator.pop(context, {
                            'amount':
                                double.tryParse(amountController.text) ?? 0.0,
                            'category': selectedCategory,
                            'threshold':
                                double.tryParse(thresholdController.text),
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF14B8A6),
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Create',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      try {
        await BudgetService.createBudget(
          category: result['category'],
          amount: result['amount'],
          period: _selectedPeriod,
          warningThreshold: result['threshold'],
        );
        _loadBudgetData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Budget created successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating budget: $e')),
        );
      }
    }
  }

  Future<void> _showEditBudgetDialog(
      BuildContext context, Budget budget) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final TextEditingController amountController =
        TextEditingController(text: budget.amount.toString());
    final TextEditingController thresholdController = TextEditingController(
      text: (budget.warningThreshold ?? 80.0).toString(),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: isDark ? Color(0xFF1E293B) : Colors.white,
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFF14B8A6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.edit,
                      color: Color(0xFF14B8A6),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Edit Budget',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),
              // Budget Amount
              Text(
                'Budget Amount',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  prefixText: 'R ',
                  prefixStyle: GoogleFonts.inter(
                    color: theme.textTheme.bodyMedium?.color,
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor:
                      isDark ? theme.scaffoldBackgroundColor : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Color(0xFF14B8A6),
                      width: 2,
                    ),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              SizedBox(height: 20),
              // Warning Threshold
              Text(
                'Warning Threshold',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: thresholdController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                decoration: InputDecoration(
                  hintText: '80',
                  suffixText: '%',
                  suffixStyle: GoogleFonts.inter(
                    color: theme.textTheme.bodyMedium?.color,
                    fontSize: 16,
                  ),
                  helperText: 'Get notified when you reach this percentage',
                  helperStyle: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                  filled: true,
                  fillColor:
                      isDark ? theme.scaffoldBackgroundColor : Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Color(0xFF14B8A6),
                      width: 2,
                    ),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              SizedBox(height: 24),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      if (amountController.text.isNotEmpty) {
                        Navigator.pop(context, {
                          'amount': double.tryParse(amountController.text) ??
                              budget.amount,
                          'threshold':
                              double.tryParse(thresholdController.text),
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF14B8A6),
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      try {
        final updatedBudget = budget.copyWith(
          amount: result['amount'],
          warningThreshold: result['threshold'],
        );
        await BudgetService.updateBudget(updatedBudget);
        _loadBudgetData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Budget updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating budget: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteBudgetDialog(
      BuildContext context, Budget budget) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        backgroundColor: isDark ? Color(0xFF1E293B) : Colors.white,
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Delete Budget',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'Are you sure you want to delete this budget? This action cannot be undone.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: theme.textTheme.bodyMedium?.color,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await BudgetService.deleteBudget(budget.id);
        await BudgetNotificationService.cancelBudgetNotification(budget.id);
        _loadBudgetData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Budget deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting budget: $e')),
        );
      }
    }
  }

  Future<void> _applySuggestion(
      BudgetSuggestion suggestion, String? category) async {
    try {
      await BudgetService.createBudget(
        category: category,
        amount: suggestion.amount,
        period: _selectedPeriod,
        warningThreshold: 80.0,
      );
      _loadBudgetData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Budget suggestion applied successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error applying suggestion: $e')),
      );
    }
  }
}
