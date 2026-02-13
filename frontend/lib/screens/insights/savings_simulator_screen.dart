import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:budget_app/services/local_storage_service.dart';
import 'package:budget_app/services/settings_service.dart';
import 'package:budget_app/utils/helpers.dart';

class SavingsSimulatorScreen extends StatefulWidget {
  const SavingsSimulatorScreen({super.key});

  @override
  State<SavingsSimulatorScreen> createState() => _SavingsSimulatorScreenState();
}

class _SavingsSimulatorScreenState extends State<SavingsSimulatorScreen> {
  double _monthlySavings = 500;
  double _annualReturnRate = 0.08; // 8% default
  bool _isLoading = true;
  double _currentMonthlyIncome = 0;
  double _currentMonthlyExpenses = 0;
  double _currentMonthlySavingsRate = 0;
  double _unplannedMonthlySpend = 0;
  double _savedGoal = 0; // The user's persisted goal
  final TextEditingController _savingsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _savedGoal = SettingsService.getMonthlySavingsGoal();
    // Pre-set from saved goal so the UI is never blank
    if (_savedGoal > 0) {
      _monthlySavings = _savedGoal;
    }
    _savingsController.text = _monthlySavings.toStringAsFixed(0);
    _loadSpendingData();
  }

  @override
  void dispose() {
    _savingsController.dispose();
    super.dispose();
  }

  Future<void> _loadSpendingData() async {
    try {
      final transactions = await LocalStorageService.getTransactions();
      final now = DateTime.now();

      // Get last 3 months of data for a better average
      final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
      final recentTransactions = transactions.where((t) =>
          t.date.isAfter(threeMonthsAgo)).toList();

      if (recentTransactions.isEmpty) {
        setState(() {
          // Still honour the saved goal even with no transactions
          if (_savedGoal > 0) {
            _monthlySavings = _savedGoal;
          }
          _savingsController.text = _monthlySavings.toStringAsFixed(0);
          _isLoading = false;
        });
        return;
      }

      // Calculate months span
      final firstDate = recentTransactions
          .map((t) => t.date)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final monthsSpan = max(1, ((now.difference(firstDate).inDays) / 30).ceil());

      final totalIncome = recentTransactions
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.amount);
      final totalExpenses = recentTransactions
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);
      final unplannedExpenses = recentTransactions
          .where((t) => t.type == 'expense' && t.isPlanned == false)
          .fold(0.0, (sum, t) => sum + t.amount);

      setState(() {
        _currentMonthlyIncome = totalIncome / monthsSpan;
        _currentMonthlyExpenses = totalExpenses / monthsSpan;
        _currentMonthlySavingsRate = max(0, _currentMonthlyIncome - _currentMonthlyExpenses);
        _unplannedMonthlySpend = unplannedExpenses / monthsSpan;
        // Prefer saved goal > current savings rate > default 500
        if (_savedGoal > 0) {
          _monthlySavings = _savedGoal;
        } else if (_currentMonthlySavingsRate > 0) {
          _monthlySavings = _currentMonthlySavingsRate;
        } else {
          _monthlySavings = 500;
        }
        _savingsController.text = _monthlySavings.toStringAsFixed(0);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading spending data: $e');
      setState(() {
        if (_savedGoal > 0) {
          _monthlySavings = _savedGoal;
        }
        _savingsController.text = _monthlySavings.toStringAsFixed(0);
        _isLoading = false;
      });
    }
  }

  double _futureValue(double monthlyAmount, int months, double annualRate) {
    if (annualRate == 0) return monthlyAmount * months;
    final monthlyRate = annualRate / 12;
    return monthlyAmount * ((pow(1 + monthlyRate, months) - 1) / monthlyRate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = SettingsService.getCurrencySymbol();

    final saving6m = _futureValue(_monthlySavings, 6, _annualReturnRate);
    final saving1y = _futureValue(_monthlySavings, 12, _annualReturnRate);
    final saving3y = _futureValue(_monthlySavings, 36, _annualReturnRate);
    final saving5y = _futureValue(_monthlySavings, 60, _annualReturnRate);

    // "Do nothing" scenario — current savings rate
    final nothing6m = _futureValue(_currentMonthlySavingsRate, 6, _annualReturnRate);
    final nothing1y = _futureValue(_currentMonthlySavingsRate, 12, _annualReturnRate);
    final nothing3y = _futureValue(_currentMonthlySavingsRate, 36, _annualReturnRate);
    final nothing5y = _futureValue(_currentMonthlySavingsRate, 60, _annualReturnRate);

    return Scaffold(
      appBar: AppBar(title: Text('Savings Simulator')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6)))
          : ListView(
              padding: EdgeInsets.all(20),
              children: [
                // Current situation card
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Current Situation',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildStatRow('Monthly income', _currentMonthlyIncome, Colors.white),
                      SizedBox(height: 8),
                      _buildStatRow('Monthly expenses', _currentMonthlyExpenses, Colors.white),
                      if (_unplannedMonthlySpend > 0) ...[
                        SizedBox(height: 8),
                        _buildStatRow(
                          'Impulse spending',
                          _unplannedMonthlySpend,
                          Colors.orange[200]!,
                        ),
                      ],
                      Divider(color: Colors.white.withOpacity(0.3), height: 24),
                      _buildStatRow(
                        'Current savings/month',
                        _currentMonthlySavingsRate,
                        _currentMonthlySavingsRate > 0
                            ? Colors.greenAccent
                            : Colors.redAccent,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Savings slider + text input
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What if you saved...',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      SizedBox(height: 12),
                      // Amount display + text input
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            currency,
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF14B8A6),
                            ),
                          ),
                          SizedBox(width: 4),
                          IntrinsicWidth(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: 80, maxWidth: 180),
                              child: TextField(
                                controller: _savingsController,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF14B8A6),
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  border: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFF14B8A6).withOpacity(0.3)),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: Color(0xFF14B8A6), width: 2),
                                  ),
                                  hintText: '0',
                                  hintStyle: GoogleFonts.poppins(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF14B8A6).withOpacity(0.3),
                                  ),
                                ),
                                onChanged: (value) {
                                  final parsed = double.tryParse(value);
                                  if (parsed != null && parsed > 0) {
                                    final sliderMax = max(10000.0, _currentMonthlyIncome > 0 ? _currentMonthlyIncome : 10000.0);
                                    setState(() {
                                      _monthlySavings = parsed.clamp(100, sliderMax);
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          Text(
                            '/mo',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF14B8A6).withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Center(
                        child: Text(
                          'Type an amount or drag the slider',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Slider(
                        value: _monthlySavings.clamp(100, max(10000, _currentMonthlyIncome > 0 ? _currentMonthlyIncome : 10000)),
                        min: 100,
                        max: max(10000, _currentMonthlyIncome > 0 ? _currentMonthlyIncome : 10000),
                        divisions: 99,
                        activeColor: Color(0xFF14B8A6),
                        onChanged: (v) {
                          setState(() {
                            _monthlySavings = v;
                            _savingsController.text = v.toStringAsFixed(0);
                          });
                        },
                      ),
                      SizedBox(height: 12),
                      // "Set as My Goal" button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await SettingsService.setMonthlySavingsGoal(_monthlySavings);
                            setState(() => _savedGoal = _monthlySavings);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Savings goal set to ${currency}${_monthlySavings.toStringAsFixed(0)}/month!',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Color(0xFF14B8A6),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            _savedGoal > 0 && _savedGoal == _monthlySavings
                                ? Icons.check_rounded
                                : Icons.savings_rounded,
                            size: 20,
                          ),
                          label: Text(
                            _savedGoal > 0 && _savedGoal == _monthlySavings
                                ? 'Goal saved!'
                                : _savedGoal > 0
                                    ? 'Update My Goal'
                                    : 'Set as My Monthly Goal',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _savedGoal > 0 && _savedGoal == _monthlySavings
                                ? Color(0xFF14B8A6).withOpacity(0.7)
                                : Color(0xFF14B8A6),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      if (_savedGoal > 0) ...[
                        SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Current goal: ${currency}${_savedGoal.toStringAsFixed(0)}/month',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Color(0xFF14B8A6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 12),
                      if (_unplannedMonthlySpend > 0)
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.flash_on_rounded, color: Colors.orange, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You spend ~${Helpers.formatCurrency(_unplannedMonthlySpend)}/month on impulse purchases. Redirecting even half could change your future.',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.orange[800],
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Projection chart
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Future',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        height: 220,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: max(saving5y, nothing5y) * 1.2,
                            barTouchData: BarTouchData(
                              touchTooltipData: BarTouchTooltipData(
                                tooltipRoundedRadius: 8,
                                getTooltipItem: (group, gIdx, rod, rIdx) {
                                  final labels = ['6 months', '1 year', '3 years', '5 years'];
                                  return BarTooltipItem(
                                    '${labels[gIdx]}\n${Helpers.formatCurrency(rod.toY)}',
                                    TextStyle(
                                      color: rIdx == 0 ? Color(0xFF14B8A6) : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final labels = ['6mo', '1yr', '3yr', '5yr'];
                                    return Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        labels[value.toInt()],
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: theme.textTheme.bodyMedium?.color,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: FlGridData(show: false),
                            barGroups: [
                              _buildBarGroup(0, saving6m, nothing6m),
                              _buildBarGroup(1, saving1y, nothing1y),
                              _buildBarGroup(2, saving3y, nothing3y),
                              _buildBarGroup(3, saving5y, nothing5y),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      // Legend
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegend(Color(0xFF14B8A6), 'If you save'),
                          SizedBox(width: 24),
                          _buildLegend(Colors.grey[400]!, 'Current habits'),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Projection numbers
                _buildProjectionCard(
                  theme,
                  '6 Months',
                  saving6m,
                  nothing6m,
                ),
                SizedBox(height: 12),
                _buildProjectionCard(
                  theme,
                  '1 Year',
                  saving1y,
                  nothing1y,
                ),
                SizedBox(height: 12),
                _buildProjectionCard(
                  theme,
                  '3 Years',
                  saving3y,
                  nothing3y,
                ),
                SizedBox(height: 12),
                _buildProjectionCard(
                  theme,
                  '5 Years',
                  saving5y,
                  nothing5y,
                ),
                SizedBox(height: 24),

                // Motivational message
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF14B8A6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Color(0xFF14B8A6).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.auto_awesome, color: Color(0xFF14B8A6), size: 32),
                      SizedBox(height: 12),
                      Text(
                        saving5y > nothing5y
                            ? 'In 5 years, you could have ${Helpers.formatCurrency(saving5y - nothing5y)} more than your current path.'
                            : 'Start saving today \u2014 even small amounts compound over time.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D9488),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double savingValue, double currentValue) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: savingValue,
          color: Color(0xFF14B8A6),
          width: 16,
          borderRadius: BorderRadius.circular(4),
        ),
        BarChartRodData(
          toY: currentValue,
          color: Colors.grey[400]!,
          width: 16,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, color: color.withOpacity(0.9)),
        ),
        Text(
          Helpers.formatCurrency(amount),
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectionCard(
    ThemeData theme,
    String period,
    double savingAmount,
    double currentAmount,
  ) {
    final diff = savingAmount - currentAmount;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'If you save: ${Helpers.formatCurrency(savingAmount)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Color(0xFF14B8A6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Current path: ${Helpers.formatCurrency(currentAmount)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: diff > 0
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              diff > 0 ? '+${Helpers.formatCurrency(diff)}' : Helpers.formatCurrency(diff),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: diff > 0 ? Colors.green : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
