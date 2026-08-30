import 'package:drift/drift.dart';

/// Mirrors `TransactionEntity.kt` / Room table `transactions` (schema v13).
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // "INCOME" | "EXPENSE"
  TextColumn get category => text()(); // category NAME, not FK
  IntColumn get timestamp => integer()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurringInterval => text().withDefault(const Constant('MONTHLY'))();
  BoolColumn get isRecurringActive => boolean().withDefault(const Constant(true))();
  IntColumn get lastProcessedDate => integer()();
  IntColumn get recurringSeriesId => integer().withDefault(const Constant(0))();
  IntColumn get effectiveFromTimestamp => integer()();
  TextColumn get paymentMethod => text().withDefault(const Constant('Cash'))();
  IntColumn get tripId => integer().withDefault(const Constant(0))();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
}
