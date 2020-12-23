import 'package:flutter/foundation.dart';
import 'package:urthate/src/model/model.dart';
import 'package:urthate/src/model/column.dart';
import 'package:urthate/src/model/reference.dart';
import 'package:urthate/src/urthate.dart';

import '../urthate.dart';
import '../urthate.dart';
import '../urthate.dart';
import 'column.dart';
import 'column.dart';

/// Mapper function to create a [Model] from a [Map].
typedef T ModelFromMap<T extends Model>(Map<String, dynamic> map);

/// Information about a database model.
@immutable
class ModelInfo {
  /// Name of model / database table.
  final String name;

  /// Table columns.
  final List<Column> columns;

  /// Mapper function.
  final ModelFromMap mapper;

  const ModelInfo({
    @required this.name,
    @required this.columns,
    @required this.mapper,
  });

  List<Column> get primaryColumns => columns.where((column) => column.primary).toList();

  String _buildColumn(Urthate u, Column column) {
    String line = '  `${column.name}` ';

    if (u.mappers.containsKey(column.type)) {
      line += u.mappers[column.type].columnType;
      if (u.mappers[column.type].columnSize != null) {
        line += '(${u.mappers[column.type].columnSize})';
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

  List<String> _buildOneToOne(Urthate u, Column column) {
    List<String> lines = [];
    List<Column> otherPrimaries = u.models[column.reference.modelName].primaryColumns;
    for (Column otherColumn in otherPrimaries) {
      lines.add(_buildColumn(
        u,
        Column(
          name: '${column.name}__${otherColumn.name}',
          type: otherColumn.type,
          notNull: column.notNull,
        ),
      ));
    }
    return lines;
  }

  String buildCreateTable() {
    final Urthate u = Urthate();

    List<String> lines = [];
    List<String> primaries = [];
    List<Column> references = [];

    for (Column column in columns) {
      if (column.reference != null) {
        references.add(column);
        continue;
      }
      if (column.primary) {
        primaries.add('`${column.name}`');
      }

      lines.add(_buildColumn(u, column));
    }

    for (Column column in references) {
      switch (column.reference.type) {
        case ReferenceType.oneToOne:
          lines.addAll(_buildOneToOne(u, column));
          break;
        default:
          throw UnimplementedError();
      }
    }

    String sql = 'CREATE TABLE $name (\n';
    sql += lines.join(',\n');
    if (primaries.isNotEmpty) {
      sql += ',\n\n  primary key(' + primaries.join(',') + ')\n';
    } else {
      sql += '\n';
    }
    return sql + ')';
  }
}
