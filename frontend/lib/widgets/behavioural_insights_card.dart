import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/utils/helpers.dart';

/// A card widget that shows behavioural spending insights:
/// - Planned vs impulse spending breakdown
/// - Regret ratio per category
/// - Top impulse categories
class BehaviouralInsightsCard extends StatelessWidget {
  final List<Transaction> transactions;

  const BehaviouralInsightsCard({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenses = transactions.where((t) => t.type == 'expense').toList();

    if (expenses.isEmpty) return SizedBox.shrink();

    // Calculate behavioural stats
    final withPlanData = expenses.where((t) => t.isPlanned != null).toList();
    final impulse = withPlanData.where((t) => t.isPlanned == false).toList();
    final totalExpenseAmount = expenses.fold(0.0, (sum, t) => sum + t.amount);
    final impulseAmount = impulse.fold(0.0, (sum, t) => sum + t.amount);

    // Regret stats
    final rated = expenses.where((t) => t.regretStatus != null).toList();
    final regretted = rated.where((t) => t.regretStatus == 'not_worth_it').toList();
    final regretAmount = regretted.fold(0.0, (sum, t) => sum + t.amount);

    // If no behavioural data at all, show a prompt
    if (withPlanData.isEmpty && rated.isEmpty) {
      return _buildPromptCard(theme);
    }

    // Category regret breakdown
    Map<String, Map<String, dynamic>> categoryRegret = {};
    for (var t in rated) {
      categoryRegret.putIfAbsent(t.category, () => {
        'total': 0,
        'regretted': 0,
        'regretAmount': 0.0,
      });
      categoryRegret[t.category]!['total'] =
          (categoryRegret[t.category]!['total'] as int) + 1;
      if (t.regretStatus == 'not_worth_it') {
        categoryRegret[t.category]!['regretted'] =
            (categoryRegret[t.category]!['regretted'] as int) + 1;
        categoryRegret[t.category]!['regretAmount'] =
            (categoryRegret[t.category]!['regretAmount'] as double) + t.amount;
      }
    }

    // Sort categories by regret ratio
    final sortedCategories = categoryRegret.entries
        .where((e) => (e.value['regretted'] as int) > 0)
        .toList()
      ..sort((a, b) {
        final ratioA = (a.value['regretted'] as int) / (a.value['total'] as int);
        final ratioB = (b.value['regretted'] as int) / (b.value['total'] as int);
        return ratioB.compareTo(ratioA);
      });

    // Top impulse categories
    Map<String, double> impulseByCategory = {};
    for (var t in impulse) {
      impulseByCategory[t.category] =
          (impulseByCategory[t.category] ?? 0) + t.amount;
    }
    final sortedImpulseCategories = impulseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
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
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: Color(0xFF14B8A6), size: 24),
              SizedBox(width: 12),
              Text(
                'Behaviour Insights',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Planned vs Impulse breakdown
          if (withPlanData.isNotEmpty) ...[
            _buildInsightTile(
              theme,
              icon: Icons.flash_on_rounded,
              iconColor: Colors.orange,
              title: 'Impulse spending',
              value: Helpers.formatCurrency(impulseAmount),
              subtitle: impulseAmount > 0 && totalExpenseAmount > 0
                  ? '${(impulseAmount / totalExpenseAmount * 100).toStringAsFixed(0)}% of your spending was unplanned'
                  : 'All your spending was planned',
              valueColor: impulseAmount > 0 ? Colors.orange : Colors.green,
            ),
            SizedBox(height: 12),
          ],

          // Regret summary
          if (rated.isNotEmpty) ...[
            _buildInsightTile(
              theme,
              icon: Icons.thumb_down_rounded,
              iconColor: Colors.red,
              title: 'Spending you regret',
              value: Helpers.formatCurrency(regretAmount),
              subtitle: regretted.isNotEmpty
                  ? '${regretted.length} of ${rated.length} rated transactions weren\'t worth it'
                  : 'Everything you rated was worth it!',
              valueColor: regretAmount > 0 ? Colors.red : Colors.green,
            ),
            SizedBox(height: 12),
          ],

          // Top impulse categories
          if (sortedImpulseCategories.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              'Top impulse categories',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            ...sortedImpulseCategories.take(3).map((entry) {
              final percentage = totalExpenseAmount > 0
                  ? (entry.value / totalExpenseAmount * 100)
                  : 0.0;
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.flash_on_rounded, size: 16, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    Text(
                      '${Helpers.formatCurrency(entry.value)} (${percentage.toStringAsFixed(0)}%)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Categories with highest regret
          if (sortedCategories.isNotEmpty) ...[
            SizedBox(height: 16),
            Text(
              'Highest regret categories',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
            SizedBox(height: 8),
            ...sortedCategories.take(3).map((entry) {
              final ratio = (entry.value['regretted'] as int) /
                  (entry.value['total'] as int);
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.thumb_down_rounded, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                    Text(
                      '${(ratio * 100).toStringAsFixed(0)}% regret',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightTile(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required Color valueColor,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: valueColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCard(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF14B8A6).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Color(0xFF14B8A6).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.psychology_rounded, color: Color(0xFF14B8A6), size: 40),
          SizedBox(height: 12),
          Text(
            'Unlock Behaviour Insights',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'When adding expenses, mark them as planned or impulse. Rate past transactions as "worth it" or "not worth it" to unlock personalised insights.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.textTheme.bodyMedium?.color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
