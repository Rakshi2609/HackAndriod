// Web-safe stub for MongoReportService used when `dart:io` is not available.
// This mirrors the interface used by the native implementation but persists
// reports to `SharedPreferences` on web so users still see saved reports.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ObjectId {
  final String _hex = DateTime.now().millisecondsSinceEpoch.toString();
  String toHexString() => _hex;
}

class MongoReportService {
  MongoReportService._internal();
  factory MongoReportService() => MongoReportService._internal();

  static const _kStorageKey = 'carelytix_reports';

  Future<void> init({String uri = ''}) async {
    // nothing to initialize for SharedPreferences-backed stub
    return;
  }

  Future<ObjectId> insertReport({
    required String type,
    String? subtype,
    required Map<String, dynamic> content,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc().toIso8601String();
    final id = ObjectId();
    final doc = {
      '_id': id.toHexString(),
      'type': type,
      'subtype': subtype ?? '',
      'content': content,
      'created_at': now,
    };

    final existing = prefs.getStringList(_kStorageKey) ?? <String>[];
    existing.insert(0, jsonEncode(doc));
    await prefs.setStringList(_kStorageKey, existing);
    return id;
  }

  Future<List<Map<String, dynamic>>> fetchAllReports() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kStorageKey) ?? <String>[];
    final out = <Map<String, dynamic>>[];
    for (final s in list) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        out.add(m);
      } catch (_) {}
    }
    return out;
  }

  Future<void> dispose() async {}
}
