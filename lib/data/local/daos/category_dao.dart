import 'package:drift/drift.dart';

import '../../../core/constants.dart';
import '../database.dart';

/// Ported 1:1 from `CategoryDao.kt`.
class CategoryDao {
  final AppDatabase db;

  CategoryDao(this.db);

  Future<int> insertCategory(CategoriesCompanion entry) {
    return db.into(db.categories).insertOnConflictUpdate(entry);
  }

  Future<void> insertAll(List<CategoriesCompanion> entries) {
    return db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.categories, entries);
    });
  }

  Future<void> deleteCategory(int id) {
    return (db.delete(db.categories)..where((c) => c.id.equals(id))).go();
  }

  Stream<List<Category>> watchAllCategories() {
    return (db.select(db.categories)
          ..orderBy([(c) => OrderingTerm.asc(c.isCustom), (c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  Future<List<Category>> getAllCategoriesSync() {
    return (db.select(db.categories)
          ..orderBy([(c) => OrderingTerm.asc(c.isCustom), (c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  Stream<List<Category>> watchCategoriesByType(TransactionType type) {
    return (db.select(db.categories)
          ..where((c) => c.type.equals(type.storageName))
          ..orderBy([(c) => OrderingTerm.asc(c.isCustom), (c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  Future<List<Category>> getCategoriesByTypeSync(TransactionType type) {
    return (db.select(db.categories)
          ..where((c) => c.type.equals(type.storageName))
          ..orderBy([(c) => OrderingTerm.asc(c.isCustom), (c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  Future<int> getCount() async {
    final countExp = db.categories.id.count();
    final query = db.selectOnly(db.categories)..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<Category?> findByName(String name) {
    return (db.select(db.categories)..where((c) => c.name.equals(name))..limit(1)).getSingleOrNull();
  }
}
