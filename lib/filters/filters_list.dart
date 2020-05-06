import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:photofilters/image_utils.dart';
import 'package:photofilters/ml_utils.dart';
import 'package:scoped_model/scoped_model.dart';

import 'filter_model.dart';
import 'filters_dbworker.dart';
import 'package:photofilters/camera_utils.dart';

class FilterList extends StatelessWidget {
  final String tempFilename = 'temp_photo';

  @override
  Widget build(BuildContext context) {;
    return ScopedModelDescendant<FilterModel>(builder: (BuildContext context, Widget child, FilterModel model) {
      print('FiltersModel: ${filtersModel.imageML}, Model ML ${model.imageML}');
      return Scaffold(
        floatingActionButton: buildFloatingActionButton(model),
        body: Column(children: [
          ListTile(
            trailing: IconButton(
              icon: Icon(Icons.photo_library),
              color: Colors.blue,
              onPressed: () async {
                await selectImage(context, tempFilename);
                model.imageML = await ImageML.fromFilename(tempFilename);
                filtersModel.clear();
              },
            ),
          ),
          ImageML.getPreviewWidget(model),
          (model.entityList.length == 0)
              ? Center(child: Text('No filters added yet!'))
              : (model.imageML != null)
                  ? Expanded(
                      child: ListView.builder(
                      scrollDirection: Axis.vertical,
                      physics: ScrollPhysics(),
                      itemCount: model.entityList.length,
                      itemBuilder: (BuildContext context, int index) => buildSlidable(context, model, model.entityList[index]),
                    ))
                  : Text('Cannot apply filters before an image is selected!')
        ]),
      );
    });
  }

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
      secondaryActions: [
        IconSlideAction(caption: "Delete", color: Colors.red, icon: Icons.delete, onTap: () => deleteFilter(context, filter)),
        IconSlideAction(caption: 'Edit', color: Colors.blue, icon: Icons.edit, onTap: () => editFilter(model, filter))
      ],
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
