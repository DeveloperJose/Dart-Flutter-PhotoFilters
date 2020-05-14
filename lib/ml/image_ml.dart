import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../image_utils.dart';
import 'firebase_utils.dart';

/// The different ways an ImageML can be loaded
enum ImageMLType { LIVE_CAMERA_MEMORY, FILE, ASSET }

/// The different states an ImageML goes through when being loaded
enum ImageMLLoadState { START, LOADING_ASSET, LOADING_IMAGE, LOADING_IMAGE_INFO, PERFORMING_ML, CLEANING_UP, FINISHED }

/// Image ML (Machine Learning) class
/// Contains the information related to the machine learning aspects of an Image
/// Wraps all the needed information for processing
class ImageML {
  /// How this image needs to be loaded or was loaded
  ImageMLType loadType;

  /// The list of faces provided by the FirebaseVision face detector
  List<Face> faces;

  /// If loaded from FILE, this will be the filename that can be passed to image_utils functions
  /// If loaded from ASSET, this will be the asset path
  String filename;

  /// The dart:ui Image which contains the image dimensions, null if loaded from memory
  ui.Image dartImage;

  /// The flutter Image widget containing the image, null if loaded from memory
  Image flutterImage;

  /// Is this image already loaded?
  bool isLoaded = false;

  /// The width of the image, null if not loaded or loaded from memory
  double get width => dartImage?.width?.toDouble();

  /// The height of the image, null if not loaded or loaded from memory
  double get height => dartImage?.height?.toDouble();

  /// The size of the image, null if not loaded or loaded from memory
  Size get size => Size(width, height);

  /// Constructs an ImageML
  ImageML(this.loadType, [this.filename]) {
    isLoaded = loadType == ImageMLType.LIVE_CAMERA_MEMORY;
  }

  /// Loads this image and processes it based on the loadType
  /// Streams the loading state it's currently at
  Stream<ImageMLLoadState> load() async* {
    if (loadType == ImageMLType.ASSET)
      yield* _loadAsset();
    else if (loadType == ImageMLType.FILE) yield* _loadFile();
  }

  /// Loads this image from a file
  /// Streams the loading state it's currently at
  Stream<ImageMLLoadState> _loadFile() async* {
    yield ImageMLLoadState.LOADING_IMAGE;
    this.flutterImage = getAppFlutterImage(filename);

    yield ImageMLLoadState.LOADING_IMAGE_INFO;
    this.dartImage = await getAppDartImage(filename);

    yield ImageMLLoadState.PERFORMING_ML;
    var firebaseImage = getAppFirebaseImage(filename);
    this.faces = await faceDetector.processImage(firebaseImage);

    isLoaded = true;
    yield ImageMLLoadState.FINISHED;
  }

  /// Loads this image from an asset
  /// Streams the loading state it's currently at
  Stream<ImageMLLoadState> _loadAsset() async* {
    // Save image temporarily into a file
    yield ImageMLLoadState.LOADING_ASSET;
    File tempFile = await createAppFileFromAssetIfNotExists(filename);

    // Load from file
    yield* _loadFile();

    // Remove temp file
    yield ImageMLLoadState.CLEANING_UP;
    tempFile.delete();

    yield ImageMLLoadState.FINISHED;
  }
}
