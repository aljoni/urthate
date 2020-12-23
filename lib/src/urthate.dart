import 'package:flutter/foundation.dart';
import 'package:urthate/src/mapping/bool_mapper.dart';
import 'package:urthate/src/mapping/datetime_mapper.dart';
import 'package:urthate/src/model/model_info.dart';
import 'package:urthate/src/mapping/type_mapper.dart';

@immutable
class Urthate {
  /// Singleton instance.
  static final Urthate _instance = Urthate._();

  /// Registered models.
  final Map<String, ModelInfo> models = const <String, ModelInfo>{};

  /// Type mappers.
  final Map<String, TypeMapper> mappers = const <String, TypeMapper>{
    'datetime': const DateTimeMapper(),
    'bool': const BoolMapper(),
  };

  /// Private constructor to prevent initialisation.
  const Urthate._();

  /// Factory constructor returning singleton instance.
  factory Urthate() => _instance;

  /// Register a new model.
  void register(ModelInfo info) => models[info.name] = info;
}
