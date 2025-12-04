import 'package:flutter/material.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/utils/helpers.dart';
import 'package:budget_app/utils/constants.dart';

class TransactionCard extends StatelessWidget {
    final Transaction transaction;
    final VoidCallback? onTap;

    const TransactionCard({
        super.key,
        required this.transaction,
        this.onTap,
    });

    @override
    Widget build(BuildContext context) {
        final isIncome = transaction.type == 'income';

        return Card(
            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: AppConstants.categoryColors[transaction.category] ?? Colors.grey,
                    child: Icon(
                        isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                        color: Colors.white,
                    ),
                ),
                title: Text(
                    transaction.category,
                    style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                            transaction.description.isEmpty ? 'No Description' : transaction.description,
                        ),
                        if (transaction.isRecurring || transaction.isSubscription) ...[
                            SizedBox(height: 4),
                            Row(
                                children: [
                                    Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: transaction.isSubscription 
                                                ? Colors.purple.withOpacity(0.1)
                                                : Colors.orange.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                Icon(
                                                    transaction.isSubscription 
                                                        ? Icons.subscriptions 
                                                        : Icons.repeat,
                                                    size: 10,
                                                    color: transaction.isSubscription 
                                                        ? Colors.purple 
                                                        : Colors.orange,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                    transaction.isSubscription ? 'Subscription' : 'Recurring',
                                                    style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w600,
                                                        color: transaction.isSubscription 
                                                            ? Colors.purple 
                                                            : Colors.orange,
                                                    ),
                                                ),
                                            ],
                                        ),
                                    ),
                                ],
                            ),
                        ],
                    ],
                ),
                trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                        Text(
                            Helpers.formatCurrency(transaction.amount),
                            style: TextStyle(
                                color: isIncome ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                            ),
                        ),
                        Text(
                            Helpers.FormatDate(transaction.date),
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                ),
                onTap: onTap,
            ),
        );
    }
}