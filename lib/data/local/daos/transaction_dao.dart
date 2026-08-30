import 'package:drift/drift.dart';

import '../database.dart';

/// Ported 1:1 from `TransactionDao.kt`.
class TransactionDao {
  final AppDatabase db;

  TransactionDao(this.db);

  Future<int> insertTransaction(TransactionsCompanion entry) {
    return db.into(db.transactions).insertOnConflictUpdate(entry);
  }

  Future<void> insertAll(List<TransactionsCompanion> entries) {
    return db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.transactions, entries);
    });
  }

  Future<void> updateTransaction(TransactionsCompanion entry) {
    return (db.update(db.transactions)
          ..where((t) => t.id.equals(entry.id.value)))
        .write(entry);
  }

  Future<void> deleteTransactionById(int id) {
    return (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteSeriesFromTimestamp(int seriesId, int fromTimestamp) {
    return (db.delete(db.transactions)
          ..where((t) =>
              (t.recurringSeriesId.equals(seriesId) | t.id.equals(seriesId)) &
              t.timestamp.isBiggerOrEqualValue(fromTimestamp)))
        .go();
  }

  Future<void> deleteRecurringSeries(int seriesId) {
    return (db.delete(db.transactions)
          ..where((t) => t.recurringSeriesId.equals(seriesId) | t.id.equals(seriesId)))
        .go();
  }

  Future<void> deleteAllTransactions() {
    return db.delete(db.transactions).go();
  }

  Stream<List<Transaction>> watchAllTransactions() {
    return (db.select(db.transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch();
  }

  Future<List<Transaction>> getAllTransactions() {
    return (db.select(db.transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
  }

  Stream<List<Transaction>> watchTransactionsBetween(int startDate, int endDate) {
    return (db.select(db.transactions)
          ..where((t) => t.timestamp.isBiggerOrEqualValue(startDate) & t.timestamp.isSmallerOrEqualValue(endDate))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch();
  }

  Future<List<Transaction>> getTransactionsBetweenSync(int startDate, int endDate) {
    return (db.select(db.transactions)
          ..where((t) => t.timestamp.isBiggerOrEqualValue(startDate) & t.timestamp.isSmallerOrEqualValue(endDate))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
  }

  Stream<List<Transaction>> watchRecentTransactions(int limit) {
    return (db.select(db.transactions)
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .watch();
  }

  Stream<List<Transaction>> watchRecurringTransactions() {
    return (db.select(db.transactions)
          ..where((t) => t.isRecurring.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch();
  }

  Future<List<Transaction>> getActiveRecurringTransactionsSync() {
    return (db.select(db.transactions)
          ..where((t) => t.isRecurring.equals(true) & t.isRecurringActive.equals(true)))
        .get();
  }

  Future<Transaction?> getTransactionById(int id) {
    return (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Transaction?> getRecurringMasterBySeriesId(int seriesId) {
    return ((db.select(db.transactions)
          ..where((t) =>
              (t.recurringSeriesId.equals(seriesId) | t.id.equals(seriesId)) & t.isRecurring.equals(true))
          ..limit(1))
        .getSingleOrNull());
  }

  Future<void> updateRecurringActiveState(int id, bool isActive) {
    return db.customStatement(
      'UPDATE transactions SET isRecurringActive = ? WHERE id = ? OR recurringSeriesId = ?',
      [isActive, id, id],
    );
  }

  Future<void> updateLastProcessedDate(int id, int timestamp) {
    return (db.update(db.transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(lastProcessedDate: Value(timestamp)));
  }

  Future<void> updateIsPaid(int id, bool isPaid) {
    return (db.update(db.transactions)..where((t) => t.id.equals(id)))
        .write(TransactionsCompanion(isPaid: Value(isPaid)));
  }

  Future<void> updateSeriesFromTimestamp({
    required int seriesId,
    required int fromTimestamp,
    required double amount,
    required String title,
    required String category,
    required String notes,
    required String paymentMethod,
    required int tripId,
  }) {
    return db.customStatement(
      'UPDATE transactions SET amount = ?, title = ?, category = ?, notes = ?, paymentMethod = ?, tripId = ? '
      'WHERE (recurringSeriesId = ? OR id = ?) AND timestamp >= ?',
      [amount, title, category, notes, paymentMethod, tripId, seriesId, seriesId, fromTimestamp],
    );
  }

  Stream<List<Transaction>> searchTransactions(String query) {
    final likeQuery = '%$query%';
    return (db.select(db.transactions)
          ..where((t) => t.title.like(likeQuery) | t.notes.like(likeQuery) | t.category.like(likeQuery))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .watch();
  }

  Stream<double> watchTotalTaggedToTrip(int tripId) {
    final sumExpr = db.transactions.amount.sum();
    final query = db.selectOnly(db.transactions)
      ..addColumns([sumExpr])
      ..where(db.transactions.tripId.equals(tripId));
    return query.watchSingle().map((row) => row.read(sumExpr) ?? 0.0);
  }
}
