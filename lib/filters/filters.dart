import 'package:flutter/material.dart';
import 'package:scoped_model/scoped_model.dart';

import 'filter_model.dart';
import 'filters_dbworker.dart';
import 'filters_entry.dart';
import 'filters_list.dart';

class Filters extends StatelessWidget {
  Filters() {
    filtersModel.loadData(DBWorker.db);
  }

  @override
  Widget build(BuildContext context) {
    return ScopedModel<FilterModel>(
        model: filtersModel,
        child: ScopedModelDescendant<FilterModel>(builder: (BuildContext context, Widget child, FilterModel model) {
          return IndexedStack(
            index: model.stackIndex,
            children: <Widget>[FilterList(), FilterEntry()],
          );
        }));
  }
}
