import 'package:drift/drift.dart';

class Translations extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get sourceText => text()();
  TextColumn get translatedText => text()();

  TextColumn get sourceLang => text()(); // e.g. 'de'
  TextColumn get targetLang => text()(); // e.g. 'en'

  TextColumn get imagePath => text().nullable()(); // For image translations

  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isLearning => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
