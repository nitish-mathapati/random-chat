
import 'guest_session_api.dart';
import 'guest_session_storage.dart';

class GuestSession {
  final String guestId;
  final String sessionToken;

  const GuestSession({
    required this.guestId,
    required this.sessionToken,
  });
}

class GuestSessionManager {
  // Restore an existing session or create a new one.
  static Future<GuestSession> initialize() async {
    final savedToken =
        await GuestSessionStorage.getSessionToken();

    // Try restoring an existing session.
    if (savedToken != null && savedToken.isNotEmpty) {
      try {
        final response =
            await GuestSessionApi.restoreSession(savedToken);

        final data =
            response['data'] as Map<String, dynamic>;

        return GuestSession(
          guestId: data['guestId'].toString(),
          sessionToken: savedToken,
        );
      } on GuestSessionApiException catch (error) {
        // Only an invalid, expired, or revoked token
        // should trigger creation of a new session.
        if (error.statusCode != 401) {
          rethrow;
        }

        await GuestSessionStorage.deleteSessionToken();
      }
    }

    // No saved token, or the old token is invalid.
    final response = await GuestSessionApi.createSession();

    final data = response['data'] as Map<String, dynamic>;

    final guestId = data['guestId'].toString();
    final sessionToken = data['sessionToken'].toString();

    // Save the new token securely.
    await GuestSessionStorage.saveSessionToken(sessionToken);

    return GuestSession(
      guestId: guestId,
      sessionToken: sessionToken,
    );
  }

  // Log out and revoke the current session.
  static Future<void> logout() async {
    final token = await GuestSessionStorage.getSessionToken();

    if (token == null || token.isEmpty) {
      return;
    }

    await GuestSessionApi.logout(token);

    await GuestSessionStorage.deleteSessionToken();
  }
}
