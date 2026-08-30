import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../local/daos/transaction_dao.dart';
import '../local/database.dart';
import '../models.dart';
import '../preferences/user_preferences.dart';
import '../remote/drive_sync_manager.dart';

enum RecurringUpdateScope { thisMonthOnly, thisAndFutureMonths }

enum RecurringDeleteScope { thisMonthOnly, thisAndFutureMonths, allMonths }

/// Mediates access to transactions, seamless recurring adjustments, per-month
/// deletion/override scopes, and automated Google Drive syncing.
/// Ported 1:1 from `TransactionRepository.kt`.
///
/// DESIGN: When a recurring transaction is created, concrete rows are inserted for the
/// current month + 24 future months. Each row has its own unique id and shares the same
/// `recurringSeriesId`. This makes per-month editing and deletion trivial.
class TransactionRepository {
  final TransactionDao _dao;
  final UserPreferences _preferences;
  final DriveSyncManager _syncManager;

  TransactionRepository(this._dao, this._preferences, this._syncManager);

  Stream<List<Transaction>> watchAllTransactions() => _dao.watchAllTransactions();

  Stream<List<Transaction>> watchRecentTransactions({int limit = 10}) => _dao.watchRecentTransactions(limit);

  Stream<List<Transaction>> watchTransactionsBetween(int startDate, int endDate) =>
      _dao.watchTransactionsBetween(startDate, endDate);

  Future<List<Transaction>> getTransactionsBetweenSync(int startDate, int endDate) =>
      _dao.getTransactionsBetweenSync(startDate, endDate);

  Stream<List<Transaction>> watchRecurringTransactions() => _dao.watchRecurringTransactions();

  Stream<List<Transaction>> searchTransactions(String query) => _dao.searchTransactions(query);

  /// Inserts a transaction. If marked as recurring, creates concrete rows for the next
  /// 24 months (each with its own id, sharing `recurringSeriesId`).
  Future<int> insertTransaction(TransactionsCompanion transaction) async {
    final insertedId = await _dao.insertTransaction(transaction);

    if (transaction.isRecurring.present && transaction.isRecurring.value) {
      final seriesId = insertedId;

      // Update master row to set its own recurringSeriesId.
      final masterEntry = transaction.copyWith(
        id: Value(insertedId),
        recurringSeriesId: Value(seriesId),
        effectiveFromTimestamp: Value(transaction.timestamp.value),
      );
      await _dao.updateTransaction(masterEntry);

      final futureList = _buildFutureRecurringEntries(masterEntry, seriesId);
      await _dao.insertAll(futureList);
    }

    _pushToGoogleCloud();
    return insertedId;
  }

  /// Generates the next 24 months of concrete recurring rows from [origin], clamping the
  /// day-of-month for shorter months (e.g. Jan 31 -> Feb 28/29).
  List<TransactionsCompanion> _buildFutureRecurringEntries(TransactionsCompanion origin, int seriesId) {
    final originDate = DateTime.fromMillisecondsSinceEpoch(origin.timestamp.value);
    final originalDay = originDate.day;

    final futureList = <TransactionsCompanion>[];
    for (var i = 1; i <= 24; i++) {
      // Compute a fresh target month/year each time to avoid cumulative drift.
      final targetMonthIndex = originDate.month - 1 + i; // 0-based
      final targetYear = originDate.year + targetMonthIndex ~/ 12;
      final targetMonth = targetMonthIndex % 12 + 1;
      final maxDays = DateTime(targetYear, targetMonth + 1, 0).day;
      final clampedDay = originalDay < maxDays ? originalDay : maxDays;
      final futureDate = DateTime(
        targetYear,
        targetMonth,
        clampedDay,
        originDate.hour,
        originDate.minute,
        originDate.second,
        originDate.millisecond,
      );
      final futureTimestamp = futureDate.millisecondsSinceEpoch;

      futureList.add(
        TransactionsCompanion.insert(
          title: origin.title.value,
          amount: origin.amount.value,
          type: origin.type.value,
          category: origin.category.value,
          timestamp: futureTimestamp,
          notes: Value(origin.notes.value),
          isRecurring: const Value(true),
          recurringInterval: Value(origin.recurringInterval.value),
          isRecurringActive: const Value(true),
          lastProcessedDate: futureTimestamp,
          recurringSeriesId: Value(seriesId),
          effectiveFromTimestamp: futureTimestamp,
          paymentMethod: Value(origin.paymentMethod.value),
          tripId: Value(origin.tripId.value),
        ),
      );
    }
    return futureList;
  }

