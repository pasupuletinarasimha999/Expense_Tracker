import 'package:drift/drift.dart';

/// Mirrors `TripExpenseEntity.kt` / Room table `trip_expenses`.
class TripExpenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get tripId => integer()();
  TextColumn get category => text()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  IntColumn get date => integer()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get paymentMethod => text().withDefault(const Constant('Cash'))();
}
