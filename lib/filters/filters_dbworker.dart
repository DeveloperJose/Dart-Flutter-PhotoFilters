import 'dart:convert';
import 'dart:ui' as ui;

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/Serialization/iconDataSerialization.dart';
import 'package:sqflite/sqflite.dart';

import '../image_utils.dart';
import 'filter.dart';

/// A database used to store filter information
abstract class DBWorker {
  static final DBWorker db = SQFLiteDB._();

  /// Creates an entry in the DB for a given filter
  Future<int> create(Filter filter);

  /// Updates an entry in the DB for a given filter
  Future<void> update(Filter filter);

  /// Deletes the given filter from the DB given the ID
  Future<void> delete(int id);

  /// Gets a filter from the DB given the ID
  Future<Filter> get(int id);

  /// Gets all filters from the DB
  Future<List<Filter>> getAll();
}

/// An implementation of a database using SQFLite for local storage
class SQFLiteDB extends DBWorker {
  static const SEPARATOR = '|';
  static const String DB_NAME = 'filters.db';
  static const String TBL_NAME = 'filters';

  static const String KEY_ID = 'id';
  static const String KEY_FILTER_NAME = 'filter_name';
  static const String KEY_ICON = 'filter_icon';

  static const String KEY_LANDMARKS = 'landmarks';
  static const String KEY_WIDTHS = 'landmark_widths';
  static const String KEY_HEIGHTS = 'landmark_heights';

  Database _db;

  SQFLiteDB._();

  Future<Database> get database async => _db ??= await _init();

  Future<Database> _init() async {
    return await openDatabase(DB_NAME, version: 1, onOpen: (db) {}, onCreate: (Database db, int version) async {
      createTable(db);
    });
  }

  Future<void> createTable(Database db) async {
    await db.execute("CREATE TABLE IF NOT EXISTS $TBL_NAME ("
        "$KEY_ID INTEGER PRIMARY KEY,"
        "$KEY_FILTER_NAME TEXT,"
        "$KEY_ICON TEXT,"
        "$KEY_LANDMARKS TEXT,"
        "$KEY_WIDTHS TEXT,"
        "$KEY_HEIGHTS TEXT"
        ")");
  }

  Future<void> upgradeTable() async {
    await _db.execute('DROP TABLE IF EXISTS $TBL_NAME');
    await createTable(_db);
  }

  @override
  Future<int> create(Filter filter) async {
    Database db = await database;
    var map = _toMap(filter);
    return await db.rawInsert(
        "INSERT INTO $TBL_NAME ($KEY_FILTER_NAME, $KEY_ICON, $KEY_LANDMARKS, $KEY_WIDTHS, $KEY_HEIGHTS) "
        "VALUES (?, ?, ?, ?, ?)",
        [map[KEY_FILTER_NAME], map[KEY_ICON], map[KEY_LANDMARKS], map[KEY_WIDTHS], map[KEY_HEIGHTS]]);
  }

  @override
  Future<void> delete(int id) async {
    Database db = await database;
    await db.delete(TBL_NAME, where: "$KEY_ID = ?", whereArgs: [id]);
  }

  @override
  Future<Filter> get(int id) async {
    Database db = await database;
    var values = await db.query(TBL_NAME, where: "$KEY_ID = ?", whereArgs: [id]);
    return values.isEmpty ? null : _fromMap(values.first);
  }

  @override
  Future<List<Filter>> getAll() async {
    Database db = await database;
    var values = await db.query(TBL_NAME);
    return values.isNotEmpty ? Future.wait(values.map((m) => _fromMap(m)).toList()) : [];
  }

  @override
  Future<void> update(Filter filter) async {
    Database db = await database;
    return await db.update(TBL_NAME, _toMap(filter), where: "$KEY_ID = ?", whereArgs: [filter.id]);
  }

  /// Loads filter information from a database map
  Future<Filter> _fromMap(Map<String, dynamic> map) async {
    Filter filter = Filter(map[KEY_ID], map[KEY_FILTER_NAME]);

    // Icon decoding
    Map<String, dynamic> iconMap = jsonDecode(map[KEY_ICON]);
    IconData iconData = mapToIconData(iconMap);
    filter.icon = iconData;

    // Reading of landmark information
    List<String> landmarkSplit = map[KEY_LANDMARKS].split(SEPARATOR);
    List<String> widthSplit = map[KEY_WIDTHS].split(SEPARATOR);
    List<String> heightSplit = map[KEY_HEIGHTS].split(SEPARATOR);
    if (landmarkSplit.isEmpty || widthSplit.isEmpty || heightSplit.isEmpty) return null;

    for (int i = 0; i < landmarkSplit.length; i++) {
      String landmarkString = landmarkSplit[i];
      if (landmarkString.isEmpty)
        break;

      // String to Enum
      FaceLandmarkType landmarkType = FaceLandmarkType.values.singleWhere((e) => e.toString() == landmarkSplit[i]);

      // Prepare FilterInfo members
      String filename = getLandmarkFilename(filter.name, landmarkType);
      double width = double.tryParse(widthSplit[i]);
      double height = double.tryParse(heightSplit[i]);
      ui.Image dartImage = await getAppDartImage(filename);

      filter.landmarks[landmarkType] = LandmarkFilterInfo(filename, dartImage, width, height);
    }
    return filter;
  }

  /// Converts filter information into a mappable format
  Map<String, dynamic> _toMap(Filter filter) => Map<String, dynamic>()
    ..[KEY_ID] = filter.id
    ..[KEY_FILTER_NAME] = filter.name
    ..[KEY_ICON] = jsonEncode(iconDataToMap(filter.icon ?? Icons.device_unknown))
    ..[KEY_LANDMARKS] = filter.landmarks.keys.map((landmark) => landmark.toString()).join(SEPARATOR)
    ..[KEY_WIDTHS] = filter.landmarks.values.map((filterInfo) => filterInfo.width).join(SEPARATOR)
    ..[KEY_HEIGHTS] = filter.landmarks.values.map((filterInfo) => filterInfo.height).join(SEPARATOR);
}
