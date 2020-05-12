import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_camera_ml_vision/flutter_camera_ml_vision.dart';
import 'package:photofilters/filters/filter_model.dart';

import '../image_utils.dart';
import 'face_overlay_painter.dart';
import 'firebase_utils.dart';

/// We keep track of this so we don't make multiples in the widget tree
/// That would cause the widget to refresh constantly
final GlobalKey<CameraMlVisionState> _cameraMLVisionKey = GlobalKey();

enum ImageMLType { MEMORY, FILE, ASSET }

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

  ImageML(this.loadType, [this.filename]) {
    isLoaded = loadType == ImageMLType.MEMORY;
  }

  /// Builds the custom painter widget which draws all our filter effects onto the canvas
  Widget buildOverlayWidget(FaceOverlayPainter overlayPainter) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: overlayPainter),
      ),
    );
  }

  Widget _buildProgressStack(String progressText, [Widget backgroundWidget]) {
    if (backgroundWidget == null) backgroundWidget = Container();
    return Stack(alignment: AlignmentDirectional.center, children: [backgroundWidget, Text(progressText), Positioned(child: CircularProgressIndicator())]);
  }

  Stream<Widget> _loadFile(FaceOverlayPainter overlayPainter) async* {
    yield _buildProgressStack('Loading image...');
    this.flutterImage = getAppFlutterImage(filename);

    yield _buildProgressStack('Loading image dimensions and information...', flutterImage);
    this.dartImage = await getAppDartImage(filename);

    yield _buildProgressStack('Performing machine learning recognition...', buildOverlayWidget(overlayPainter));
    var firebaseImage = getAppFirebaseImage(filename);
    this.faces = await faceDetector.processImage(firebaseImage);

    yield buildOverlayWidget(overlayPainter);
    isLoaded = true;
  }

  Stream<Widget> _loadAsset(FaceOverlayPainter overlayPainter) async* {
    // Save image temporarily into a file
    yield _buildProgressStack('Loading asset from app...');
    File tempFile = await createAppFileFromAssetIfNotExists(filename);

    // Load from file
    yield* _loadFile(overlayPainter);

    // Remove temp file
    yield _buildProgressStack('Cleaning up...', buildOverlayWidget(overlayPainter));
    tempFile.delete();

    yield buildOverlayWidget(overlayPainter);
    isLoaded = true;
  }

  static Widget buildPreviewWidget(BuildContext context, FilterModel model) {
    if (model.imageML == null)
      return Center(child: Text('Error: Cannot load preview widget'));
    else if (model.imageML.loadType == ImageMLType.MEMORY)
      return _buildLivePreviewWidget(model);
    else
      return _buildImagePreviewWidget(model);
  }

  static Widget _buildImagePreviewWidget(FilterModel model) {
    // Show if loaded. If not loaded, load asynchronously so the user doesn't get impacted
    var overlayPainter = FaceOverlayPainter(model);
    if (model.imageML.isLoaded)
      return model.imageML.buildOverlayWidget(overlayPainter);
    else
      return StreamBuilder<Widget>(
        initialData: Container(),
        stream: (model.imageML.loadType == ImageMLType.FILE) ? model.imageML._loadFile(overlayPainter) : model.imageML._loadAsset(overlayPainter),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) model.triggerRebuild();
          return snapshot.data;
        },
      );
  }

  static Widget _buildLivePreviewWidget(FilterModel model) {
    return CameraMlVision<List<Face>>(
      key: _cameraMLVisionKey,
      detector: faceDetector.processImage,
      cameraLensDirection: model.cameraLensDirection,
      resolution: ResolutionPreset.max,
      overlayBuilder: (context) {
        return CustomPaint(painter: FaceOverlayPainter(model, _cameraMLVisionKey.currentState.cameraValue.previewSize.flipped));
      },
      onResult: (resultFaces) {
        if (resultFaces == null || resultFaces.isEmpty) return;
        model.imageML.faces = resultFaces.toList();
        model.triggerRebuild();
      },
    );
  }
}
