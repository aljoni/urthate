import 'package:urthate/src/model/model_info.dart';

/// Base type for all database models.
abstract class Model {
  ModelInfo get modelInfo;

  Map<String, dynamic> get dbMap;
}
