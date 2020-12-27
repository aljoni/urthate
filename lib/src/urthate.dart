import 'package:flutter/foundation.dart';
import 'package:urthate/src/mapping/bool_mapper.dart';
import 'package:urthate/src/mapping/datetime_mapper.dart';
import 'package:urthate/src/model/model_info.dart';
import 'package:urthate/src/mapping/type_mapper.dart';
import 'package:urthate/src/model/reference.dart';

class Urthate {
  /// Database version.
  int version;

  /// Registered models.
  Map<String, ModelInfo> models = <String, ModelInfo>{};

  /// Type mappers.
  Map<String, TypeMapper> mappers = <String, TypeMapper>{
    'datetime': const DateTimeMapper(),
    'bool': const BoolMapper(),
  };

  Urthate({
    @required this.version,
  });

  /// Register a new model.
  void register(ModelInfo info) => models[info.name] = info;

  /// Returns a list of all models which contain a reference of type [referenceType].
  List<ModelInfo> findModelsWithReferenceType(ReferenceType referenceType) =>
      models.values.where((model) => model.hasReferenceOfType(this, referenceType)).toList();

  /// Returns a list of all models which reference the [modelName] specified, by default finds models which reference
  /// using [ReferenceType.oneToMany].
  List<ModelInfo> findModelsThatReferenceModel(String modelName, ReferenceType referenceType) =>
      models.values.where((model) => model.referencesModel(this, modelName, referenceType)).toList();
}
