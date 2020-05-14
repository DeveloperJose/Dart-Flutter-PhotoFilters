import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:photofilters/filters/filter_model.dart';
import 'package:photofilters/image_utils.dart';
import 'package:scoped_model/scoped_model.dart';

import '../filter.dart';
import '../filter_model.dart';

const double DEFAULT_WIDTH = 15;
const double DEFAULT_HEIGHT = 15;

/// Converts a FaceLandmarkType into a nice readable string
String landmarkToNiceString(FaceLandmarkType type) {
  if (type != null)
    return type.toString().substring('FaceLandmarkType.'.length);
  else
    return '?';
}

class LandmarkEditPage extends StatefulWidget {
  final GlobalKey<FormBuilderState> _formKey;

  LandmarkEditPage(this._formKey);

  @override
  State<StatefulWidget> createState() => LandmarkEditPageState();
}

class LandmarkEditPageState extends State<LandmarkEditPage> {
  GlobalKey _widthKey = GlobalKey();
  GlobalKey _heightKey = GlobalKey();
  FaceLandmarkType currentLandmarkBeingEdited;

  @override
  Widget build(BuildContext context) => ScopedModelDescendant<FilterModel>(builder: (BuildContext context, Widget child, FilterModel model) {
        return Scrollbar(
            child: SingleChildScrollView(
                child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: _buildForm(context, model),
        )));
      });

  Widget _buildForm(BuildContext context, FilterModel model) {
    var formChildren = [_buildLandmarkSelector(model)];
    if (currentLandmarkBeingEdited != null) {
      formChildren.add(_buildImageEditor(context, model));
      formChildren.add(_buildWidthEditor(model));
      formChildren.add(_buildHeightEditor(model));
    }

    return FormBuilder(key: widget._formKey, child: Column(children: formChildren));
  }

  Widget _buildLandmarkSelector(FilterModel model) {
    var landmarkOptions = FaceLandmarkType.values.map((landmarkType) {
      String landmarkText = landmarkToNiceString(landmarkType);

      bool modifiedBefore = model.landmarks[landmarkType] != null;
      if (modifiedBefore) landmarkText += '*';

      return FormBuilderFieldOption(value: landmarkType, child: Text(landmarkText));
    }).toList();

    return FormBuilderChoiceChip(
      attribute: 'landmark',
      decoration: InputDecoration(labelText: 'Select a facial landmark to edit'),
      options: landmarkOptions,
      validators: [
        (landmarkType) {
          if (model.landmarks.isEmpty) return 'Please edit at least one facial feature';
          return null;
        }
      ],
      onChanged: (landmarkType) => setState(() {
        // Update landmark
        currentLandmarkBeingEdited = landmarkType;
        // Re-fill form
        _widthKey = GlobalKey();
        _heightKey = GlobalKey();
      }),
      onSaved: (value) => setState(() => currentLandmarkBeingEdited = null),
    );
  }

  Widget _buildImageEditor(BuildContext context, FilterModel model) {
    // Check if we have a temporary landmark image saved
    String landmarkFilename = getLandmarkFilename('temp', currentLandmarkBeingEdited);
    Image landmarkImage = getAppFlutterImage(landmarkFilename);

    // If not, check if we had a previously saved landmark image from a previous filter
    if (landmarkImage == null) landmarkImage = getAppFlutterImage(getLandmarkFilename(model?.entityBeingEdited?.name, currentLandmarkBeingEdited));

    return InputDecorator(
        decoration: InputDecoration(labelText: 'Select an image for the ${landmarkToNiceString(currentLandmarkBeingEdited)} filter'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(),
            (landmarkImage != null) ? Container(width: 75, height: 75, child: landmarkImage) : Text('No image set yet', style: TextStyle(backgroundColor: Theme.of(context).primaryColor.withAlpha(50))),
            Container(
              child: GestureDetector(
                child: Container(width: 50, height: 50, color: Theme.of(context).primaryColor.withAlpha(50), child: Icon(Icons.camera_enhance)),
                onTap: () async {
                  await selectImage(context, landmarkFilename);
                  LandmarkFilterInfo filterInfo = await LandmarkFilterInfo.fromFilename(landmarkFilename);
                  filterInfo.width = DEFAULT_WIDTH;
                  filterInfo.height = DEFAULT_HEIGHT;
                  model.addLandmarkFilter(currentLandmarkBeingEdited, filterInfo);
                  widget._formKey.currentState.validate();
                },
              ),
            ),
          ],
        ));
  }

  Widget _buildWidthEditor(FilterModel model) {
    LandmarkFilterInfo filterInfo = model.landmarks[currentLandmarkBeingEdited];
    print('Model Landmarks: ${model.landmarks}');
    return FormBuilderTouchSpin(
      key: _widthKey,
      attribute: 'width',
      decoration: InputDecoration(labelText: 'Choose the width of the filter'),
      readOnly: (filterInfo == null),
      min: 1,
      max: 100,
      initialValue: (filterInfo == null) ? DEFAULT_WIDTH : filterInfo.width,
      step: 0.5,
      onChanged: (value) {
        filterInfo?.width = value;
      },
    );
  }

  Widget _buildHeightEditor(FilterModel model) {
    LandmarkFilterInfo filterInfo = model.landmarks[currentLandmarkBeingEdited];
    return FormBuilderTouchSpin(
      key: _heightKey,
      attribute: 'height',
      decoration: InputDecoration(labelText: 'Choose the height of the filter'),
      readOnly: (filterInfo == null),
      min: 1,
      max: 100,
      initialValue: (filterInfo == null) ? DEFAULT_HEIGHT : filterInfo.height,
      step: 0.5,
      onChanged: (value) {
        filterInfo?.height = value;
      },
    );
  }
}
