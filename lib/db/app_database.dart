import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'translation_model.dart';

part 'app_database.g.dart'; // Drift will generate this

@DriftDatabase(tables: [Translations])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // ───── CRUD OPERATIONS ─────────────────────────────

  Future<int> insertTranslation(TranslationsCompanion entry) {
    return into(translations).insert(entry);
  }

  Future<List<Translation>> getAllTranslations() {
    return select(translations).get();
  }

  Future<List<Translation>> getFavorites() {
    return (select(translations)
      ..where((t) => t.isFavorite.equals(true))).get();
  }

  Future<List<Translation>> getLearningStack() {
    return (select(translations)
      ..where((t) => t.isLearning.equals(true))).get();
  }

  Future<void> toggleFavorite(int id, bool isFav) {
    return (update(translations)..where(
      (t) => t.id.equals(id),
    )).write(TranslationsCompanion(isFavorite: Value(isFav)));
  }

  Future<void> toggleLearning(int id, bool isLearn) {
    return (update(translations)..where(
      (t) => t.id.equals(id),
    )).write(TranslationsCompanion(isLearning: Value(isLearn)));
  }

  Future<void> deleteOldTranslations() async {
    final thresholdDate = DateTime.now().subtract(const Duration(days: 30));

    await (delete(translations)..where(
      (t) =>
          t.createdAt.isSmallerThanValue(thresholdDate) &
          t.isFavorite.equals(false) &
          t.isLearning.equals(false),
    )).go();
  }

  Future<void> deleteAllTranslations() => delete(translations).go();
}

// ───── DATABASE CONNECTION ──────────────

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app_db.sqlite'));
    return NativeDatabase(file);
  });
}
