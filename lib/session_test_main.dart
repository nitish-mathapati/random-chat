
import 'package:flutter/material.dart';

import 'services/guest_session_manager.dart';
import 'services/guest_session_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SessionTestApp());
}

class SessionTestApp extends StatelessWidget {
  const SessionTestApp({super.key});

  Future<String> runSessionTest() async {
    // First initialization: create or restore a guest session.
    final firstSession = await GuestSessionManager.initialize();

    // Verify that the token was saved securely.
    final savedToken =
        await GuestSessionStorage.getSessionToken();

    if (savedToken == null || savedToken.isEmpty) {
      throw Exception('Session token was not saved!');
    }

    // Second initialization: should restore the same guest.
    final secondSession = await GuestSessionManager.initialize();

    if (firstSession.guestId != secondSession.guestId) {
      throw Exception('Guest ID changed during restoration!');
    }

    return '''
Guest session test passed!

Guest ID: ${firstSession.guestId}

Token saved securely: YES

Session restored successfully: YES

Same guest ID after restoration: YES
''';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('UserChat Session Test'),
        ),
        body: Center(
          child: FutureBuilder<String>(
            future: runSessionTest(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Testing guest session...'),
                  ],
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'TEST FAILED\n\n${snapshot.error}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.data ?? 'No result',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
