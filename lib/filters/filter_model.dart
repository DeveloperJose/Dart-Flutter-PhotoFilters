import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:photofilters/base_model.dart';
import 'package:photofilters/image_utils.dart';
import 'package:photofilters/ml_utils.dart';

FilterModel filtersModel = FilterModel();

class FilterInfo {
  String imageFilename;
  double width;
  double height;

  FilterInfo(this.imageFilename, this.width, this.height);
}

class Filter {
  int id;
  String name;
  Map<FaceLandmarkType, FilterInfo> landmarks = {};

  @override
  String toString() {
    return "Filter.toString(): ID=$id, Name=$name, Landmark Keys=${landmarks.keys.length}";
  }

  /// Database helper methods
  String get dbLandmarks => landmarks.keys
      .map((landmark) {
        print('Reading: $landmark, ${landmarks.keys.toList()}');
        return landmark.toString();
      })
      .join(',');

  String get dbWidths => landmarks.values.map((filterInfo) => filterInfo.width).join(',');

  String get dbHeights => landmarks.values.map((filterInfo) => filterInfo.height).join(',');

  static Future<Filter> fromDatabase(int id, String filterName, String landmarkStr, String widthStr, String heightStr) async {
    var result = Filter()
      ..id = id
      ..name = filterName;

    List<String> landmarkSplit = landmarkStr.split(',');
    List<String> widthSplit = widthStr.split(',');
    List<String> heightSplit = heightStr.split(',');
    if (landmarkSplit.length == 0) return null;

    for (int i = 0; i < landmarkSplit.length; i++) {
      // String to Enum
      var landmarkType = FaceLandmarkType.values.singleWhere((e) => e.toString() == landmarkSplit[i]);

      var filename = getLandmarkFilename(filterName, landmarkType);
      double width = double.tryParse(widthSplit[i]);
      double height = double.tryParse(heightSplit[i]);

      result.landmarks[landmarkType] = FilterInfo(filename, width, height);
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

  void addLandmarkFilter(FaceLandmarkType landmarkType, String filename) {
    landmarks[landmarkType] = FilterInfo(filename, 20, 20);
    notifyListeners();
  }
}