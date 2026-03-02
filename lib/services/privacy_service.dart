import 'dart:convert';
import 'package:crypto/crypto.dart';

class PrivacyService {
  // SHA-256 Health ID generator — AG-XXXXXXXX
  static String generateSecureID(String email, String phone) {
    final combined = '$email$phone';
    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);
    return 'AG-${digest.toString().substring(0, 8).toUpperCase()}';
  }

  // Hash any sensitive string for storage
  static String hashValue(String value) {
    final bytes = utf8.encode(value);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Generate a display-safe ID from any sensitive data
  static String generateDisplayId(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 12).toUpperCase();
  }
}
