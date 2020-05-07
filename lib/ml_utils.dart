import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_camera_ml_vision/flutter_camera_ml_vision.dart';

import 'camera_utils.dart';
import 'filters/filter_model.dart';
import 'image_utils.dart';

FaceDetector detector = FirebaseVision.instance.faceDetector(FaceDetectorOptions(enableClassification: false, enableLandmarks: true, enableTracking: true, mode: FaceDetectorMode.accurate, enableContours: true));

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
    print('build overlay: $width, $height');
    return FittedBox(fit: BoxFit.contain, child: SizedBox(width: width, height: height, child: CustomPaint(painter: overlayPainter)));
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
    this.faces = await detector.processImage(firebaseImage);

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

  static Widget getPreviewWidget(BuildContext context, FilterModel model) {
    if (model.imageML == null)
      return Text('Error: Cannot load preview widget');
    else if (model.imageML.loadType == ImageMLType.MEMORY) {
      return CameraMlVision<List<Face>>(
        key: cameraMLVisionKey,
        cameraLensDirection: cameraLensDirection,
        detector: detector.processImage,
        overlayBuilder: (context) {
          return CustomPaint(painter: FaceOverlayPainter(model, cameraMLVisionKey.currentState.cameraValue.previewSize.flipped));
        },
        onResult: (resultFaces) {
          model.imageML.faces = resultFaces.toList();
          model.triggerRebuild();
        },
      );
    } else {
      var overlayPainter = FaceOverlayPainter(model);
      print('Loaded: ${model.imageML.isLoaded}');
      // Show if loaded. If not loaded, load asynchronously so the user doesn't get impacted
      if (model.imageML.isLoaded)
        return model.imageML.buildOverlayWidget(overlayPainter);
      else
        return StreamBuilder<Widget>(
          initialData: Container(),
          stream: (model.imageML.loadType == ImageMLType.FILE) ? model.imageML._loadFile(overlayPainter) : model.imageML._loadAsset(overlayPainter),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done)
              model.triggerRebuild();

            return snapshot.data;
          },
        );
    }
  }
}

/// Modified from the example provided by the library
/// https://github.com/rushio-consulting/flutter_camera_ml_vision/blob/master/example/lib/main_face.dart
class FaceOverlayPainter extends CustomPainter {
  FaceOverlayPainter(this.model, [this.imageSize]);

  bool get reflection => model.imageML.loadType == ImageMLType.MEMORY ? (cameraLensDirection == CameraLensDirection.front) : false;
  Size imageSize;
  final FilterModel model;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20.0
      ..color = Colors.red;

    // Need to draw image to the canvas if we are not doing live camera
    if (model.imageML.dartImage != null) {
      canvas.drawImage(model.imageML.dartImage, Offset.zero, Paint());
      imageSize = model.imageML.size;
    }

    model.imageML.faces?.forEach((Face face) {
      // Draw the bounding boxes for the faces for debugging
      final faceRect = _reflectionRect(reflection, face.boundingBox, imageSize.width);
      canvas.drawRect(_scaleRect(rect: faceRect, imageSize: imageSize, widgetSize: size), paint);

      // TODO: Debugging landmarks
      FaceLandmark faceLandmark = face.getLandmark(FaceLandmarkType.leftEar);
      if (faceLandmark != null) {
        Rect landmarkRect = _scaleRect(rect: Rect.fromCenter(center: faceLandmark.position, width: 200, height: 200), imageSize: imageSize, widgetSize: size);
        canvas.drawRect(landmarkRect, paint);
      }

      // Place the filters onto the landmarks (if possible)
      model.landmarks?.forEach((FaceLandmarkType landmarkType, FilterInfo filter) {
        FaceLandmark faceLandmark = face.getLandmark(landmarkType);
        if (faceLandmark == null) return;

        if (filter.dartImage == null) return;
        final scaleX = size.width / imageSize.width;
        final scaleY = size.height / imageSize.height;
        Rect landmarkRect = _scaleRect(rect: Rect.fromCenter(center: faceLandmark.position, width: filter.width*scaleX ?? 0, height: filter.height*scaleY ?? 0), imageSize: imageSize, widgetSize: size);
        paintImage(canvas: canvas, rect: landmarkRect, image: filter.dartImage, fit: BoxFit.fill, filterQuality: FilterQuality.high);
      });
    });
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return true;
  }
}

Rect _reflectionRect(bool reflection, Rect boundingBox, double width) {
  if (!reflection) return boundingBox;

  final centerX = width / 2;
  final left = ((boundingBox.left - centerX) * -1) + centerX;
  final right = ((boundingBox.right - centerX) * -1) + centerX;

  return Rect.fromLTRB(left, boundingBox.top, right, boundingBox.bottom);
}

Rect _scaleRect({@required Rect rect, @required Size imageSize, @required Size widgetSize}) {
  final scaleX = widgetSize.width / imageSize.width;
  final scaleY = widgetSize.height / imageSize.height;

  final scaledRect = Rect.fromLTRB(
    rect.left.toDouble() * scaleX,
    rect.top.toDouble() * scaleY,
    rect.right.toDouble() * scaleX,
    rect.bottom.toDouble() * scaleY,
  );
  return scaledRect;
}
