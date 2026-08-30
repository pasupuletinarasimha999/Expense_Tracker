import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/utils/currency_utils.dart';
import '../../core/utils/date_time_utils.dart';
import 'settings_providers.dart';

Future<void> showRecurringManagerDialog(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    builder: (context) => const _RecurringManagerDialog(),
  );
}

class _RecurringManagerDialog extends ConsumerWidget {
  const _RecurringManagerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencySymbol = ref.watch(currencySymbolProvider);
    final itemsAsync = ref.watch(recurringTransactionsProvider);

    return AlertDialog(
      title: const Text('Recurring Expenses'),
      content: SizedBox(
        width: double.maxFinite,
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Text('Error: $e'),
          data: (items) {
            // Only the master row per series needs a toggle shown once — dedupe by seriesId.
            final seen = <int>{};
            final masters = items.where((t) {
              final key = t.recurringSeriesId != 0 ? t.recurringSeriesId : t.id;
              if (seen.contains(key)) return false;
              seen.add(key);
              return true;
            }).toList();

            if (masters.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No recurring transactions', style: TextStyle(color: Colors.grey)),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: masters.length,
              itemBuilder: (context, index) {
                final item = masters[index];
                return SwitchListTile(
                  title: Text(item.title),
                  subtitle: Text(
                    '${CurrencyUtils.formatAmount(item.amount, currencySymbol)} • ${DateTimeUtils.formatDate(item.timestamp)}',
                  ),
                  value: item.isRecurringActive,
                  onChanged: (value) => ref.read(transactionRepositoryProvider).updateRecurringActiveState(item.id, value),
                );
              },
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
