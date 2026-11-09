
import 'dart:convert';
import 'package:http/http.dart' as http;

class MatchmakingApiException implements Exception {
  final int statusCode;
  final String message;

  MatchmakingApiException(this.statusCode, this.message);

  @override
  String toString() => 'Matchmaking API Error ($statusCode): $message';
}

class MatchmakingApi {
  static const String _baseUrl = 'http://192.168.1.11:3000';

  static Future<Map<String, dynamic>> joinQueue(
    String sessionToken,
  ) async {
    final uri = Uri.parse('$_baseUrl/api/matchmaking/join');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $sessionToken',
      },
      body: jsonEncode({}),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> cancelQueue(
    String sessionToken,
  ) async {
    final uri = Uri.parse('$_baseUrl/api/matchmaking/cancel');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $sessionToken',
      },
      body: jsonEncode({}),
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

    throw MatchmakingApiException(
      response.statusCode,
      data['message']?.toString() ?? 'Matchmaking request failed',
    );
  }
}
