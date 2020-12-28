import 'package:flutter/foundation.dart';
import 'package:urthate/src/mapping/bool_mapper.dart';
import 'package:urthate/src/mapping/datetime_mapper.dart';
import 'package:urthate/src/model/model_info.dart';
import 'package:urthate/src/mapping/type_mapper.dart';
import 'package:urthate/src/model/reference.dart';
import 'package:urthate/src/model/model.dart';
import 'package:urthate/src/model/column.dart';
import 'package:urthate/src/sql_generator.dart';
import 'package:sqflite/sqflite.dart' as sql;

class Urthate {
  /// Database version.
  int version;

  /// Database path.
  String path;

  /// Database instance.
  sql.Database _db;

  /// Registered models.
  Map<String, ModelInfo> models = <String, ModelInfo>{};

  /// Type mappers.
  Map<String, TypeMapper> mappers = <String, TypeMapper>{
    'datetime': const DateTimeMapper(),
    'bool': const BoolMapper(),
  };

  Urthate({
    @required this.version,
    this.path = 'data.db',
  });

  /// Register a new model.
  void register(ModelInfo info) => models[info.name] = info;

  /// Returns a list of all models which contain a reference of type [referenceType].
  List<ModelInfo> findModelsWithReferenceType(ReferenceType referenceType) =>
      models.values.where((model) => model.hasReferenceOfType(this, referenceType)).toList();

  /// Returns a list of all models which reference the [modelName] specified, by default finds models which reference
  /// using [ReferenceType.oneToMany].
  List<ModelInfo> findModelsThatReferenceModel(String modelName, ReferenceType referenceType) =>
      models.values.where((model) => model.referencesModel(this, modelName, referenceType)).toList();

  Future init() async {
    SQLGenerator generator = SQLGenerator();
    _db = await sql.openDatabase(
      path,
      version: version,
      onCreate: (sql.Database db, int version) async {
        // -- Create tables for models.
        for (ModelInfo modelInfo in models.values) {
          await db.execute(generator.generateCreateTable(this, modelInfo));
        }

        // -- Create linking tables.
        for (String sql in generator.generateManyToManyTables(this)) {
          await db.execute(sql);
        }
      },
    );
  }

  /// Save [model] to database.  New models will be inserted, existing models will be updated.
  Future save(
    Model model, {
    sql.Transaction txn,
    Reference ref,
    Model parent,
    ModelInfo parentInfo,
    bool deleteCascade = false,
  }) async {
    // TODO: Handle [_db] being null.

    if (txn == null) {
      return await _db.transaction((txn) async => await save(
            model,
            txn: txn,
            ref: ref,
            parent: parent,
          ));
    }

    // -- Save this model.
    ModelInfo modelInfo = models[model.modelName];

    // Get, and process database map.
    Map<String, dynamic> map = model.dbMap;
    Map<String, dynamic> mapWithoutRefs = {};
    for (Column column in modelInfo.columns[version]) {
      if (mappers.containsKey(column.type)) {
        map[column.name] = mappers[column.type].mapTo(map[column.name]);
      }
      if (column.references == null) {
        mapWithoutRefs[column.name] = map[column.name];
      }
    }

    // Add fields to map for reference.
    if (ref != null) {
      Map<String, dynamic> parentMap = parent.dbMap;
      for (Column column in parentInfo.primaryColumns(version)) {
        mapWithoutRefs['${parentInfo.name}__${column.name}'] = parentMap[column.name];
      }
    }

    // Load model from database.
    List<Map<String, dynamic>> rows = await txn.query(
      modelInfo.name,
      where: SQLGenerator.generateWherePrimary(this, modelInfo),
      whereArgs: modelInfo.primaryColumns(version).map((column) => map[column.name]).toList(),
    );

    if (rows.isEmpty) {
      // Was not found in database, perform insert.
      txn.insert(modelInfo.name, mapWithoutRefs);
    } else {
      // Was found, perform update.
      txn.update(
        modelInfo.name,
        mapWithoutRefs,
        where: SQLGenerator.generateWherePrimary(this, modelInfo),
        whereArgs: modelInfo.primaryColumns(version).map((column) => map[column.name]).toList(),
      );
    }

    // -- Save one-to-one referenced models.
    for (Column column in modelInfo.getColumnsWithReference(this, ReferenceType.oneToOne)) {
      // TODO: Handle removing models where model was present in loaded model, but not present now.
      await save(
        map[column.name],
        txn: txn,
        ref: column.references,
        parent: model,
        parentInfo: modelInfo,
      );
    }

    // -- Save one-to-many referenced models.
    for (Column column in modelInfo.getColumnsWithReference(this, ReferenceType.oneToMany)) {
      for (Model otherModel in map[column.name]) {
        // TODO: Handle removing models where model was present in loaded model, but not present now.
        await save(
          otherModel,
          txn: txn,
          ref: column.references,
          parent: model,
          parentInfo: modelInfo,
        );
      }
    }

    // -- Save many-to-many referenced models.
    for (Column column in modelInfo.getColumnsWithReference(this, ReferenceType.manyToMany)) {
      for (Model otherModel in map[column.name]) {
        // TODO: Handle removing models where model was present in loaded model, but not present now.
        await save(otherModel, txn: txn);

        Map<String, dynamic> linkValues = {};
        List<String> columnNames = [];
        List<dynamic> whereArgs = [];
        for (Column column in modelInfo.primaryColumns(version)) {
          linkValues['${modelInfo.name}__${column.name}'] = map[column.name];
          columnNames.add('${modelInfo.name}__${column.name}');
          whereArgs.add(map[column.name]);
        }

        ModelInfo otherModelInfo = models[otherModel.modelName];
        Map<String, dynamic> otherMap = otherModel.dbMap;
        for (Column column in otherModelInfo.primaryColumns(version)) {
          linkValues['${otherModelInfo.name}__${column.name}'] = otherMap[column.name];
          columnNames.add('${otherModelInfo.name}__${column.name}');
          whereArgs.add(otherMap[column.name]);
        }

        String tableName = ([modelInfo.name, otherModelInfo.name]..sort((a, b) => a.compareTo(b))).join('__');

        List<Map<String, dynamic>> rows = await txn.query(
          tableName,
          where: columnNames.map((name) => '`$name` = ?').join(' AND '),
          whereArgs: whereArgs,
        );
        if (rows.isEmpty) {
          await txn.insert(tableName, linkValues);
        }
      }
    }
  }

