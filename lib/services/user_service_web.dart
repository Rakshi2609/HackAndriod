import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> createUser(
      {required String name,
      required String email,
      required String password,
      String role = 'patient'}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_users') ?? '[]';
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    if (list.any((u) => u['email'] == email)) return false;
    list.add({
      'name': name,
      'email': email,
      'role': role,
      'password_hash': _hashPassword(password),
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await prefs.setString('local_users', jsonEncode(list));
    return true;
  }

  Future<Map<String, dynamic>?> findByEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_users') ?? '[]';
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final doc = list.firstWhere((u) => u['email'] == email, orElse: () => {});
    if (doc.isEmpty) return null;
    final copy = Map<String, dynamic>.from(doc);
    copy.remove('password_hash');
    return copy;
  }

  Future<bool> authenticate(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_users') ?? '[]';
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final doc = list.firstWhere((u) => u['email'] == email, orElse: () => {});
    if (doc.isEmpty) return false;
    final stored = doc['password_hash'] as String?;
    if (stored == null) return false;
    return stored == _hashPassword(password);
  }

  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_users') ?? '[]';
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map((e) {
      final copy = Map<String, dynamic>.from(e);
      copy.remove('password_hash');
      return copy;
    }).toList();
  }
}
