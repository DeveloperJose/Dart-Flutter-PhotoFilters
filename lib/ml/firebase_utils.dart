import 'package:firebase_ml_vision/firebase_ml_vision.dart';

/// The face detector used for detecting faces in the app
/// Here we can tweak the settings
FaceDetector faceDetector = FirebaseVision.instance.faceDetector(FaceDetectorOptions(
  enableClassification: false,
  enableLandmarks: true,
  enableTracking: false,
  mode: FaceDetectorMode.fast,
  enableContours: true,
));
