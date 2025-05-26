// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TranslationsTable extends Translations
    with TableInfo<$TranslationsTable, Translation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranslationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _inputMeta = const VerificationMeta('input');
  @override
  late final GeneratedColumn<String> input = GeneratedColumn<String>(
    'input',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outputMeta = const VerificationMeta('output');
  @override
  late final GeneratedColumn<String> output = GeneratedColumn<String>(
    'output',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromLangMeta = const VerificationMeta(
    'fromLang',
  );
  @override
  late final GeneratedColumn<String> fromLang = GeneratedColumn<String>(
    'from_lang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toLangMeta = const VerificationMeta('toLang');
  @override
  late final GeneratedColumn<String> toLang = GeneratedColumn<String>(
    'to_lang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    input,
    output,
    fromLang,
    toLang,
    timestamp,
    isFavorite,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'translations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Translation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('input')) {
      context.handle(
        _inputMeta,
        input.isAcceptableOrUnknown(data['input']!, _inputMeta),
      );
    } else if (isInserting) {
      context.missing(_inputMeta);
    }
    if (data.containsKey('output')) {
      context.handle(
        _outputMeta,
        output.isAcceptableOrUnknown(data['output']!, _outputMeta),
      );
    } else if (isInserting) {
      context.missing(_outputMeta);
    }
    if (data.containsKey('from_lang')) {
      context.handle(
        _fromLangMeta,
        fromLang.isAcceptableOrUnknown(data['from_lang']!, _fromLangMeta),
      );
    } else if (isInserting) {
      context.missing(_fromLangMeta);
    }
    if (data.containsKey('to_lang')) {
      context.handle(
        _toLangMeta,
        toLang.isAcceptableOrUnknown(data['to_lang']!, _toLangMeta),
      );
    } else if (isInserting) {
      context.missing(_toLangMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Translation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Translation(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      input:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}input'],
          )!,
      output:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}output'],
          )!,
      fromLang:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}from_lang'],
          )!,
      toLang:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}to_lang'],
          )!,
      timestamp:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}timestamp'],
          )!,
      isFavorite:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_favorite'],
          )!,
    );
  }

  @override
  $TranslationsTable createAlias(String alias) {
    return $TranslationsTable(attachedDatabase, alias);
  }
}

