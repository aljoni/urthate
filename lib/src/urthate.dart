import 'package:urthate/src/mapping/bool_mapper.dart';
import 'package:urthate/src/mapping/datetime_mapper.dart';
import 'package:urthate/src/model/model_info.dart';
import 'package:urthate/src/mapping/type_mapper.dart';

import 'model/model_info.dart';

class Urthate {
  /// Singleton instance.
  static final Urthate _instance = Urthate._();

  /// Registered models.
  Map<String, ModelInfo> models = <String, ModelInfo>{};

  /// Type mappers.
  Map<String, TypeMapper> mappers = <String, TypeMapper>{
    'datetime': const DateTimeMapper(),
    'bool': const BoolMapper(),
  };

  /// Private constructor to prevent initialisation.
  Urthate._();

  /// Factory constructor returning singleton instance.
  factory Urthate() => _instance;

  /// Register a new model.
  void register(ModelInfo info) => models[info.name] = info;
}
