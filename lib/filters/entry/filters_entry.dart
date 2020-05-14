import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:photofilters/filters/entry/info_edit_page.dart';
import 'package:photofilters/filters/entry/landmark_edit_page.dart';
import 'package:photofilters/filters/filter_model.dart';
import 'package:photofilters/filters/filter_preview_widget.dart';
import 'package:photofilters/image_utils.dart';
import 'package:photofilters/ml/image_ml.dart';
import 'package:scoped_model/scoped_model.dart';

import '../filter_model.dart';
import '../filters_dbworker.dart';

class FilterEntry extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => FilterEntryState();
}

class FilterEntryState extends State<FilterEntry> {
  static const int TOTAL_WIZARD_STEPS = 2;

  List<GlobalKey<FormBuilderState>> _wizardFormKeys = List.generate(TOTAL_WIZARD_STEPS, (index) => GlobalKey());
  int _currentWizardStep = 0;

  bool get isFirstWizardStep => (_currentWizardStep == 0);

  bool get isLastWizardStep => (_currentWizardStep == TOTAL_WIZARD_STEPS - 1);

  GlobalKey<FormBuilderState> get currentKey => _wizardFormKeys[_currentWizardStep];

  @override
  Widget build(BuildContext context) => ScopedModelDescendant<FilterModel>(builder: (BuildContext context, Widget child, FilterModel model) {
        return Scaffold(
            resizeToAvoidBottomPadding: false,
            body: Column(children: [
              Expanded(child: Scrollbar(child: SingleChildScrollView(child: IndexedStack(index: _currentWizardStep, children: buildWizardChildren(context, model))))),
              buildNavigationControls(context, model),
              Container(constraints: BoxConstraints(maxHeight: 400), child: _buildPreview(context, model)),
            ]));
      });

  Widget _buildPreview(BuildContext context, FilterModel model) => Stack(alignment: AlignmentDirectional.bottomEnd, children: [
        FilterPreviewWidget(filterModel: model),
        Positioned(
            bottom: 0,
            left: 0,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text('Preview:', style: TextStyle(backgroundColor: Theme.of(context).accentColor, color: Colors.white)),
            )),
        Padding(
          padding: const EdgeInsets.all(10.0),
          child: RaisedButton.icon(
              label: Text('Change Image'),
              icon: Icon(Icons.image),
              onPressed: () async {
                await selectImage(context, 'temp');
                if (getAppFile('temp').existsSync()) {
                  model.imageML = ImageML(ImageMLType.FILE, 'temp');
                }
              }),
        )
      ]);

  List<Widget> buildWizardChildren(BuildContext context, FilterModel model) {
    return [LandmarkEditPage(_wizardFormKeys[0]), InfoEditPage(_wizardFormKeys[1])];
  }

  Widget buildNavigationControls(BuildContext context, FilterModel model) {
    return Container(
        color: Theme.of(context).accentColor.withAlpha(75),
        padding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
        child: Row(children: [
          FlatButton(child: Text('Cancel'), onPressed: () => cancelEntry(context, model)),
          Spacer(),
          FlatButton(child: Text('Previous'), onPressed: isFirstWizardStep ? null : onPreviousPressed),
          RaisedButton(
            child: Text(isLastWizardStep ? 'Save' : 'Next'),
            onPressed: () => onNextPressed(model),
          ),
        ]));
  }

  void onPreviousPressed() async {
    if (!currentKey.currentState.validate()) return;
    setState(() => _currentWizardStep--);
  }

  void onNextPressed(FilterModel model) async {
    if (!currentKey.currentState.validate()) return;
    if (isLastWizardStep)
      saveEntry(context, model);
    else
      setState(() => _currentWizardStep++);
  }

  void returnToFilterList(BuildContext context, FilterModel model) {
    clearTemporaryFiles();

    model.landmarks.clear();
    model.imageML = model.imageMLEdit;
    model.imageMLEdit = null;

    FocusScope.of(context).requestFocus(FocusNode());
    model.setStackIndex(0);
  }

  void cancelEntry(BuildContext context, FilterModel model) {
    // Clear state
    setState(() {
      _currentWizardStep = 0;
      _wizardFormKeys = List.generate(TOTAL_WIZARD_STEPS, (index) => GlobalKey());
    });
    returnToFilterList(context, model);
  }

  void saveEntry(BuildContext context, FilterModel model) async {
    // Save files and remove temps
    int count = 0;
    FaceLandmarkType.values.forEach((landmarkType) {
      var tempFile = getAppFile(getLandmarkFilename('temp', landmarkType));
      var newPath = getInternalFilename(getLandmarkFilename(model.entityBeingEdited.name, landmarkType));
      if (tempFile.existsSync()) {
        tempFile.renameSync(newPath);
        count++;
      }
    });

    print('Saved $count landmarks from the entity being edited under the name ${model.entityBeingEdited.name}');

    // Update entity
    model.entityBeingEdited.landmarks = model.landmarks;

    // Update DB
    if (model.entityBeingEdited.id == null) {
      await DBWorker.db.create(model.entityBeingEdited);
    } else {
      await DBWorker.db.update(model.entityBeingEdited);
    }
    model.loadData(DBWorker.db);

    Scaffold.of(context).showSnackBar(SnackBar(backgroundColor: Colors.green, duration: Duration(seconds: 2), content: Text('Filter saved!')));
    returnToFilterList(context, model);
  }
}
