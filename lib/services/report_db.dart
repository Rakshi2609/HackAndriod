import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ReportDb {
  static final ReportDb _instance = ReportDb._internal();
  factory ReportDb() => _instance;
  ReportDb._internal();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'reports.db');
    _db = await openDatabase(dbPath, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          subtype TEXT,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
    });
  }

  Future<int> insertReport(
      {required String type,
      String? subtype,
      required Map<String, dynamic> content}) async {
    await init();
    final data = {
      'type': type,
      'subtype': subtype ?? '',
      'content': jsonEncode(content),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
    return await _db!.insert('reports', data);
  }

  Future<List<Map<String, dynamic>>> fetchAll() async {
    await init();
    final rows = await _db!.query('reports', orderBy: 'created_at DESC');
    return rows
        .map((r) => {
              'id': r['id'],
              'type': r['type'],
              'subtype': r['subtype'],
              'content': jsonDecode(r['content'] as String),
              'created_at':
                  DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
            })
        .toList();
  }
}
