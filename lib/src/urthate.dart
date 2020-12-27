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
  Future save(Model model, {sql.Transaction txn}) async {
    // TODO: Handle [_db] being null.

    if (txn == null) {
      return await _db.transaction((txn) async => save(model, txn: txn));
    }

    // -- Save this model.
    ModelInfo modelInfo = models[model.modelName];

    // Load model from database.
    Map<String, dynamic> map = model.dbMap;
    List<Map<String, dynamic>> rows = await txn.query(
      modelInfo.name,
      where: SQLGenerator.generateWherePrimary(this, modelInfo),
      whereArgs: modelInfo.primaryColumns(version).map((column) => map[column.name]).toList(),
    );

    if (rows.isEmpty) {
      // Was not found in database, perform insert.
      txn.insert(modelInfo.name, map);
    } else {
      // Was found, perform update.
      txn.update(
        modelInfo.name,
        map,
        where: SQLGenerator.generateWherePrimary(this, modelInfo),
        whereArgs: modelInfo.primaryColumns(version).map((column) => map[column.name]).toList(),
      );
    }

    // -- Save one-to-one referenced models.
    for (Column column in modelInfo.getColumnsWithReference(this, ReferenceType.oneToOne)) {
      // TODO: Handle removing models where model was present in loaded model, but not present now.
      await save(map[column.name], txn: txn);
    }

    // -- Save one-to-many referenced models.
    for (Column column in modelInfo.getColumnsWithReference(this, ReferenceType.oneToMany)) {
      for (Model otherModel in map[column.name]) {
        // TODO: Handle removing models where model was present in loaded model, but not present now.
        await save(otherModel, txn: txn);
      }
    }

    // -- Save many-to-many referenced models.
    for (Column column in modelInfo.getColumnsWithReference(this, ReferenceType.manyToMany)) {
      for (Model otherModel in map[column.name]) {
        // TODO: Handle removing models where model was present in loaded model, but not present now.
        await save(otherModel, txn: txn);

        // TODO: Insert into linking table
      }
    }
  }

  /// Delete [model] from database.
  Future<bool> delete(Model model) => Future.value(false);

  /// Load a single model from the database.
  Future<T> load<T extends Model>() => Future.value(null);

  /// Load all models from the database.
  Future<List<T>> loadAll<T extends Model>() => Future.value([]);
}