  /// - [RecurringUpdateScope.thisMonthOnly]: updates only this specific month's row.
  /// - [RecurringUpdateScope.thisAndFutureMonths]: bulk SQL UPDATE on all rows in the series
  ///   from this month onward. No new rows are created — existing rows are updated in place.
  Future<void> updateRecurringTransaction(TransactionsCompanion transaction, RecurringUpdateScope scope) async {
    final seriesId = transaction.recurringSeriesId.present ? transaction.recurringSeriesId.value : 0;

    if (seriesId == 0) {
      // This row was never part of a recurring series before now (recurring was just
      // switched on while editing a previously one-off transaction) — establish a new
      // series and generate future months, same as a brand-new recurring transaction.
      await _establishRecurringSeries(transaction);
      _pushToGoogleCloud();
      return;
    }

    if (scope == RecurringUpdateScope.thisMonthOnly) {
      await _dao.updateTransaction(transaction);
    } else {
      final txnDate = DateTime.fromMillisecondsSinceEpoch(transaction.timestamp.value);
      final startOfMonth = DateTime(txnDate.year, txnDate.month, 1).millisecondsSinceEpoch;

      await _dao.updateSeriesFromTimestamp(
        seriesId: seriesId,
        fromTimestamp: startOfMonth,
        amount: transaction.amount.value,
        title: transaction.title.value,
        category: transaction.category.value,
        notes: transaction.notes.value,
        paymentMethod: transaction.paymentMethod.value,
        tripId: transaction.tripId.value,
      );
    }
    _pushToGoogleCloud();
  }

  /// Turns an existing one-off transaction into the master of a brand-new recurring series.
  Future<void> _establishRecurringSeries(TransactionsCompanion transaction) async {
    final seriesId = transaction.id.value;
    final masterEntry = transaction.copyWith(
      recurringSeriesId: Value(seriesId),
      isRecurringActive: const Value(true),
      effectiveFromTimestamp: Value(transaction.timestamp.value),
    );
    await _dao.updateTransaction(masterEntry);

    final futureList = _buildFutureRecurringEntries(masterEntry, seriesId);
    await _dao.insertAll(futureList);
  }

  Future<void> updateTransaction(TransactionsCompanion transaction) async {
    if (transaction.isRecurring.present && transaction.isRecurring.value) {
      await updateRecurringTransaction(transaction, RecurringUpdateScope.thisAndFutureMonths);
    } else {
      await _dao.updateTransaction(transaction);
      _pushToGoogleCloud();
    }
  }

  /// - [RecurringDeleteScope.thisMonthOnly]: deletes only this specific month's entry.
  /// - [RecurringDeleteScope.thisAndFutureMonths]: deletes from this month onward.
  /// - [RecurringDeleteScope.allMonths]: deletes all entries in the entire series.
  Future<void> deleteTransaction(
    Transaction transaction, {
    RecurringDeleteScope scope = RecurringDeleteScope.thisMonthOnly,
  }) async {
    if (!transaction.isRecurring || scope == RecurringDeleteScope.thisMonthOnly) {
      await _dao.deleteTransactionById(transaction.id);
    } else {
      final seriesId = transaction.recurringSeriesId != 0 ? transaction.recurringSeriesId : transaction.id;
      if (scope == RecurringDeleteScope.thisAndFutureMonths) {
        final txnDate = DateTime.fromMillisecondsSinceEpoch(transaction.timestamp);
        final startOfMonth = DateTime(txnDate.year, txnDate.month, 1).millisecondsSinceEpoch;
        await _dao.deleteSeriesFromTimestamp(seriesId, startOfMonth);
      } else {
        await _dao.deleteRecurringSeries(seriesId);
      }
    }
    _pushToGoogleCloud();
  }

