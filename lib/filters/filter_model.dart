import 'dart:io';
import 'package:flutter/material.dart';
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
  String name;
  Map<FaceLandmarkType, FilterInfo> landmarks = {};

  @override
  String toString() {
    return "Filter.toString(): $name";
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

  void addLandmarkFilter(FaceLandmarkType type, ImageWrapper image)
  {
    landmarks[type] = FilterInfo(image);
    notifyListeners();
  }
}