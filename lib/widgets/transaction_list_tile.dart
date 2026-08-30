import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/currency_utils.dart';
import '../core/utils/date_time_utils.dart';
import '../data/local/database.dart';

class TransactionListTile extends StatelessWidget {
  final Transaction transaction;
  final String currencySymbol;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool useRelativeDate;

  const TransactionListTile({
    super.key,
    required this.transaction,
    required this.currencySymbol,
    this.onTap,
    this.onLongPress,
    this.useRelativeDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final type = TransactionTypeX.fromStorage(transaction.type);
    final category = findDefaultCategoryByName(transaction.category);
    final color = AppColors.fromHex(category.colorHex);
    final dateLabel = useRelativeDate
        ? DateTimeUtils.getRelativeDateString(transaction.timestamp)
        : DateTimeUtils.formatDate(transaction.timestamp);

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(iconForName(transaction.category == AppConstants.tripSavingsCategoryName
            ? 'ic_wallet'
            : findDefaultCategoryByName(transaction.category).iconName), color: color),
      ),
      title: Text(transaction.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Flexible(child: Text('${transaction.category} • $dateLabel', overflow: TextOverflow.ellipsis)),
          if (transaction.isRecurring) ...[
            const SizedBox(width: 4),
            const Icon(Icons.autorenew, size: 14, color: Colors.grey),
          ],
        ],
      ),
      trailing: Text(
        CurrencyUtils.formatSignedAmount(transaction.amount, type, currencySymbol),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: type == TransactionType.income ? AppColors.incomeGreenDark : AppColors.expenseRedDark,
        ),
      ),
    );
  }
}
