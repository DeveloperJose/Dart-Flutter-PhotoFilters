import 'dart:ui' as ui;

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';

import '../image_utils.dart';

/// Contains information about a Face Landmark Filter
class LandmarkFilterInfo {
  /// Filename for the landmark filter image
  String imageFilename;

  /// dart:ui Image used for rendering and resizing
  ui.Image dartImage;

  /// The width of the filter, given by the user during creation
  double width;

  /// The height of the filter, given by the user during creation
  double height;

  /// The filter size
  Size get size => Size(width, height);

  /// The max width of the filter
  double get maxWidth => dartImage.width.toDouble();

  /// The max height of the filter
  double get maxHeight => dartImage.height.toDouble();

  /// Creates a new LandmarkFilter
  LandmarkFilterInfo(this.imageFilename, this.dartImage, this.width, this.height);

  /// Creates a LandmarkFilter from a filename and dartImage
  LandmarkFilterInfo.fromDartImage(this.imageFilename, this.dartImage) {
    width = dartImage.width.toDouble();
    height = dartImage.height.toDouble();
  }

  /// Creates a LandmarkFilter from a filename
  static Future<LandmarkFilterInfo> fromFilename(String filename) async {
    ui.Image dartImage = await getAppDartImage(filename);
    if (dartImage == null) return null;
    return LandmarkFilterInfo.fromDartImage(filename, dartImage);
  }
}

/// A fun photo filter that overlays pictures on top of an image using machine learning and face recognition
class Filter {
  /// The database ID for this filter
  int id;

  /// The name of this filter
  String name;

  /// The icon of this filter
  IconData icon;

  /// The map containing the image filters applied to Facial Landmarks
  Map<FaceLandmarkType, LandmarkFilterInfo> landmarks = {};

  /// Creates a new filter
  Filter([this.id, this.name, this.icon]);

  @override
  String toString() {
    return "Filter.toString(): ID=$id, Name=$name, Landmark Keys=${landmarks.keys.length}";
  }
}
