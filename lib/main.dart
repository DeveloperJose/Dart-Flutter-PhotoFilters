import 'package:feature_discovery/feature_discovery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scoped_model/scoped_model.dart';

import 'filters/filter_model.dart';
import 'filters/filters_dbworker.dart';
import 'filters/filters_entry.dart';
import 'filters/filters_list.dart';
import 'image_utils.dart';
import 'ml/firebase_utils.dart';
import 'ml/image_ml.dart';

FilterModel mainFilterModel = FilterModel();

void clearTemporaryFiles() {
  var tempFile = getAppFile('temp');
  if (tempFile.existsSync()) tempFile.deleteSync(recursive: true);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize utilities
  mDocsDir = await getApplicationDocumentsDirectory();

  // Initialize app to camera live stream mode
  mainFilterModel.imageML = ImageML(ImageMLType.LIVE_CAMERA_MEMORY);

  // Clear temporary files
  clearTemporaryFiles();

  // Load DB data
  mainFilterModel.loadData(DBWorker.db);

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return FeatureDiscovery(
        child: MaterialApp(
            debugShowCheckedModeBanner: true,
            home: Scaffold(
              appBar: AppBar(title: Text('PhotoFilters by Jose G. Perez')),
              body: buildScopedModel(),
            )));
  }

  ScopedModel<FilterModel> buildScopedModel() {
    return ScopedModel<FilterModel>(
        model: mainFilterModel,
        child: ScopedModelDescendant<FilterModel>(builder: (BuildContext context, Widget child, FilterModel model) {
          return IndexedStack(index: model.stackIndex, children: [FilterList(), FilterEntry()]);
        }));
  }

  @override
  void dispose() {
    super.dispose();
    faceDetector.close();

    clearTemporaryFiles();
  }
}
