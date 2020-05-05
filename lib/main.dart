import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'filters/filters.dart';
import 'image_utils.dart' as image_utils;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  image_utils.mDocsDir = await getApplicationDocumentsDirectory();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: true,
        home: Scaffold(
          appBar: AppBar(title: Text('PhotoFilters by Jose G. Perez')),
          body: Filters(),
        ));
  }
}
