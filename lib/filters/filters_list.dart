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
  /// Used to size the icons in the Swiper
  static const double ICON_PADDING = 50.0;

  /// Current index of the entity being previewed from the model entityList
  /// Index 0 is special, it clears all the filters, it's not really stored in the database
  int currentPreviewedFilterIndex = 0;

  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
      FeatureDiscovery.discoverFeatures(context, {'filter_list', 'flip_camera'});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) => ScopedModelDescendant<FilterModel>(builder: (BuildContext context, Widget child, FilterModel model) {
        return Scaffold(
          resizeToAvoidBottomPadding: false,
          floatingActionButton: _buildSpeedDial(context, model),
          body: Stack(
            children: [
              FilterPreviewWidget(filterModel: model),
              Positioned(bottom: 10, right: 0, child: _buildFilterList(context, model)),
            ],
          ),
        );
      });

  /// Builds the widget responsible for displaying the list of filters
  Widget _buildFilterList(BuildContext context, FilterModel model) {
    var child;
    if (model.entityList.isEmpty)
      child = Container(alignment: Alignment.bottomCenter, child: Container(width: double.maxFinite, color: Colors.grey.shade200, child: Text('No filters created yet!', textAlign: TextAlign.center)));
    else if (!model.imageML.isLoaded)
      child = Container(alignment: Alignment.bottomCenter, child: Container(width: double.maxFinite, color: Colors.grey.shade200, child: Text('Filters unavailable until preview is loaded', textAlign: TextAlign.center)));
    else
      child = DescribedFeatureOverlay(featureId: 'filter_list', tapTarget: _buildSwiperItem(model, Filter(-1, 'Filter Name', Icons.hourglass_empty)), title: Text('Filter List'), description: Text('Swipe left and right to move between your filters'), child: _buildSwiper(model));

    return LimitedBox(maxHeight: 150, maxWidth: MediaQuery.of(context).size.width, child: child);
  }

  /// Builds the swiper that allows for filter changing on the fly
  Swiper _buildSwiper(FilterModel model) {
    return Swiper(
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
        return _buildSwiperItem(model, model.entityList[index]);
      },
    );
  }

  /// Builds a single item for the swiper
  Widget _buildSwiperItem(FilterModel model, Filter item) => LayoutBuilder(builder: (context, constraint) {
        double height = math.max(constraint.biggest.height - ICON_PADDING, 1);
        return Stack(alignment: AlignmentDirectional.center, children: [
          ClipOval(child: Container(color: Colors.tealAccent, child: Icon(item.icon ?? Icons.device_unknown, size: height))),
          _buildListItemText(model, item),
        ]);
      });

  /// Builds the text of a single item for the swiper
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

  /// Builds the floating action speed dial
  Widget _buildSpeedDial(BuildContext context, FilterModel model) {
    var currentPreviewedFilter;
    if (currentPreviewedFilterIndex < model.entityList.length) currentPreviewedFilter = model.entityList[currentPreviewedFilterIndex];

    List<SpeedDialChild> children = [];
    if (model.imageML.loadType == ImageMLType.FILE) {
      children.add(_buildOpenCameraFAB(model));
    }

    children.add(_buildOpenImageFAB(context, model));

    if (currentPreviewedFilterIndex > 0) {
      children.add(_buildDeleteFilterFAB(context, model, currentPreviewedFilter));
      children.add(_buildEditFilterFAB(model, currentPreviewedFilter));
    }
    children.add(_buildAddFilterFAB(model));

    children.add(SpeedDialChild(
        child: Icon(Icons.camera),
        label: '[Debugging] FeatureDiscovery Clear',
        onTap: () {
          var list = ['add_filter', 'open_image', 'open_camera', 'edit_filter', 'delete_filter', 'flip_camera', 'filter_list'];
          FeatureDiscovery.clearPreferences(context, list);
        }));

    return SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        children: children,
        onOpen: () {
          FeatureDiscovery.discoverFeatures(context, ['add_filter', 'open_image', 'open_camera', 'edit_filter', 'delete_filter']);
        });
  }

  /// Builds the add filter button of the speed-dial
  SpeedDialChild _buildAddFilterFAB(FilterModel model) {
    return SpeedDialChild(
      child: _buildDescribedFeature('add_filter', Icons.library_add, 'Add A New Filter', 'Begin the filter creation process here'),
      onTap: () => editFilter(model, Filter()),
      label: 'Add a new filter',
    );
  }

  /// Builds the edit filter button of the speed-dial
  SpeedDialChild _buildEditFilterFAB(FilterModel model, Filter currentPreviewedFilter) {
    return SpeedDialChild(
      child: _buildDescribedFeature('edit_filter', Icons.edit, 'Edit An Existing Filter', 'Edit the currently selected filter using the creation wizard again'),
      onTap: () => editFilter(model, model.entityList[currentPreviewedFilterIndex]),
      label: 'Edit "${currentPreviewedFilter?.name}" filter',
    );
  }

  /// Builds the delete filter button of the speed-dial
  SpeedDialChild _buildDeleteFilterFAB(BuildContext context, FilterModel model, Filter currentPreviewedFilter) {
    return SpeedDialChild(
      child: _buildDescribedFeature('delete_filter', Icons.delete, 'Delete An Existing Filter', 'Delete the currently selected filter from the list of filters'),
      onTap: () async => await deleteFilterDialog(context, model, currentPreviewedFilter),
      backgroundColor: Colors.red,
      label: 'Delete "${currentPreviewedFilter?.name}" filter',
    );
  }

  /// Builds the open image button of the speed-dial
  SpeedDialChild _buildOpenImageFAB(BuildContext context, FilterModel model) {
    return SpeedDialChild(
      child: _buildDescribedFeature('open_image', Icons.image, 'Open Image From Phone', 'Instead of applying filters to your live camera view apply them to an image from your gallery', ContentLocation.above),
      onTap: () => editImageFromPhone(context, model),
      backgroundColor: Colors.green,
      label: 'Open image from phone',
    );
  }

  /// Builds the open live camera view button of the speed-dial
  SpeedDialChild _buildOpenCameraFAB(FilterModel model) {
    return SpeedDialChild(
      label: 'Open live camera view',
      backgroundColor: Colors.green,
      child: _buildDescribedFeature('open_camera', Icons.face, 'Open Live Camera View', 'Switch to the live camera view to apply filters to your face', ContentLocation.above),
      onTap: () => model.imageML = ImageML(ImageMLType.LIVE_CAMERA_MEMORY),
    );
  }

  /// Builds a DescribedFeature used for FeatureDiscovery
  DescribedFeatureOverlay _buildDescribedFeature(String featureID, IconData icon, String title, String description, [ContentLocation contentLocation = ContentLocation.trivial]) {
    return DescribedFeatureOverlay(
      featureId: featureID,
      child: Icon(icon),
      tapTarget: Icon(icon),
      title: Text(title),
      description: Text(description),
      contentLocation: contentLocation,
    );
  }

  /// Prompts the user to select an image from their phone and then sends them to the editor
  void editImageFromPhone(BuildContext context, FilterModel model) async {
    await selectImage(context, 'temp');
    if (getAppFile('temp').existsSync()) {
      model.imageML = ImageML(ImageMLType.FILE, 'temp');
    }

    // Clear widget state
    setState(() => currentPreviewedFilterIndex = 0);
  }

  /// Edits a given filter by preparing the entry and sending the user there
  void editFilter(FilterModel model, Filter filter) async {
    // Clear widget state
    setState(() => currentPreviewedFilterIndex = 0);

    if (filter.id != null)
      model.entityBeingEdited = await DBWorker.db.get(filter.id);
    else
      model.entityBeingEdited = filter;

    model.landmarks = filter.landmarks;
    model.imageMLEdit = model.imageML;
    model.imageML = ImageML(ImageMLType.ASSET, 'assets/preview.jpg');
    model.setStackIndex(1);
  }

  /// Deletes a given filter from the database and the filter list
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

  /// Prompts the user to confirm they want to delete a selected filter
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
