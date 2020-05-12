import 'package:flutter/material.dart';
import 'package:photofilters/ml/image_ml.dart';
import 'package:scoped_model/scoped_model.dart';

import 'filter_model.dart';
import 'filters_dbworker.dart';
import 'filters_entry.dart';
import 'filters_list.dart';

class FiltersMainWidget extends StatelessWidget {
  FiltersMainWidget() {
    // Set starting type of app
    filtersModel.imageML = ImageML(ImageMLType.ASSET, 'assets/preview.jpg');
    // Load previous data from DB
    filtersModel.loadData(DBWorker.db);
  }

  @override
  Widget build(BuildContext parentContext) {
    return ScopedModel<FilterModel>(
        model: filtersModel,
        child: ScopedModelDescendant<FilterModel>(builder: (BuildContext context, Widget child, FilterModel model) {
          if (model.stackIndex == 0)
            return FilterList().build(context);
          else
            return FilterEntry().build(context);
        }));
  }
}
