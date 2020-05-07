import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'camera_utils.dart';
import 'filters/filter_model.dart';
import 'filters/filters.dart';
import 'image_utils.dart';
import 'ml_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize utilities
  mDocsDir = await getApplicationDocumentsDirectory();
  cameras = await availableCameras();

  for(CameraDescription cameraDescription in cameras){
    CameraController controller = CameraController(cameraDescription, ResolutionPreset.high, enableAudio: false);
    await controller.initialize();
    cameraControllers.add(controller);
  }

  filtersModel.imageML = ImageML(ImageMLType.ASSET, 'assets/preview.jpg');

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: true,
        home: Scaffold(
          appBar: AppBar(title: Text('PhotoFilters by Jose G. Perez')),
          body: Filters(),
        ));
  }

  @override
  void dispose() {
    super.dispose();
    detector.close();

    cameraControllers.forEach((controller) => controller.dispose());
  }
}
