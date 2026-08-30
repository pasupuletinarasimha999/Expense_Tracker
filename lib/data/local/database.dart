import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants.dart';
import 'tables/categories_table.dart';
import 'tables/transactions_table.dart';
import 'tables/trip_expenses_table.dart';
import 'tables/trips_table.dart';

part 'database.g.dart';

/// Local SQLite database, mirroring the original app's Room `ExpenseTrackerDatabase`.
///
/// The Room database went through 13 versioned migrations (8→13) as the native
/// app evolved; since this Flutter database has no prior installed history to
/// migrate *from*, there is nothing to port — `onCreate` simply builds the
/// final (v13-equivalent) schema directly and seeds the same default categories
/// the original app's `DatabaseCallback.onCreate` did.
@DriftDatabase(tables: [Transactions, Categories, Trips, TripExpenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedDefaultCategories();
        },
      );

  Future<void> _seedDefaultCategories() async {
    for (final cat in DefaultCategories.all) {
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: cat.name,
          iconName: Value(cat.iconName),
          colorHex: Value(cat.colorHex),
          type: Value(cat.type.storageName),
        ),
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'expense_tracker_database.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
