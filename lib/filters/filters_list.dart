import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_circular_text/circular_text.dart';
import 'package:flutter_page_indicator/flutter_page_indicator.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_swiper/flutter_swiper.dart';
import 'package:photofilters/image_utils.dart';
import 'package:photofilters/ml/image_ml.dart';
import 'package:scoped_model/scoped_model.dart';

import 'filter.dart';
import 'filter_model.dart';
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
        floatingActionButton: buildFloatingActionButton(model),
        body: Stack(children: [
          ImageML.buildPreviewWidget(context, model),
          RaisedButton(
              child: Text('Live or Die'),
              onPressed: () async {
                if (model.imageML.loadType == ImageMLType.MEMORY)
                  model.imageML = ImageML(ImageMLType.ASSET, 'assets/preview.jpg');
                else if (model.imageML.loadType == ImageMLType.ASSET) {
                  await selectImage(context, "temp");
                  model.imageML = ImageML(ImageMLType.FILE, 'temp');
                } else
                  model.imageML = ImageML(ImageMLType.MEMORY);
              }),
          Positioned(
            bottom: 10,
            right: 0,
            child: _buildList(context, model),
          )
        ]),
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
                  index: model.currentStep,
                  onIndexChanged: (index) {
                    model.currentStep = index;
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

  Widget buildFloatingActionButton(FilterModel model) => (model.imageML != null)
      ? FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () async {
            editFilter(model, Filter());
          })
      : Container();

  Widget buildSlidable(BuildContext context, FilterModel model, Filter filter) {
    return Slidable(
      child: GestureDetector(
        child: Card(child: Container(padding: EdgeInsets.all(20), child: Center(child: Text('Filter Name: ${filter.name}')))),
        onTap: () {
          print('Applying...: ID: ${filter.id}, ${filter.dbLandmarks}, ${filter.dbWidths}, ${filter.dbHeights}, ${filter.toString()}');
          model.landmarks = filter.landmarks;
        },
      ),
      actionPane: SlidableDrawerActionPane(),
      actionExtentRatio: 0.2,
      secondaryActions: [IconSlideAction(caption: "Delete", color: Colors.red, icon: Icons.delete, onTap: () => deleteFilter(context, filter)), IconSlideAction(caption: 'Edit', color: Colors.blue, icon: Icons.edit, onTap: () => editFilter(model, filter))],
    );
  }

  void editFilter(FilterModel model, Filter filter) async {
    if (filter.id != null)
      model.entityBeingEdited = await DBWorker.db.get(filter.id);
    else
      model.entityBeingEdited = filter;

    model.landmarks = filter.landmarks;
    model.setStackIndex(1);
  }

  Future deleteFilter(BuildContext context, Filter filter) async {
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext alertContext) {
          return AlertDialog(title: Text('Delete Filter'), content: Text('Really delete ${filter.name}?'), actions: [
            FlatButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(alertContext).pop();
              },
            ),
            FlatButton(
              child: Text('Delete'),
              onPressed: () async {
                // Delete from DB
                await DBWorker.db.delete(filter.id);

                // Clear saved images
                filter.landmarks.forEach((landmarkType, filterInfo) {
                  var file = getAppFile(getLandmarkFilename(filter.name, landmarkType));
                  if (file.existsSync()) file.deleteSync();
                });

                Navigator.of(alertContext).pop();
                Scaffold.of(context).showSnackBar(SnackBar(
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                  content: Text('Filter deleted'),
                ));
                filtersModel.loadData(DBWorker.db);
                filtersModel.clear();
              },
            )
          ]);
        });
  }
}
