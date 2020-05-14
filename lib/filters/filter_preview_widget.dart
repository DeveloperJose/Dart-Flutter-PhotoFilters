import 'dart:ui' as ui;

import 'package:feature_discovery/feature_discovery.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_camera_ml_vision/flutter_camera_ml_vision.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photofilters/ml/face_overlay_painter.dart';
import 'package:photofilters/ml/firebase_utils.dart';
import 'package:photofilters/ml/image_ml.dart';

import 'filter_model.dart';

/// A widget that overlays a filter on top of an image, mostly used for previews
/// Can detect whether the image is from a file or live camera given a model and display the corresponding widget
class FilterPreviewWidget extends StatefulWidget {
  final FilterModel filterModel;

  FilterPreviewWidget({Key key, @required this.filterModel}) : super(key: key);

  @override
  State<StatefulWidget> createState() => FilterPreviewWidgetState();
}

class FilterPreviewWidgetState extends State<FilterPreviewWidget> {
  /// This is the key to controlling the camera preview
  /// Any time you change this, the camera preview widget gets rebuilt
  /// Useful to change camera resolution or orientation
  GlobalKey<CameraMlVisionState> cameraMLVisionKey = GlobalKey();

  /// The direction of the camera lens. Specifies which camera to use for the preview.
  CameraLensDirection cameraLensDirection = CameraLensDirection.front;

  /// Flips the camera
  void flipCameraLens() {
    setState(() {
      if (cameraLensDirection == CameraLensDirection.front)
        cameraLensDirection = CameraLensDirection.back;
      else
        cameraLensDirection = CameraLensDirection.front;

      cameraMLVisionKey = GlobalKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filterModel?.imageML == null) return Center(child: Text('Error: Could not load preview widget.'));

    return Stack(children: [
      widget.filterModel.imageML.loadType == ImageMLType.LIVE_CAMERA_MEMORY ? _buildLivePreviewWidget() : _buildImagePreviewWidget(),
      RaisedButton(
          child: Text('Save'),
          onPressed: () async {
            // Code copied and modified from https://github.com/vemarav/signature/blob/master/lib/main.dart and https://github.com/rxlabz/flutter_canvas_to_image
            ui.PictureRecorder recorder = ui.PictureRecorder();
            Canvas canvas = Canvas(recorder);
            FaceOverlayPainter painter = FaceOverlayPainter(widget.filterModel);
            painter.paint(canvas, context.size);

            ui.Image im = await recorder.endRecording().toImage(context.size.width.floor(), context.size.height.floor());
            var byteData = await im.toByteData(format: ui.ImageByteFormat.png);
            var imageBytes = byteData.buffer.asUint8List();
            print('Bytes: $imageBytes');
            var permResult = await Permission.storage.request();
            if (permResult.isGranted) {
              await ImageGallerySaver.saveImage(imageBytes);
              Scaffold.of(context).showSnackBar(SnackBar(content: Text('Image saved to gallery!'), duration: Duration(seconds: 5), backgroundColor: Colors.green));
            } else {
              Scaffold.of(context).showSnackBar(SnackBar(content: Text('Could not save image due to denied permissions'), duration: Duration(seconds: 5), backgroundColor: Colors.red));
            }
          }),
    ]);
  }

  /// Builds the live camera preview widget
  Widget _buildLivePreviewWidget() {
    return Stack(children: [
      CameraMlVision<List<Face>>(
        key: cameraMLVisionKey,
        detector: faceDetector.processImage,
        cameraLensDirection: cameraLensDirection,
        overlayBuilder: (context) {
          return CustomPaint(painter: FaceOverlayPainter(widget.filterModel, cameraMLVisionKey.currentState.cameraValue.previewSize.flipped));
        },
        onResult: (resultFaces) {
          if (resultFaces == null || resultFaces.isEmpty) return;
          widget.filterModel.imageML.faces = resultFaces.toList();
          widget.filterModel.triggerRebuild();
        },
        onDispose: () {},
      ),
      Positioned(
          top: 0,
          right: 0,
          child: DescribedFeatureOverlay(
              featureId: 'flip_camera',
              tapTarget: Icon(Icons.sync),
              title: Text('Camera Flip'),
              description: Text('Flip between your front and back camera'),
              contentLocation: ContentLocation.below,
              child: RaisedButton.icon(
                icon: Icon(Icons.sync),
                label: Text('Flip Camera'),
                onPressed: flipCameraLens,
              )))
    ]);
  }

  /// Builds the image preview widget using a still image
  /// If the image has not already been loaded, loads it asynchronously so the user doesn't get impacted
  Widget _buildImagePreviewWidget() {
    if (widget.filterModel.imageML.isLoaded)
      return _buildOverlayWidget();
    else
      return _buildStreamBuilder();
  }

  /// Builds the custom painter widget which draws all our filter effects onto the canvas
  Widget _buildOverlayWidget() {
    return FittedBox(fit: BoxFit.contain, child: SizedBox(width: widget.filterModel.imageML.width, height: widget.filterModel.imageML.height, child: CustomPaint(painter: FaceOverlayPainter(widget.filterModel))));
  }

  /// Builds the StreamBuilder used to load images asynchronously
  StreamBuilder<ImageMLLoadState> _buildStreamBuilder() {
    return StreamBuilder<ImageMLLoadState>(
        stream: widget.filterModel.imageML.load(),
        initialData: ImageMLLoadState.START,
        builder: (context, snapshot) {
          return _widgetFromLoadState(snapshot.data);
        });
  }

  /// Builds a stack containing the current progress text and an optional background widget
  Stack _buildProgressStack(String progressText, [Widget backgroundWidget]) {
    if (backgroundWidget == null) backgroundWidget = Container();
    return Stack(alignment: AlignmentDirectional.center, children: [backgroundWidget, Text(progressText, style: TextStyle(backgroundColor: Colors.deepPurple, color: Colors.white)), Positioned(child: CircularProgressIndicator())]);
  }

  /// Creates the preview widget from the current StreamBuilder's stream state
  Widget _widgetFromLoadState(ImageMLLoadState state) {
    if (state == ImageMLLoadState.START)
      return _buildProgressStack('Starting...');
    else if (state == ImageMLLoadState.LOADING_ASSET)
      return _buildProgressStack('Loading asset from app...');
    else if (state == ImageMLLoadState.LOADING_IMAGE)
      return _buildProgressStack('Loading image...');
    else if (state == ImageMLLoadState.LOADING_IMAGE_INFO)
      return _buildProgressStack('Loading image dimensions and information...', widget.filterModel.imageML.flutterImage);
    else if (state == ImageMLLoadState.PERFORMING_ML)
      return _buildProgressStack('Performing machine learning recognition...', _buildOverlayWidget());
    else if (state == ImageMLLoadState.CLEANING_UP)
      return _buildProgressStack('Cleaning up...', _buildOverlayWidget());
    else {
      widget.filterModel.triggerRebuild();
      return _buildOverlayWidget();
    }
  }
}
