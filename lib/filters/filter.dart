import 'dart:ui' as ui;

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';

import '../image_utils.dart';

class LandmarkFilterInfo {
  String imageFilename;
  ui.Image dartImage;

  double width;
  double height;

  double get maxWidth => dartImage.width.toDouble();

  double get maxHeight => dartImage.height.toDouble();

  Size get size => Size(width, height);

  LandmarkFilterInfo(this.imageFilename, this.dartImage, this.width, this.height);

  LandmarkFilterInfo.fromDartImage(this.imageFilename, this.dartImage) {
    width = dartImage.width.toDouble();
    height = dartImage.height.toDouble();
  }

  static Future<LandmarkFilterInfo> fromFilename(String filename) async {
    ui.Image dartImage = await getAppDartImage(filename);
    if (dartImage == null) return null;
    return LandmarkFilterInfo.fromDartImage(filename, dartImage);
  }
}

class Filter {
  /// The database ID for this filter
  int id;

  /// The name of this filter
  String name;

  /// The icon of this filter
  IconData icon;

  /// The map containing the image filters applied to Facial Landmarks
  Map<FaceLandmarkType, LandmarkFilterInfo> landmarks = {};

  Filter([this.id, this.name, this.icon]);

  @override
  String toString() {
    return "Filter.toString(): ID=$id, Name=$name, Landmark Keys=${landmarks.keys.length}";
  }
}