  Future<void> deleteTransactionById(int id) async {
    await _dao.deleteTransactionById(id);
    _pushToGoogleCloud();
  }

  Future<void> deleteAllTransactions() async {
    await _dao.deleteAllTransactions();
    _pushToGoogleCloud();
  }

  Future<void> updateRecurringActiveState(int id, bool isActive) async {
    final txn = await _dao.getTransactionById(id);
    final seriesId = (txn != null && txn.recurringSeriesId != 0) ? txn.recurringSeriesId : id;
    await _dao.updateRecurringActiveState(seriesId, isActive);
    _pushToGoogleCloud();
  }

  Future<void> setPaidStatus(int transactionId, bool isPaid) async {
    await _dao.updateIsPaid(transactionId, isPaid);
    _pushToGoogleCloud();
  }

  void _pushToGoogleCloud() {
    final email = _preferences.userEmail;
    if (email.trim().isNotEmpty) {
      debugPrint('TransactionRepository: triggering auto-push for $email');
      // Best-effort, fire-and-forget — mirrors the original's app-lifetime coroutine scope.
      // ignore: discarded_futures
      _syncManager.pushUserData(email);
    } else {
      debugPrint('TransactionRepository: skipping auto-push, no signed-in email in preferences');
    }
  }

  Future<int> processRecurringTransactions() async {
    _preferences.lastRecurringSync = DateTime.now().millisecondsSinceEpoch;
    return 0;
  }

  Stream<MonthlySummary> watchMonthlySummary(int startDate, int endDate) {
    return watchTransactionsBetween(startDate, endDate).map((transactions) {
      var income = 0.0, expense = 0.0;
      for (final txn in transactions) {
        if (txn.type == TransactionType.income.storageName) {
          income += txn.amount;
        } else {
          expense += txn.amount;
        }
      }
      return MonthlySummary(totalIncome: income, totalExpense: expense, balance: income - expense);
    });
  }

  Stream<List<CategorySummary>> watchCategoryBreakdown(int startDate, int endDate) {
    return watchTransactionsBetween(startDate, endDate).map(
      (transactions) => _breakdownByCategory(
        transactions.where((t) => t.type == TransactionType.expense.storageName).toList(),
      ),
    );
  }

  /// Sum of every transaction tagged to a trip's savings goal, across all months — past,
  /// current, and future allocations you've explicitly tagged all count toward the goal.
  Stream<double> watchSavingsForTrip(int tripId) => _dao.watchTotalTaggedToTrip(tripId);

  Stream<List<CategorySummary>> watchPaymentMethodBreakdown(int startDate, int endDate) {
    return watchTransactionsBetween(startDate, endDate).map((transactions) {
      final expenseTxns = transactions.where((t) => t.type == TransactionType.expense.storageName).toList();
      final totalExpense = expenseTxns.fold<double>(0, (sum, t) => sum + t.amount);
      if (totalExpense <= 0) return <CategorySummary>[];

      final grouped = <String, List<Transaction>>{};
      for (final t in expenseTxns) {
        grouped.putIfAbsent(t.paymentMethod, () => []).add(t);
      }

      final result = grouped.entries.map((entry) {
        final amount = entry.value.fold<double>(0, (sum, t) => sum + t.amount);
        return CategorySummary(
          categoryName: entry.key,
          totalAmount: amount,
          percentage: (amount / totalExpense) * 100,
          colorHex: PaymentMethod.colorFor(entry.key),
          transactionCount: entry.value.length,
        );
      }).toList();
      result.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
      return result;
    });
  }

