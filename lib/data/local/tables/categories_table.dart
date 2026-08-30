import 'package:drift/drift.dart';

/// Mirrors `CategoryEntity.kt` / Room table `categories`.
/// `@DataClassName` is required because drift's default singularization
/// naively strips a trailing "s" ("Categories" -> "Categorie") rather than
/// handling the "-ies" -> "-y" case.
@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get iconName => text().withDefault(const Constant('ic_misc'))();
  TextColumn get colorHex => text().withDefault(const Constant('#64748B'))();
  TextColumn get type => text().withDefault(const Constant('EXPENSE'))();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}
