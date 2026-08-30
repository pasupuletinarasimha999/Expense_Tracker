import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_time_utils.dart';
import '../../data/local/database.dart';

class TripExpenseTile extends StatelessWidget {
  final TripExpense expense;
  final String currencySymbol;
  final VoidCallback onTap;

  const TripExpenseTile({super.key, required this.expense, required this.currencySymbol, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final iconName = TripCategories.iconFor(expense.category);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        child: Icon(iconForName(iconName), color: AppColors.primary),
      ),
      title: Text(expense.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${expense.category} • ${DateTimeUtils.formatDate(expense.date)}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(CurrencyUtils.formatAmount(expense.amount, currencySymbol), style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            expense.isPaid ? 'Paid' : 'To be paid',
            style: TextStyle(
              fontSize: 11,
              color: expense.isPaid ? AppColors.incomeGreenDark : AppColors.expenseRedDark,
            ),
          ),
        ],
      ),
    );
  }
}