class Translation extends DataClass implements Insertable<Translation> {
  final int id;
  final String input;
  final String output;
  final String fromLang;
  final String toLang;
  final DateTime timestamp;
  final bool isFavorite;
  const Translation({
    required this.id,
    required this.input,
    required this.output,
    required this.fromLang,
    required this.toLang,
    required this.timestamp,
    required this.isFavorite,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['input'] = Variable<String>(input);
    map['output'] = Variable<String>(output);
    map['from_lang'] = Variable<String>(fromLang);
    map['to_lang'] = Variable<String>(toLang);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['is_favorite'] = Variable<bool>(isFavorite);
    return map;
  }

  TranslationsCompanion toCompanion(bool nullToAbsent) {
    return TranslationsCompanion(
      id: Value(id),
      input: Value(input),
      output: Value(output),
      fromLang: Value(fromLang),
      toLang: Value(toLang),
      timestamp: Value(timestamp),
      isFavorite: Value(isFavorite),
    );
  }

  factory Translation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Translation(
      id: serializer.fromJson<int>(json['id']),
      input: serializer.fromJson<String>(json['input']),
      output: serializer.fromJson<String>(json['output']),
      fromLang: serializer.fromJson<String>(json['fromLang']),
      toLang: serializer.fromJson<String>(json['toLang']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'input': serializer.toJson<String>(input),
      'output': serializer.toJson<String>(output),
      'fromLang': serializer.toJson<String>(fromLang),
      'toLang': serializer.toJson<String>(toLang),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'isFavorite': serializer.toJson<bool>(isFavorite),
    };
  }

  Translation copyWith({
    int? id,
    String? input,
    String? output,
    String? fromLang,
    String? toLang,
    DateTime? timestamp,
    bool? isFavorite,
  }) => Translation(
    id: id ?? this.id,
    input: input ?? this.input,
    output: output ?? this.output,
    fromLang: fromLang ?? this.fromLang,
    toLang: toLang ?? this.toLang,
    timestamp: timestamp ?? this.timestamp,
    isFavorite: isFavorite ?? this.isFavorite,
  );
  Translation copyWithCompanion(TranslationsCompanion data) {
    return Translation(
      id: data.id.present ? data.id.value : this.id,
      input: data.input.present ? data.input.value : this.input,
      output: data.output.present ? data.output.value : this.output,
      fromLang: data.fromLang.present ? data.fromLang.value : this.fromLang,
      toLang: data.toLang.present ? data.toLang.value : this.toLang,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Translation(')
          ..write('id: $id, ')
          ..write('input: $input, ')
          ..write('output: $output, ')
          ..write('fromLang: $fromLang, ')
          ..write('toLang: $toLang, ')
          ..write('timestamp: $timestamp, ')
          ..write('isFavorite: $isFavorite')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, input, output, fromLang, toLang, timestamp, isFavorite);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Translation &&
          other.id == this.id &&
          other.input == this.input &&
          other.output == this.output &&
          other.fromLang == this.fromLang &&
          other.toLang == this.toLang &&
          other.timestamp == this.timestamp &&
          other.isFavorite == this.isFavorite);
}

class TranslationsCompanion extends UpdateCompanion<Translation> {
  final Value<int> id;
  final Value<String> input;
  final Value<String> output;
  final Value<String> fromLang;
  final Value<String> toLang;
  final Value<DateTime> timestamp;
  final Value<bool> isFavorite;
  const TranslationsCompanion({
    this.id = const Value.absent(),
    this.input = const Value.absent(),
    this.output = const Value.absent(),
    this.fromLang = const Value.absent(),
    this.toLang = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.isFavorite = const Value.absent(),
  });
  TranslationsCompanion.insert({
    this.id = const Value.absent(),
    required String input,
    required String output,
    required String fromLang,
    required String toLang,
    this.timestamp = const Value.absent(),
    this.isFavorite = const Value.absent(),
  }) : input = Value(input),
       output = Value(output),
       fromLang = Value(fromLang),
       toLang = Value(toLang);
  static Insertable<Translation> custom({
    Expression<int>? id,
    Expression<String>? input,
    Expression<String>? output,
    Expression<String>? fromLang,
    Expression<String>? toLang,
    Expression<DateTime>? timestamp,
    Expression<bool>? isFavorite,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (input != null) 'input': input,
      if (output != null) 'output': output,
      if (fromLang != null) 'from_lang': fromLang,
      if (toLang != null) 'to_lang': toLang,
      if (timestamp != null) 'timestamp': timestamp,
      if (isFavorite != null) 'is_favorite': isFavorite,
    });
  }

  TranslationsCompanion copyWith({
    Value<int>? id,
    Value<String>? input,
    Value<String>? output,
    Value<String>? fromLang,
    Value<String>? toLang,
    Value<DateTime>? timestamp,
    Value<bool>? isFavorite,
  }) {
    return TranslationsCompanion(
      id: id ?? this.id,
      input: input ?? this.input,
      output: output ?? this.output,
      fromLang: fromLang ?? this.fromLang,
      toLang: toLang ?? this.toLang,
      timestamp: timestamp ?? this.timestamp,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (input.present) {
      map['input'] = Variable<String>(input.value);
    }
    if (output.present) {
      map['output'] = Variable<String>(output.value);
    }
    if (fromLang.present) {
      map['from_lang'] = Variable<String>(fromLang.value);
    }
    if (toLang.present) {
      map['to_lang'] = Variable<String>(toLang.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranslationsCompanion(')
          ..write('id: $id, ')
          ..write('input: $input, ')
          ..write('output: $output, ')
          ..write('fromLang: $fromLang, ')
          ..write('toLang: $toLang, ')
          ..write('timestamp: $timestamp, ')
          ..write('isFavorite: $isFavorite')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TranslationsTable translations = $TranslationsTable(this);
  late final TranslationDao translationDao = TranslationDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [translations];
}

typedef $$TranslationsTableCreateCompanionBuilder =
    TranslationsCompanion Function({
      Value<int> id,
      required String input,
      required String output,
      required String fromLang,
      required String toLang,
      Value<DateTime> timestamp,
      Value<bool> isFavorite,
    });
typedef $$TranslationsTableUpdateCompanionBuilder =
    TranslationsCompanion Function({
      Value<int> id,
      Value<String> input,
      Value<String> output,
      Value<String> fromLang,
      Value<String> toLang,
      Value<DateTime> timestamp,
      Value<bool> isFavorite,
    });

class $$TranslationsTableFilterComposer
    extends Composer<_$AppDatabase, $TranslationsTable> {
  $$TranslationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get input => $composableBuilder(
    column: $table.input,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get output => $composableBuilder(
    column: $table.output,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromLang => $composableBuilder(
    column: $table.fromLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toLang => $composableBuilder(
    column: $table.toLang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TranslationsTableOrderingComposer
    extends Composer<_$AppDatabase, $TranslationsTable> {
  $$TranslationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get input => $composableBuilder(
    column: $table.input,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get output => $composableBuilder(
    column: $table.output,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromLang => $composableBuilder(
    column: $table.fromLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toLang => $composableBuilder(
    column: $table.toLang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TranslationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranslationsTable> {
  $$TranslationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get input =>
      $composableBuilder(column: $table.input, builder: (column) => column);

  GeneratedColumn<String> get output =>
      $composableBuilder(column: $table.output, builder: (column) => column);

  GeneratedColumn<String> get fromLang =>
      $composableBuilder(column: $table.fromLang, builder: (column) => column);

  GeneratedColumn<String> get toLang =>
      $composableBuilder(column: $table.toLang, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );
}

class $$TranslationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranslationsTable,
          Translation,
          $$TranslationsTableFilterComposer,
          $$TranslationsTableOrderingComposer,
          $$TranslationsTableAnnotationComposer,
          $$TranslationsTableCreateCompanionBuilder,
          $$TranslationsTableUpdateCompanionBuilder,
          (
            Translation,
            BaseReferences<_$AppDatabase, $TranslationsTable, Translation>,
          ),
          Translation,
          PrefetchHooks Function()
        > {
  $$TranslationsTableTableManager(_$AppDatabase db, $TranslationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$TranslationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$TranslationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$TranslationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> input = const Value.absent(),
                Value<String> output = const Value.absent(),
                Value<String> fromLang = const Value.absent(),
                Value<String> toLang = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
              }) => TranslationsCompanion(
                id: id,
                input: input,
                output: output,
                fromLang: fromLang,
                toLang: toLang,
                timestamp: timestamp,
                isFavorite: isFavorite,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String input,
                required String output,
                required String fromLang,
                required String toLang,
                Value<DateTime> timestamp = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
              }) => TranslationsCompanion.insert(
                id: id,
                input: input,
                output: output,
                fromLang: fromLang,
                toLang: toLang,
                timestamp: timestamp,
                isFavorite: isFavorite,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TranslationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranslationsTable,
      Translation,
      $$TranslationsTableFilterComposer,
      $$TranslationsTableOrderingComposer,
      $$TranslationsTableAnnotationComposer,
      $$TranslationsTableCreateCompanionBuilder,
      $$TranslationsTableUpdateCompanionBuilder,
      (
        Translation,
        BaseReferences<_$AppDatabase, $TranslationsTable, Translation>,
      ),
      Translation,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TranslationsTableTableManager get translations =>
      $$TranslationsTableTableManager(_db, _db.translations);
}

mixin _$TranslationDaoMixin on DatabaseAccessor<AppDatabase> {
  $TranslationsTable get translations => attachedDatabase.translations;
}
