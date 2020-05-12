import 'dart:ui' as ui;

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';

import '../image_utils.dart';

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
