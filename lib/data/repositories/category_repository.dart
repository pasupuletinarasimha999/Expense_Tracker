import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../../core/constants.dart';
import '../local/daos/category_dao.dart';
import '../local/database.dart';
import '../preferences/user_preferences.dart';
import '../remote/drive_sync_manager.dart';

/// Mediates access to [Category] rows with default fallbacks. Ported 1:1 from
/// `CategoryRepository.kt`. Falls back to in-memory default categories (sentinel `id: -1`,
/// never persisted) only if the categories table is unexpectedly empty — in normal
/// operation the database's `onCreate` seed means this path is rarely hit.
class CategoryRepository {
  final CategoryDao _dao;
  final DriveSyncManager _syncManager;
  final UserPreferences _preferences;

  CategoryRepository(this._dao, this._syncManager, this._preferences);

  static Category _fromDefault(CategoryDefault d) => Category(
        id: -1,
        name: d.name,
        iconName: d.iconName,
        colorHex: d.colorHex,
        type: d.type.storageName,
        isCustom: false,
      );

  Stream<List<Category>> watchAllCategories() {
    return _dao.watchAllCategories().map(
          (list) => list.isEmpty ? DefaultCategories.all.map(_fromDefault).toList() : list,
        );
  }

  Stream<List<Category>> watchCategoriesByType(TransactionType type) {
    return _dao.watchCategoriesByType(type).map((list) {
      if (list.isNotEmpty) return list;
      final defaults = type == TransactionType.expense ? DefaultCategories.expense : DefaultCategories.income;
      return defaults.map(_fromDefault).toList();
    });
  }

  Future<List<Category>> getCategoriesByTypeSync(TransactionType type) async {
    final list = await _dao.getCategoriesByTypeSync(type);
    if (list.isNotEmpty) return list;
    final defaults = type == TransactionType.expense ? DefaultCategories.expense : DefaultCategories.income;
    return defaults.map(_fromDefault).toList();
  }

  Future<int> addCategory({
    required String name,
    required String iconName,
    required String colorHex,
    required TransactionType type,
  }) async {
    final id = await _dao.insertCategory(CategoriesCompanion.insert(
      name: name.trim(),
      iconName: Value(iconName),
      colorHex: Value(colorHex),
      type: Value(type.storageName),
      isCustom: const Value(true),
    ));
    _pushToGoogleCloud();
    return id;
  }

  /// Only intended for custom categories — default categories aren't editable.
  Future<void> updateCategory({
    required int categoryId,
    required String name,
    required String iconName,
    required String colorHex,
    required TransactionType type,
  }) async {
    await _dao.insertCategory(CategoriesCompanion(
      id: Value(categoryId),
      name: Value(name.trim()),
      iconName: Value(iconName),
      colorHex: Value(colorHex),
      type: Value(type.storageName),
      isCustom: const Value(true),
    ));
    _pushToGoogleCloud();
  }

  Future<void> deleteCategory(Category category) async {
    await _dao.deleteCategory(category.id);
    _pushToGoogleCloud();
  }

  void _pushToGoogleCloud() {
    final email = _preferences.userEmail;
    if (email.trim().isNotEmpty) {
      // ignore: discarded_futures
      _syncManager.pushUserData(email);
    } else {
      debugPrint('CategoryRepository: skipping auto-push, no signed-in email in preferences');
    }
  }
}
