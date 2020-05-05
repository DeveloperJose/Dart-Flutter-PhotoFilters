import 'dart:ui';

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';

import 'filters/filter_model.dart';
import 'image_utils.dart';

FaceDetector getFaceDetector() => FirebaseVision.instance.faceDetector(FaceDetectorOptions(enableClassification: false, enableLandmarks: true, enableTracking: true, mode: FaceDetectorMode.fast, enableContours: true));

class ImageML {
  ImageWrapper imageWrapper;
  FirebaseVisionImage firebaseImage;
  List<Face> faces;

  static Future<ImageML> fromFilename(String filename) async {
    ImageML result = ImageML()..imageWrapper = await ImageWrapper.fromFilename(filename);
    result.firebaseImage = FirebaseVisionImage.fromFile(result.imageWrapper.file);
    result.faces = await getFaceDetector().processImage(result.firebaseImage);
    return result;
  }

  Widget getWidget(FilterModel model) => SizedBox(width: model.imageML.imageWrapper.width, height: model.imageML.imageWrapper.height, child: CustomPaint(painter: FacePainter(model: model)));
}

class FacePainter extends CustomPainter {
  FilterModel model;

  FacePainter({@required this.model});

  @override
  void paint(Canvas canvas, Size size) async {
    canvas.drawImage(model.imageML.imageWrapper.dartImage, Offset.zero, Paint());

    model.imageML.faces.forEach((Face face) {
      canvas.drawRect(
          face.boundingBox,
          Paint()
            ..color = Colors.teal
            ..strokeWidth = 6
            ..style = PaintingStyle.stroke);

      var faceCont = face.getContour(FaceContourType.face);
      if (faceCont != null){
        canvas.drawPoints(PointMode.points, faceCont.positionsList, Paint()..strokeWidth = 3..color = Colors.white);
        print('Face Contours: ${faceCont.positionsList.length}');
      }

      model.landmarks.forEach((landmarkType, filterInfo) {
        var landmark = face.getLandmark(landmarkType);
        if (landmark != null) {
          paintImage(
            canvas: canvas,
            rect: Rect.fromCenter(
              center: landmark.position,
              width: filterInfo.width ?? 0,
              height: filterInfo.height ?? 0,
            ),
            image: filterInfo.imageWrapper.dartImage,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          );
        }
      });
    });
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
