import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:photofilters/base_model.dart';
import 'package:photofilters/ml/image_ml.dart';

import 'filter.dart';

class FilterModel extends BaseModel<Filter> {
  ImageML _imageML;
  Map<FaceLandmarkType, FilterInfo> _landmarks = {};

  /// Stores a copy of ImageML when we are creating a filter
  /// Used to preform machine learning operations without losing our previous ImageML
  ImageML imageMLEdit;

  /// The image containing the face to be detected
  ImageML get imageML => _imageML;

  /// The map of filter information for each face landmark needed to be applied
  Map<FaceLandmarkType, FilterInfo> get landmarks => _landmarks;

  set imageML(ImageML value) {
    this._imageML = value;
    notifyListeners();
  }

  set landmarks(Map<FaceLandmarkType, FilterInfo> value) {
    this._landmarks = value;
    notifyListeners();
  }

  @override
  void loadData(database) {
    super.loadData(database);
    entityList.insert(0, Filter(-1, 'No Filter'));
  }

  /// Adds a landmark filter to this model and updates the views
  void addLandmarkFilter(FaceLandmarkType landmarkType, FilterInfo filterInfo) {
    landmarks[landmarkType] = filterInfo;
    notifyListeners();
  }
}
