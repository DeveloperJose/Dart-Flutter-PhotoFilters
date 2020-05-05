import 'package:sqflite/sqflite.dart';

import 'filter_model.dart';

abstract class DBWorker {
  static final DBWorker db = SQFLiteDB._();

  Future<int> create(Filter filter);

  Future<void> update(Filter filter);

  Future<void> delete(int id);

  Future<Filter> get(int id);

  Future<List<Filter>> getAll();
}

class SQFLiteDB extends DBWorker {
  static const String DB_NAME = 'filters.db';
  static const String TBL_NAME = 'filters';
  static const String KEY_ID = 'id';
  static const String KEY_FILTER_NAME = 'filter_name';
  static const String KEY_LANDMARKS = 'landmarks';
  static const String KEY_WIDTHS = 'landmark_widths';
  static const String KEY_HEIGHTS = 'landmark_heights';

  Database _db;

  SQFLiteDB._();

  /// Loads grocery information from a database map
  Future<Filter> _fromMap(Map<String, dynamic> map) async => await Filter.fromDatabase(map[KEY_ID], map[KEY_FILTER_NAME], map[KEY_LANDMARKS], map[KEY_WIDTHS], map[KEY_HEIGHTS]);

  /// Converts grocery information into a mappable format
  Map<String, dynamic> _toMap(Filter filter) => Map<String, dynamic>()
    ..[KEY_ID] = filter.id
    ..[KEY_FILTER_NAME] = filter.name
    ..[KEY_LANDMARKS] = filter.dbLandmarks
    ..[KEY_WIDTHS] = filter.dbWidths
    ..[KEY_HEIGHTS] = filter.dbHeights;

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
        "$KEY_LANDMARKS TEXT,"
        "$KEY_WIDTHS TEXT,"
        "$KEY_HEIGHTS TEXT"
        ")");
  }

  Future<void> upgradeTable() async {
    await _db.execute('DROP TABLE IF EXISTS $TBL_NAME');
    print('Dropped database table');
    await createTable(_db);
    print('Created new database table');
  }

  @override
  Future<int> create(Filter filter) async {
    Database db = await database;
    return await db.rawInsert(
        "INSERT INTO $TBL_NAME ($KEY_FILTER_NAME, $KEY_LANDMARKS, $KEY_WIDTHS, $KEY_HEIGHTS) "
        "VALUES (?, ?, ?, ?)",
        [filter.name, filter.dbLandmarks, filter.dbWidths, filter.dbHeights]);
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
    return values.isNotEmpty ? values.map((m) => _fromMap(m)).toList() : [];
  }

  @override
  Future<void> update(Filter filter) async {
    Database db = await database;
    return await db.update(TBL_NAME, _toMap(filter), where: "$KEY_ID = ?", whereArgs: [filter.id]);
  }
}
