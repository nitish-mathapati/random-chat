import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/video_call_screen.dart';
import 'services/guest_session_manager.dart';
import 'services/socket_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Connect',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const GuestSessionGate(),
    );
  }
}

class GuestSessionGate extends StatefulWidget {
  const GuestSessionGate({super.key});

  @override
  State<GuestSessionGate> createState() => _GuestSessionGateState();
}

class _GuestSessionGateState extends State<GuestSessionGate> {
  late Future<GuestSession> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _initializeSession();
  }

  void _initializeSession() {
    _sessionFuture = GuestSessionManager.initialize();
  }

  void _retryInitialization() {
    setState(() {
      _initializeSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GuestSession>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Initializing your guest session...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      size: 60,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Unable to connect',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'We could not initialize your guest session. '
                      'Please check your internet connection '
                      'and try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _retryInitialization,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          return SessionReadyHome(session: snapshot.data!);
        }

        return const Scaffold(
          body: Center(
            child: Text('Something went wrong. Please restart the app.'),
          ),
        );
      },
    );
  }
}

class SessionReadyHome extends StatefulWidget {
  final GuestSession session;

  const SessionReadyHome({super.key, required this.session});

  @override
  State<SessionReadyHome> createState() => _SessionReadyHomeState();
}

class _SessionReadyHomeState extends State<SessionReadyHome> {
  @override
  void initState() {
    super.initState();

    SocketService.instance.connect(widget.session.sessionToken);
  }

  void _openCameraTest() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const VideoCallScreen()));
  }

  @override
  void dispose() {
    SocketService.instance.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        HomeScreen(guestId: widget.session.guestId),
        Positioned(
          right: 16,
          bottom: 24,
          child: FloatingActionButton.extended(
            heroTag: 'camera_test_button',
            onPressed: _openCameraTest,
            icon: const Icon(Icons.videocam),
            label: const Text('Test Video Camera'),
          ),
        ),
      ],
    );
  }
}
