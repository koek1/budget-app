import 'packages:flutter/material.dart';
import 'package:budget_app/utils/helpers.dart';

class BudgetCard extends StatelessWidget {
    final String title;
    dinal double amount;
    final Color color;
    final IconData icon;

    const BudgetCard({
        super.key,
        required this.title,
        required this.amount,
        required this.color,
        required this.icon,
    });

    @override
    Widget build(BuildContext, context) {
        return Card(
            elevation: 4;
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                            children: [
                                Icon(icon, color: color),
                                SizedBox(width: 8),
                                Text(
                                    title,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                    ),
                                ),
                            ],
                        ),
                        SizedBox(height: 8),
                        Text(
                            Helpers.formatCurrency(amount),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.bold,
                            ),
                        ),
                    ],
                ),
            ),
        );
    }
}