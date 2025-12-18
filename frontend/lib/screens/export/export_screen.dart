import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:budget_app/widgets/date_range_picker.dart';
import 'package:budget_app/services/export_service.dart';
import 'package:budget_app/utils/helpers.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  _ExportScreenState createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  String _selectedReportType = 'all';
  bool _isLoading = false;
  bool _isGenerating = false;
  Map<String, dynamic>? _summary;

  final List<Map<String, String>> _reportTypes = [
    {'value': 'all', 'label': 'All Transactions'},
    {'value': 'income', 'label': 'Income Only'},
    {'value': 'expense', 'label': 'Expenses Only'},
  ];

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().subtract(Duration(days: 30));
    _endDate = DateTime.now();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    try {
      final summary = await ExportService.getReportSummary(
        startDate: _startDate,
        endDate: _endDate,
        reportType: _selectedReportType,
      );
      setState(() => _summary = summary);
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to load summary';
        if (e.toString().contains('Exception: ')) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        }
        Helpers.showErrorSnackBar(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (!mounted) return;
    
    setState(() => _isGenerating = true);

    try {
      await ExportService.exportToExcel(
      startDate: _startDate,
      endDate: _endDate,
      reportType: _selectedReportType,
      onSuccess: (message) {
        if (mounted) {
          Helpers.showSuccessSnackBar(context, message);
        }
      },
      onError: (error) {
        if (mounted) {
          Helpers.showErrorSnackBar(context, error);
        }
      },
      );
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to export report';
        if (e.toString().contains('Exception: ')) {
          errorMessage = e.toString().replaceFirst('Exception: ', '');
        }
        Helpers.showErrorSnackBar(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _onDateRangeChanged(DateTime start, DateTime end) {
    setState(() {
      _startDate = start;
      _endDate = end;
    });
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Export Report',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Range Picker Card
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xFF14B8A6).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: DateRangePicker(
                        startDate: _startDate,
                        endDate: _endDate,
                        onStartDateChanged: (date) => _onDateRangeChanged(date, _endDate),
                        onEndDateChanged: (date) => _onDateRangeChanged(_startDate, date),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Report Type Selection Card
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xFF14B8A6).withOpacity(0.3),
                          width: 1,
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
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Color(0xFF14B8A6).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.filter_list_rounded,
                                  color: Color(0xFF14B8A6),
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Report Type',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? theme.scaffoldBackgroundColor
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(0xFF14B8A6).withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedReportType,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              dropdownColor: isDark ? Color(0xFF1E293B) : Colors.white,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                              items: _reportTypes.map((type) {
                                return DropdownMenuItem(
                                  value: type['value'],
                                  child: Text(type['label']!),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => _selectedReportType = value!);
                                _loadSummary();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Summary Preview
                    if (_isLoading)
                      Container(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
                          ),
                        ),
                      )
                    else if (_summary != null)
                      _buildSummaryCard(theme, isDark),
                  ],
                ),
              ),
            ),

            // Export Button (Fixed at bottom with SafeArea)
            Container(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: _isGenerating
                    ? Container(
                        height: 56,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
                          ),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _exportToExcel,
                          icon: Icon(Icons.file_download_rounded, size: 24),
                          label: Text(
                            'Export to Excel',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF14B8A6),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, bool isDark) {
    final summary = _summary!;
    final totalIncome = (summary['totalIncome'] as num).toDouble();
    final totalExpenses = (summary['totalExpenses'] as num).toDouble();
    final netTotal = (summary['netTotal'] as num).toDouble();
    final totalTransactions = summary['totalTransactions'] as int;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFF14B8A6).withOpacity(0.3),
          width: 1,
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
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF14B8A6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.summarize_rounded,
                  color: Color(0xFF14B8A6),
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Report Summary',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _buildSummaryRow(
            theme,
            'Total Transactions',
            totalTransactions.toString(),
          ),
          SizedBox(height: 12),
          _buildSummaryRow(
            theme,
            'Total Income',
            Helpers.formatCurrency(totalIncome),
            valueColor: Colors.green,
          ),
          SizedBox(height: 12),
          _buildSummaryRow(
            theme,
            'Total Expenses',
            Helpers.formatCurrency(totalExpenses),
            valueColor: Colors.red,
          ),
          SizedBox(height: 16),
          Divider(
            color: theme.dividerColor.withOpacity(0.3),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (netTotal >= 0 ? Colors.green : Colors.red)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (netTotal >= 0 ? Colors.green : Colors.red)
                    .withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Total',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                Text(
                  Helpers.formatCurrency(netTotal),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: netTotal >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Daily Income Preview (if income report)
          if (_selectedReportType != 'expense' &&
              summary['dailyIncome'] != null)
            _buildDailyIncomePreview(theme, isDark, summary['dailyIncome']),

          if (_selectedReportType != 'expense' &&
              summary['dailyIncome'] != null)
            SizedBox(height: 20),

          // Export Insights
          _buildExportInsights(
            theme,
            isDark,
            totalIncome,
            totalExpenses,
            netTotal,
            totalTransactions,
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getExportInsights(
    double totalIncome,
    double totalExpenses,
    double netTotal,
    int totalTransactions,
  ) {
    String analysis = '';
    String recommendation = '';
    Color insightColor = Colors.blue;

    final dateRange = _endDate.difference(_startDate).inDays + 1;
    final avgTransactionAmount = totalTransactions > 0
        ? (totalIncome + totalExpenses) / totalTransactions
        : 0.0;

    if (totalTransactions == 0) {
      analysis = 'No transactions found in the selected date range.';
      recommendation =
          'Try selecting a different date range or ensure you have transactions recorded.';
      insightColor = Colors.grey;
    } else {
      // Net total analysis
      if (netTotal > 0) {
        final savingsRate =
            totalIncome > 0 ? (netTotal / totalIncome) * 100 : 0.0;
        analysis =
            'Over ${dateRange} days, you have a positive cash flow of ${Helpers.formatCurrency(netTotal.abs())} (${savingsRate.toStringAsFixed(1)}% savings rate).';
        if (savingsRate >= 20) {
          recommendation =
              'Excellent savings rate! Consider exporting this data regularly to track your financial progress over time.';
          insightColor = Colors.green;
        } else {
          recommendation =
              'Good progress! Use this export to analyze your spending patterns and identify opportunities to increase your savings rate.';
          insightColor = Colors.blue;
        }
      } else if (netTotal < 0) {
        analysis =
            'Over ${dateRange} days, you have a negative cash flow of ${Helpers.formatCurrency(netTotal.abs())}.';
        recommendation =
            'Review the exported data to identify spending patterns. Focus on reducing expenses in categories that consume the most of your budget.';
        insightColor = Colors.red;
      } else {
        analysis =
            'Your income and expenses are balanced over the selected ${dateRange} days.';
        recommendation =
            'Use this export to create a budget and set savings goals. Even small savings can add up over time.';
        insightColor = Colors.blue;
      }

      // Transaction frequency insight
      final transactionsPerDay =
          dateRange > 0 ? totalTransactions / dateRange : 0.0;
      if (transactionsPerDay > 2) {
        final frequencyInsight =
            ' You\'re averaging ${transactionsPerDay.toStringAsFixed(1)} transactions per day.';
        analysis += frequencyInsight;
      }

      // Average transaction size insight
      if (avgTransactionAmount > 0) {
        final sizeInsight =
            ' Average transaction size: ${Helpers.formatCurrency(avgTransactionAmount)}.';
        if (analysis.length < 150) {
          analysis += sizeInsight;
        }
      }
    }

    return {
      'analysis': analysis,
      'recommendation': recommendation,
      'color': insightColor,
    };
  }

  Widget _buildExportInsights(
    ThemeData theme,
    bool isDark,
    double totalIncome,
    double totalExpenses,
    double netTotal,
    int totalTransactions,
  ) {
    final insights = _getExportInsights(
      totalIncome,
      totalExpenses,
      netTotal,
      totalTransactions,
    );

    if (insights['analysis']!.isEmpty) {
      return SizedBox.shrink();
    }

    final insightColor = insights['color'] as Color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          color: theme.dividerColor.withOpacity(0.3),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: insightColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.insights_rounded,
                color: insightColor,
                size: 18,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Export Insights',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: insightColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: insightColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    color: insightColor,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Analysis',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                insights['analysis'] as String,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium?.color,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        if (insights['recommendation']!.isNotEmpty) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Colors.orange,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Recommendation',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  insights['recommendation'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryRow(
    ThemeData theme,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: valueColor ?? theme.textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyIncomePreview(
      ThemeData theme, bool isDark, List<dynamic> dailyIncome) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.trending_up_rounded,
              color: Colors.green,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Daily Income Preview',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? theme.scaffoldBackgroundColor : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ...dailyIncome.take(5).map((daily) {
                final date = DateTime.parse(daily['date']);
                final amount = (daily['amount'] as num).toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy').format(date),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      Text(
                        Helpers.formatCurrency(amount),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              if (dailyIncome.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '... and ${dailyIncome.length - 5} more days',
                    style: GoogleFonts.inter(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
