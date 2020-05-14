import 'dart:math' as math;

import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_circular_text/circular_text.dart';
import 'package:flutter_page_indicator/flutter_page_indicator.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_swiper/flutter_swiper.dart';
import 'package:photofilters/image_utils.dart';
import 'package:photofilters/ml/image_ml.dart';
import 'package:scoped_model/scoped_model.dart';

import 'filter.dart';
import 'filter_model.dart';
import 'filter_preview_widget.dart';
import 'filters_dbworker.dart';

class FilterList extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => FilterListState();
}

class FilterListState extends State<FilterList> {
  static const double ICON_PADDING = 50.0;
  int currentPreviewedFilterIndex = 0;

  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
      FeatureDiscovery.discoverFeatures(context, {'filter_list', 'flip_camera'});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<FilterModel>(builder: buildScaffold);
  }

  Scaffold buildScaffold(BuildContext context, Widget child, FilterModel model) {
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      floatingActionButton: buildFloatingActionButton(context, model),
      body: Stack(children: [FilterPreviewWidget(filterModel: model), Positioned(bottom: 10, right: 0, child: _buildList(context, model))]),
    );
  }

  Widget _buildList(BuildContext context, FilterModel model) => LimitedBox(
      maxHeight: 150,
      maxWidth: MediaQuery.of(context).size.width,
      child: model.entityList.length == 0
          ? Container(alignment: Alignment.bottomCenter, child: Container(width: double.maxFinite, color: Colors.grey.shade200, child: Text('No filters created yet!', textAlign: TextAlign.center)))
          : !model.imageML.isLoaded
              ? Container(alignment: Alignment.bottomCenter, child: Container(width: double.maxFinite, color: Colors.grey.shade200, child: Text('Filters unavailable until preview is loaded', textAlign: TextAlign.center)))
              : DescribedFeatureOverlay(
                  featureId: 'filter_list',
                  tapTarget: _buildListItem(model, Filter(-1, 'Filter Name', Icons.hourglass_empty)),
                  title: Text('Filter List'),
                  description: Text('Swipe left and right to move between your filters'),
                  child: Swiper(
                    loop: false,
                    viewportFraction: 0.25,
                    scale: 0.1,
                    indicatorLayout: PageIndicatorLayout.SLIDE,
                    pagination: new SwiperPagination(margin: EdgeInsets.zero, builder: SwiperPagination.dots),
                    index: currentPreviewedFilterIndex,
                    onIndexChanged: (index) {
                      setState(() => currentPreviewedFilterIndex = index);
                      model.landmarks = model.entityList[index].landmarks;
                      model.triggerRebuild();
                    },
                    itemCount: model.entityList.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _buildListItem(model, model.entityList[index]);
                    },
                  )));

  Widget _buildListItem(FilterModel model, Filter item) => LayoutBuilder(builder: (context, constraint) {
        double height = math.max(constraint.biggest.height - ICON_PADDING, 1);
        return Stack(alignment: AlignmentDirectional.center, children: [
          ClipOval(child: Container(color: Colors.tealAccent, child: Icon(item.icon ?? Icons.device_unknown, size: height))),
          _buildListItemText(model, item),
        ]);
      });

  Widget _buildListItemText(FilterModel model, Filter item) => CircularText(
          backgroundPaint: Paint()
            ..strokeWidth = 20
            ..color = Colors.teal
            ..style = PaintingStyle.stroke,
          children: [
            TextItem(
              startAngle: -90,
              startAngleAlignment: StartAngleAlignment.center,
              space: 14,
              text: Text(item?.name?.toUpperCase() ?? 'ERR: INVALID ITEM NAME', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            )
          ]);

  Widget buildFloatingActionButton(BuildContext context, FilterModel model) {
    var currentPreviewedFilter;
    if (currentPreviewedFilterIndex < model.entityList.length) currentPreviewedFilter = model.entityList[currentPreviewedFilterIndex];

    List<SpeedDialChild> list = [];
    if (model.imageML.loadType == ImageMLType.FILE) {
      var openCameraIcon = Icon(Icons.face);
      var openCameraTitle = Text('Open Live Camera View');
      var openCameraDescription = Text('Switch to the live camera view to apply filters to your face');
      var openCameraChild = DescribedFeatureOverlay(featureId: 'open_camera', child: openCameraIcon, tapTarget: openCameraIcon, title: openCameraTitle, description: openCameraDescription, contentLocation: ContentLocation.above);

      list.add(SpeedDialChild(child: openCameraChild, backgroundColor: Colors.green, label: 'Open live camera view', onTap: () => model.imageML = ImageML(ImageMLType.LIVE_CAMERA_MEMORY)));
    }

    var openImageIcon = Icon(Icons.image);
    var openImageTitle = Text('Open Image From Phone');
    var openImageDescription = Text('Instead of applying filters to your live camera view apply them to an image from your gallery');
    var openImageChild = DescribedFeatureOverlay(featureId: 'open_image', child: openImageIcon, tapTarget: openImageIcon, title: openImageTitle, description: openImageDescription, contentLocation: ContentLocation.above);

    list.add(SpeedDialChild(child: openImageChild, backgroundColor: Colors.green, label: 'Open image from phone', onTap: () => editImageFromPhone(context, model)));

    if (currentPreviewedFilterIndex > 0) {
      var deleteFilterIcon = Icon(Icons.delete);
      var deleteFilterTitle = Text('Delete An Existing Filter');
      var deleteFilterDescription = Text('Delete the currently selected filter from the list of filters');
      var deleteFilterChild = DescribedFeatureOverlay(featureId: 'delete_filter', child: deleteFilterIcon, tapTarget: deleteFilterIcon, title: deleteFilterTitle, description: deleteFilterDescription);
      list.add(SpeedDialChild(child: deleteFilterChild, backgroundColor: Colors.red, label: 'Delete "${currentPreviewedFilter?.name}" filter'));

      var editFilterIcon = Icon(Icons.edit);
      var editFilterTitle = Text('Edit An Existing Filter');
      var editFilterDescription = Text('Edit the currently selected filter using the creation wizard again');
      var editFilterChild = DescribedFeatureOverlay(featureId: 'edit_filter', child: editFilterIcon, tapTarget: editFilterIcon, title: editFilterTitle, description: editFilterDescription);
      list.add(SpeedDialChild(child: editFilterChild, label: 'Edit "${currentPreviewedFilter?.name}" filter', onTap: () => editFilter(model, model.entityList[currentPreviewedFilterIndex])));
    }

    var addFilterIcon = Icon(Icons.library_add);
    var addFilterTitle = Text('Add A New Filter');
    var addFilterDescription = Text('Begin the filter creation process here');
    var addFilterChild = DescribedFeatureOverlay(featureId: 'add_filter', child: addFilterIcon, tapTarget: addFilterIcon, title: addFilterTitle, description: addFilterDescription);
    list.add(SpeedDialChild(child: addFilterChild, label: 'Add a new filter', onTap: () => editFilter(model, Filter())));

    list.add(SpeedDialChild(
        child: Icon(Icons.camera),
        label: '[Debugging] FeatureDiscovery Clear',
        onTap: () {
          var list = ['add_filter', 'open_image', 'open_camera', 'edit_filter', 'delete_filter', 'flip_camera', 'filter_list'];
          FeatureDiscovery.clearPreferences(context, list);
        }));

    var fab = SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        children: list,
        onOpen: () {
          FeatureDiscovery.discoverFeatures(context, ['add_filter', 'open_image', 'open_camera', 'edit_filter', 'delete_filter']);
        });
    return fab;
  }

  void editImageFromPhone(BuildContext context, FilterModel model) async {
    await selectImage(context, 'temp');
    if (getAppFile('temp').existsSync()) {
      model.imageML = ImageML(ImageMLType.FILE, 'temp');
    }

    // Clear widget state
    setState(() => currentPreviewedFilterIndex = 0);
  }

  void editFilter(FilterModel model, Filter filter) async {
    // Clear widget state
    setState(() => currentPreviewedFilterIndex = 0);

    if (filter.id != null)
      model.entityBeingEdited = await DBWorker.db.get(filter.id);
    else
      model.entityBeingEdited = filter;

    print('Setting model to filter: ${filter.landmarks}');
    model.landmarks = filter.landmarks;
    model.imageMLEdit = model.imageML;
    model.imageML = ImageML(ImageMLType.ASSET, 'assets/preview.jpg');
    model.setStackIndex(1);
  }

  void deleteFilter(FilterModel model, Filter filter) async {
    // Delete from DB
    await DBWorker.db.delete(filter.id);

    // Clear saved images
    filter.landmarks.forEach((landmarkType, filterInfo) {
      var file = getAppFile(getLandmarkFilename(filter.name, landmarkType));
      if (file.existsSync()) file.deleteSync();
    });

    // Reload DB and refresh filter list
    model.loadData(DBWorker.db);
    model.landmarks.clear();

    // Clear widget state
    setState(() => currentPreviewedFilterIndex = 0);
  }

  Future deleteFilterDialog(BuildContext context, FilterModel model, Filter filter) async {
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext alertContext) {
          return AlertDialog(title: Text('Delete Filter'), content: Text('Really delete ${filter.name}?'), actions: [
            FlatButton(child: Text('Cancel'), onPressed: () => Navigator.of(alertContext).pop()),
            FlatButton(
              child: Text('Delete'),
              onPressed: () {
                deleteFilter(model, filter);
                Navigator.of(context).pop();
                Scaffold.of(context).showSnackBar(SnackBar(
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                  content: Text('Filter deleted'),
                ));
              },
            )
          ]);
        });
  }
}
