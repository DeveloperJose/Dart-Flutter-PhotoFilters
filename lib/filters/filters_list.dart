import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

class FilterList extends StatelessWidget {
  static const int ICON_PADDING = 30;

  static Paint listItemTextPaint = Paint()
    ..strokeWidth = 20
    ..color = Colors.deepPurple
    ..style = PaintingStyle.stroke;

  @override
  Widget build(BuildContext context) => ScopedModelDescendant<FilterModel>(builder: buildScaffold);

  Scaffold buildScaffold(BuildContext context, Widget child, FilterModel model) => Scaffold(
        floatingActionButton: buildFloatingActionButton(context, model),
        body: Stack(children: [FilterPreviewWidget(filterModel: model), Positioned(bottom: 10, right: 0, child: _buildList(context, model))]),
      );

  Widget _buildList(BuildContext context, FilterModel model) => LimitedBox(
      maxHeight: 150,
      maxWidth: MediaQuery.of(context).size.width,
      child: model.entityList.length == 0
          ? Container(alignment: Alignment.bottomCenter, child: Container(width: double.maxFinite, color: Colors.grey.shade200, child: Text('No filters created yet!', textAlign: TextAlign.center)))
          : !model.imageML.isLoaded
              ? Container(alignment: Alignment.bottomCenter, child: Container(width: double.maxFinite, color: Colors.grey.shade200, child: Text('Filters unavailable until preview is loaded', textAlign: TextAlign.center)))
              : Swiper(
                  loop: false,
                  viewportFraction: 0.25,
                  scale: 0.1,
                  indicatorLayout: PageIndicatorLayout.SLIDE,
                  pagination: new SwiperPagination(margin: EdgeInsets.zero, builder: SwiperPagination.dots),
                  index: model.currentPreviewedFilterIndex,
                  onIndexChanged: (index) {
                    model.currentPreviewedFilterIndex = index;
                    model.landmarks = model.entityList[index].landmarks;
                    model.triggerRebuild();
                  },
                  itemCount: model.entityList.length,
                  itemBuilder: (BuildContext context, int index) {
                    return _buildListItem(model, model.entityList[index]);
                  },
                ));

  Widget _buildListItem(FilterModel model, Filter item) => LayoutBuilder(builder: (context, constraint) {
        return Stack(alignment: AlignmentDirectional.center, children: [
          _buildListItemText(model, item),
          Icon(Icons.not_listed_location, size: constraint.biggest.width - ICON_PADDING),
        ]);
      });

  Widget _buildListItemText(FilterModel model, Filter item) => CircularText(backgroundPaint: listItemTextPaint, children: [
        TextItem(
          startAngle: -90,
          startAngleAlignment: StartAngleAlignment.center,
          space: 14,
          text: Text(item.name.toUpperCase(), style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        )
      ]);

  Widget buildFloatingActionButton(BuildContext context, FilterModel model) {
    List<SpeedDialChild> list = [];
    if (model.imageML.loadType == ImageMLType.LIVE_CAMERA_MEMORY)
      list.add(SpeedDialChild(child: Icon(Icons.image), label: 'Open image from phone', onTap: () => editImageFromPhone(context, model)));
    else
      list.add(SpeedDialChild(child: Icon(Icons.face), label: 'Open live camera view', onTap: () => model.imageML = ImageML(ImageMLType.LIVE_CAMERA_MEMORY)));

    list.add(SpeedDialChild(child: Icon(Icons.library_add), label: 'Add a new filter', onTap: () => editFilter(model, Filter())));

    if (model.currentPreviewedFilterIndex > 0) {
      list.add(SpeedDialChild(child: Icon(Icons.delete), label: 'Delete "${model.currentPreviewedFilter?.name}" filter'));
      list.add(SpeedDialChild(child: Icon(Icons.edit), label: 'Edit "${model.currentPreviewedFilter?.name}" filter'));
    }

    return SpeedDial(animatedIcon: AnimatedIcons.menu_close, children: list);
  }

  void editImageFromPhone(BuildContext context, FilterModel model) async {
    await selectImage(context, 'temp');
    if (getAppFile('temp').existsSync()) model.imageML = ImageML(ImageMLType.FILE, 'temp');
  }

  void editFilter(FilterModel model, Filter filter) async {
    if (filter.id != null)
      model.entityBeingEdited = await DBWorker.db.get(filter.id);
    else
      model.entityBeingEdited = filter;

    // TODO: Replace FAStepper
    model.currentPreviewedFilterIndex = 0;

    model.landmarks = filter.landmarks;
    model.imageMLEdit = model.imageML;
    model.imageML = ImageML(ImageMLType.ASSET, 'assets/preview.jpg');
    model.setStackIndex(1);
  }

  void _deleteFilter(FilterModel model, Filter filter) async {
    // Delete from DB
    await DBWorker.db.delete(filter.id);

    // Clear saved images
    filter.landmarks.forEach((landmarkType, filterInfo) {
      var file = getAppFile(getLandmarkFilename(filter.name, landmarkType));
      if (file.existsSync()) file.deleteSync();
    });

    // Reload DB and refresh filter list
    model.loadData(DBWorker.db);
    model.currentPreviewedFilterIndex = 0;
    model.landmarks.clear();
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
                _deleteFilter(model, filter);
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
