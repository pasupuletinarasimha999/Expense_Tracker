import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_providers.dart';
import '../../core/constants.dart';
import '../../data/local/database.dart';

enum TransactionFilter { all, expense, income, recurring }

final transactionFilterProvider = StateProvider<TransactionFilter>((ref) => TransactionFilter.all);

final searchQueryProvider = StateProvider<String>((ref) => '');

final allTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchAllTransactions();
});

/// Client-side filtered + searched transaction list, mirroring the original's
/// `MediatorLiveData` combining all-transactions + filter + search query.
final filteredTransactionsProvider = Provider<AsyncValue<List<Transaction>>>((ref) {
  final asyncTxns = ref.watch(allTransactionsProvider);
  final filter = ref.watch(transactionFilterProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return asyncTxns.whenData((txns) {
    return txns.where((t) {
      final matchesFilter = switch (filter) {
        TransactionFilter.all => true,
        TransactionFilter.expense => t.type == TransactionType.expense.storageName,
        TransactionFilter.income => t.type == TransactionType.income.storageName,
        TransactionFilter.recurring => t.isRecurring,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return t.title.toLowerCase().contains(query) ||
          t.category.toLowerCase().contains(query) ||
          t.notes.toLowerCase().contains(query);
    }).toList();
  });
});

final expenseCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategoriesByType(TransactionType.expense);
});

final incomeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategoriesByType(TransactionType.income);
});

final allTripsProvider = StreamProvider<List<Trip>>((ref) {
  return ref.watch(tripRepositoryProvider).watchAllTripsWithSpent().map(
        (list) => list.map((e) => e.trip).toList(),
      );
});
