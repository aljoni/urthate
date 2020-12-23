import 'package:flutter/foundation.dart';
import 'package:urthate/src/model/reference.dart';

/// Stores information about a table column.
@immutable
class Column {
  /// Column name.
  final String name;

  /// Column type (e.g. integer, real, text, blob).
  final String type;

  /// Size of column.
  final int size;

  /// Whether column forms part of primary key.
  final bool primary;

  /// Whether column values must be unique.
  final bool unique;

  /// Whether column value should not be null.
  final bool notNull;

  /// Name of other model which column references.
  final Reference references;

  const Column({
    @required this.name,
    this.type,
    this.size,
    this.primary = false,
    this.unique = false,
    this.notNull = false,
    this.references,
  });
}
