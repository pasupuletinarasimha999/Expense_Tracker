import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/constants.dart';
import '../../core/utils/currency_utils.dart';
import '../../data/local/database.dart';
import '../../widgets/transaction_list_tile.dart';
import 'add_edit_transaction_sheet.dart';
import 'recurring_scope_dialog.dart';
import 'transactions_providers.dart';

/// Ported 1:1 from `TransactionsFragment.kt` + `TransactionsViewModel.kt`.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  Future<void> _onLongPress(BuildContext context, WidgetRef ref, Transaction transaction) async {
    final scope = await showDeleteScopeDialog(context, isRecurring: transaction.isRecurring);
    if (scope == null) return;
    await ref.read(transactionRepositoryProvider).deleteTransaction(transaction, scope: scope);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencySymbol = ref.watch(currencySymbolProvider);
    final filteredAsync = ref.watch(filteredTransactionsProvider);
    final filter = ref.watch(transactionFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: filter == TransactionFilter.all,
                  onTap: () => ref.read(transactionFilterProvider.notifier).state = TransactionFilter.all,
                ),
                _FilterChip(
                  label: 'Expenses',
                  selected: filter == TransactionFilter.expense,
                  onTap: () => ref.read(transactionFilterProvider.notifier).state = TransactionFilter.expense,
                ),
                _FilterChip(
                  label: 'Income',
                  selected: filter == TransactionFilter.income,
                  onTap: () => ref.read(transactionFilterProvider.notifier).state = TransactionFilter.income,
                ),
                _FilterChip(
                  label: 'Recurring',
                  selected: filter == TransactionFilter.recurring,
                  onTap: () => ref.read(transactionFilterProvider.notifier).state = TransactionFilter.recurring,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No transactions found', style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }

                final total = list.fold<double>(
                  0,
                  (sum, t) => sum + (t.type == TransactionType.income.storageName ? t.amount : -t.amount),
                );

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Showing ${list.length} transaction${list.length != 1 ? 's' : ''}'),
                          Text('Net: ${CurrencyUtils.formatBalance(total, currencySymbol)}'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final txn = list[index];
                          return TransactionListTile(
                            transaction: txn,
                            currencySymbol: currencySymbol,
                            onTap: () => showAddEditTransactionSheet(context, editing: txn),
                            onLongPress: () => _onLongPress(context, ref, txn),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}
