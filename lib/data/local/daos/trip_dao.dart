import 'package:drift/drift.dart';

import '../database.dart';

/// A trip joined with the sum of its logged expenses — mirrors `TripWithSpent` in `TripDao.kt`.
class TripWithSpent {
  final Trip trip;
  final double totalSpent;

  TripWithSpent(this.trip, this.totalSpent);
}

/// Ported 1:1 from `TripDao.kt`.
class TripDao {
  final AppDatabase db;

  TripDao(this.db);

  Future<int> insertTrip(TripsCompanion entry) {
    return db.into(db.trips).insertOnConflictUpdate(entry);
  }

  Future<void> deleteTrip(int id) {
    return (db.delete(db.trips)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAllTrips() {
    return db.delete(db.trips).go();
  }

  Future<List<Trip>> getAllTripsSync() {
    return db.select(db.trips).get();
  }

  Future<void> insertAll(List<TripsCompanion> entries) {
    return db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.trips, entries);
    });
  }

  Future<Trip?> getTripById(int id) {
    return (db.select(db.trips)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Trip?> watchTripById(int id) {
    return (db.select(db.trips)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Stream<List<TripWithSpent>> watchAllTripsWithSpent() {
    final spentSum = db.tripExpenses.amount.sum();
    final query = db.select(db.trips).join([
      leftOuterJoin(db.tripExpenses, db.tripExpenses.tripId.equalsExp(db.trips.id)),
    ])
      ..addColumns([spentSum])
      ..groupBy([db.trips.id])
      ..orderBy([OrderingTerm.desc(db.trips.startDate)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final trip = row.readTable(db.trips);
        final total = row.read(spentSum) ?? 0.0;
        return TripWithSpent(trip, total);
      }).toList();
    });
  }
}
