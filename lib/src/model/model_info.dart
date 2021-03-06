import 'package:flutter/foundation.dart';
import 'package:urthate/src/model/model.dart';
import 'package:urthate/src/model/column.dart';
import 'package:urthate/src/model/reference.dart';
import 'package:urthate/src/urthate.dart';

/// Mapper function to create a [Model] from a [Map].
typedef T ModelFromMap<T extends Model>(Map<String, dynamic> map);

/// Information about a database model.
@immutable
class ModelInfo {
  /// Name of model / database table.
  final String name;

  /// Table columns.
  final Map<int, List<Column>> columns;

  /// Mapper function.
  final ModelFromMap fromDbMap;

  const ModelInfo({
    @required this.name,
    @required this.columns,
    @required this.fromDbMap,
  });

  /// Returns a list of all columns marked as primary.
  List<Column> primaryColumns(int version) => columns[version].where((column) => column.primary).toList();

  /// Returns a list of all columns with a reference of type [referenceType].
  List<Column> getColumnsWithReference(Urthate ut, ReferenceType referenceType) => columns[ut.version]
      .where((column) => column.references != null && column.references.type == referenceType)
      .toList();

  /// Returns true if model has any columns with a reference of type [referenceType].
  bool hasReferenceOfType(Urthate ut, ReferenceType referenceType) =>
      columns[ut.version].any((column) => column.references != null && column.references.type == referenceType);

  /// Returns true if model references the [modelName] specified.
  bool referencesModel(Urthate ut, String modelName, ReferenceType referenceType) => columns[ut.version].any((column) =>
      column.references != null &&
      (column.references.modelName == modelName && column.references.type == referenceType));
}
