// Web-safe stub for MongoReportService used when `dart:io` is not available.
// This mirrors the interface used by the native implementation but does nothing
// so the app can run on web without mongo_dart.

class ObjectId {
  final String _hex = DateTime.now().millisecondsSinceEpoch.toString();
  String toHexString() => _hex;
}

class MongoReportService {
  MongoReportService._internal();
  factory MongoReportService() => MongoReportService._internal();

  Future<void> init({String uri = ''}) async {}

  Future<ObjectId> insertReport({
    required String type,
    String? subtype,
    required Map<String, dynamic> content,
  }) async {
    // No-op on web; return a dummy ObjectId
    return ObjectId();
  }

  Future<List<Map<String, dynamic>>> fetchAllReports() async {
    return <Map<String, dynamic>>[];
  }

  Future<void> dispose() async {}
}
