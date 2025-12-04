import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load summary: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToExcel() async {
    setState(() => _isGenerating = true);

    await ExportService.exportToExcel(
      startDate: _startDate,
      endDate: _endDate,
      reportType: _selectedReportType,
      onSuccess: (message) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      },
    );

    setState(() => _isGenerating = false);
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Export Report'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Date Range Picker
            DateRangePicker(
              startDate: _startDate,
              endDate: _endDate,
              onStartDateChanged: (date) => _onDateRangeChanged(date, _endDate),
              onEndDateChanged: (date) => _onDateRangeChanged(_startDate, date),
            ),
            SizedBox(height: 24),

            // Report Type Selection
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedReportType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
              ],
            ),
            SizedBox(height: 24),

            // Summary Preview
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_summary != null)
              _buildSummaryCard(),
            SizedBox(height: 24),

            // Export Button
            _isGenerating
                ? Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _exportToExcel,
                      icon: Icon(Icons.file_download),
                      label: Text('Export to Excel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = _summary!;
    final totalIncome = (summary['totalIncome'] as num).toDouble();
    final totalExpenses = (summary['totalExpenses'] as num).toDouble();
    final netTotal = (summary['netTotal'] as num).toDouble();
    final totalTransactions = summary['totalTransactions'] as int;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: 16),
            _buildSummaryRow(
                'Total Transactions', totalTransactions.toString()),
            _buildSummaryRow(
                'Total Income', Helpers.formatCurrency(totalIncome)),
            _buildSummaryRow(
                'Total Expenses', Helpers.formatCurrency(totalExpenses)),
            Divider(),
            _buildSummaryRow(
              'Net Total',
              Helpers.formatCurrency(netTotal),
              isBold: true,
              color: netTotal >= 0 ? Colors.green : Colors.red,
            ),
            SizedBox(height: 16),

            // Daily Income Preview (if income report)
            if (_selectedReportType != 'expense' &&
                summary['dailyIncome'] != null)
              _buildDailyIncomePreview(summary['dailyIncome']),

            SizedBox(height: 16),

            // Export Insights
            _buildExportInsights(
              totalIncome,
              totalExpenses,
              netTotal,
              totalTransactions,
            ),
          ],
        ),
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
    double totalIncome,
    double totalExpenses,
    double netTotal,
    int totalTransactions,
  ) {
    final theme = Theme.of(context);
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
        Divider(),
        SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.insights_rounded,
              color: insightColor,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Export Insights',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
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
                    style: TextStyle(
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
                style: TextStyle(
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
                      style: TextStyle(
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
                  style: TextStyle(
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

  Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyIncomePreview(List<dynamic> dailyIncome) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Income:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        ...dailyIncome.take(5).map((daily) {
          final date = DateTime.parse(daily['date']);
          final amount = (daily['amount'] as num).toDouble();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('MMM dd').format(date)),
                Text(
                  Helpers.formatCurrency(amount),
                  style: TextStyle(color: Colors.green),
                ),
              ],
            ),
          );
        }).toList(),
        if (dailyIncome.length > 5)
          Text(
            '... and ${dailyIncome.length - 5} more days',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
      ],
    );
  }
}
