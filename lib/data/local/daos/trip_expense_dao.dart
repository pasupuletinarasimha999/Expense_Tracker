import 'package:drift/drift.dart';

import '../database.dart';

/// Ported 1:1 from `TripExpenseDao.kt`.
class TripExpenseDao {
  final AppDatabase db;

  TripExpenseDao(this.db);

  Future<int> insertExpense(TripExpensesCompanion entry) {
    return db.into(db.tripExpenses).insertOnConflictUpdate(entry);
  }

  Future<void> deleteExpense(int id) {
    return (db.delete(db.tripExpenses)..where((e) => e.id.equals(id))).go();
  }

  Future<void> deleteExpensesForTrip(int tripId) {
    return (db.delete(db.tripExpenses)..where((e) => e.tripId.equals(tripId))).go();
  }

  Future<void> deleteAllExpenses() {
    return db.delete(db.tripExpenses).go();
  }

  Future<List<TripExpense>> getAllExpensesSync() {
    return db.select(db.tripExpenses).get();
  }

  Future<void> insertAll(List<TripExpensesCompanion> entries) {
    return db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.tripExpenses, entries);
    });
  }

  Stream<List<TripExpense>> watchExpensesForTrip(int tripId) {
    return (db.select(db.tripExpenses)
          ..where((e) => e.tripId.equals(tripId))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .watch();
  }

  Future<List<TripExpense>> getExpensesForTripSync(int tripId) {
    return (db.select(db.tripExpenses)
          ..where((e) => e.tripId.equals(tripId))
          ..orderBy([(e) => OrderingTerm.asc(e.date)]))
        .get();
  }
}
