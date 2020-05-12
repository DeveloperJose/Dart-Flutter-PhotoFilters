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
}
