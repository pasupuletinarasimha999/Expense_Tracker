import 'package:drift/drift.dart';

/// Mirrors `TripEntity.kt` / Room table `trips`.
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get destination => text().withDefault(const Constant(''))();
  IntColumn get startDate => integer()();
  IntColumn get endDate => integer()();
  RealColumn get budget => real().withDefault(const Constant(0.0))();
}