  /// Delete [model] from database.
  Future delete(
    String model, {
    String where,
    List<dynamic> whereArgs,
    bool cascade = false,
    sql.Transaction txn,
  }) async {
    if (txn == null) {
      await _db.transaction((txn) async => await delete(
            model,
            cascade: cascade,
            txn: txn,
          ));
    }

    ModelInfo modelInfo = models[model];

    if (cascade) {
      Map<String, dynamic> dbMap = (await load(
        model,
        where: where,
        whereArgs: whereArgs,
      ))
          .dbMap;

      for (Column column in modelInfo.columns[version]) {
        if (column.references != null) {
          switch (column.references.type) {
            case ReferenceType.oneToOne:
            case ReferenceType.oneToMany:
              List<Column> primaryColumns = modelInfo.primaryColumns(version);

              await delete(
                column.references.modelName,
                where: primaryColumns.map((column) => '`${modelInfo.name}__${column.name}` = ?').join(' AND '),
                whereArgs: primaryColumns.map((column) => dbMap[column.name]).toList(),
                txn: txn,
              );
              break;
            default:
              // TODO: Implement cascade delete for 'manyToMany'
              throw UnimplementedError('Not implemented');
          }
        }
      }
    }

    await txn.delete(
      modelInfo.name,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Load a single model from the database.
  Future<T> load<T extends Model>(String model, {String where, List<dynamic> whereArgs, sql.Transaction txn}) async {
    if (txn == null) {
      return await _db.transaction((txn) async => await load(
            model,
            where: where,
            whereArgs: whereArgs,
            txn: txn,
          ));
    }

    ModelInfo modelInfo = models[model];

    List<Map<String, dynamic>> rows = await txn.query(
      modelInfo.name,
      where: where,
      whereArgs: whereArgs,
    );

    if (rows.isEmpty) {
      return null;
    }

    Map<String, dynamic> map = Map.from(rows.first);
    for (Column column in modelInfo.columns[version]) {
      if (mappers.containsKey(column.type)) {
        map[column.name] = mappers[column.type].mapFrom(map[column.name]);
      }

      // TODO: Load referenced models
    }

    return modelInfo.fromDbMap(map);
  }

  /// Load all models from the database.
  Future<List<T>> loadAll<T extends Model>() => Future.value([]);
}
