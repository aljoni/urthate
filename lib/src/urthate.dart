import 'package:urthate/src/mapping/bool_mapper.dart';
import 'package:urthate/src/mapping/datetime_mapper.dart';
import 'package:urthate/src/model/model_info.dart';
import 'package:urthate/src/mapping/type_mapper.dart';
import 'package:urthate/src/model/reference.dart';

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

  /// Returns a list of all models which contain a reference of type [referenceType].
  List<ModelInfo> findModelsWithReferenceType(ReferenceType referenceType) =>
      models.values.where((model) => model.hasReferenceOfType(referenceType)).toList();

  /// Returns a list of all models which reference the [modelName] specified, by default finds models which reference
  /// using [ReferenceType.oneToMany].
  List<ModelInfo> findModelsThatReference(String modelName, {ReferenceType referenceType = ReferenceType.oneToMany}) =>
      models.values.where((model) => model.referencesModel(modelName, referenceType)).toList();
}
