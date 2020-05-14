import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photofilters/filters/filter.dart';
import 'package:photofilters/filters/filter_model.dart';

/// A CustomPainter that overlays things on top of images based on Firebase ML face detectors
/// Modified from the example provided by the library
/// https://github.com/rushio-consulting/flutter_camera_ml_vision/blob/master/example/lib/main_face.dartclass
class FaceOverlayPainter extends CustomPainter {
  /// The filter we are overlaying on top of an image
  FilterModel model;

  /// The size of the image we are overlaying on top of
  Size imageSize;

  /// Constructs the overlay painter
  FaceOverlayPainter(this.model, [this.imageSize]);

  @override
  void paint(Canvas canvas, Size widgetSize) {
    // Need to draw image to the canvas if we are not doing live camera
    if (model.imageML.dartImage != null) {
      canvas.drawImage(model.imageML.dartImage, Offset.zero, Paint());
      imageSize = model.imageML.size;
    }

    model.imageML.faces?.forEach((Face face) {
      // Draw the bounding boxes for the faces for debugging
      var faceBoundingRect = _transformRect(face.boundingBox, widgetSize);
      var faceBoundingPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.amber;
      canvas.drawRect(faceBoundingRect, faceBoundingPaint);

      // TODO: Debugging contours
      var debugContour = face.getContour(FaceContourType.face);
      if (debugContour != null) {
        debugContour.positionsList.forEach((offset) {
          var rec = Rect.fromCenter(center: offset, width: 5, height: 5);
          canvas.drawRect(_transformRect(rec, widgetSize), Paint()..color = Colors.red);
        });
      }

      // Place the filters onto the landmarks (if possible)
      model.landmarks?.forEach((FaceLandmarkType landmarkType, LandmarkFilterInfo filter) {
        FaceLandmark faceLandmark = face.getLandmark(landmarkType);
        if (faceLandmark == null || filter.dartImage == null) return;

        // Scale filter size relative to face width (can also be image width)
        double filterScaleX = filter.width ?? 0 / faceBoundingRect.width;
        double filterScaleY = filter.height ?? 0 / faceBoundingRect.height;
        Rect resizedFilterRect = Rect.fromCenter(center: faceLandmark.position, width: filter.width * filterScaleX, height: filter.height * filterScaleY);

        // Scale relative to widget size
        Rect scaledFilterRect = _transformRect(resizedFilterRect, widgetSize);

        // Paint on canvas
        paintImage(canvas: canvas, rect: scaledFilterRect, image: filter.dartImage, fit: BoxFit.fill, filterQuality: FilterQuality.high);
      });
    });
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return true;
  }

  /// Reflects and scales rectangles to appropriate sizes given the image and widget size proportions
  Rect _transformRect(Rect rect, Size widgetSize) {
    // Reflect image if we are using a live camera and it's the back camera
    // bool reflection = model.imageML.loadType == ImageMLType.MEMORY ? (model.cameraLensDirection == CameraLensDirection.front) : false;
    bool reflection = false;
    var reflectRect = _reflectionRect(reflection, rect, widgetSize.width);
    var scaledRect = _scaleRect(reflectRect, widgetSize);
    return scaledRect;
  }

  /// Reflects a given rectangle if needed
  Rect _reflectionRect(bool reflection, Rect boundingBox, double width) {
    if (!reflection) return boundingBox;

    final centerX = width / 2;
    final left = ((boundingBox.left - centerX) * -1) + centerX;
    final right = ((boundingBox.right - centerX) * -1) + centerX;

    return Rect.fromLTRB(left, boundingBox.top, right, boundingBox.bottom);
  }

  /// Scales a given rectangle to an appropriate size given the image and widget size proportions
  Rect _scaleRect(Rect rect, Size widgetSize) {
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
}
