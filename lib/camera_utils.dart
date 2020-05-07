import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_camera_ml_vision/flutter_camera_ml_vision.dart';

final GlobalKey<CameraMlVisionState> cameraMLVisionKey = GlobalKey();
List<CameraDescription> cameras = [];
List<CameraController> cameraControllers = [];
CameraLensDirection cameraLensDirection = CameraLensDirection.front;

CameraController getCurrentCamera() {
  return cameraControllers.firstWhere((controller) => controller.description.lensDirection == cameraLensDirection);
}