import 'package:urthate/src/model/column.dart';
import 'package:urthate/src/model/model_info.dart';
import 'package:urthate/src/model/reference.dart';
import 'package:urthate/src/urthate.dart';

class SQLGenerator {
  Set<String> generatedManyToManyTableNames = Set();

  String _buildColumn(Urthate ut, Column column) {
    String line = '  `${column.name}` ';

    if (ut.mappers.containsKey(column.type)) {
      line += ut.mappers[column.type].columnType.toUpperCase();
      if (ut.mappers[column.type].columnSize != null) {
        line += '(${ut.mappers[column.type].columnSize})';
      } else if (column.size != null) {
        line += '(${column.size})';
      }
    } else {
      line += column.type.toUpperCase();
      if (column.size != null) {
        line += '(${column.size})';
      }
    }

    if (column.notNull) {
      line += ' NOT NULL';
    }
    if (column.unique) {
      line += ' UNIQUE';
    }

    return line;
  }

  List<String> _buildOneToOne(Urthate ut, Column column) {
    List<String> lines = [];
    List<Column> otherPrimaries = ut.models[column.references.modelName].primaryColumns(ut);
    for (Column otherColumn in otherPrimaries) {
      lines.add(_buildColumn(
        ut,
        Column(
          name: '${column.name}__${otherColumn.name}',
          type: otherColumn.type,
          notNull: column.notNull,
        ),
      ));
    }
    return lines;
  }

  List<String> _buildOneToMany(Urthate ut, ModelInfo modelInfo) {
    List<String> lines = [];
    for (Column otherColumn in modelInfo.primaryColumns(ut)) {
      lines.add(_buildColumn(
        ut,
        Column(
          name: '${modelInfo.name}__${otherColumn.name}',
          type: otherColumn.type,
          notNull: otherColumn.notNull,
        ),
      ));
    }
    return lines;
  }

  String generateCreateTable(Urthate ut, ModelInfo modelInfo) {
    List<String> lines = [];
    List<String> primaries = [];
    List<Column> oneToOneReferences = [];
    List<Column> oneToManyReferences = [];

    // Add columns directly defined on model.
    for (Column column in modelInfo.columns[ut.version]) {
      if (column.references != null) {
        switch (column.references.type) {
          case ReferenceType.oneToOne:
            oneToOneReferences.add(column);
            break;
          case ReferenceType.oneToMany:
            oneToManyReferences.add(column);
            break;
          default:
            break;
        }
        continue;
      }
      if (column.primary) {
        primaries.add(column.name);
      }

      lines.add(_buildColumn(ut, column));
    }

    // Add columns for one-to-one.
    lines.addAll(oneToOneReferences.expand((column) => _buildOneToOne(ut, column)));

    // Add columns for one-to-many references.
    List<ModelInfo> referencesModel = ut.findModelsThatReferenceModel(modelInfo.name, ReferenceType.oneToMany);
    lines.addAll(referencesModel.expand((column) => _buildOneToMany(ut, column)));

    // Generate SQL string.
    String sql = 'CREATE TABLE `${modelInfo.name}` (\n';
    sql += lines.join(',\n');

    if (primaries.isNotEmpty) {
      sql += ',\n  PRIMARY KEY(' + primaries.map((name) => '`$name`').join(',') + '),\n';
    }

    for (Column column in oneToOneReferences) {
      ModelInfo otherModelInfo = ut.models[column.references.modelName];
      for (Column otherColumn in otherModelInfo.primaryColumns(ut)) {
        sql +=
            '  FOREIGN KEY(`${column.name}__${otherColumn.name}`) REFERENCES `${otherModelInfo.name}`(`${otherColumn.name}`),\n';
      }
    }

    for (ModelInfo otherModelInfo in referencesModel) {
      for (Column column in modelInfo.primaryColumns(ut)) {
        sql +=
            '  FOREIGN KEY(`${otherModelInfo.name}__${column.name}`) REFERENCES `${otherModelInfo.name}`(`${column.name}`),\n';
      }
    }

    sql = sql.substring(0, sql.length - 2);
    return sql + '\n)';
  }

  String _generateManyToManyForColumn(Urthate ut, ModelInfo modelInfo, Column column) {
    // Get referenced model.
    ModelInfo otherModelInfo = ut.models[column.references.modelName];

    // Ensure other model exists.
    if (otherModelInfo == null) {
      throw StateError('Model "${column.references.modelName}", referenced by "${modelInfo.name}", does not exist');
    }

    // Generate table name by combining both names in alphabetical order.
    String tableName = ([modelInfo.name, otherModelInfo.name]..sort((a, b) => a.compareTo(b))).join('__');

    // Prevent generating the linking table twice.
    if (generatedManyToManyTableNames.contains(tableName)) {
      return null;
    }
    generatedManyToManyTableNames.add(tableName);

    // Ensure other model references the model were generating for.
    if (!otherModelInfo.referencesModel(ut, modelInfo.name, ReferenceType.manyToMany)) {
      throw StateError(
          'Model "${column.references.modelName}", referenced by "${modelInfo.name}", does not have a manyToMany reference to "${modelInfo.name}"');
    }

    // Generate columns linking both tables.
    List<String> columnNames = [];
    List<String> lines = []
      ..addAll(modelInfo.primaryColumns(ut).map((column) {
        columnNames.add('${modelInfo.name}__${column.name}');
        return _buildColumn(
            ut,
            Column(
              name: '${modelInfo.name}__${column.name}',
              type: column.type,
              size: column.size,
            ));
      }))
      ..addAll(otherModelInfo.primaryColumns(ut).map((column) {
        columnNames.add('${otherModelInfo.name}__${column.name}');
        return _buildColumn(
            ut,
            Column(
              name: '${otherModelInfo.name}__${column.name}',
              type: column.type,
              size: column.size,
            ));
      }));

    // Generate SQL string.
    String sql = 'CREATE TABLE `$tableName` (\n';
    sql += lines.join(',\n');
    sql += ',\n  PRIMARY KEY(' + columnNames.map((name) => '`$name`').join(',') + '),\n';
    modelInfo.primaryColumns(ut).forEach((column) => sql +=
        '  FOREIGN KEY(`${modelInfo.name}__${column.name}`) REFERENCES `${modelInfo.name}`(`${column.name}`),\n');
    otherModelInfo.primaryColumns(ut).forEach((column) => sql +=
        '  FOREIGN KEY(`${otherModelInfo.name}__${column.name}`) REFERENCES `${otherModelInfo.name}`(`${column.name}`),\n');
    sql = sql.substring(0, sql.length - 2);
    return sql + '\n)';
  }

  List<String> _generateManyToManyTablesForModel(Urthate ut, ModelInfo modelInfo) => modelInfo
      .getColumnsWithReference(ut, ReferenceType.manyToMany)
      .map((column) => _generateManyToManyForColumn(ut, modelInfo, column))
      .toList();

  List<String> generateManyToManyTables(Urthate ut) => ut
      .findModelsWithReferenceType(ReferenceType.manyToMany)
      .expand((model) => _generateManyToManyTablesForModel(ut, model))
      .where((sql) => sql != null)
      .toList();
}
