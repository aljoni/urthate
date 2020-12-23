import 'package:urthate/src/mapping/type_mapper.dart';

class DateTimeMapper extends TypeMapper<DateTime, String> {
  const DateTimeMapper() : super();

  @override
  String get columnType => 'text';

  @override
  int get columnSize => null;

  @override
  DateTime mapFrom(String value) => DateTime.parse(value).toLocal();

  @override
  String mapTo(DateTime value) => value.toUtc().toIso8601String();
}
