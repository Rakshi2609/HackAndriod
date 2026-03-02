import 'mongo_user_service.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final MongoUserService _mongo = MongoUserService();

  Future<bool> createUser(
      {required String name,
      required String email,
      required String password,
      String role = 'patient'}) async {
    return await _mongo.createUser(
        name: name, email: email, password: password, role: role);
  }

  Future<Map<String, dynamic>?> findByEmail(String email) async {
    return await _mongo.findByEmail(email);
  }

  Future<bool> authenticate(String email, String password) async {
    return await _mongo.authenticate(email, password);
  }

  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    return await _mongo.fetchAllUsers();
  }
}
