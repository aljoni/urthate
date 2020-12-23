import 'package:urthate/src/mapping/type_mapper.dart';

class BoolMapper extends TypeMapper<bool, int> {
  const BoolMapper() : super();

  @override
  String get columnType => 'numeric';

  @override
  int get columnSize => 1;

  @override
  bool mapFrom(int value) => value == 1;

  @override
  int mapTo(bool value) => value ? 1 : 0;
}
