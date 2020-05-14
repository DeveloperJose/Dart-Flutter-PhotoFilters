import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:page_slider/page_slider.dart';
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
  /// Key used to keep track of the current wizard page and to navigate back and forth
  GlobalKey<PageSliderState> _sliderKey = GlobalKey();

  /// How many steps are there in the entry wizard? (total)
  static const int TOTAL_WIZARD_STEPS = 2;

  /// All keys used by the wizard for validation, one per step
  List<GlobalKey<FormBuilderState>> _wizardFormKeys = List.generate(TOTAL_WIZARD_STEPS, (index) => GlobalKey());

  /// The key used for validation for the current wizard step
  GlobalKey<FormBuilderState> get currentKey => _wizardFormKeys[_sliderKey.currentState.currentPage];

  /// Can we move backward in this wizard?
  /// If not, we are at the beginning of the wizard
  bool get hasPrevious => _sliderKey?.currentState?.hasPrevious ?? false;

  /// Can we move forward in this wizard?
  /// If not, we have reached the end of the wizard
  bool get hasNext => _sliderKey?.currentState?.hasNext ?? false;

  @override
  Widget build(BuildContext context) => ScopedModelDescendant<FilterModel>(builder: (BuildContext context, Widget child, FilterModel model) {
        return Scaffold(
            resizeToAvoidBottomPadding: false,
            body: Column(children: [
              Expanded(child: buildWizard(context, model)),
              buildNavigationControls(context, model),
              Container(constraints: BoxConstraints(maxHeight: 400), child: _buildPreview(context, model)),
            ]));
      });

  /// Builds the preview widget
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

  /// Builds the entry wizard
  Widget buildWizard(BuildContext context, FilterModel model) {
    return PageSlider(key: _sliderKey, pages: [LandmarkEditPage(_wizardFormKeys[0]), InfoEditPage(_wizardFormKeys[1])]);
  }

  /// Builds the navigation control widget
  Widget buildNavigationControls(BuildContext context, FilterModel model) {
    return Container(
        color: Theme.of(context).accentColor.withAlpha(75),
        padding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
        child: Row(children: [
          FlatButton(child: Text('Cancel'), onPressed: () => onCancelPressed(model)),
          Spacer(),
          FlatButton(child: Text('Previous'), onPressed: (hasPrevious) ? onPreviousPressed : null),
          RaisedButton(
            child: Text(hasNext ? 'Next' : 'Finish & Save'),
            onPressed: () => onNextPressed(model),
          ),
        ]));
  }

  /// Actions to take when the Cancel button is pressed
  void onCancelPressed(FilterModel model) {
    currentKey.currentState.save();
    cancelEntry(context, model);
  }

  /// Actions to take when the Previous button is pressed
  void onPreviousPressed() async {
    if (!currentKey.currentState.validate()) return;
    setState(() => _sliderKey.currentState.previous());
  }

  /// Actions to take when the Next/Finish & Save button is pressed
  void onNextPressed(FilterModel model) async {
    if (!currentKey.currentState.validate()) return;

    if (hasNext) {
      setState(() => _sliderKey.currentState.next());
    } else {
      currentKey.currentState.save();
      saveEntry(context, model);
    }
  }

  /// Clears this entry and returns to the list of filters
  void returnToFilterList(BuildContext context, FilterModel model) {
    clearTemporaryFiles();

    model.landmarks.clear();
    model.imageML = model.imageMLEdit;
    model.imageMLEdit = null;

    // Clear state
    setState(() {
      _sliderKey = GlobalKey();
      _wizardFormKeys = List.generate(TOTAL_WIZARD_STEPS, (index) => GlobalKey());
    });

    FocusScope.of(context).requestFocus(FocusNode());
    model.setStackIndex(0);
  }

  /// Cancels this entry, closes and returns to list of filters
  void cancelEntry(BuildContext context, FilterModel model) {
    returnToFilterList(context, model);
  }

  /// Saves this entry, closes and returns to list of filters
  /// Stores or updates entry into DB
  /// Makes landmark files permanent
  void saveEntry(BuildContext context, FilterModel model) async {
    // Rename all temporary files using permanent filenames
    FaceLandmarkType.values.forEach((landmarkType) {
      var tempFile = getAppFile(getLandmarkFilename('temp', landmarkType));
      var newPath = getInternalFilename(getLandmarkFilename(model.entityBeingEdited.name, landmarkType));
      if (tempFile.existsSync()) tempFile.renameSync(newPath);
    });

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
