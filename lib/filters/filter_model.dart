import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:photofilters/base_model.dart';
import 'package:photofilters/image_utils.dart';
import 'package:photofilters/ml_utils.dart';

FilterModel filtersModel = FilterModel();

class FilterInfo {
  ImageWrapper imageWrapper;
  double width;
  double height;

  FilterInfo(this.imageWrapper) {
    width = imageWrapper.width;
    height = imageWrapper.height;
  }
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
  get dbLandmarks => landmarks.keys
      .map((landmark) {
        print('Reading: $landmark, ${landmarks.keys.toList()}');
        return landmark.toString();
      })
      .join(',');

  get dbWidths => landmarks.values.map((filterInfo) => filterInfo.width).join(',');

  get dbHeights => landmarks.values.map((filterInfo) => filterInfo.height).join(',');

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
      
      print('Parsed: $landmarkType from string ${landmarkSplit[i]}, ');
      double width = double.tryParse(widthSplit[i]);
      double height = double.tryParse(heightSplit[i]);
      var imageWrapper = await ImageWrapper.fromFilename(getLandmarkFilename(filterName, landmarkType));
      result.landmarks[landmarkType] = FilterInfo(imageWrapper)
        ..width = width
        ..height = height;
    }
    return result;
  }
}

class FilterModel extends BaseModel<Filter> {
  int _currentStep = 0;
  ImageML _imageML;
  Map<FaceLandmarkType, FilterInfo> _landmarks = {};

  get currentStep => _currentStep;

  set currentStep(value) {
    _currentStep = value;
    notifyListeners();
  }

  get landmarks => _landmarks;

  set landmarks(value) {
    this._landmarks = value;
    notifyListeners();
  }

  get imageML => _imageML;

  set imageML(value) {
    this._imageML = value;
    notifyListeners();
  }

  void clear() {
    _currentStep = 0;
    _landmarks = {};
  }

  void addLandmarkFilter(FaceLandmarkType landmarkType, ImageWrapper imageWrapper) {
    landmarks[landmarkType] = FilterInfo(imageWrapper);
    notifyListeners();
  }
}
