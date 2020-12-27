/// Base type for all database models.
abstract class Model {
  String get modelName;

  Map<String, dynamic> get dbMap;
}
