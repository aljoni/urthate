import 'package:flutter/foundation.dart';
import 'package:urthate/src/model/model.dart';

/// Mapper function to create a [Model] from a [Map].
typedef T ModelFromMap<T extends Model>(Map<String, dynamic> map);

/// Information about a database model.
@immutable
class ModelInfo {
  /// Name of model / database table.
  final String name;

  /// Table columns.
  final Map<String, String> columns;

  /// Mapper function.
  final ModelFromMap mapper;

  const ModelInfo({
    @required this.name,
    @required this.columns,
    @required this.mapper,
  });
}
