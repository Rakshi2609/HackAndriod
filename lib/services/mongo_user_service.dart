import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoUserService {
  static final MongoUserService _instance = MongoUserService._internal();
  factory MongoUserService() => _instance;
  MongoUserService._internal();

  Db? _db;
  DbCollection? _users;
  bool _indexesCreated = false;

  Future<void> init(
      {String uri = 'mongodb://127.0.0.1:27017/carelytix'}) async {
    if (_db != null && _db!.isConnected) return;
    _db = Db(uri);
    await _db!.open();
    _users = _db!.collection('users');
    // Ensure an index on email for uniqueness (create once)
    if (!_indexesCreated) {
      try {
        await _users!.createIndex(keys: {'email': 1}, unique: true);
      } catch (_) {}
      _indexesCreated = true;
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> createUser({
    required String name,
    required String email,
    required String password,
    String role = 'patient',
  }) async {
    await init();
    final existing = await _users!.findOne(where.eq('email', email));
    if (existing != null) return false;
    final doc = {
      'name': name,
      'role': role,
      'email': email,
      'password_hash': _hashPassword(password),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    final res = await _users!.insertOne(doc);
    return res.isSuccess;
  }

  Future<Map<String, dynamic>?> findByEmail(String email) async {
    await init();
    final doc = await _users!.findOne(where.eq('email', email));
    if (doc == null) return null;
    final copy = Map<String, dynamic>.from(doc);
    if (copy.containsKey('_id') && copy['_id'] is ObjectId) {
      copy['id'] = (copy['_id'] as ObjectId).toHexString();
    }
    copy.remove('password_hash');
    return copy;
  }

  Future<bool> authenticate(String email, String password) async {
    await init();
    final doc = await _users!.findOne(where.eq('email', email));
    if (doc == null) return false;
    final stored = doc['password_hash'] as String?;
    if (stored == null) return false;
    return stored == _hashPassword(password);
  }

  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    await init();
    final out = <Map<String, dynamic>>[];
    final cursor = _users!.find();
    await for (final d in cursor) {
      final copy = Map<String, dynamic>.from(d);
      if (copy.containsKey('_id') && copy['_id'] is ObjectId) {
        copy['id'] = (copy['_id'] as ObjectId).toHexString();
      }
      copy.remove('password_hash');
      out.add(copy);
    }
    return out;
  }

  Future<void> dispose() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _users = null;
    }
  }
}
