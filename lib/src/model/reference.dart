import 'package:flutter/foundation.dart';

enum ReferenceType {
  oneToOne,
  oneToMany,
  manyToMany,
}

@immutable
class Reference {
  final String modelName;
  final ReferenceType type;

  const Reference(this.modelName, this.type);
}
