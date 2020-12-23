/// Mapper between types [F] and [T].
abstract class TypeMapper<F, T> {
  const TypeMapper();

  /// Type that column should have (integer, real, text, blob).
  String get columnType;

  /// Size that column should have, return null if not important.
  int get columnSize;

  /// Map from [F] to [T].
  T mapTo(F value);

  /// Map from [T] to [F].
  F mapFrom(T value);
}
