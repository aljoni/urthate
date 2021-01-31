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
    bool deleteRemoved = true,
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
      if (deleteRemoved && rows.isNotEmpty) {
        await _deleteRemovedOneToX(
          column: column,
          parentModelInfo: modelInfo,
          parentMap: map,
          deleteCascade: deleteCascade,
          txn: txn,
        );
      }

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
        if (deleteRemoved && rows.isNotEmpty) {
          await _deleteRemovedOneToX(
            column: column,
            parentModelInfo: modelInfo,
            parentMap: map,
            deleteCascade: deleteCascade,
            txn: txn,
          );
        }

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
      String tableName = ([modelInfo.name, column.references.modelName]..sort((a, b) => a.compareTo(b))).join('__');

      // Handle removing referenced models which are no longer referenced.
      if (rows.isNotEmpty) {
        // Load linking table, for this model type.
        List<Column> primaryColumns = modelInfo.primaryColumns(version);
        List<Map<String, dynamic>> linkRows = await txn.query(
          tableName,
          where: primaryColumns.map((column) => '`${modelInfo.name}__${column.name}` = ?').join(' AND '),
          whereArgs: primaryColumns.map((column) => map[column.name]).toList(),
        );

        // Identify removed models.
        List<List<String>> removedOtherPrimaryValues = [];
        for (Map<String, dynamic> linkRow in linkRows) {
          for (Model referencedModel in map[column.name]) {
            ModelInfo referencedInfo = models[referencedModel.modelName];
            Map<String, dynamic> referencedMap = referencedModel.dbMap;

            bool foundMatch = true;
            for (Column referencedPrimary in referencedInfo.primaryColumns(version)) {
              String columnName = '${referencedInfo.name}__${referencedPrimary.name}';
              if (linkRow[columnName] != referencedMap[referencedPrimary.name]) {
                foundMatch = false;
                break;
              }
            }

            if (!foundMatch) {
              List<String> values = [];
              for (Column referencedPrimary in referencedInfo.primaryColumns(version)) {
                values.add(linkRow['${referencedInfo.name}__${referencedPrimary.name}']);
              }
              removedOtherPrimaryValues.add(values);
            }
          }
        }

        // Remove links.
        for (List<String> removedPrimaryValues in removedOtherPrimaryValues) {
          // Get referenced model info.
          ModelInfo referencedInfo = models[column.references.modelName];
          List<Column> otherPrimaryColumns = referencedInfo.primaryColumns(version);

          // Build where for current, and referenced model.
          List<String> modelWhere = primaryColumns.map((column) => '`${modelInfo.name}__${column.name}` = ?');
          List<String> referencedWhere = otherPrimaryColumns.map((column) => '`${modelInfo.name}__${column.name}` = ?');

          // Combine where into a single string.
          String where = ([]..add(modelWhere)..add(referencedWhere)).join(' AND ');

          // Build where arguments for current, and referenced model.
          List<dynamic> whereArgs = []
            ..addAll(modelInfo.primaryColumns(version).map((column) => map[column.name]))
            ..addAll(removedPrimaryValues);

          // Delete references.
          await txn.delete(
            tableName,
            where: where,
            whereArgs: whereArgs,
          );

          // TODO: Handle delete removed for referenced model.
        }
      }

      for (Model otherModel in map[column.name]) {
        // Save model.
        await save(otherModel, txn: txn);

        // Add linking table entries.
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

        List<Map<String, dynamic>> linkRows = await txn.query(
          tableName,
          where: columnNames.map((name) => '`$name` = ?').join(' AND '),
          whereArgs: whereArgs,
        );
        if (linkRows.isEmpty) {
          await txn.insert(tableName, linkValues);
        }
      }
    }
  }

  Future _deleteRemovedOneToX({
    @required Column column,
    @required ModelInfo parentModelInfo,
    @required Map<String, dynamic> parentMap,
    @required bool deleteCascade,
    @required sql.Transaction txn,
  }) async {
    ModelInfo childModelInfo = models[column.references.modelName];

    List<Column> primaryColumns = parentModelInfo.primaryColumns(version);
    String where = primaryColumns.map((column) => '`${parentModelInfo.name}__${column.name}` = ?').join(' AND ');

    // Query primary columns for existing references.
    List<Map<String, dynamic>> otherRows = await _db.query(
      childModelInfo.name,
      columns: childModelInfo.primaryColumns(version).map((column) => column.name).toList(),
      where: where,
      whereArgs: primaryColumns.map((column) => parentMap[column.name]).toList(),
    );

    // Compute list of removed rows.
    List<List<String>> removedPrimaryValues = [];
    for (Map<String, dynamic> row in otherRows) {
      if (!parentMap[column.name].any((Model model) => model.matches(row))) {
        removedPrimaryValues.add(row.values);
      }
    }

    // Delete removed rows.
    for (List<String> whereArgs in removedPrimaryValues) {
      await delete(
        childModelInfo.name,
        where: where,
        whereArgs: whereArgs,
        cascade: deleteCascade,
      );
    }
  }

  /// Delete [modelName] from database.
  Future delete(
    String modelName, {
    String where,
    List<dynamic> whereArgs,
    bool cascade = false,
    sql.Transaction txn,
  }) async {
    if (txn == null) {
      await _db.transaction((txn) async => await delete(
            modelName,
            cascade: cascade,
            txn: txn,
          ));
    }

    ModelInfo modelInfo = models[modelName];

    if (cascade) {
      Map<String, dynamic> dbMap = (await load(
        modelName,
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
