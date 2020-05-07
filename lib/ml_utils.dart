import 'dart:io';
import 'dart:ui' as ui;

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:flutter_camera_ml_vision/flutter_camera_ml_vision.dart';

import 'camera_utils.dart';
import 'filters/filter_model.dart';
import 'image_utils.dart';

FaceDetector detector = FirebaseVision.instance.faceDetector(FaceDetectorOptions(enableClassification: false, enableLandmarks: true, enableTracking: true, mode: FaceDetectorMode.accurate, enableContours: true));

enum ImageMLType { MEMORY, FILE, ASSET }
enum _ImageMLBuildState { START, LOADING_ASSET, LOADING_FLUTTER_IMAGE, LOADING_UI_IMAGE, LOADING_FIREBASE, FINISHED }

class ImageML {
  /// How this image needs to be loaded
  ImageMLType loadType;

  /// Regardless of how the image is loaded, this will be filled by the detector
  List<Face> faces;

  ImageML(this.loadType, [this.filename]);

  /// If loaded from FILE, this will be the filename that can be passed to image_utils functions
  /// If loaded from ASSET, this will be the asset path
  String filename;

  /// If loaded from MEMORY (live camera) these will be null
  ui.Image dartImage;
  Image flutterImage;

  bool get isLoaded => (faces != null);

  Widget buildOverlayWidget(FaceOverlayPainter overlayPainter) {
    return FittedBox(fit: BoxFit.contain, child: SizedBox(width: width, height: height, child: CustomPaint(painter: overlayPainter)));
  }

  Widget _buildProgressStack(Widget backgroundWidget, String progressText) {
    return Center(
      child: Stack(alignment: AlignmentDirectional.center, children: [
        backgroundWidget,
        Text(progressText),
        Positioned(child: CircularProgressIndicator())
      ]),
    );
  }

  Widget _buildFromState(_ImageMLBuildState buildState, FaceOverlayPainter overlayPainter) {
    if (buildState == _ImageMLBuildState.START)
      return _buildProgressStack(Container(), 'Loading preview...');
    else if (buildState == _ImageMLBuildState.LOADING_ASSET)
      return _buildProgressStack(Container(), 'Loading asset from app...');
    else if (buildState == _ImageMLBuildState.LOADING_FLUTTER_IMAGE)
      return _buildProgressStack(Container(), 'Loading image...');
    else if (buildState == _ImageMLBuildState.LOADING_UI_IMAGE)
      return _buildProgressStack(flutterImage, 'Loading image dimensions and information...');
    else if (buildState == _ImageMLBuildState.LOADING_FIREBASE)
      return _buildProgressStack(buildOverlayWidget(overlayPainter), 'Performing machine learning recognition...');
    else
      return buildOverlayWidget(overlayPainter);
  }

  Stream<_ImageMLBuildState> _loadFile(FaceOverlayPainter overlayPainter) async* {
    yield _ImageMLBuildState.LOADING_FLUTTER_IMAGE;
    this.flutterImage = getAppFlutterImage(filename);
    print('lmao');

    yield _ImageMLBuildState.LOADING_UI_IMAGE;
    this.dartImage = await getAppDartImage(filename);
    print('rolf');

    yield _ImageMLBuildState.LOADING_FIREBASE;
    var firebaseImage = getAppFirebaseImage(filename);
    this.faces = await detector.processImage(firebaseImage);

    yield _ImageMLBuildState.FINISHED;
  }

  Stream<_ImageMLBuildState> _loadAsset(FaceOverlayPainter overlayPainter) async* {
    // Save image temporarily into a file
    yield _ImageMLBuildState.LOADING_ASSET;
    File tempFile = await createAppFileFromAssetIfNotExists(filename);

    // Load from file
    yield* _loadFile(overlayPainter);
    // Remove temp file
//    tempFile.delete();
  }

  bool get usesDartUI => dartImage != null;

  double get width => dartImage.width.toDouble();

  double get height => dartImage.height.toDouble();

  Size get size => Size(width, height);

  static Widget getPreviewWidget(BuildContext context, FilterModel model) {
    if (model.imageML == null)
      return Text('[Image preview will go here]');
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
      if (model.imageML.isLoaded) return model.imageML.buildOverlayWidget(overlayPainter);

      return StreamBuilder<_ImageMLBuildState>(
        initialData: _ImageMLBuildState.START,
        stream: (model.imageML.loadType == ImageMLType.FILE) ? model.imageML._loadFile(overlayPainter) : model.imageML._loadAsset(overlayPainter),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            print('Snapshot state: ${snapshot.data}');
            var m = model.imageML._buildFromState(snapshot.data, overlayPainter);
            return m;
          }
          return Text('no datas');
        },
      );
    }
  }
}

