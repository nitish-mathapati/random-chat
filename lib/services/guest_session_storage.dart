
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GuestSessionStorage {
  // Secure storage instance.
  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  // Key used to store the guest session token.
  static const String _sessionTokenKey = 'guest_session_token';

  // Save the guest session token securely.
  static Future<void> saveSessionToken(String token) async {
    await _storage.write(
      key: _sessionTokenKey,
      value: token,
    );
  }

  // Retrieve the saved guest session token.
  static Future<String?> getSessionToken() async {
    return await _storage.read(
      key: _sessionTokenKey,
    );
  }

  // Delete the saved guest session token.
  static Future<void> deleteSessionToken() async {
    await _storage.delete(
      key: _sessionTokenKey,
    );
  }
}
