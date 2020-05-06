import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_camera_ml_vision/flutter_camera_ml_vision.dart';

final GlobalKey<CameraMlVisionState> cameraMLVisionKey = GlobalKey();
CameraLensDirection cameraLensDirection = CameraLensDirection.front;