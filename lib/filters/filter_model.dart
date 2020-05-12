import 'package:camera/camera.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:photofilters/base_model.dart';
import 'package:photofilters/ml/image_ml.dart';

import 'filter.dart';

FilterModel filtersModel = FilterModel();

class FilterModel extends BaseModel<Filter> {
  ImageML _imageML;
  Map<FaceLandmarkType, FilterInfo> _landmarks = {};

  CameraLensDirection cameraLensDirection = CameraLensDirection.front;
  int _currentStep = 0;

  int get currentStep => _currentStep;

  ImageML get imageML => _imageML;

  Map<FaceLandmarkType, FilterInfo> get landmarks => _landmarks;

  set currentStep(int value) {
    _currentStep = value;
    notifyListeners();
  }

  set imageML(ImageML value) {
    this._imageML = value;
    notifyListeners();
  }

  set landmarks(Map<FaceLandmarkType, FilterInfo> value) {
    this._landmarks = value;
    notifyListeners();
  }

  void clear() {
    _currentStep = 0;
    _landmarks.clear();
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