//print('Model ImageML Size: ${model.imageML.size}');
//return Stack(fit: StackFit.passthrough,
//children: [
////        model.imageML.flutterImage,
//FittedBox(fit: BoxFit.fitWidth, child: SizedBox(width: model.imageML.width, height: model.imageML.height, child: CustomPaint(painter: FacePainter(model.imageML.size, model)))),
//]);
//}
//// Check if we are displaying a static image
//else if (model.imageML.usesDartUI) {
//return SizedBox(width: model.imageML.width, height: model.imageML.height, child: CustomPaint(painter: FacePainter(model.imageML.size, model)));
//}
class FaceOverlayPainter extends CustomPainter {
  FaceOverlayPainter(this.model, [this.imageSize]);

  bool get reflection => model.imageML.usesDartUI ? false : (cameraLensDirection == CameraLensDirection.front);
  Size imageSize;
  final FilterModel model;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20.0
      ..color = Colors.red;

    // Need to draw image to the canvas if file-based
    if (model.imageML.usesDartUI) {
      canvas.drawImage(model.imageML.dartImage, Offset.zero, Paint());
      imageSize = model.imageML.size;
    }

    model.imageML.faces?.forEach((Face face) {
      // Draw the bounding boxes for the faces for debugging
      final faceRect = _reflectionRect(reflection, face.boundingBox, imageSize.width, imageSize.height);
      canvas.drawRect(_scaleRect(rect: faceRect, imageSize: imageSize, widgetSize: size), paint);

//    canvas.drawRect(faceRect, paint);

      FaceLandmark faceLandmark = face.getLandmark(FaceLandmarkType.leftEar);
      if (faceLandmark != null) {
        Rect landmarkRect = _scaleRect(rect: Rect.fromCenter(center: faceLandmark.position, width: 10, height: 10), imageSize: imageSize, widgetSize: size);
        canvas.drawRect(landmarkRect, paint);
      }

      model.landmarks?.forEach((FaceLandmarkType landmarkType, FilterInfo filter) {
        FaceLandmark faceLandmark = face.getLandmark(landmarkType);
        if (faceLandmark == null) return;

        Rect landmarkRect = _scaleRect(rect: Rect.fromCenter(center: faceLandmark.position, width: filter.width, height: filter.height), imageSize: imageSize, widgetSize: size);

        ui.Image landmarkDartImage = filter.dartImage;
        if (landmarkDartImage == null) return;

        paintImage(
          canvas: canvas,
          rect: landmarkRect,
          image: landmarkDartImage,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.high,
        );
//
      });
      // Overlay the filter
    });

//    for (Face face in faces) {
//      final faceRect =
//      _reflectionRect(reflection, face.boundingBox, imageSize.width);
//      canvas.drawRect(
//        _scaleRect(
//          rect: faceRect,
//          imageSize: imageSize,
//          widgetSize: size,
//        ),
//        paint,
//      );
//    }
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return true;
//    return oldDelegate.imageSize != imageSize || oldDelegate.faces != faces;
  }
}

