import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart';

class MongoReportService {
  static final MongoReportService _instance = MongoReportService._internal();
  factory MongoReportService() => _instance;
  MongoReportService._internal();

  Db? _db;
  DbCollection? _coll;

  /// Call once before using the service. Connects to local MongoDB at default port.
  Future<void> init(
      {String uri = 'mongodb://127.0.0.1:27017/carelytix'}) async {
    if (_db != null && _db!.isConnected) return;
    _db = Db(uri);
    await _db!.open();
    _coll = _db!.collection('reports');
  }

  Future<ObjectId> insertReport(
      {required String type,
      String? subtype,
      required Map<String, dynamic> content}) async {
    await init();
    final doc = {
      'type': type,
      'subtype': subtype ?? '',
      'content': content,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    final result = await _coll!.insertOne(doc);
    // insertOne returns WriteResult; get insertedId if available
    if (result.isSuccess &&
        result.document != null &&
        result.document!['_id'] != null) {
      return result.document!['_id'] as ObjectId;
    }
    // Fallback: create new ObjectId
    final oid = ObjectId();
    await _coll!.updateOne(
        where.eq('_id', oid), modify.set('created_at', doc['created_at']),
        upsert: true);
    return oid;
  }

  Future<List<Map<String, dynamic>>> fetchAllReports() async {
    await init();
    final cursor = _coll!.find(where.sortBy('created_at', descending: true));
    final out = <Map<String, dynamic>>[];
    await for (final doc in cursor) {
      final copy = Map<String, dynamic>.from(doc);
      // convert ObjectId to hex string
      if (copy.containsKey('_id') && copy['_id'] is ObjectId) {
        copy['id'] = (copy['_id'] as ObjectId).toHexString();
      }
      // Ensure content is a Map
      if (copy['content'] is String) {
        try {
          copy['content'] = jsonDecode(copy['content'] as String);
        } catch (_) {}
      }
      out.add(copy);
    }
    return out;
  }

  Future<void> dispose() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _coll = null;
    }
  }
}
