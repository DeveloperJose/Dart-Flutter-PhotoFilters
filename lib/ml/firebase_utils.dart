import 'package:firebase_ml_vision/firebase_ml_vision.dart';

FaceDetector faceDetector = FirebaseVision.instance.faceDetector(FaceDetectorOptions(
  enableClassification: false,
  enableLandmarks: true,
  enableTracking: false,
  mode: FaceDetectorMode.fast,
  enableContours: true,
));
