import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';

Directory mDocsDir;

// General File IO
String getInternalFilename(String filename) => join(mDocsDir.path, filename);
File getAppFile(String filename) => File(getInternalFilename(filename));
Image getAppImage(String filename) {
  File file = getAppFile(filename);
  if (!file.existsSync()) return null;
  return Image.memory(file.readAsBytesSync());
}

// Landmark IO
String getLandmarkFilename(String filterName, FaceLandmarkType type) => ((filterName ?? '') + '-' + type.toString());


/// Wrapper for supporting both dart:ui Images and flutter Image widgets
class ImageWrapper {
  String internalFilename;
  File file;
  Uint8List fileBytes;

  Image flutterImage;
  ui.Image dartImage;

  ImageWrapper._(String filename) {
    internalFilename = getInternalFilename(filename);
    file = getAppFile(filename);

    if (file.existsSync()) {
      fileBytes = file.readAsBytesSync();
      flutterImage = Image.memory(fileBytes);

    }
  }

  static Future<ImageWrapper> fromFilename(String filename) async {
    var wrapper = ImageWrapper._(filename);
    if (wrapper.file.existsSync()) {
      wrapper.dartImage = await decodeImageFromList(wrapper.fileBytes);
    }
    return wrapper;
  }

  get isValid => file?.existsSync();

  get width => dartImage?.width?.toDouble();

  get height => dartImage?.height?.toDouble();
}

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
