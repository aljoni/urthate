import 'package:urthate/src/model/column.dart';
import 'package:urthate/src/model/model_info.dart';
import 'package:urthate/src/model/reference.dart';
import 'package:urthate/src/urthate.dart';

class SQLGenerator {
  Set<String> generatedManyToManyTableNames = Set();

  String _buildColumn(Column column) {
    String line = '  `${column.name}` ';

    if (Urthate().mappers.containsKey(column.type)) {
      line += Urthate().mappers[column.type].columnType;
      if (Urthate().mappers[column.type].columnSize != null) {
        line += '(${Urthate().mappers[column.type].columnSize})';
      } else if (column.size != null) {
        line += '(${column.size})';
      }
    } else {
      line += column.type;
      if (column.size != null) {
        line += '(${column.size})';
      }
    }

    if (column.notNull) {
      line += ' not null';
    }
    if (column.unique) {
      line += ' unique';
    }

    return line;
  }

  List<String> _buildOneToOne(Column column) {
    List<String> lines = [];
    List<Column> otherPrimaries = Urthate().models[column.references.modelName].primaryColumns;
    for (Column otherColumn in otherPrimaries) {
      lines.add(_buildColumn(
        Column(
          name: '${column.name}__${otherColumn.name}',
          type: otherColumn.type,
          notNull: column.notNull,
        ),
      ));
    }
    return lines;
  }

  List<String> _buildOneToMany(ModelInfo modelInfo) {
    List<String> lines = [];
    for (Column otherColumn in modelInfo.primaryColumns) {
      lines.add(_buildColumn(
        Column(
          name: '${modelInfo.name}__${otherColumn.name}',
          type: otherColumn.type,
          notNull: otherColumn.notNull,
        ),
      ));
    }
    return lines;
  }

  String generateCreateTable(ModelInfo modelInfo) {
    List<String> lines = [];
    List<String> primaries = [];
    List<Column> oneToOneReferences = [];
    List<Column> oneToManyReferences = [];

    // Add columns directly defined on model.
    for (Column column in modelInfo.columns) {
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

      lines.add(_buildColumn(column));
    }

    // Add columns for one-to-one.
    lines.addAll(oneToOneReferences.expand(_buildOneToOne));

    // Add columns for one-to-many references.
    List<ModelInfo> referencesModel = Urthate().findModelsThatReference(modelInfo.name);
    lines.addAll(referencesModel.expand(_buildOneToMany));

    // Generate SQL string.
    String sql = 'CREATE TABLE `${modelInfo.name}` (\n';
    sql += lines.join(',\n');
    if (primaries.isNotEmpty) {
      sql += ',\n\n  primary key(' + primaries.map((name) => '`$name`').join(',') + ')\n';
    } else {
      sql += '\n';
    }
    return sql + ')';
  }

  String _generateManyToManyForColumn(ModelInfo modelInfo, Column column) {
    // Get referenced model.
    ModelInfo otherModelInfo = Urthate().models[column.references.modelName];

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
    if (!otherModelInfo.referencesModel(modelInfo.name, ReferenceType.manyToMany)) {
      throw StateError(
          'Model "${column.references.modelName}", referenced by "${modelInfo.name}", does not have a manyToMany reference to "${modelInfo.name}"');
    }

    // Generate columns linking both tables.
    List<String> lines = []
      ..addAll(modelInfo.primaryColumns.map(_buildColumn))
      ..addAll(otherModelInfo.primaryColumns.map(_buildColumn));

    // Generate SQL string.
    String sql = 'CREATE TABLE `$tableName` (\n';
    sql += lines.join(',\n');
    return sql + '\n)';
  }

  List<String> _generateManyToManyTablesForModel(ModelInfo modelInfo) => modelInfo
      .getColumnsWithReference(ReferenceType.manyToMany)
      .map((column) => _generateManyToManyForColumn(modelInfo, column))
      .toList();

  List<String> generateManyToManyTables() => Urthate()
      .findModelsWithReferenceType(ReferenceType.manyToMany)
      .expand((model) => _generateManyToManyTablesForModel(model))
      .where((sql) => sql != null)
      .toList();
}
