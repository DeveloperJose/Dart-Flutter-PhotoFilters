import 'package:card_settings/card_settings.dart';
import 'package:fa_stepper/fa_stepper.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photofilters/filters/filter_model.dart';
import 'package:photofilters/image_utils.dart';
import 'package:scoped_model/scoped_model.dart';

import 'filter_model.dart';

class FilterEntry extends StatelessWidget {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return ScopedModel<FilterModel>(
        model: filtersModel,
        child: ScopedModelDescendant<FilterModel>(builder: (BuildContext context, Widget child, FilterModel model) {
          return Scaffold(body: Form(key: _formKey, child: Column(children: [_buildPreview(model), Expanded(child: _buildLandmarkStepper(context, model))])));
        }));
  }

  Widget _buildPreview(FilterModel model) => (model.imageML != null && model.currentStep >= 1)
      ? Stack(alignment: AlignmentDirectional.bottomEnd, children: [model.imageML.getWidget(model), _buildRefreshPreviewFAB(model)])
      : Container();

  FloatingActionButton _buildRefreshPreviewFAB(FilterModel model) => FloatingActionButton(child: Icon(Icons.refresh), onPressed: () => model.triggerRebuild());

  FAStep _buildFilterDetailsStep(FilterModel model) {
    return FAStep(title: Text('Basic Filter Information'), content: _buildFilterDetailsContent(model));
  }

  Widget _buildFilterDetailsContent(FilterModel model) {
    return CardSettings(
      shrinkWrap: true,
      children: [
        CardSettingsText(
            hintText: 'Enter a name for your filter here',
            label: 'Name',
            initialValue: model?.entityBeingEdited?.name ?? '',
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please type a filter name';
              return null;
            },
            onChanged: (value) => model.entityBeingEdited.name = value),
      ],
    );
  }

  Widget _buildLandmarkStep(BuildContext context, FilterModel model, FaceLandmarkType type) {
    // Check if we have a temporary landmark image saved
    Image landmarkImage = getAppImage(getLandmarkFilename('temp', type));

    // If not, check if we had a previously saved landmark image from a previous filter
    if (landmarkImage == null) landmarkImage = getAppImage(getLandmarkFilename(model?.entityBeingEdited?.name, type));

    print('Landmark Image: $landmarkImage, filename: ${getLandmarkFilename('temp', type)}');
    return CardSettings(shrinkWrap: true, children: [
      CardSettingsHeader(label: type.toString()),
      CardSettingsField(
        label: 'Image',
        content: ListTile(
          leading: (landmarkImage != null) ? landmarkImage : Text('No image set yet.'),
          title: Text(''),
          trailing: IconButton(
              icon: Icon(Icons.photo_library),
              onPressed: () async {
                await selectImage(context, getLandmarkFilename('temp', type));
                model.addLandmarkFilter(type, await ImageWrapper.fromFilename(getLandmarkFilename('temp', type)));
              }),
        ),
      ),
      Row(children: [
        Flexible(
          child: CardSettingsDouble(
            label: 'Width',
            hintText: '##',
            decimalDigits: 1,
            maxLength: 2,
            initialValue: model.landmarks[type]?.width,
            onChanged: (value) => model.landmarks[type]?.width = value,
          ),
        ),
        Flexible(
          child: CardSettingsDouble(
            label: 'Height',
            hintText: '##',
            decimalDigits: 1,
            maxLength: 2,
            initialValue: model.landmarks[type]?.height,
            onChanged: (value) => model.landmarks[type]?.height = value,
          ),
        )
      ])
    ]);
  }

  Widget _buildLandmarkStepper(BuildContext context, FilterModel model) {
    List<FAStep> steps = [_buildFilterDetailsStep(model)];
    FaceLandmarkType.values.forEach((landmarkType) {
      var title = landmarkType.toString().substring('FaceLandmarkType.'.length);
      var currentStep = FAStep(title: Text(title), content: _buildLandmarkStep(context, model, landmarkType));
      steps.add(currentStep);
    });
    return FAStepper(
      currentStep: model.currentStep,
      type: FAStepperType.horizontal,
      titleIconArrange: FAStepperTitleIconArrange.column,
      steps: steps,
      onStepContinue: () {
        if (!_formKey.currentState.validate()) return;
        if (model.currentStep == steps.length - 1)
          saveEntry(context, model);
        else if (model.currentStep <= steps.length) model.currentStep++;
      },
      onStepCancel: () {
        if (model.currentStep > 0) model.currentStep--;
      },
      controlsBuilder: (buildContext, {onStepContinue, onStepCancel}) => Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        FlatButton(child: Text('Cancel'), onPressed: () => cancelEntry(context, model)),
        FlatButton(child:  Text('Previous'), onPressed: (model.currentStep > 0) ? onStepCancel : null),
        RaisedButton(child: (model.currentStep == steps.length - 1) ? Text('Finish and Save') : Text('Next'), onPressed: onStepContinue)
      ]),
    );
  }

  void cancelEntry(BuildContext context, FilterModel model) {
    clearTemporaryFiles();

    FocusScope.of(context).requestFocus(FocusNode());
    model.setStackIndex(0);
  }

  void saveEntry(BuildContext context, FilterModel model) {
    int count = 0;
    FaceLandmarkType.values.forEach((landmarkType) {
      var tempFile = getAppFile(getLandmarkFilename('temp', landmarkType));
      var newPath = getInternalFilename(getLandmarkFilename(model.entityBeingEdited.name, landmarkType));
      if (tempFile.existsSync()) {
        tempFile.renameSync(newPath);
        count++;
      }
    });

    clearTemporaryFiles();
    print('Saved $count landmarks from the entity being edited under the name ${model.entityBeingEdited.name}');
    model.entityBeingEdited.landmarks = model.landmarks;
    model.entityList.add(model.entityBeingEdited);
    model.triggerRebuild();
    model.setStackIndex(0);
    Scaffold.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green, duration: Duration(seconds: 2), content: Text('Filter saved!')));
  }

  void clearTemporaryFiles() {
    FaceLandmarkType.values.forEach((landmarkType) {
      var tempFile = getAppFile(getLandmarkFilename('temp', landmarkType));
      if (tempFile.existsSync()) tempFile.deleteSync();
    });
  }
}
