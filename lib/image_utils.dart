import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';

/// Application documents directory, initialized by main
Directory mDocsDir;

/// Clears all temporary files from the app if they exist
void clearTemporaryFiles() {
  var tempFile = getAppFile('temp');
  if (tempFile.existsSync()) tempFile.deleteSync(recursive: true);

  FaceLandmarkType.values.forEach((type) {
    var tempLandmarkFile = getAppFile(getLandmarkFilename('temp', type));
    if (tempLandmarkFile.existsSync()) tempLandmarkFile.deleteSync(recursive: true);
  });
}

/// Converts a filename into a (working) internal valid filename
String getInternalFilename(String filename) => join(mDocsDir.path, filename);

/// Gets a file from the app's document directory
File getAppFile(String filename) => File(getInternalFilename(filename));

/// Gets an image from the app's document directory
Image getAppFlutterImage(String filename) {
  File file = getAppFile(filename);
  if (!file.existsSync()) return null;
  return Image.memory(file.readAsBytesSync());
}

/// Converts an asset into a file and saves it into the app's document directory
/// This is used for a hacky fix to load an asset into Firebase ML since the docs of readBytes are terrible
Future<File> createAppFileFromAssetIfNotExists(String assetFilename) async {
  File file = getAppFile(assetFilename);
  if (!file.existsSync()) {
    ByteData data = await rootBundle.load(assetFilename);
    file.createSync(recursive: true);
    file.writeAsBytesSync(data.buffer.asUint8List());
  }
  return getAppFile(assetFilename);
}

/// Gets a dart:ui Image from the app's document directory
Future<ui.Image> getAppDartImage(String filename) async {
  File file = getAppFile(filename);
  if (!file.existsSync()) return null;
  return await decodeImageFromList(file.readAsBytesSync());
}

/// Gets a Firebase ML ready image from the app's document directory
FirebaseVisionImage getAppFirebaseImage(String filename) => FirebaseVisionImage.fromFile(getAppFile(filename));

/// Converts a FaceLandmarkType into a filename for IO operations
String getLandmarkFilename(String filterName, FaceLandmarkType type) => ((filterName ?? '') + '-' + type.toString());

/// Dialog that allows you to pick an image with your camera or from your gallery
Future selectImage(BuildContext context, String filename) {
  String internalFilename = getInternalFilename(filename);
  double width = MediaQuery.of(context).size.width;
  return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          contentPadding: EdgeInsets.all(10),
          content: SingleChildScrollView(
            child: ListBody(children: [
              GestureDetector(
                  child: ListTile(leading: Icon(Icons.camera_alt), title: Text("Take a picture", style: TextStyle(fontSize: 20))),
                  onTap: () async {
                    var cameraImage = await ImagePicker.pickImage(source: ImageSource.camera);
                    _saveImage(cameraImage, internalFilename);
                    Navigator.of(dialogContext).pop();
                  }),
              Divider(),
              GestureDetector(
                  child: ListTile(leading: Icon(Icons.photo), title: Text("Select from your gallery", style: TextStyle(fontSize: 20))),
                  onTap: () async {
                    var galleryImage = await ImagePicker.pickImage(source: ImageSource.gallery, maxWidth: width);
                    _saveImage(galleryImage, internalFilename);
                    Navigator.of(dialogContext).pop();
                  }),
            ]),
          ),
        );
      });
}

/// Saves a given file with the given filename
void _saveImage(File file, String filename) {
  if (file == null) return;

  file.copySync(filename);
  imageCache.clear();
}
