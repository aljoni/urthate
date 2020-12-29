/// Base type for all database models.
abstract class Model {
  String get modelName;

  Map<String, dynamic> get dbMap;

  /// Checks if the values in [dbMap] match those provided in [otherMap].
  bool matches(Map<String, dynamic> otherMap) => modelMatches(dbMap, otherMap);

  /// Checks if the values in [map] match those provided in [otherMap].
  static bool modelMatches(Map<String, dynamic> map, Map<String, dynamic> otherMap) {
    for (MapEntry<String, dynamic> entry in otherMap.entries) {
      if (!map.containsKey(entry.key)) {
        return false;
      }
      if (map[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }
}
