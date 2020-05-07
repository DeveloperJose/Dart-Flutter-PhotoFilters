import 'dart:ui' as ui;
import 'dart:ui';

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:photofilters/base_model.dart';
import 'package:photofilters/image_utils.dart';
import 'package:photofilters/ml_utils.dart';

FilterModel filtersModel = FilterModel();

class FilterInfo {
  String imageFilename;
  ui.Image dartImage;

  double width;
  double height;
  Size get size => Size(width, height);

  FilterInfo(this.imageFilename, this.dartImage, this.width, this.height);

  FilterInfo.fromDartImage(this.imageFilename, this.dartImage) {
    width = dartImage.width.toDouble();
    height = dartImage.height.toDouble();
  }

  static Future<FilterInfo> fromFilename(String filename) async {
    ui.Image dartImage = await getAppDartImage(filename);
    if (dartImage == null) return null;
    return FilterInfo.fromDartImage(filename, dartImage);
  }
}

class Filter {
  int id;
  String name;
  Map<FaceLandmarkType, FilterInfo> landmarks = {};

  Filter([this.id, this.name]);

  @override
  String toString() {
    return "Filter.toString(): ID=$id, Name=$name, Landmark Keys=${landmarks.keys.length}";
  }

  /// Database helper methods
  String get dbLandmarks => landmarks.keys.map((landmark) => landmark.toString()).join(',');

  String get dbWidths => landmarks.values.map((filterInfo) => filterInfo.width).join(',');

  String get dbHeights => landmarks.values.map((filterInfo) => filterInfo.height).join(',');

  static Future<Filter> fromDatabase(int id, String filterName, String landmarkStr, String widthStr, String heightStr) async {
    Filter result = Filter(id, filterName);

    List<String> landmarkSplit = landmarkStr.split(',');
    List<String> widthSplit = widthStr.split(',');
    List<String> heightSplit = heightStr.split(',');
    if (landmarkSplit.length == 0) return null;

    for (int i = 0; i < landmarkSplit.length; i++) {
      // String to Enum
      FaceLandmarkType landmarkType = FaceLandmarkType.values.singleWhere((e) => e.toString() == landmarkSplit[i]);

      // Prepare FilterInfo members
      String filename = getLandmarkFilename(filterName, landmarkType);
      double width = double.tryParse(widthSplit[i]);
      double height = double.tryParse(heightSplit[i]);
      ui.Image dartImage = await getAppDartImage(filename);

      result.landmarks[landmarkType] = FilterInfo(filename, dartImage, width, height);
    }
    return result;
  }
}

class FilterModel extends BaseModel<Filter> {
  int _currentStep = 0;
  ImageML _imageML;
  Map<FaceLandmarkType, FilterInfo> _landmarks = {};

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

  void addLandmarkFilter(FaceLandmarkType landmarkType, FilterInfo filterInfo) {
    landmarks[landmarkType] = filterInfo;
    notifyListeners();
  }
}
