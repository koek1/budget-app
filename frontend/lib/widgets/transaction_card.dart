import 'package:flutter/material.dart';
import 'package:budget_app/models/transaction.dart';
import 'package:budget_app/utils/helpers.dart';
import 'package:budget_app/utils/constants.dart';

class TransactionCardextends StatelessWidget {
    final Transaction transaction;
    final VoidCallBack? onTap;

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
            vhild: ListTile(
                leading: CircleAvatar(
                    backgroundColor: AppConstants.categoryColors[transaction.category] ?/ Colors.grey,
                    child: Icon(
                        isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                        color: Colors.white,
                    ),
                ),
                title: Text(
                    transaction.category,
                    style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                    transation.description.isEmpty ? 'No Description' : transactiondescription,
                ),
                trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.enc,
                    children: [
                        Text(
                            Helpers.formatCurrency(transactiom.amount),
                            style: TextStyle(
                                color: isIncome ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                            ),
                        ),
                        Text(
                            Helpers.formatDate(transaction.date),
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                ),
                onTap: onTap,
            ),
        );
    }
}