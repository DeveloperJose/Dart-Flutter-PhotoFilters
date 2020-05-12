import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:photofilters/base_model.dart';
import 'package:photofilters/ml/image_ml.dart';

import 'filter.dart';

class FilterModel extends BaseModel<Filter> {
  ImageML _imageML;
  Map<FaceLandmarkType, FilterInfo> _landmarks = {};
  int _currentPreviewedFilterIndex = 0;

  // TODO: Remove FAStepper
  int _currentStep = 0;

  int get currentStep => _currentStep;

  set currentStep(int value) {
    _currentStep = value;
    notifyListeners();
  }

  /// Stores a copy of ImageML when we are creating a filter
  /// Used to preform machine learning operations without losing our previous ImageML
  ImageML imageMLEdit;

  /// The image containing the face to be detected
  ImageML get imageML => _imageML;

  set imageML(ImageML value) {
    this._imageML = value;
    notifyListeners();
  }

  /// The map of filter information for each face landmark needed to be applied
  Map<FaceLandmarkType, FilterInfo> get landmarks => _landmarks;

  set landmarks(Map<FaceLandmarkType, FilterInfo> value) {
    this._landmarks = value;
    notifyListeners();
  }

  /// The current filter (index) being previewed
  int get currentPreviewedFilterIndex => _currentPreviewedFilterIndex;

  set currentPreviewedFilterIndex(int value) {
    _currentPreviewedFilterIndex = value;
    notifyListeners();
  }

  /// The current filter being previewed
  Filter get currentPreviewedFilter {
    if (_currentPreviewedFilterIndex >= entityList.length) return null;
    return entityList[_currentPreviewedFilterIndex];
  }

  @override
  void loadData(database) {
    super.loadData(database);
    entityList.insert(0, Filter(-1, 'No Filter'));
  }

  void addLandmarkFilter(FaceLandmarkType landmarkType, FilterInfo filterInfo) {
    landmarks[landmarkType] = filterInfo;
    notifyListeners();
  }
}
