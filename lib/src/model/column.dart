import 'package:flutter/foundation.dart';

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

  /// Name of other model which column references.
  final String references;

  const Column({
    @required this.name,
    @required this.type,
    this.size,
    this.primary = false,
    this.unique = false,
    this.references,
  });
}