  /// Category breakdown restricted to a single payment method's expenses — the "drill-down" view.
  Future<List<CategorySummary>> getCategoryBreakdownForPaymentMethod(
    int startDate,
    int endDate,
    String paymentMethod,
  ) async {
    final transactions = await getTransactionsBetweenSync(startDate, endDate);
    final expenseTxns = transactions
        .where((t) => t.type == TransactionType.expense.storageName && t.paymentMethod == paymentMethod)
        .toList();
    return _breakdownByCategory(expenseTxns);
  }

  List<CategorySummary> _breakdownByCategory(List<Transaction> expenseTxns) {
    final totalExpense = expenseTxns.fold<double>(0, (sum, t) => sum + t.amount);
    if (totalExpense <= 0) return [];

    final grouped = <String, List<Transaction>>{};
    for (final t in expenseTxns) {
      grouped.putIfAbsent(t.category, () => []).add(t);
    }

    final result = grouped.entries.map((entry) {
      final amount = entry.value.fold<double>(0, (sum, t) => sum + t.amount);
      final categoryObj = findDefaultCategoryByName(entry.key);
      return CategorySummary(
        categoryName: entry.key,
        totalAmount: amount,
        percentage: (amount / totalExpense) * 100,
        colorHex: categoryObj.colorHex,
        transactionCount: entry.value.length,
      );
    }).toList();
    result.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return result;
  }

  /// Fiscal year runs April 1 -> March 31.
  Future<FiscalYearSummary> getFiscalYearSummary(int startYear) async {
    final startMillis = DateTime(startYear, 4, 1).millisecondsSinceEpoch;
    final endMillis = DateTime(startYear + 1, 3, 31, 23, 59, 59, 999).millisecondsSinceEpoch;

    final txns = await getTransactionsBetweenSync(startMillis, endMillis);
    final income = txns
        .where((t) => t.type == TransactionType.income.storageName)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final expense = txns
        .where((t) => t.type == TransactionType.expense.storageName)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final netSavings = income - expense;

    final savingsRate = income > 0 ? ((netSavings / income) * 100).clamp(0.0, 100.0) : 0.0;

    return FiscalYearSummary(
      fiscalYearLabel: 'FY $startYear–${startYear + 1}',
      totalIncome: income,
      totalExpense: expense,
      netSavings: netSavings,
      savingsRatePercentage: savingsRate,
      startTimestamp: startMillis,
      endTimestamp: endMillis,
    );
  }

  Future<List<MonthlyTrend>> getMonthlyTrends({int monthsBack = 6, DateTime? end}) async {
    final endDate = end ?? DateTime.now();
    final monthFormat = DateFormat('MMM');
    final trends = <MonthlyTrend>[];

    for (var i = monthsBack - 1; i >= 0; i--) {
      final monthDate = DateTime(endDate.year, endDate.month - i, 1);
      final startMillis = monthDate.millisecondsSinceEpoch;
      final endMillis = DateTime(monthDate.year, monthDate.month + 1, 1)
          .subtract(const Duration(milliseconds: 1))
          .millisecondsSinceEpoch;

      final txns = await _dao.getTransactionsBetweenSync(startMillis, endMillis);
      final income = txns
          .where((t) => t.type == TransactionType.income.storageName)
          .fold<double>(0, (sum, t) => sum + t.amount);
      final expense = txns
          .where((t) => t.type == TransactionType.expense.storageName)
          .fold<double>(0, (sum, t) => sum + t.amount);

      trends.add(MonthlyTrend(
        monthLabel: monthFormat.format(monthDate),
        totalIncome: income,
        totalExpense: expense,
        timestamp: startMillis,
      ));
    }
    return trends;
  }
}