Rect _reflectionRect(bool reflection, Rect boundingBox, double width, double height) {
  if (!reflection) return boundingBox;

  final centerX = width / 2;
  final centerY = height / 2;
  final left = ((boundingBox.left - centerX) * -1) + centerX;
  final right = ((boundingBox.right - centerX) * -1) + centerX;

//  final top = ((boundingBox.top - centerY) * -1) + centerY;
//  final bottom = ((boundingBox.bottom - centerY) * -1) + centerY;

  final top = boundingBox.top;
  final bottom = boundingBox.bottom;

  return Rect.fromLTRB(left, top, right, bottom);
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

//class FacePainter extends CustomPainter {
//  FilterModel model;
//
//  FacePainter({@required this.model});
//
//  @override
//  void paint(Canvas canvas, Size size) async {
////    print('paint()');
////    ImageML imageML = model.imageML;
////    if (imageML.imageWrapper.libImage != null) {
////      for (int i = 0; i < imageML.imageWrapper.libImage.width; i++)
////        for (int j = 0; j < imageML.imageWrapper.libImage.height; j++) {
////          int pixel = imageML.imageWrapper.libImage.getPixel(i, j);
////          print('Pixel: $pixel');
//////          canvas.drawRect(Rect.fromCenter(center: Offset(i.toDouble(), j.toDouble()), width: 1, height: 1), Paint()..color = Color.);
////        }
////    } else
//    if (model.imageML.imageWrapper.dartImage != null) canvas.drawImage(model.imageML.imageWrapper.dartImage, Offset.zero, Paint());
//
//    model.imageML.faces.forEach((Face face) {
//      canvas.drawRect(
//          face.boundingBox,
//          Paint()
//            ..color = Colors.teal
//            ..strokeWidth = 6
//            ..style = PaintingStyle.stroke);
//
//      var faceCont = face.getContour(FaceContourType.face);
//      if (faceCont != null) {
//        canvas.drawPoints(
//            ui.PointMode.points,
//            faceCont.positionsList,
//            Paint()
//              ..strokeWidth = 3
//              ..color = Colors.white);
//        print('Face Contours: ${faceCont.positionsList.length}');
//      }
//
//      model.landmarks.forEach((landmarkType, filterInfo) {
//        var landmark = face.getLandmark(landmarkType);
//        var landmarkImage = filterInfo.imageWrapper.dartImage;
//        if (landmark != null && landmarkImage != null) {
//          paintImage(
//            canvas: canvas,
//            rect: Rect.fromCenter(
//              center: landmark.position,
//              width: filterInfo.width ?? 0,
//              height: filterInfo.height ?? 0,
//            ),
//            image: filterInfo.imageWrapper.dartImage,
//            fit: BoxFit.fill,
//            filterQuality: FilterQuality.high,
//          );
//        }
//      });
//    });
//  }
//
//  @override
//  bool shouldRepaint(CustomPainter oldDelegate) {
//    return true;
//  }
//}
/// Modified from https://github.com/wal33d006/jumping_dots/blob/master/lib/jumping_dots.dart
class _JumpingLetter extends AnimatedWidget {
  final String letter;
  final TextStyle style;

  _JumpingLetter({Key key, Animation<double> animation, this.letter, this.style}) : super(key: key, listenable: animation);

  Widget build(BuildContext context) {
    final Animation<double> animation = listenable;
    return Container(
      height: animation.value,
      child: Text(letter, style: style),
    );
  }
}

class JumpingText extends StatefulWidget {
  final TextStyle letterStyle;
  final double letterSpacing;

  /// Animation
  final int milliseconds;
  final double beginTweenValue = 10.0;
  final double endTweenValue = 20.0;

  JumpingText({
    Key key,
    this.letterStyle,
    this.letterSpacing = 0.0,
    this.milliseconds = 250,
  }) : super(key: key);

  _JumpingTextState createState() => _JumpingTextState();
}

class _JumpingTextState extends State<JumpingText> with TickerProviderStateMixin {
  String _text = "";

  String get text => _text;

  set text(String value) {
    setState(() {
      _text = value;
    });
  }

  List<AnimationController> controllers = new List<AnimationController>();
  List<Animation<double>> animations = new List<Animation<double>>();
  List<Widget> _widgets = new List<Widget>();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < text.length; i++) {
      _addAnimationControllers();
      _buildAnimations(i);
      _addListOfDots(i);
    }

    controllers[0].forward();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _widgets,
      ),
    );
  }

  @override
  void dispose() {
    for (int i = 0; i < text.length; i++) controllers[i].dispose();
    super.dispose();
  }

  void stop() {
    for (int i = 0; i < text.length; i++) controllers[i].stop();
  }

  void _addAnimationControllers() {
    controllers.add(AnimationController(duration: Duration(milliseconds: widget.milliseconds), vsync: this));
  }

  void _addListOfDots(int index) {
    _widgets.add(Padding(
      padding: EdgeInsets.only(right: widget.letterSpacing),
      child: _JumpingLetter(animation: animations[index], letter: text[index], style: widget.letterStyle),
    ));
  }

  void _buildAnimations(int index) {
    animations.add(Tween(begin: widget.beginTweenValue, end: widget.endTweenValue).animate(controllers[index])
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) controllers[index].reverse();
        if (index == text.length - 1 && status == AnimationStatus.dismissed) {
          controllers[0].forward();
        }
        if (animations[index].value > widget.endTweenValue / 2 && index < text.length - 1) {
          controllers[index + 1].forward();
        }
      }));
  }
}
