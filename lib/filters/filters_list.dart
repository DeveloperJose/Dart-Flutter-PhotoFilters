import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:photofilters/image_utils.dart';
import 'package:scoped_model/scoped_model.dart';


import 'package:photofilters/ml_utils.dart';
import 'filter_model.dart';

class FilterList extends StatelessWidget {
  final String tempFilename = 'temp_photo';

  Widget buildFloatingActionButton(FilterModel model) => FloatingActionButton(
      child: Icon(Icons.add),
      onPressed: () async {
        // Delete temp file
        model.entityBeingEdited = Filter();
        model.setStackIndex(1);
      });

  Widget buildSlideable(BuildContext context, FilterModel model, Filter filter) {
    return Card(elevation: 8, child: Text(filter.name));
  }

  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<FilterModel>(builder: (BuildContext context, Widget child, FilterModel model) {
      return Scaffold(
        floatingActionButton: buildFloatingActionButton(model),
        body: Column(children: [
          ListTile(
            trailing: IconButton(
              icon: Icon(Icons.photo_library),
              color: Colors.blue,
              onPressed: () async {
                await selectImage(context, tempFilename);
                model.addImageML(await ImageML.fromFilename(tempFilename));
              },
            ),
          ),
          (model.imageML != null)
              ? model.imageML.getWidget(model)
              : Text('ML stuff will go here'),
          (model.entityList.length == 0)
              ? Text('No filters added yet!')
              : Expanded(
                  child: GridView.builder(
                  physics: ScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
                  itemCount: model.entityList.length,
                  itemBuilder: (BuildContext context, int index) => buildSlideable(context, model, model.entityList[index]),
                ))
        ]),
      );
    });
  }
}