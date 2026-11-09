
import 'dart:convert';
import 'package:http/http.dart' as http;

class GuestSessionApiException implements Exception {
  final int statusCode;
  final String message;

  GuestSessionApiException(this.statusCode, this.message);

  @override
  String toString() => 'API Error ($statusCode): $message';
}

class GuestSessionApi {
  static const String baseUrl = 'http://192.168.1.11:3000';

  static Future<Map<String, dynamic>> createSession() async {
    final uri = Uri.parse('$baseUrl/api/guest/session');
    final response = await http.post(uri);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> restoreSession(
    String sessionToken,
  ) async {
    final uri = Uri.parse('$baseUrl/api/guest/restore');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sessionToken': sessionToken}),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> logout(
    String sessionToken,
  ) async {
    final uri = Uri.parse('$baseUrl/api/guest/logout');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sessionToken': sessionToken}),
    );

    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(
    http.Response response,
  ) {
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return data;
    }

    throw GuestSessionApiException(
      response.statusCode,
      data['message']?.toString() ?? 'Backend request failed',
    );
  }
}
