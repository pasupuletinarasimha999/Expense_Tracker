import 'package:flutter/material.dart';

import '../../data/repositories/transaction_repository.dart';

/// Shared 3-option recurring-delete confirmation, used from Dashboard's long-press delete,
/// the Transactions list, and the Add/Edit Transaction sheet's Delete button.
Future<RecurringDeleteScope?> showDeleteScopeDialog(BuildContext context, {required bool isRecurring}) {
  if (!isRecurring) {
    return showDialog<RecurringDeleteScope?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, RecurringDeleteScope.thisMonthOnly),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  return showDialog<RecurringDeleteScope?>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Delete Recurring Transaction'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, RecurringDeleteScope.thisMonthOnly),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('This Month Only'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, RecurringDeleteScope.thisAndFutureMonths),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('This & Future Months'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, RecurringDeleteScope.allMonths),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('All Months'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ),
      ],
    ),
  );
}
