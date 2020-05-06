import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:image/image.dart' as im_lib;

import 'package:camera/camera.dart';

Directory mDocsDir;

// General File IO
String getInternalFilename(String filename) => join(mDocsDir.path, filename);
File getAppFile(String filename) => File(getInternalFilename(filename));
Image getAppFlutterImage(String filename) {
  File file = getAppFile(filename);
  if (!file.existsSync()) return null;
  return Image.memory(file.readAsBytesSync());
}

Future<ui.Image> getAppDartImage(String filename) async {
  File file = getAppFile(filename);
  if (!file.existsSync()) return null;
  return await decodeImageFromList(file.readAsBytesSync());
}

FirebaseVisionImage getAppFirebaseImage(String filename) => FirebaseVisionImage.fromFile(getAppFile(filename));

// Landmark IO
String getLandmarkFilename(String filterName, FaceLandmarkType type) => ((filterName ?? '') + '-' + type.toString());

/// Allows you to select if you want to take a picture with your camera or get it from your gallery
Future selectImage(BuildContext context, String filename) {
  String internalFilename = getInternalFilename(filename);
  double width = MediaQuery.of(context).size.width;
  return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
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

void _saveImage(File file, String filename) {
  if (file == null) return;

  file.copySync(filename);
  imageCache.clear();
}
