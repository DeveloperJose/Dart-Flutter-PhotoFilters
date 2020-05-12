import 'package:feature_discovery/feature_discovery.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_camera_ml_vision/flutter_camera_ml_vision.dart';
import 'package:photofilters/ml/face_overlay_painter.dart';
import 'package:photofilters/ml/firebase_utils.dart';
import 'package:photofilters/ml/image_ml.dart';

import 'filter_model.dart';

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
  CameraLensDirection _cameraLensDirection = CameraLensDirection.front;

  /// Flips the camera
  void flipCameraLens() {
    setState(() {
      if (_cameraLensDirection == CameraLensDirection.front)
        _cameraLensDirection = CameraLensDirection.back;
      else
        _cameraLensDirection = CameraLensDirection.front;

      cameraMLVisionKey = GlobalKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filterModel?.imageML == null)
      return Center(child: Text('Error: Could not load preview widget.'));
    else if (widget.filterModel.imageML.loadType == ImageMLType.LIVE_CAMERA_MEMORY)
      return buildLivePreviewWidget();
    else
      return buildImagePreviewWidget();
  }

  /// Builds the live camera preview widget
  Widget buildLivePreviewWidget() {
    return Stack(children: [
      CameraMlVision<List<Face>>(
        key: cameraMLVisionKey,
        detector: faceDetector.processImage,
        cameraLensDirection: _cameraLensDirection,
        resolution: ResolutionPreset.max,
        overlayBuilder: (context) {
          print('overlaybuilder called');
          return CustomPaint(painter: FaceOverlayPainter(widget.filterModel, cameraMLVisionKey.currentState.cameraValue.previewSize.flipped));
        },
        onResult: (resultFaces) {
          if (resultFaces == null || resultFaces.isEmpty) return;
          widget.filterModel.imageML.faces = resultFaces.toList();
          widget.filterModel.triggerRebuild();
        },
        onDispose: () {},
      ),
      ListTile(
          trailing: DescribedFeatureOverlay(
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
  Widget buildImagePreviewWidget() {
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
    return Stack(alignment: AlignmentDirectional.center, children: [backgroundWidget, Text(progressText), Positioned(child: CircularProgressIndicator())]);
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
